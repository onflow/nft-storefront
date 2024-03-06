package test

import (
	"context"
	"io/ioutil"
	"regexp"
	"testing"

	"github.com/onflow/cadence"
	"github.com/onflow/flow-emulator/adapters"
	"github.com/onflow/flow-emulator/convert"
	"github.com/onflow/flow-emulator/emulator"
	ftcontracts "github.com/onflow/flow-ft/lib/go/contracts"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	sdktemplates "github.com/onflow/flow-go-sdk/templates"
	"github.com/onflow/flow-go-sdk/test"
	nftcontracts "github.com/onflow/flow-nft/lib/go/contracts"
	"github.com/rs/zerolog"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	sdk "github.com/onflow/flow-go-sdk"
)

const (
	flowTokenName           = "FlowToken"
	nonFungibleTokenName    = "NonFungibleToken"
	defaultAccountFunding   = "1000.0"
	emulatorFTAddress       = "ee82856bf20e2aa6"
	metadataViewsAddress    = "f8d6e0586b0a20c7"
	NonFungibleTokenAddress = "f8d6e0586b0a20c7"
)

var (
	ftAddressPlaceholder            = regexp.MustCompile(`"[^"\s].*/FungibleToken(.cdc)?"`)
	flowTokenAddressPlaceHolder     = regexp.MustCompile(`"[^"\s].*/FlowToken(.cdc)?"`)
	nftAddressPlaceholder           = regexp.MustCompile(`"[^"\s].*/NonFungibleToken(.cdc)?"`)
	exampleNFTAddressPlaceHolder    = regexp.MustCompile(`"[^"\s].*/ExampleNFT(.cdc)?"`)
	nftStorefrontAddressPlaceholder = regexp.MustCompile(`"[^"\s].*/NFTStorefront(.cdc)?"`)
	metadataViewsAddressPlaceholder = regexp.MustCompile(`"[^"\s].*/MetadataViews(.cdc)?"`)
	exampleTokenAddressPlaceholder  = regexp.MustCompile(`"[^"\s].*/ExampleToken(.cdc)?"`)
)

var (
	ftAddress        = flow.HexToAddress("ee82856bf20e2aa6")
	flowTokenAddress = flow.HexToAddress("0ae53cb6e3f42a79")
)

type Contracts struct {
	NFTAddress                        flow.Address
	ExampleNFTAddress                 flow.Address
	ExampleNFTSigner                  crypto.Signer
	ExampleTokenAddress               flow.Address
	ExampleTokenSigner                crypto.Signer
	NFTStorefrontAddress              flow.Address
	NFTStorefrontSigner               crypto.Signer
	MetadataViewsAddress              flow.Address
	FungibleTokenMetadataViewsAddress flow.Address
	FungibleTokenMetadataViewsSigner  crypto.Signer
}

func deployExampleContracts(t *testing.T, b emulator.Emulator, a *adapters.SDKAdapter) (flow.Address, flow.Address, flow.Address, flow.Address, flow.Address, crypto.Signer, crypto.Signer, crypto.Signer) {

	accountKeys := test.AccountKeyGenerator()

	exampleNFTAccountKey, exampleNFTSigner := accountKeys.NewWithSigner()

	exampleNFTCode := nftcontracts.ExampleNFT(flow.HexToAddress(NonFungibleTokenAddress), flow.HexToAddress(metadataViewsAddress), flow.HexToAddress(metadataViewsAddress))
	exampleNFTAddress, err := a.CreateAccount(
		context.Background(),
		[]*flow.AccountKey{exampleNFTAccountKey},
		[]sdktemplates.Contract{
			{
				Name:   "ExampleNFT",
				Source: string(exampleNFTCode),
			},
		},
	)
	require.NoError(t, err)

	fungibleTokenMetadataViewsAccountKey, fungibleTokenMetadataViewsSigner := accountKeys.NewWithSigner()
	fungibleTokenMetadataViews := ftcontracts.FungibleTokenMetadataViews(emulatorFTAddress, metadataViewsAddress, metadataViewsAddress)
	ftMetadataViewsAddress, err := a.CreateAccount(
		context.Background(),
		[]*flow.AccountKey{fungibleTokenMetadataViewsAccountKey},
		[]sdktemplates.Contract{
			{
				Name:   "FungibleTokenMetadataViews",
				Source: string(fungibleTokenMetadataViews),
			},
		},
	)

	exampleTokenAccountKey, exampleTokenSigner := accountKeys.NewWithSigner()
	exampleTokenCode := ftcontracts.ExampleToken(emulatorFTAddress, metadataViewsAddress, ftMetadataViewsAddress.String(), metadataViewsAddress)

	exampleTokenAddress, err := a.CreateAccount(
		context.Background(),
		[]*flow.AccountKey{exampleTokenAccountKey},
		[]sdktemplates.Contract{
			{
				Name:   "ExampleToken",
				Source: string(exampleTokenCode),
			},
		},
	)

	_, err = b.CommitBlock()
	require.NoError(t, err)

	return flow.HexToAddress(NonFungibleTokenAddress), exampleNFTAddress, exampleTokenAddress, flow.HexToAddress(metadataViewsAddress), ftMetadataViewsAddress, exampleNFTSigner, exampleTokenSigner, fungibleTokenMetadataViewsSigner
}

