import NFTStorefrontV2 from "../contracts/NFTStorefrontV2.cdc"
import FungibleToken   from "../contracts/utility/FungibleToken.cdc"

// This script returns the list of allowed commission receivers supported by the given listing Id.
pub fun main(account: Address, listingResourceID: UInt64): [Capability<&{FungibleToken.Receiver}>]? {
    let storefrontRef = getAccount(account)
        .getCapability<&NFTStorefrontV2.Storefront{NFTStorefrontV2.StorefrontPublic}>(
            NFTStorefrontV2.StorefrontPublicPath
        )
        .borrow()
        ?? panic("Could not borrow public storefront from address")

    let listing = storefrontRef.borrowListing(listingResourceID: listingResourceID)
        ?? panic("No item with that ID")
    
    return listing.getAllowedCommissionReceivers()
}