package test

// go test -timeout 30s . -run ^TestNftStorefront -v

import (
	"fmt"
	"strings"
	"testing"

	"github.com/onflow/cadence"
	emulator "github.com/onflow/flow-emulator"
	fttemplates "github.com/onflow/flow-ft/lib/go/templates"
	"github.com/onflow/flow-go-sdk"
	sdk "github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	sdktemplates "github.com/onflow/flow-go-sdk/templates"
	"github.com/onflow/flow-go-sdk/test"
	nftcontracts "github.com/onflow/flow-nft/lib/go/contracts"
	nfttemplates "github.com/onflow/flow-nft/lib/go/templates"
	"github.com/stretchr/testify/require"
)

const (
	nftStorefrontNftStorefrontPath   = "../../../contracts/nftStorefront.cdc"
	nftStorefrontRootPath            = "../../../transactions"
	nftStorefrontSetupAccountPath    = nftStorefrontRootPath + "/setup_account.cdc"
	nftStorefrontSellItemPath        = nftStorefrontRootPath + "/sell_item.cdc"
	nftStorefrontBuyItemPath         = nftStorefrontRootPath + "/buy_item.cdc"
	nftStorefrontRemoveItemPath      = nftStorefrontRootPath + "/remove_item.cdc"
	nftStorefrontGetIDsPath          = nftStorefrontRootPath + "/scripts/read_storefront_ids.cdc"
	nftStorefrontGetOfferDetailsPath = nftStorefrontRootPath + "/scripts/read_sale_offer_details.cdc"
)

const (
	flowTokenName         = "FlowToken"
	nonFungibleTokenName  = "NonFungibleToken"
	defaultAccountFunding = "1000.0"

	ftAddressPlaceholder            = "0xFUNGIBLETOKENADDRESS"
	flowTokenAddressPlaceHolder     = "0xFLOWTOKEN"
	nftAddressPlaceholder           = "0xNONFUNGIBLETOKEN"
	exampleNFTAddressPlaceHolder    = "0xEXAMPLENFT"
	nftStorefrontAddressPlaceholder = "0xNFTSTOREFRONT"
)

var (
	ftAddress        = flow.HexToAddress("ee82856bf20e2aa6")
	flowTokenAddress = flow.HexToAddress("0ae53cb6e3f42a79")
)

type Contracts struct {
	NFTAddress           flow.Address
	ExampleNFTAddress    flow.Address
	ExampleNFTSigner     crypto.Signer
	NFTStorefrontAddress flow.Address
	NFTStorefrontSigner  crypto.Signer
}

func deployNFTContracts(t *testing.T, b *emulator.Blockchain) (flow.Address, flow.Address, crypto.Signer) {
	nftCode := nftcontracts.NonFungibleToken()
	nftAddress, err := b.CreateAccount(nil,
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

	exampleNFTAccountKey, exampleNFTSigner := accountKeys.NewWithSigner()

	exampleNFTCode := nftcontracts.ExampleNFT(nftAddress.String())
	exampleNFTAddress, err := b.CreateAccount(
		[]*flow.AccountKey{exampleNFTAccountKey},
		[]sdktemplates.Contract{
			{
				Name:   "ExampleNFT",
				Source: string(exampleNFTCode),
			},
		},
	)
	require.NoError(t, err)

	_, err = b.CommitBlock()
	require.NoError(t, err)

	return nftAddress, exampleNFTAddress, exampleNFTSigner
}

func nftStorefrontDeployContracts(t *testing.T, b *emulator.Blockchain) Contracts {
	accountKeys := test.AccountKeyGenerator()

	nftAddress, exampleNFTAddress, exampleNFTSigner := deployNFTContracts(t, b)

	nftStorefrontAccountKey, nftStorefrontSigner := accountKeys.NewWithSigner()
	nftStorefrontCode := loadNFTStorefront(
		ftAddress.String(),
		nftAddress.String(),
	)

	nftStorefrontAddress, err := b.CreateAccount(
		[]*flow.AccountKey{nftStorefrontAccountKey},
		nil,
	)
	require.NoError(t, err)

	fundAccount(t, b, nftStorefrontAddress, defaultAccountFunding)

	tx := sdktemplates.AddAccountContract(
		nftStorefrontAddress,
		sdktemplates.Contract{
			Name:   "NFTStorefront",
			Source: string(nftStorefrontCode),
		},
	)

	tx.
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, nftStorefrontAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), exampleNFTSigner},
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
	}
}

func setupNFTStorefront(
	t *testing.T,
	b *emulator.Blockchain,
	userAddress sdk.Address,
	userSigner crypto.Signer,
	nftStorefrontAddr sdk.Address,
) {
	tx := flow.NewTransaction().
		SetScript(nftStorefrontGenerateSetupAccountScript(nftStorefrontAddr.String())).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(userAddress)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, userAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), userSigner},
		false,
	)
}

