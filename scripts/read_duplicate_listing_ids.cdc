import "NFTStorefrontV2"

/// This script returns an array of all the duplicate listingIDs for a given nftID.
///
access(all) fun main(account: Address, nftID: UInt64, listingID: UInt64, nftTypeIdentifier: String): [UInt64] {
    let nftType = CompositeType(nftTypeIdentifier) ?? panic("Could not construct type from identifier ".concat(nftTypeIdentifier))

    return getAccount(account).capabilities.borrow<&{NFTStorefrontV2.StorefrontPublic}>(
            NFTStorefrontV2.StorefrontPublicPath
        )?.getDuplicateListingIDs(nftType: nftType, nftID: nftID, listingID: listingID)
        ?? panic("Could not borrow public storefront from address")
}
