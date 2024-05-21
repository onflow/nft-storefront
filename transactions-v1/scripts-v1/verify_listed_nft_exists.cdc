import "NonFungibleToken"
import "NFTStorefront"

/// This script returns the details for a listing within a storefront
///
access(all) fun main(account: Address, listingResourceID: UInt64): Bool {
    let storefrontRef = getAccount(account).capabilities.borrow<&{NFTStorefront.StorefrontPublic}>(
            NFTStorefront.StorefrontPublicPath
        ) ?? panic("Could not borrow public storefront from address")

    let listing = storefrontRef.borrowListing(listingResourceID: listingResourceID)
        ?? panic("No listing with that ID")
    
    let nft: &{NonFungibleToken.NFT}? = listing.borrowNFT()

    return nft != nil
}