// Create a new account with the Kibble, nftStorefront, and nftStorefront resources set up.
func nftStorefrontCreateAccount(
	b *emulator.Blockchain,
	t *testing.T,
	contracts Contracts,
) (sdk.Address, crypto.Signer) {
	userAddress, userSigner, _ := createAccount(t, b)

	setupNFTStorefront(t, b, userAddress, userSigner, contracts.NFTStorefrontAddress)
	setupExampleNFTCollection(t, b, userAddress, userSigner, contracts.NFTAddress, contracts.ExampleNFTAddress)
	fundAccount(t, b, userAddress, defaultAccountFunding)

	return userAddress, userSigner
}

func nftStorefrontSellItem(
	t *testing.T,
	b *emulator.Blockchain,
	contracts Contracts,
	userAddress sdk.Address,
	userSigner crypto.Signer,
	tokenID uint64,
	price string,
	shouldFail bool,
) uint64 {
	tx := flow.NewTransaction().
		SetScript(nftStorefrontGenerateSellItemScript(contracts)).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(userAddress)

	tx.AddArgument(cadence.NewUInt64(tokenID))
	tx.AddArgument(cadenceUFix64(price))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, userAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), userSigner},
		shouldFail,
	)

	// Get the most recently created SaleOfferAvailable event resource ID
	eventType := fmt.Sprintf("A.%s.NFTStorefront.SaleOfferAvailable", contracts.NFTStorefrontAddress.Hex())
	saleOfferResourceID := uint64(0)

	var i uint64
	i = 0
	for i < 1000 {
		results, _ := b.GetEventsByHeight(i, eventType)
		for _, event := range results {
			if event.Type == eventType {
				saleOfferResourceID = event.Value.Fields[0].(cadence.UInt64).ToGoValue().(uint64)
			}
		}
		i = i + 1
	}

	return saleOfferResourceID
}

func nftStorefrontBuyItem(
	b *emulator.Blockchain,
	t *testing.T,
	contracts Contracts,
	userAddress sdk.Address,
	userSigner crypto.Signer,
	marketCollectionAddress sdk.Address,
	offerResourceID uint64,
	shouldFail bool,
) {
	tx := flow.NewTransaction().
		SetScript(nftStorefrontGenerateBuyItemScript(contracts)).
		SetGasLimit(200).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(userAddress)

	tx.AddArgument(cadence.NewUInt64(offerResourceID))
	tx.AddArgument(cadence.NewAddress(marketCollectionAddress))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, userAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), userSigner},
		shouldFail,
	)
}

func nftStorefrontRemoveItem(
	b *emulator.Blockchain,
	t *testing.T,
	contracts Contracts,
	userAddress sdk.Address,
	userSigner crypto.Signer,
	offerResourceID uint64,
	shouldFail bool,
) {
	tx := flow.NewTransaction().
		SetScript(nftStorefrontGenerateRemoveItemScript(contracts)).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(userAddress)

	tx.AddArgument(cadence.NewUInt64(offerResourceID))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, userAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), userSigner},
		shouldFail,
	)
}

func TestNFTStorefrontDeployContracts(t *testing.T) {
	b := newEmulator()
	nftStorefrontDeployContracts(t, b)
}

func TestNFTStorefrontSetupAccount(t *testing.T) {
	b := newEmulator()

	contracts := nftStorefrontDeployContracts(t, b)

	t.Run("Should be able to create an empty Collection", func(t *testing.T) {
		userAddress, userSigner, _ := createAccount(t, b)
		setupNFTStorefront(t, b, userAddress, userSigner, contracts.NFTStorefrontAddress)
	})
}

func TestNFTStorefrontCreateSaleSell(t *testing.T) {
	b := newEmulator()

	contracts := nftStorefrontDeployContracts(t, b)

	t.Run("Should be able to list a sale offer", func(t *testing.T) {
		tokenToList := uint64(0)
		tokenPrice := "1.11"
		userAddress, userSigner := nftStorefrontCreateAccount(b, t, contracts)

		// Contract mints item to user account
		mintExampleNFT(
			t,
			b,
			userAddress,
			contracts.NFTAddress,
			contracts.ExampleNFTAddress,
			contracts.ExampleNFTSigner,
		)

		// User account lists the item
		nftStorefrontSellItem(
			t,
			b,
			contracts,
			userAddress,
			userSigner,
			tokenToList,
			tokenPrice,
			false,
		)
	})

	t.Run("Should be able to accept a sale offer", func(t *testing.T) {
		tokenToList := uint64(1)
		tokenPrice := "1.11"
		userAddress, userSigner := nftStorefrontCreateAccount(b, t, contracts)

		// Contract mints item to user account
		mintExampleNFT(
			t,
			b,
			userAddress,
			contracts.NFTAddress,
			contracts.ExampleNFTAddress,
			contracts.ExampleNFTSigner,
		)

		// User account lists the item
		saleOfferResourceID := nftStorefrontSellItem(
			t,
			b,
			contracts,
			userAddress,
			userSigner,
			tokenToList,
			tokenPrice,
			false,
		)

		buyerAddress, buyerSigner := nftStorefrontCreateAccount(b, t, contracts)

		// Make the purchase
		nftStorefrontBuyItem(
			b,
			t,
			contracts,
			buyerAddress,
			buyerSigner,
			userAddress,
			saleOfferResourceID,
			false,
		)
	})

	t.Run("Should be able to remove a sale offer", func(t *testing.T) {
		tokenToList := uint64(2)
		tokenPrice := "1.11"
		userAddress, userSigner := nftStorefrontCreateAccount(b, t, contracts)

		// Contract mints item to user account
		mintExampleNFT(
			t,
			b,
			userAddress,
			contracts.NFTAddress,
			contracts.ExampleNFTAddress,
			contracts.ExampleNFTSigner,
		)

		// User account lists the item
		saleOfferResourceID := nftStorefrontSellItem(
			t,
			b,
			contracts,
			userAddress,
			userSigner,
			tokenToList,
			tokenPrice,
			false,
		)

		// Cancel the sale
		nftStorefrontRemoveItem(
			b,
			t,
			contracts,
			userAddress,
			userSigner,
			saleOfferResourceID,
			false,
		)
	})
}

