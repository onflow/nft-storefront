package test

import (
	"strings"

	"github.com/onflow/flow-go-sdk"
)

const (
	nftStorefrontNftStorefrontPath     = "../../../contracts/NFTStorefront.cdc"
	nftStorefrontRootPath              = "../../../transactions"
	nftStorefrontSetupAccountPath      = nftStorefrontRootPath + "/setup_account.cdc"
	nftStorefrontSellItemPath          = nftStorefrontRootPath + "/sell_item.cdc"
	nftStorefrontBuyItemPath           = nftStorefrontRootPath + "/buy_item.cdc"
	nftStorefrontRemoveItemPath        = nftStorefrontRootPath + "/remove_item.cdc"
	nftStorefrontGetIDsPath            = nftStorefrontRootPath + "/scripts/read_storefront_ids.cdc"
	nftStorefrontGetListingDetailsPath = nftStorefrontRootPath + "/scripts/read_listing_details.cdc"
)

func replaceAddresses(codeBytes []byte, contracts Contracts) []byte {
	code := string(codeBytes)

	code = strings.ReplaceAll(code, ftAddressPlaceholder, "0x"+ftAddress.String())
	code = strings.ReplaceAll(code, flowTokenAddressPlaceHolder, "0x"+flowTokenAddress.String())
	code = strings.ReplaceAll(code, nftAddressPlaceholder, "0x"+contracts.NFTAddress.String())
	code = strings.ReplaceAll(code, exampleNFTAddressPlaceHolder, "0x"+contracts.ExampleNFTAddress.String())
	code = strings.ReplaceAll(code, nftStorefrontAddressPlaceholder, "0x"+contracts.NFTStorefrontAddress.String())

	return []byte(code)
}

func loadNFTStorefront(ftAddr, nftAddr flow.Address) []byte {
	code := string(readFile(nftStorefrontNftStorefrontPath))

	code = strings.ReplaceAll(code, ftAddressPlaceholder, "0x"+ftAddr.String())
	code = strings.ReplaceAll(code, nftAddressPlaceholder, "0x"+nftAddr.String())

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
