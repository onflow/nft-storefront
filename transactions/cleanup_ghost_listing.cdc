import NFTStorefrontV2 from "../contracts/NFTStorefrontV2.cdc"

/// Below transaction help to remove the ghost listing for the given storefront.
///
/// @param listingResourceID Id of the listing resource that would get deleted if it found ghost listing.
/// @param storefrontOwner Address of the storefront resource, Owner of the given `listingResourceID`
///
transaction(listingResourceID: UInt64, storefrontOwner: Address) {

    let storefrontPublicRef: &{NFTStorefrontV2.StorefrontPublic}   

    prepare(acct: AuthAccount) {
        // Access the storefront public resource of the seller to purchase the listing.
        self.storefront = getAccount(storefrontAddress).capabilities.borrow<&{NFTStorefrontV2.StorefrontPublic}>(
                NFTStorefrontV2.StorefrontPublicPath
            ) ?? panic("Could not borrow Storefront from provided address")
    }

    execute {
        self.storefrontPublicRef.cleanupGhostListings(listingResourceID: listingResourceID)
    }
}
