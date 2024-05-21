import NFTStorefrontV2 from "../contracts/NFTStorefrontV2.cdc"

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