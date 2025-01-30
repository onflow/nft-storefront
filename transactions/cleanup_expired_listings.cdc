import NFTStorefrontV2 from "../contracts/NFTStorefrontV2.cdc"

/// Transaction to facilitate the cleanup of the expired listings of a given storefront resource account holder. This
/// transaction facilitates the cleanup in pagination model where signer of the transaction will provide the
/// `fromIndex` & `toIndex` of `listingsIDs` array to remove the expired listings under the given range.
///
/// Cleanup is publicly accessible so can be executed by anyone.

transaction(fromIndex: UInt64, toIndex: UInt64, storefrontAddress: Address) {
    let storefront: &{NFTStorefrontV2.StorefrontPublic}

    prepare(acct: &Account) {
        // Access the storefront public resource of the seller to purchase the listing.
        self.storefront = getAccount(storefrontAddress).capabilities.borrow<&{NFTStorefrontV2.StorefrontPublic}>(
                NFTStorefrontV2.StorefrontPublicPath
            ) ?? panic("Could not get a Storefront from the provided address \(storefrontAddress)!")
    }

    execute {
        // Be kind and recycle
        self.storefront.cleanupExpiredListings(fromIndex: fromIndex, toIndex: toIndex)
    }
}
