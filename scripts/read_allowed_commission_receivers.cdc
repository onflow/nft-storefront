import "NFTStorefrontV2"
import "FungibleToken"

/// This script returns the list of allowed commission receivers supported by the given listing Id.
///
access(all) fun main(account: Address, listingResourceID: UInt64): [Capability<&{FungibleToken.Receiver}>]? {
    let storefrontRef = getAccount(account).capabilities.borrow<&{NFTStorefrontV2.StorefrontPublic}>(
            NFTStorefrontV2.StorefrontPublicPath
        ) ?? panic("Could not borrow public storefront from address")

    let listing = storefrontRef.borrowListing(listingResourceID: listingResourceID)
        ?? panic("No item with that ID")
    
    return listing.getAllowedCommissionReceivers()
}
