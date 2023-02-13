import NFTStorefrontV2 from "../contracts/NFTStorefrontV2.cdc"

/// This script provides the array of listing resource Id which got ghosted
/// It automatically skips the duplicate listing as duplicate listings would get
/// automatically delete once the primary one.
/// @param storefront Address of the storefront resource whose ghost listings get queried.
pub fun main(storefront: Address): [UInt64] {

    var duplicateListings: [UInt64] = []
    var ghostListings: [UInt64] = []

    let storefrontPublicRef = getAccount(storefront)
        .getCapability<&{NFTStorefrontV2.StorefrontPublic}>(NFTStorefrontV2.StorefrontPublicPath)
        .borrow()
        ?? panic("Given account does not has storefront resource")

    // Access all the listings under the given storefront account
    let availableListingIds = storefrontPublicRef.getListingIDs()
    // Iterate the available listings and find out which listing falls under ghost listing category.
    for id in availableListingIds {
        if !duplicateListings.contains(id) {
            let listingRef = storefrontPublicRef.borrowListing(listingResourceID: id)!
            if !listingRef.hasListingBecomeGhosted() {
                ghostListings.append(id)
                let listingDetails = listingRef.getDetails()
                let dupListings = storefrontPublicRef.getDuplicateListingIDs(nftType: listingDetails.nftType, nftID: listingDetails.nftID, listingID: id)
                if dupListings.length > 0 {
                    duplicateListings.appendAll(dupListings)
                }
            }
        }
    }

    return ghostListings
}