package contracts

import (
	_ "embed"
	"fmt"
	"strings"

	"github.com/onflow/nft-storefront/lib/go/contracts/internal/assets"
)

//go:generate go run github.com/kevinburke/go-bindata/go-bindata -prefix ../../../contracts -o internal/assets/assets.go -pkg assets -nometadata -nomemcopy ../../../contracts

const (
	storefrontFilename                 = "NFTStorefront%d.cdc"
	placeholderFungibleTokenAddress    = "./utility/FungibleToken.cdc"
	placeholderNonfungibleTokenAddress = "./utility/NonFungibleToken.cdc"
)

func NFTStorefront(version int, fungibleTokenAddress string, nonfungibleTokenAddress string) []byte {
	if version != 1 && version != 2 {
		panic("storefront contract version doesn't exist")
	}
	contractFile := fmt.Sprintf(storefrontFilename, version)

	code := assets.MustAssetString(contractFile)

	// Replace the fungible token address
	code = strings.ReplaceAll(
		code,
		placeholderFungibleTokenAddress,
		withHexPrefix(fungibleTokenAddress),
	)

	// Replace the non-fungible token address
	code = strings.ReplaceAll(
		code,
		placeholderNonfungibleTokenAddress,
		withHexPrefix(nonfungibleTokenAddress),
	)

	return []byte(code)
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
