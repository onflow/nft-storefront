import "NFTStorefrontV2"

/// DEPRECATED: This script calls `hasListingBecomeGhosted()`, whose return value is semantically
/// inverted — it returns `true` when the NFT is still present (NOT a ghost listing) and `false`
/// when the NFT is absent (IS a ghost listing). Use `is_ghost_listing.cdc` instead, which
/// calls `isGhostListing()` and returns `true` when the listing is ghosted.
///
/// This script tells whether the provided `listingID` under the provided `storefront` address
/// has a ghost listing.
access(all) fun main(storefrontAddress: Address, listingID: UInt64): Bool {
    let storefrontPublicRef = getAccount(storefrontAddress).capabilities.borrow<&{NFTStorefrontV2.StorefrontPublic}>(
            NFTStorefrontV2.StorefrontPublicPath
        ) ?? panic("Given account does not has storefront resource")

    // Access the listing under the given storefront account
    let listingRef = storefrontPublicRef.borrowListing(listingResourceID: listingID)
         ?? panic("Provided listingID doesn't exist under the given storefront address")
    return listingRef.hasListingBecomeGhosted()
}