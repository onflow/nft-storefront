import NFTStorefront from "../../contracts/NFTStorefront.cdc"

// This script returns the details for a listing within a storefront

pub fun main(account: Address, listingResourceID: UInt64): NFTStorefront.ListingDetails {
    let storefrontRef = getAccount(account)
        .getCapability<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(
            NFTStorefront.StorefrontPublicPath
        )
        .borrow()
        ?? panic("Could not borrow public storefront from address")

    let listing = storefrontRef.borrowListing(listingResourceID: listingResourceID)
        ?? panic("No item with that ID")
    
    return listing.getDetails()
}
