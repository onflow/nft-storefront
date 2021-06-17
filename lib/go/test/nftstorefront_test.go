package test

// go test -timeout 30s . -run ^TestNftStorefront -v

import (
	"fmt"
	"strings"
	"testing"

	"github.com/onflow/cadence"
	emulator "github.com/onflow/flow-emulator"
	"github.com/onflow/flow-go-sdk"
	sdk "github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	sdktemplates "github.com/onflow/flow-go-sdk/templates"
	"github.com/onflow/flow-go-sdk/test"
	"github.com/stretchr/testify/assert"
)

const (
	nftStorefrontRootPath            = "../../../cadence/nftStorefront"
	nftStorefrontNftStorefrontPath   = nftStorefrontRootPath + "/contracts/nftStorefront.cdc"
	nftStorefrontSetupAccountPath    = nftStorefrontRootPath + "/transactions/setup_account.cdc"
	nftStorefrontSellItemPath        = nftStorefrontRootPath + "/transactions/sell_item.cdc"
	nftStorefrontBuyItemPath         = nftStorefrontRootPath + "/transactions/buy_item.cdc"
	nftStorefrontRemoveItemPath      = nftStorefrontRootPath + "/transactions/remove_item.cdc"
	nftStorefrontGetIDsPath          = nftStorefrontRootPath + "/scripts/read_storefront_ids.cdc"
	nftStorefrontGetOfferDetailsPath = nftStorefrontRootPath + "/scripts/read_sale_offer_details.cdc"
)

type TestNftContractsInfo struct {
	FTAddr              flow.Address
	KibbleAddr          flow.Address
	KibbleSigner        crypto.Signer
	NFTAddr             flow.Address
	KittyItemsAddr      flow.Address
	KittyItemsSigner    crypto.Signer
	NFTStorefrontAddr   flow.Address
	NFTStorefrontSigner crypto.Signer
}

func nftStorefrontDeployContracts(b *emulator.Blockchain, t *testing.T) TestNftContractsInfo {
	accountKeys := test.AccountKeyGenerator()

	ftAddr, kibbleAddr, kibbleSigner := KibbleDeployContracts(b, t)
	nftAddr, kittyItemsAddr, kittyItemsSigner := KittyItemsDeployContracts(b, t)

	// Should be able to deploy a contract as a new account with one key.
	nftStorefrontAccountKey, nftStorefrontSigner := accountKeys.NewWithSigner()
	nftStorefrontCode := loadNftStorefront(
		ftAddr.String(),
		nftAddr.String(),
	)

	nftStorefrontAddr, err := b.CreateAccount(
		[]*flow.AccountKey{nftStorefrontAccountKey},
		[]sdktemplates.Contract{
			{
				Name:   "NFTStorefront",
				Source: string(nftStorefrontCode),
			},
		})
	if !assert.NoError(t, err) {
		t.Log(err.Error())
	}
	_, err = b.CommitBlock()
	assert.NoError(t, err)

	// Simplify the workflow by having contract addresses also be our initial test collections.
	KibbleSetupAccount(t, b, kibbleAddr, kibbleSigner, ftAddr, kibbleAddr)
	KittyItemsSetupAccount(t, b, kittyItemsAddr, kittyItemsSigner, nftAddr, kittyItemsAddr)
	nftStorefrontSetupAccount(b, t, nftStorefrontAddr, nftStorefrontSigner, nftStorefrontAddr)

	return TestNftContractsInfo{
		ftAddr,
		kibbleAddr,
		kibbleSigner,
		nftAddr,
		kittyItemsAddr,
		kittyItemsSigner,
		nftStorefrontAddr,
		nftStorefrontSigner,
	}
}

