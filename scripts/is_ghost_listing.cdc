import "NFTStorefrontV2"

/// Returns `true` if the listing with the given `listingID` under the given `storefrontAddress`
/// is a ghost listing — i.e. the underlying NFT is no longer present in the seller's collection
/// and the listing cannot be purchased. Returns `false` if the NFT is still available.
///
/// This script uses `isGhostListing()`, which has correct semantics. Prefer this over the
/// deprecated `has_listing_become_ghosted.cdc`, whose underlying function returns an inverted value.
///
/// @param storefrontAddress Address of the account holding the storefront resource.
/// @param listingID Resource ID of the listing to check.
access(all) fun main(storefrontAddress: Address, listingID: UInt64): Bool {
    let storefrontPublicRef = getAccount(storefrontAddress).capabilities.borrow<&{NFTStorefrontV2.StorefrontPublic}>(
            NFTStorefrontV2.StorefrontPublicPath
        ) ?? panic("Given account does not have a storefront resource")

    let listingRef = storefrontPublicRef.borrowListing(listingResourceID: listingID)
        ?? panic("Provided listingID doesn't exist under the given storefront address")

    return listingRef.isGhostListing()
}
