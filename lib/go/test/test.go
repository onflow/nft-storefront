package test

import (
	"context"
	"github.com/onflow/flow-emulator/convert"
	"io/ioutil"
	"regexp"
	"testing"

	"github.com/onflow/cadence"
	"github.com/onflow/flow-emulator/adapters"
	"github.com/onflow/flow-emulator/emulator"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	sdktemplates "github.com/onflow/flow-go-sdk/templates"
	"github.com/onflow/flow-go-sdk/test"
	"github.com/onflow/flow-nft/lib/go/contracts"
	nftcontracts "github.com/onflow/flow-nft/lib/go/contracts"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	ftcontracts "github.com/onflow/flow-ft/lib/go/contracts"

	sdk "github.com/onflow/flow-go-sdk"
	"github.com/rs/zerolog"
)

const (
	flowTokenName         = "FlowToken"
	nonFungibleTokenName  = "NonFungibleToken"
	defaultAccountFunding = "1000.0"
	emulatorFTAddress     = "ee82856bf20e2aa6"
)

var (
	ftAddressPlaceholder            = regexp.MustCompile(`"[^"\s].*/FungibleToken.cdc"`)
	flowTokenAddressPlaceHolder     = regexp.MustCompile(`"[^"\s].*/FlowToken.cdc"`)
	nftAddressPlaceholder           = regexp.MustCompile(`"[^"\s].*/NonFungibleToken.cdc"`)
	exampleNFTAddressPlaceHolder    = regexp.MustCompile(`"[^"\s].*/ExampleNFT.cdc"`)
	nftStorefrontAddressPlaceholder = regexp.MustCompile(`"[^"\s].*/NFTStorefront.cdc"`)
)

var (
	ftAddress        = flow.HexToAddress("ee82856bf20e2aa6")
	flowTokenAddress = flow.HexToAddress("0ae53cb6e3f42a79")
)

type Contracts struct {
	NFTAddress             flow.Address
	ExampleNFTAddress      flow.Address
	ExampleNFTSigner       crypto.Signer
	NFTStorefrontAddress   flow.Address
	NFTStorefrontSigner    crypto.Signer
	ViewResolverAddress    flow.Address
	MetadataViewsAddress   flow.Address
	FTMetadataViewsAddress flow.Address
	ExampleFTAddress       flow.Address
	exampleFTSigner        crypto.Signer
}

func deployNFTAndFTContracts(t *testing.T, b *emulator.Blockchain) (flow.Address, flow.Address, flow.Address, flow.Address, flow.Address, flow.Address, crypto.Signer, crypto.Signer) {
	logger := zerolog.Nop()
	adapter := adapters.NewSDKAdapter(&logger, b)

	resolverAddress := deploy(t, b, "ViewResolver", contracts.ViewResolver())

	nftCode := nftcontracts.NonFungibleToken(resolverAddress)

	nftAddress, err := adapter.CreateAccount(context.Background(),
		nil,
		[]sdktemplates.Contract{
			{
				Name:   nonFungibleTokenName,
				Source: string(nftCode),
			},
		},
	)

	require.NoError(t, err)

	_, err = b.CommitBlock()
	require.NoError(t, err)

	accountKeys := test.AccountKeyGenerator()

	metadataAddress := deploy(t, b, "MetadataViews", contracts.MetadataViews(flow.HexToAddress(emulatorFTAddress), nftAddress, resolverAddress))

	ftMetadataAddress := deploy(t, b, "FungibleTokenMetadataViews", ftcontracts.FungibleTokenMetadataViews(ftAddress.String(), metadataAddress.String(), resolverAddress.String()))

	exampleNFTAccountKey, exampleNFTSigner := accountKeys.NewWithSigner()

	exampleNFTCode := nftcontracts.ExampleNFT(nftAddress, metadataAddress, resolverAddress)
	exampleNFTAddress := deploy(t, b, "ExampleNFT", exampleNFTCode, exampleNFTAccountKey)

	exampleTokenAccountKey, exampleFTSigner := accountKeys.NewWithSigner()

	exampleFTCode := ftcontracts.ExampleToken(ftAddress.String(), metadataAddress.String(), ftMetadataAddress.String(), resolverAddress.String())
	exampleFTAddress := deploy(t, b, "ExampleToken", exampleFTCode, exampleTokenAccountKey)

	require.NoError(t, err)

	_, err = b.CommitBlock()
	require.NoError(t, err)

	return nftAddress, exampleNFTAddress, metadataAddress, resolverAddress, ftMetadataAddress, exampleFTAddress, exampleNFTSigner, exampleFTSigner
}

