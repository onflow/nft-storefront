package test

// go test -timeout 30s . -run ^TestNFTStorefront -v

import (
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
		tokenToList := uint64(0)
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

		// Seller account lists the item
		sellItem(
			t,
			b,
			a,
			contracts,
			sellerAddress,
			sellerSigner,
			tokenToList,
			tokenPrice,
			false,
		)
	})

	t.Run("Should be able to purchase a sale offer", func(t *testing.T) {
		tokenToList := uint64(1)
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

		// Seller account lists the item
		listingResourceID := sellItem(
			t,
			b,
			a,
			contracts,
			sellerAddress,
			sellerSigner,
			tokenToList,
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
		tokenToList := uint64(2)
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

		// Seller account lists the item
		listingResourceID := sellItem(
			t,
			b,
			a,
			contracts,
			sellerAddress,
			sellerSigner,
			tokenToList,
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