func nftStorefrontDeployContracts(t *testing.T, b emulator.Emulator, a *adapters.SDKAdapter, version int) Contracts {
	accountKeys := test.AccountKeyGenerator()

	nftAddress, exampleNFTAddress, exampleTokenAddress, metadataAddress, ftMetadataViewsAddress, exampleNFTSigner, exampleTokenSigner, ftMetadataViewsSigner := deployExampleContracts(t, b, a)

	nftStorefrontAccountKey, nftStorefrontSigner := accountKeys.NewWithSigner()
	nftStorefrontCode, nftStorefrontName := loadNFTStorefront(ftAddress, nftAddress, version)

	nftStorefrontAddress, err := a.CreateAccount(
		context.Background(),
		[]*flow.AccountKey{nftStorefrontAccountKey},
		nil,
	)
	require.NoError(t, err)

	contracts := Contracts{
		nftAddress,
		exampleNFTAddress,
		exampleNFTSigner,
		exampleTokenAddress,
		exampleTokenSigner,
		nftStorefrontAddress,
		nftStorefrontSigner,
		metadataAddress,
		ftMetadataViewsAddress,
		ftMetadataViewsSigner,
	}

	setupExampleTokenVault(t, b, a, nftStorefrontAddress, nftStorefrontSigner, ftAddress, contracts.ExampleTokenAddress, flow.HexToAddress(metadataViewsAddress), contracts.MetadataViewsAddress, contracts.FungibleTokenMetadataViewsAddress)
	fundAccount(t, b, a, nftStorefrontAddress, contracts, defaultAccountFunding)

	tx := sdktemplates.AddAccountContract(
		nftStorefrontAddress,
		sdktemplates.Contract{
			Name:   nftStorefrontName,
			Source: string(nftStorefrontCode),
		},
	)

	tx.
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address)

	serviceSigner, _ := b.ServiceKey().Signer()

	signAndSubmit(
		t, b, a, tx,
		[]flow.Address{b.ServiceKey().Address, nftStorefrontAddress},
		[]crypto.Signer{serviceSigner, exampleNFTSigner},
		false,
	)

	_, err = b.CommitBlock()
	require.NoError(t, err)

	return contracts
}

// newEmulator returns a emulator object for testing
func newEmulator() (*emulator.Blockchain, *adapters.SDKAdapter) {
	b, err := emulator.New(
		append(
			[]emulator.Option{
				// No storage limit
				emulator.WithStorageLimitEnabled(false),
			},
		)...,
	)
	if err != nil {
		panic(err)
	}

	logger := zerolog.Nop()
	adapter := adapters.NewSDKAdapter(&logger, b)

	return b, adapter
}

// signAndSubmit signs a transaction with an array of signers and adds their signatures to the transaction
// Then submits the transaction to the emulator. If the private keys don't match up with the addresses,
// the transaction will not succeed.
// shouldRevert parameter indicates whether the transaction should fail or not
// This function asserts the correct result and commits the block if it passed
func signAndSubmit(
	t *testing.T,
	b emulator.Emulator,
	a *adapters.SDKAdapter,
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

	submit(t, b, a, tx, shouldRevert)
}

// submit submits a transaction and checks
// if it fails or not
func submit(
	t *testing.T,
	b emulator.Emulator,
	a *adapters.SDKAdapter,
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
func createAccount(t *testing.T, b emulator.Emulator, a *adapters.SDKAdapter) (sdk.Address, crypto.Signer) {
	accountKeys := test.AccountKeyGenerator()
	accountKey, signer := accountKeys.NewWithSigner()

	address, err := a.CreateAccount(context.Background(), []*sdk.AccountKey{accountKey}, nil)
	require.NoError(t, err)

	return address, signer
}

func setupNFTStorefront(
	t *testing.T,
	b emulator.Emulator,
	a *adapters.SDKAdapter,
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
		t, b, a, tx,
		[]flow.Address{b.ServiceKey().Address, userAddress},
		[]crypto.Signer{serviceSigner, userSigner},
		false,
	)
}

func setupAccount(
	t *testing.T,
	b emulator.Emulator,
	a *adapters.SDKAdapter,
	address flow.Address,
	signer crypto.Signer,
	contracts Contracts,
) (sdk.Address, crypto.Signer) {
	setupNFTStorefront(t, b, a, address, signer, contracts)
	setupExampleNFTCollection(t, b, a, address, signer, contracts.NFTAddress, contracts.ExampleNFTAddress, contracts.MetadataViewsAddress)
	setupExampleTokenVault(t, b, a, address, signer, ftAddress, contracts.ExampleTokenAddress, flow.HexToAddress(metadataViewsAddress), contracts.MetadataViewsAddress, contracts.FungibleTokenMetadataViewsAddress)
	fundAccount(t, b, a, address, contracts, defaultAccountFunding)

	return address, signer
}

// Deploy a contract to a new account with the specified name, code, and keys
func deploy(
	t *testing.T,
	b emulator.Emulator,
	a *adapters.SDKAdapter,
	name string,
	code []byte,
	keys ...*flow.AccountKey,
) flow.Address {
	address, err := a.CreateAccount(
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
