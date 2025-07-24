import "NFTStorefrontV2"

/// This script provides the array of listing resource Id which got ghosted It automatically skips the duplicate listing
/// as duplicate listings would get automatically delete once the primary one.
///
/// @param storefront Address of the storefront resource whose ghost listings get queried.
///
access(all) fun main(storefrontAddress: Address): [UInt64] {

    var duplicateListings: [UInt64] = []
    var ghostListings: [UInt64] = []

    let storefrontPublicRef = getAccount(storefrontAddress).capabilities.borrow<&{NFTStorefrontV2.StorefrontPublic}>(
            NFTStorefrontV2.StorefrontPublicPath
        ) ?? panic("Given account does not has storefront resource")

    // Access all the listings under the given storefront account
    let availableListingIds = storefrontPublicRef.getListingIDs()
    // Iterate over available listings and find out which listing falls under ghost listing category.
    for id in availableListingIds {
        
        if !duplicateListings.contains(id) {
        
            let listingRef = storefrontPublicRef.borrowListing(listingResourceID: id)!
            // Note hasListingBecomeGhosted() returns false if the NFT is no longer available for sale
            // i.e. it's a ghost listing if false
            if !listingRef.hasListingBecomeGhosted() {
                ghostListings.append(id)
                let listingDetails = listingRef.getDetails()
                let dupListings = storefrontPublicRef.getDuplicateListingIDs(
                        nftType: listingDetails.nftType,
                        nftID: listingDetails.nftID,
                        listingID: id
                    )
                if dupListings.length > 0 {
                    duplicateListings.appendAll(dupListings)
                }
            }
        }
    }

    return ghostListings
}