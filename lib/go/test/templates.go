package test

import (
	"github.com/onflow/flow-go-sdk"
)

const (
	nftStorefrontPath   = "../../../contracts/NFTStorefront.cdc"
	nftStorefrontV2path = "../../../contracts/NFTStorefrontV2.cdc"

	nftStorefrontRootPath              = "../../../transactions-v1"
	nftStorefrontSetupAccountPath      = nftStorefrontRootPath + "/setup_account.cdc"
	nftStorefrontSellItemPath          = nftStorefrontRootPath + "/sell_item.cdc"
	nftStorefrontBuyItemPath           = nftStorefrontRootPath + "/buy_item.cdc"
	nftStorefrontRemoveItemPath        = nftStorefrontRootPath + "/remove_item.cdc"
	nftStorefrontGetIDsPath            = nftStorefrontRootPath + "/scripts-v1/read_storefront_ids.cdc"
	nftStorefrontGetListingDetailsPath = nftStorefrontRootPath + "/scripts-v1/read_listing_details.cdc"

	exampleNFTSetupAccountPath = nftStorefrontRootPath + "/utility/setup_account_for_example_nft.cdc"
	mintExampleNFTPath         = nftStorefrontRootPath + "/utility/mint_example_nft.cdc"
)

func replaceAddresses(codeBytes []byte, contracts Contracts) []byte {
	code := string(codeBytes)

	code = ftAddressPlaceholder.ReplaceAllString(code, "0x"+ftAddress.String())
	code = flowTokenAddressPlaceHolder.ReplaceAllString(code, "0x"+flowTokenAddress.String())
	code = nftAddressPlaceholder.ReplaceAllString(code, "0x"+contracts.NFTAddress.String())
	code = exampleNFTAddressPlaceHolder.ReplaceAllString(code, "0x"+contracts.ExampleNFTAddress.String())
	code = nftStorefrontAddressPlaceholder.ReplaceAllString(code, "0x"+contracts.NFTStorefrontAddress.String())
	code = metadataViewsAddressPlaceholder.ReplaceAllString(code, "0x"+contracts.MetadataViewsAddress.String())
	code = exampleTokenAddressPlaceholder.ReplaceAllString(code, "0x"+contracts.ExampleTokenAddress.String())

	return []byte(code)
}

func loadNFTStorefront(ftAddr, nftAddr flow.Address, version int) ([]byte, string) {
	code := ""
	name := ""

	if version == 1 {
		code = string(readFile(nftStorefrontPath))
		name = "NFTStorefront"
	} else if version == 2 {
		code = string(readFile(nftStorefrontV2path))
		name = "NFTStorefrontV2"
	}

	code = ftAddressPlaceholder.ReplaceAllString(code, "0x"+ftAddr.String())
	code = nftAddressPlaceholder.ReplaceAllString(code, "0x"+nftAddr.String())

	return []byte(code), name
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

func GenerateSetupAccountScriptExampleNFT(contracts Contracts) []byte {
	return replaceAddresses(
		readFile(exampleNFTSetupAccountPath),
		contracts,
	)
}

func GenerateMintExampleNFTScript(contracts Contracts) []byte {
	return replaceAddresses(
		readFile(mintExampleNFTPath),
		contracts,
	)
}
