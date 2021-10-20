package contracts

//go:generate go run github.com/kevinburke/go-bindata/go-bindata -prefix ../../.. -o internal/assets/assets.go -pkg assets -nometadata -nomemcopy ../../../contracts ../../../transactions ../../../scripts

import (
	"fmt"
	"regexp"

	"github.com/onflow/nft-storefront/lib/go/contracts/internal/assets"
)

const (
	nftStorefrontFilename   = "contracts/NFTStorefront.cdc"
	SetupAccountTransaction = "transactions/setup_account.cdc"
	SellItemTransaction     = "transactions/sell_item.cdc"
	BuyItemTransaction      = "transactions/buy_item.cdc"
	RemoveItemTransaction   = "transactions/remove_item.cdc"
	CleanupItemTransaction  = "transactions/cleanup_item.cdc"
	GetIDsScript            = "scripts/read_storefront_ids.cdc"
	GetListingDetailsScript = "scripts/read_listing_details.cdc"
)

var recognizedAddresses = map[string]bool{
	"FungibleToken":    true,
	"FlowToken":        true,
	"NonFungibleToken": true,
	"ExampleNFT":       true,
	"NFTStorefront":    true,
}

// replaceAddresses replaces any ../*/(importFile).cdc with the address
func replaceAddresses(code string, addressMap map[string]string) string {
	for importFile, address := range addressMap {
		if !recognizedAddresses[importFile] {
			fmt.Printf("Did you mispell anything? Replacing '%s'...\n", importFile)
		}

		placeholder := regexp.MustCompile(fmt.Sprintf(`"[^"\s].*/%v.cdc"`, importFile))
		code = placeholder.ReplaceAllString(code, withHexPrefix(address))
	}
	return code
}

// ReadWithAddresses loads a .cdc file with its addresses
func ReadWithAddresses(filename string, addressMap map[string]string) []byte {
	code := assets.MustAssetString(filename)
	return []byte(replaceAddresses(code, addressMap))
}

func NFTStorefront(ftAddress, nftAddress string) []byte {
	return ReadWithAddresses(nftStorefrontFilename, map[string]string{
		"FungibleToken":    ftAddress,
		"NonFungibleToken": nftAddress,
	})
}

func withHexPrefix(address string) string {
	if address == "" {
		return ""
	}

	if address[0:2] == "0x" {
		return address
	}

	return fmt.Sprintf("0x%s", address)
}
