import NFTStorefrontV2 from "../contracts/NFTStorefrontV2.cdc"

/// Transaction to facilitate the removal of listing by the listing owner. Listing owner should provide the
/// `listingResourceID` that needs to be removed.
///
transaction(listingResourceID: UInt64) {

    let storefront: auth(NFTStorefrontV2.RemoveListing) &{NFTStorefrontV2.StorefrontManager}

    prepare(acct: auth(BorrowValue) &Account) {
        self.storefront = acct.storage.borrow<auth(NFTStorefrontV2.RemoveListing) &NFTStorefrontV2.Storefront>(
                from: NFTStorefrontV2.StorefrontStoragePath
            ) ?? panic("The signer does not store an NFT Storefront V2 object at the path \(NFTStorefrontV2.StorefrontStoragePath). "
                    .concat("The signer must initialize their account with this vault first!"))
    }

    execute {
        self.storefront.removeListing(listingResourceID: listingResourceID)
    }
}
