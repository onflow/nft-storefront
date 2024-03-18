import NFTStorefrontV2 from "../contracts/NFTStorefrontV2.cdc"

// This script returns an array of all the nft uuids for sale through a Storefront

access(all) fun main(account: Address): [UInt64] {
    return getAccount(account).capabilities.borrow<&{NFTStorefrontV2.StorefrontPublic}>(
            NFTStorefrontV2.StorefrontPublicPath
        )?.getListingIDs()
        ?? panic("Could not borrow public storefront from address")
}