func replaceNFTStorefrontAddressPlaceholders(codeBytes []byte, contracts Contracts) []byte {
	code := string(codeBytes)

	code = strings.ReplaceAll(code, ftAddressPlaceholder, "0x"+ftAddress.String())
	code = strings.ReplaceAll(code, flowTokenAddressPlaceHolder, "0x"+flowTokenAddress.String())
	code = strings.ReplaceAll(code, nftAddressPlaceholder, "0x"+contracts.NFTAddress.String())
	code = strings.ReplaceAll(code, exampleNFTAddressPlaceHolder, "0x"+contracts.ExampleNFTAddress.String())
	code = strings.ReplaceAll(code, nftStorefrontAddressPlaceholder, "0x"+contracts.NFTStorefrontAddress.String())

	return []byte(code)
}

func loadNFTStorefront(ftAddr, nftAddr string) []byte {
	code := string(readFile(nftStorefrontNftStorefrontPath))

	code = strings.ReplaceAll(code, ftAddressPlaceholder, "0x"+ftAddr)
	code = strings.ReplaceAll(code, nftAddressPlaceholder, "0x"+nftAddr)

	return []byte(code)
}

func nftStorefrontGenerateSetupAccountScript(nftStorefrontAddr string) []byte {
	code := string(readFile(nftStorefrontSetupAccountPath))

	code = strings.ReplaceAll(code, nftStorefrontAddressPlaceholder, "0x"+nftStorefrontAddr)

	return []byte(code)
}

func nftStorefrontGenerateSellItemScript(contracts Contracts) []byte {
	return replaceNFTStorefrontAddressPlaceholders(
		readFile(nftStorefrontSellItemPath),
		contracts,
	)
}

func nftStorefrontGenerateBuyItemScript(contracts Contracts) []byte {
	return replaceNFTStorefrontAddressPlaceholders(
		readFile(nftStorefrontBuyItemPath),
		contracts,
	)
}

func nftStorefrontGenerateRemoveItemScript(contracts Contracts) []byte {
	return replaceNFTStorefrontAddressPlaceholders(
		readFile(nftStorefrontRemoveItemPath),
		contracts,
	)
}

func nftStorefrontGenerateGetIDsScript(contracts Contracts) []byte {
	return replaceNFTStorefrontAddressPlaceholders(
		readFile(nftStorefrontGetIDsPath),
		contracts,
	)
}

func nftStorefrontGenerateGetOfferDetailsScript(contracts Contracts) []byte {
	return replaceNFTStorefrontAddressPlaceholders(
		readFile(nftStorefrontGetOfferDetailsPath),
		contracts,
	)
}

func setupExampleNFTCollection(
	t *testing.T,
	b *emulator.Blockchain,
	userAddress flow.Address,
	userSigner crypto.Signer,
	nftAddress, exampleNFTAddress flow.Address,
) {
	script := nfttemplates.GenerateCreateCollectionScript(
		nftAddress.String(),
		exampleNFTAddress.String(),
		"ExampleNFT",
		"exampleNFTCollection",
	)

	tx := flow.NewTransaction().
		SetScript(script).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(userAddress)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, userAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), userSigner},
		false,
	)
}

func mintExampleNFT(
	t *testing.T,
	b *emulator.Blockchain,
	receiverAddress flow.Address,
	nftAddress, exampleNFTAddress flow.Address,
	exampleNFTSigner crypto.Signer,
) {
	script := nfttemplates.GenerateMintNFTScript(nftAddress, exampleNFTAddress, receiverAddress)

	tx := flow.NewTransaction().
		SetScript(script).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(exampleNFTAddress)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, exampleNFTAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), exampleNFTSigner},
		false,
	)
}

func fundAccount(
	t *testing.T,
	b *emulator.Blockchain,
	receiverAddress flow.Address,
	amount string,
) {
	script := fttemplates.GenerateMintTokensScript(
		ftAddress,
		flowTokenAddress,
		flowTokenName,
	)

	tx := flow.NewTransaction().
		SetScript(script).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(b.ServiceKey().Address)

	tx.AddArgument(cadence.NewAddress(receiverAddress))
	tx.AddArgument(cadenceUFix64(amount))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address},
		[]crypto.Signer{b.ServiceKey().Signer()},
		false,
	)
}
