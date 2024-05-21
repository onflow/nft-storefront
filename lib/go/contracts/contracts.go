package contracts

//go:generate go run github.com/kevinburke/go-bindata/go-bindata -prefix ../../../contracts -o internal/assets/assets.go -pkg assets -nometadata -nomemcopy ../../../contracts/...

import (
	"regexp"

	"github.com/onflow/nft-storefront/lib/go/contracts/internal/assets"

	_ "github.com/kevinburke/go-bindata"
)

var (
	placeholderFungibleToken    = regexp.MustCompile(`"FungibleToken"`)
	fungibleTokenImport         = "FungibleToken from "
	placeholderNonFungibleToken = regexp.MustCompile(`"NonFungibleToken"`)
	nftImport                   = "NonFungibleToken from "
)

const (
	filenameNFTStorefrontV2 = "NFTStorefrontV2.cdc"
)

// NFTStorefrontV2 returns the NFTStorefrontV2 contract.
func NFTStorefrontV2(ftAddr, nftAddr string) []byte {
	code := assets.MustAssetString(filenameNFTStorefrontV2)

	code = placeholderFungibleToken.ReplaceAllString(code, fungibleTokenImport+"0x"+ftAddr)
	code = placeholderNonFungibleToken.ReplaceAllString(code, nftImport+"0x"+nftAddr)

	return []byte(code)
}
