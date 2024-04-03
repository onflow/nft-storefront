import "NFTStorefront"

transaction(listingResourceID: UInt64) {
    
    let storefront: auth(NFTStorefront.RemoveListing) &NFTStorefront.Storefront

    prepare(acct: auth(BorrowValue) &Account) {
        self.storefront = acct.storage.borrow<auth(NFTStorefront.RemoveListing) &NFTStorefront.Storefront>(
                from: NFTStorefront.StorefrontStoragePath
            ) ?? panic("Missing or mis-typed NFTStorefront.Storefront")
    }

    execute {
        self.storefront.removeListing(listingResourceID: listingResourceID)
    }

    post {
        self.storefront.getListingIDs().contains(listingResourceID) == false:
            "Listing was not successfully removed"
    }
}