func nftStorefrontDeployContracts(t *testing.T, b *emulator.Blockchain) Contracts {
	accountKeys := test.AccountKeyGenerator()

	nftAddress, exampleNFTAddress, metadataAddress, resolverAddress, ftMetadataAddress, exampleFTAddress, exampleNFTSigner, exampleFTSigner := deployNFTAndFTContracts(t, b)

	nftStorefrontAccountKey, nftStorefrontSigner := accountKeys.NewWithSigner()
	nftStorefrontCode := loadNFTStorefront(ftAddress, nftAddress)

	logger := zerolog.Nop()
	adapter := adapters.NewSDKAdapter(&logger, b)
	nftStorefrontAddress, err := adapter.CreateAccount(
		context.Background(),
		[]*flow.AccountKey{nftStorefrontAccountKey},
		nil,
	)

	require.NoError(t, err)

	setupExampleTokenVault(t, b, nftStorefrontAddress, nftStorefrontSigner, ftAddress, exampleFTAddress, resolverAddress, metadataAddress, ftMetadataAddress)
	fundAccount(t, b, exampleFTAddress, exampleFTSigner, metadataAddress, ftMetadataAddress, resolverAddress, nftStorefrontAddress, defaultAccountFunding)

	tx := sdktemplates.AddAccountContract(
		nftStorefrontAddress,
		sdktemplates.Contract{
			Name:   "NFTStorefront",
			Source: string(nftStorefrontCode),
		},
	)

	tx.
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address)

	serviceSigner, _ := b.ServiceKey().Signer()

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, nftStorefrontAddress},
		[]crypto.Signer{serviceSigner, exampleNFTSigner},
		false,
	)

	_, err = b.CommitBlock()
	require.NoError(t, err)

	return Contracts{
		nftAddress,
		exampleNFTAddress,
		exampleNFTSigner,
		nftStorefrontAddress,
		nftStorefrontSigner,
		resolverAddress,
		metadataAddress,
		ftMetadataAddress,
		exampleFTAddress,
		exampleFTSigner,
	}
}

// newEmulator returns a emulator object for testing
func newEmulator() *emulator.Blockchain {

	b, err := emulator.New(emulator.WithStorageLimitEnabled(false))
	if err != nil {
		panic(err)
	}
	return b
}

// signAndSubmit signs a transaction with an array of signers and adds their signatures to the transaction
// Then submits the transaction to the emulator. If the private keys don't match up with the addresses,
// the transaction will not succeed.
// shouldRevert parameter indicates whether the transaction should fail or not
// This function asserts the correct result and commits the block if it passed
func signAndSubmit(
	t *testing.T,
	b *emulator.Blockchain,
	tx *flow.Transaction,
	signerAddresses []flow.Address,
	signers []crypto.Signer,
	shouldRevert bool,
) {
	// sign transaction with each signer
	for i := len(signerAddresses) - 1; i >= 0; i-- {
		signerAddress := signerAddresses[i]
		signer := signers[i]

		if i == 0 {
			err := tx.SignEnvelope(signerAddress, 0, signer)
			assert.NoError(t, err)
		} else {
			err := tx.SignPayload(signerAddress, 0, signer)
			assert.NoError(t, err)
		}
	}

	submit(t, b, tx, shouldRevert)
}