func nftStorefrontSetupAccount(b *emulator.Blockchain, t *testing.T, userAddress sdk.Address, userSigner crypto.Signer, nftStorefrontAddr sdk.Address) {
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

// Create a new account with the Kibble and KittyItems resources set up BUT no Storefront resource.
func nftStorefrontCreatePurchaserAccount(b *emulator.Blockchain, t *testing.T, contracts TestNftContractsInfo) (sdk.Address, crypto.Signer) {
	userAddress, userSigner, _ := createAccount(t, b)

	KibbleSetupAccount(t, b, userAddress, userSigner, contracts.FTAddr, contracts.KibbleAddr)
	KittyItemsSetupAccount(t, b, userAddress, userSigner, contracts.NFTAddr, contracts.KittyItemsAddr)

	return userAddress, userSigner
}

// Create a new account with the Kibble, nftStorefront, and nftStorefront resources set up.
func nftStorefrontCreateAccount(b *emulator.Blockchain, t *testing.T, contracts TestNftContractsInfo) (sdk.Address, crypto.Signer) {
	userAddress, userSigner := nftStorefrontCreatePurchaserAccount(b, t, contracts)
	nftStorefrontSetupAccount(b, t, userAddress, userSigner, contracts.NFTStorefrontAddr)
	return userAddress, userSigner
}

func nftStorefrontSellItem(b *emulator.Blockchain, t *testing.T, contracts TestNftContractsInfo, userAddress sdk.Address, userSigner crypto.Signer, tokenID uint64, price string, shouldFail bool) uint64 {
	tx := flow.NewTransaction().
		SetScript(nftStorefrontGenerateSellItemScript(contracts)).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(userAddress)

	tx.AddArgument(cadence.NewUInt64(tokenID))
	tx.AddArgument(CadenceUFix64(price))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, userAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), userSigner},
		shouldFail,
	)

	// Get the most recently created SaleOfferAvailable event resource ID
	eventType := fmt.Sprintf("A.%s.NFTStorefront.SaleOfferAvailable", contracts.NFTStorefrontAddr.Hex())
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
	contracts TestNftContractsInfo,
	userAddress sdk.Address,
	userSigner crypto.Signer,
	marketCollectionAddress sdk.Address,
	offerResourceID uint64,
	shouldFail bool,
) {
	tx := flow.NewTransaction().
		SetScript(nftStorefrontGenerateBuyItemScript(contracts)).
		SetGasLimit(100).
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
	contracts TestNftContractsInfo,
	userAddress sdk.Address,
	userSigner crypto.Signer,
	marketCollectionAddress sdk.Address,
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

func TestNftStorefrontDeployContracts(t *testing.T) {
	b := newEmulator()
	nftStorefrontDeployContracts(b, t)
}

func TestNftStorefrontSetupAccount(t *testing.T) {
	b := newEmulator()

	contracts := nftStorefrontDeployContracts(b, t)

	t.Run("Should be able to create an empty Collection", func(t *testing.T) {
		userAddress, userSigner, _ := createAccount(t, b)
		nftStorefrontSetupAccount(b, t, userAddress, userSigner, contracts.NFTStorefrontAddr)
	})
}

func TestNftStorefrontCreateSaleSell(t *testing.T) {
	b := newEmulator()

	contracts := nftStorefrontDeployContracts(b, t)

	t.Run("Should be able to list a sale offer", func(t *testing.T) {
		tokenToList := uint64(0)
		tokenPrice := "1.11"
		userAddress, userSigner := nftStorefrontCreateAccount(b, t, contracts)

		// Contract mints item
		KittyItemsMintItem(
			b,
			t,
			contracts.NFTAddr,
			contracts.KittyItemsAddr,
			contracts.KittyItemsSigner,
			typeID1337,
		)

		// Contract transfers item to another seller account (we don't need to do this)
		KittyItemsTransferItem(
			b,
			t,
			contracts.NFTAddr,
			contracts.KittyItemsAddr,
			contracts.KittyItemsSigner,
			tokenToList,
			userAddress,
			false,
		)
		// Other seller account lists the item
		nftStorefrontSellItem(
			b,
			t,
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

		// Contract mints item
		KittyItemsMintItem(
			b,
			t,
			contracts.NFTAddr,
			contracts.KittyItemsAddr,
			contracts.KittyItemsSigner,
			typeID1337,
		)

		// Contract transfers item to another seller account (we don't need to do this)
		KittyItemsTransferItem(
			b,
			t,
			contracts.NFTAddr,
			contracts.KittyItemsAddr,
			contracts.KittyItemsSigner,
			tokenToList,
			userAddress,
			false,
		)

		// Other seller account lists the item
		saleOfferResourceID := nftStorefrontSellItem(
			b,
			t,
			contracts,
			userAddress,
			userSigner,
			tokenToList,
			tokenPrice,
			false,
		)

		buyerAddress, buyerSigner := nftStorefrontCreatePurchaserAccount(b, t, contracts)

		// Fund the purchase
		KibbleMint(
			t,
			b,
			contracts.FTAddr,
			contracts.KibbleAddr,
			contracts.KibbleSigner,
			buyerAddress,
			"100.0",
			false,
		)

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

		// Contract mints item
		KittyItemsMintItem(
			b,
			t,
			contracts.NFTAddr,
			contracts.KittyItemsAddr,
			contracts.KittyItemsSigner,
			typeID1337,
		)

		// Contract transfers item to another seller account (we don't need to do this)
		KittyItemsTransferItem(
			b,
			t,
			contracts.NFTAddr,
			contracts.KittyItemsAddr,
			contracts.KittyItemsSigner,
			tokenToList,
			userAddress,
			false,
		)

		// Other seller account lists the item
		saleOfferResourceID := nftStorefrontSellItem(
			b,
			t,
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
			userAddress,
			saleOfferResourceID,
			false,
		)
	})
}

func replaceNftStorefrontAddressPlaceholders(codeBytes []byte, contracts TestNftContractsInfo) []byte {
	code := string(codeBytes)

	code = strings.ReplaceAll(code, ftAddressPlaceholder, "0x"+contracts.FTAddr.String())
	code = strings.ReplaceAll(code, kibbleAddressPlaceHolder, "0x"+contracts.KibbleAddr.String())
	code = strings.ReplaceAll(code, nftAddressPlaceholder, "0x"+contracts.NFTAddr.String())
	code = strings.ReplaceAll(code, kittyItemsAddressPlaceHolder, "0x"+contracts.KittyItemsAddr.String())
	code = strings.ReplaceAll(code, nftStorefrontAddressPlaceholder, "0x"+contracts.NFTStorefrontAddr.String())

	return []byte(code)
}

func loadNftStorefront(ftAddr, nftAddr string) []byte {
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

func nftStorefrontGenerateSellItemScript(contracts TestNftContractsInfo) []byte {
	return replaceNftStorefrontAddressPlaceholders(
		readFile(nftStorefrontSellItemPath),
		contracts,
	)
}

func nftStorefrontGenerateBuyItemScript(contracts TestNftContractsInfo) []byte {
	return replaceNftStorefrontAddressPlaceholders(
		readFile(nftStorefrontBuyItemPath),
		contracts,
	)
}

func nftStorefrontGenerateRemoveItemScript(contracts TestNftContractsInfo) []byte {
	return replaceNftStorefrontAddressPlaceholders(
		readFile(nftStorefrontRemoveItemPath),
		contracts,
	)
}

func nftStorefrontGenerateGetIDsScript(contracts TestNftContractsInfo) []byte {
	return replaceNftStorefrontAddressPlaceholders(
		readFile(nftStorefrontGetIDsPath),
		contracts,
	)
}

func nftStorefrontGenerateGetOfferDetailsScript(contracts TestNftContractsInfo) []byte {
	return replaceNftStorefrontAddressPlaceholders(
		readFile(nftStorefrontGetOfferDetailsPath),
		contracts,
	)
}
