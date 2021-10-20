package test

import (
	"github.com/onflow/flow-go-sdk"
)

const (
	nftStorefrontNftStorefrontPath     = "../../../contracts/NFTStorefront.cdc"
	nftStorefrontRootPath              = "../../.."
	nftStorefrontSetupAccountPath      = nftStorefrontRootPath + "/transactions/setup_account.cdc"
	nftStorefrontSellItemPath          = nftStorefrontRootPath + "/transactions/sell_item.cdc"
	nftStorefrontBuyItemPath           = nftStorefrontRootPath + "/transactions/buy_item.cdc"
	nftStorefrontRemoveItemPath        = nftStorefrontRootPath + "/transactions/remove_item.cdc"
	nftStorefrontGetIDsPath            = nftStorefrontRootPath + "/scripts/read_storefront_ids.cdc"
	nftStorefrontGetListingDetailsPath = nftStorefrontRootPath + "/scripts/read_listing_details.cdc"
)

func replaceAddresses(codeBytes []byte, contracts Contracts) []byte {
	code := string(codeBytes)

	code = ftAddressPlaceholder.ReplaceAllString(code, "0x"+ftAddress.String())
	code = flowTokenAddressPlaceHolder.ReplaceAllString(code, "0x"+flowTokenAddress.String())
	code = nftAddressPlaceholder.ReplaceAllString(code, "0x"+contracts.NFTAddress.String())
	code = exampleNFTAddressPlaceHolder.ReplaceAllString(code, "0x"+contracts.ExampleNFTAddress.String())
	code = nftStorefrontAddressPlaceholder.ReplaceAllString(code, "0x"+contracts.NFTStorefrontAddress.String())

	return []byte(code)
}

func loadNFTStorefront(ftAddr, nftAddr flow.Address) []byte {
	code := string(readFile(nftStorefrontNftStorefrontPath))

	code = ftAddressPlaceholder.ReplaceAllString(code, "0x"+ftAddr.String())
	code = nftAddressPlaceholder.ReplaceAllString(code, "0x"+nftAddr.String())

	return []byte(code)
}

func nftStorefrontGenerateSetupAccountScript(contracts Contracts) []byte {
	return replaceAddresses(
		readFile(nftStorefrontSetupAccountPath),
		contracts,
	)
}

func nftStorefrontGenerateSellItemScript(contracts Contracts) []byte {
	return replaceAddresses(
		readFile(nftStorefrontSellItemPath),
		contracts,
	)
}

func nftStorefrontGenerateBuyItemScript(contracts Contracts) []byte {
	return replaceAddresses(
		readFile(nftStorefrontBuyItemPath),
		contracts,
	)
}

func nftStorefrontGenerateRemoveItemScript(contracts Contracts) []byte {
	return replaceAddresses(
		readFile(nftStorefrontRemoveItemPath),
		contracts,
	)
}

func nftStorefrontGenerateGetIDsScript(contracts Contracts) []byte {
	return replaceAddresses(
		readFile(nftStorefrontGetIDsPath),
		contracts,
	)
}

func nftStorefrontGenerateGetListingDetailsScript(contracts Contracts) []byte {
	return replaceAddresses(
		readFile(nftStorefrontGetListingDetailsPath),
		contracts,
	)
}