// submit submits a transaction and checks
// if it fails or not
func submit(
	t *testing.T,
	b *emulator.Blockchain,
	tx *flow.Transaction,
	shouldRevert bool,
) {
	// submit the signed transaction
	flowTx := convert.SDKTransactionToFlow(*tx)
	err := b.AddTransaction(*flowTx)
	require.NoError(t, err)

	result, err := b.ExecuteNextTransaction()
	require.NoError(t, err)

	if shouldRevert {
		assert.True(t, result.Reverted())
	} else {
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
	}

	_, err = b.CommitBlock()
	assert.NoError(t, err)
}

// executeScriptAndCheck executes a script and checks to make sure that it succeeded.
func executeScriptAndCheck(t *testing.T, b *emulator.Blockchain, script []byte, arguments [][]byte) cadence.Value {
	result, err := b.ExecuteScript(script, arguments)
	require.NoError(t, err)
	if !assert.True(t, result.Succeeded()) {
		t.Log(result.Error.Error())
	}

	return result.Value
}

// readFile reads a file from the file system
// and returns its contents
func readFile(path string) []byte {
	contents, err := ioutil.ReadFile(path)
	if err != nil {
		panic(err)
	}
	return contents
}

// cadenceUFix64 returns a UFix64 value
func cadenceUFix64(value string) cadence.Value {
	newValue, err := cadence.NewUFix64(value)
	if err != nil {
		panic(err)
	}

	return newValue
}

// cadenceString returns a String value
func cadenceString(value string) cadence.Value {
	newValue, err := cadence.NewString(value)
	if err != nil {
		panic(err)
	}

	return newValue
}

// Simple error-handling wrapper for Flow account creation.
func createAccount(t *testing.T, b *emulator.Blockchain) (sdk.Address, crypto.Signer) {
	accountKeys := test.AccountKeyGenerator()
	accountKey, signer := accountKeys.NewWithSigner()

	logger := zerolog.Nop()
	adapter := adapters.NewSDKAdapter(&logger, b)
	address, err := adapter.CreateAccount(
		context.Background(),
		[]*sdk.AccountKey{accountKey},
		nil,
	)

	require.NoError(t, err)

	return address, signer
}

func setupNFTStorefront(
	t *testing.T,
	b *emulator.Blockchain,
	userAddress sdk.Address,
	userSigner crypto.Signer,
	contracts Contracts,
) {
	tx := flow.NewTransaction().
		SetScript(nftStorefrontGenerateSetupAccountScript(contracts)).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(userAddress)

	serviceSigner, _ := b.ServiceKey().Signer()

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, userAddress},
		[]crypto.Signer{serviceSigner, userSigner},
		false,
	)
}

func setupAccount(
	t *testing.T,
	b *emulator.Blockchain,
	address flow.Address,
	signer crypto.Signer,
	contracts Contracts,
) (sdk.Address, crypto.Signer) {
	setupNFTStorefront(t, b, address, signer, contracts)
	setupExampleNFTCollection(t, b, address, signer, contracts.NFTAddress, contracts.ExampleNFTAddress, contracts.MetadataViewsAddress)
	setupExampleTokenVault(t, b, address, signer, ftAddress, contracts.ExampleFTAddress, contracts.ViewResolverAddress, contracts.MetadataViewsAddress, contracts.FTMetadataViewsAddress)
	fundAccount(t, b, contracts.ExampleFTAddress, contracts.exampleFTSigner, contracts.MetadataViewsAddress, contracts.FTMetadataViewsAddress, contracts.ViewResolverAddress, address, defaultAccountFunding)

	return address, signer
}

// Deploy a contract to a new account with the specified name, code, and keys
func deploy(
	t *testing.T,
	b *emulator.Blockchain,
	name string,
	code []byte,
	keys ...*flow.AccountKey,
) flow.Address {
	logger := zerolog.Nop()
	adapter := adapters.NewSDKAdapter(&logger, b)
	address, err := adapter.CreateAccount(
		context.Background(),
		keys,
		[]sdktemplates.Contract{
			{
				Name:   name,
				Source: string(code),
			},
		},
	)
	assert.NoError(t, err)

	return address
}
