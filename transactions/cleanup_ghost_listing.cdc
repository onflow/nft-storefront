import NFTStorefrontV2 from "../contracts/NFTStorefrontV2.cdc"

/// Below transaction help to remove the ghost listing for the given storefront.
/// @param listingResourceID Id of the listing resource that would get deleted if it found ghost listing.
/// @param storefrontOwner Address of the storefront resource, Owner of the given `listingResourceID`
transaction(listingResourceID: UInt64, storefrontOwner: Address) {

    let storefrontPublicRef: &{NFTStorefrontV2.StorefrontPublic}   

    prepare(caller: AuthAccount) {
        self.storefrontPublicRef = getAccount(storefrontOwner)
            .getCapability<&{NFTStorefrontV2.StorefrontPublic}>(NFTStorefrontV2.StorefrontPublicPath)
            .borrow()
            ?? panic("Given account does not has storefront resource")
    }

    execute {
        self.storefrontPublicRef.cleanupGhostListings(listingResourceID: listingResourceID)
    }
}