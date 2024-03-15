import "NFTStorefront" from "../contracts/NFTStorefront.cdc"

transaction(listingResourceID: UInt64, storefrontAddress: Address) {

    let storefront: &{NFTStorefront.StorefrontPublic}

    prepare(acct: &Account) {
        self.storefront = getAccount(storefrontAddress).capabilities.borrow<&{NFTStorefront.StorefrontPublic}>(
                NFTStorefront.StorefrontPublicPath
            ) ?? panic("Could not borrow Storefront from provided address")
    }

    execute {
        // Be kind and recycle
        self.storefront.cleanup(listingResourceID: listingResourceID)
    }

    post {
        self.storefront.getListingIDs().contains(listingResourceID) == false:
            "Listing was not successfully removed"
    }
}
