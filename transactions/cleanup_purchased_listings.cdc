import NFTStorefrontV2 from "../contracts/NFTStorefrontV2.cdc"

/// Transaction to facilitate the cleanup of the purchased listings of a given
/// storefront resource account holder.
///
/// It can be sign/authorize by anyone.

transaction(storefrontAddress: Address, listingResourceID: UInt64) {
    let storefront: &NFTStorefrontV2.Storefront{NFTStorefrontV2.StorefrontPublic}

    prepare(acct: AuthAccount) {
        self.storefront = getAccount(storefrontAddress)
            .getCapability<&NFTStorefrontV2.Storefront{NFTStorefrontV2.StorefrontPublic}>(
                NFTStorefrontV2.StorefrontPublicPath
            )!
            .borrow()
            ?? panic("Could not borrow Storefront from provided address")
    }

    execute {
        // Be kind and recycle
        self.storefront.cleanupPurchasedListings(listingResourceID: listingResourceID)
    }
}
