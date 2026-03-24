import "NFTStorefrontV2"

/// Returns the listing resource IDs of all unique ghost listings under the given storefront.
/// A ghost listing is one where the underlying NFT is no longer present in the seller's collection.
/// Duplicate listings (those sharing the same NFT type and ID as another listing) are excluded,
/// since they are cleaned up automatically when the primary listing is removed.
///
/// This script uses `isGhostListing()`, which has correct semantics. Prefer this over the
/// deprecated `read_all_unique_ghost_listings.cdc`.
///
/// @param storefrontAddress Address of the account holding the storefront resource.
access(all) fun main(storefrontAddress: Address): [UInt64] {

    var duplicateListings: [UInt64] = []
    var ghostListings: [UInt64] = []

    let storefrontPublicRef = getAccount(storefrontAddress).capabilities.borrow<&{NFTStorefrontV2.StorefrontPublic}>(
            NFTStorefrontV2.StorefrontPublicPath
        ) ?? panic("Given account does not have a storefront resource")

    let availableListingIds = storefrontPublicRef.getListingIDs()

    for id in availableListingIds {
        if !duplicateListings.contains(id) {
            let listingRef = storefrontPublicRef.borrowListing(listingResourceID: id)!
            if listingRef.isGhostListing() {
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
