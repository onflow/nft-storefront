import "NFTStorefrontV2"

/// Returns all listing resource IDs tracked in `listedNFTs` for the given NFT type and ID.
/// This reads directly from the `listedNFTs` index (via `getExistingListingIDs`), which is
/// distinct from `getListingIDs()` — a ghost entry left behind by the Bug 1 fix would show
/// up here even after the listing has been removed from `self.listings`.
///
/// @param storefrontAddress Address of the account holding the storefront resource.
/// @param nftTypeIdentifier Fully-qualified type identifier of the NFT (e.g. "A.00…ExampleNFT.NFT").
/// @param nftID Resource ID of the NFT.
access(all) fun main(storefrontAddress: Address, nftTypeIdentifier: String, nftID: UInt64): [UInt64] {
    let nftType = CompositeType(nftTypeIdentifier)
        ?? panic("Could not construct type from identifier: ".concat(nftTypeIdentifier))

    return getAccount(storefrontAddress).capabilities.borrow<&{NFTStorefrontV2.StorefrontPublic}>(
            NFTStorefrontV2.StorefrontPublicPath
        )?.getExistingListingIDs(nftType: nftType, nftID: nftID)
        ?? panic("Could not borrow public storefront from address")
}
