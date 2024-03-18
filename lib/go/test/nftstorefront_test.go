package test

// go test -timeout 30s . -run ^TestNFTStorefront -v

import (
	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/cadence/runtime/common"
	"github.com/onflow/flow-go-sdk"
	nfttemplates "github.com/onflow/flow-nft/lib/go/templates"
	"github.com/stretchr/testify/require"
	"testing"
)

func TestNFTStorefrontV1DeployContracts(t *testing.T) {
	b, a := newEmulator()
	nftStorefrontDeployContracts(t, b, a, 1)
}

func TestNFTStorefrontV2DeployContracts(t *testing.T) {
	b, a := newEmulator()
	nftStorefrontDeployContracts(t, b, a, 2)
}

func TestNFTStorefrontSetupAccount(t *testing.T) {
	b, a := newEmulator()

	contracts := nftStorefrontDeployContracts(t, b, a, 1)

	userAddress, userSigner := createAccount(t, b, a)
	setupNFTStorefront(t, b, a, userAddress, userSigner, contracts)
}

func TestNFTStorefrontCreateSaleSell(t *testing.T) {
	b, a := newEmulator()

	contracts := nftStorefrontDeployContracts(t, b, a, 1)

	t.Run("Should be able to list a sale offer", func(t *testing.T) {
		tokenPrice := "1.11"

		sellerAddress, sellerSigner := createAccount(t, b, a)
		setupAccount(t, b, a, sellerAddress, sellerSigner, contracts)

		// Contract mints item to seller account
		mintExampleNFT(
			t,
			b,
			a,
			sellerAddress,
			contracts.NFTAddress,
			contracts.ExampleNFTAddress,
			contracts.MetadataViewsAddress,
			contracts.ExampleNFTSigner,
		)

		publicPath, err := cadence.NewPath(common.PathDomainPublic, "cadenceExampleNFTCollection")
		require.NoError(t, err)

		cadenceCollectionIDs := executeScriptAndCheck(
			t,
			b,
			nfttemplates.GenerateGetCollectionIDsScript(flow.HexToAddress(NonFungibleTokenAddress), contracts.ExampleNFTAddress),
			[][]byte{
				jsoncdc.MustEncode(cadence.NewAddress(sellerAddress)),
				jsoncdc.MustEncode(publicPath),
			},
		)
		collectionIDs := cadenceCollectionIDs.ToGoValue().([]interface{})

		// Seller account lists the item
		sellItem(
			t,
			b,
			a,
			contracts,
			sellerAddress,
			sellerSigner,
			collectionIDs[0].(uint64),
			tokenPrice,
			false,
		)
	})

	t.Run("Should be able to purchase a sale offer", func(t *testing.T) {
		tokenPrice := "1.11"

		sellerAddress, sellerSigner := createAccount(t, b, a)
		setupAccount(t, b, a, sellerAddress, sellerSigner, contracts)

		// Contract mints item to seller account
		mintExampleNFT(
			t,
			b,
			a,
			sellerAddress,
			contracts.NFTAddress,
			contracts.ExampleNFTAddress,
			contracts.MetadataViewsAddress,
			contracts.ExampleNFTSigner,
		)

		publicPath, err := cadence.NewPath(common.PathDomainPublic, "cadenceExampleNFTCollection")
		require.NoError(t, err)

		cadenceCollectionIDs := executeScriptAndCheck(
			t,
			b,
			nfttemplates.GenerateGetCollectionIDsScript(flow.HexToAddress(NonFungibleTokenAddress), contracts.ExampleNFTAddress),
			[][]byte{
				jsoncdc.MustEncode(cadence.NewAddress(sellerAddress)),
				jsoncdc.MustEncode(publicPath),
			},
		)
		collectionIDs := cadenceCollectionIDs.ToGoValue().([]interface{})

		// Seller account lists the item
		listingResourceID := sellItem(
			t,
			b,
			a,
			contracts,
			sellerAddress,
			sellerSigner,
			collectionIDs[0].(uint64),
			tokenPrice,
			false,
		)

		buyerAddress, buyerSigner := createAccount(t, b, a)
		setupAccount(t, b, a, buyerAddress, buyerSigner, contracts)

		// Make the purchase
		buyItem(
			b,
			a,
			t,
			contracts,
			buyerAddress,
			buyerSigner,
			sellerAddress,
			listingResourceID,
			false,
		)
	})

	t.Run("Should be able to remove a sale offer", func(t *testing.T) {
		tokenPrice := "1.11"

		sellerAddress, sellerSigner := createAccount(t, b, a)
		setupAccount(t, b, a, sellerAddress, sellerSigner, contracts)

		// Contract mints item to seller account
		mintExampleNFT(
			t,
			b,
			a,
			sellerAddress,
			contracts.NFTAddress,
			contracts.ExampleNFTAddress,
			contracts.MetadataViewsAddress,
			contracts.ExampleNFTSigner,
		)

		publicPath, err := cadence.NewPath(common.PathDomainPublic, "cadenceExampleNFTCollection")
		require.NoError(t, err)

		cadenceCollectionIDs := executeScriptAndCheck(
			t,
			b,
			nfttemplates.G	 enerateGetCollectionIDsScript(flow.HexToAddress(NonFungibleTokenAddress), contracts.ExampleNFTAddress),
			[][]byte{
				jsoncdc.MustEncode(cadence.NewAddress(sellerAddress)),
				jsoncdc.MustEncode(publicPath),
			},
		)
		collectionIDs := cadenceCollectionIDs.ToGoValue().([]interface{})

		// Seller account lists the item
		listingResourceID := sellItem(
			t,
			b,
			a,
			contracts,
			sellerAddress,
			sellerSigner,
			collectionIDs[0].(uint64),
			tokenPrice,
			false,
		)

		// Cancel the sale
		removeItem(
			b,
			a,
			t,
			contracts,
			sellerAddress,
			sellerSigner,
			listingResourceID,
			false,
		)
	})
}
