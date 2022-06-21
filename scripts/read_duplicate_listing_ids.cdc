import NFTStorefrontV2 from "../contracts/NFTStorefrontV2.cdc"
import ExampleNFT from "../contracts/utility/ExampleNFT.cdc"

// This script returns an array of all the duplicate listingIDs for a given nftID.

pub fun main(account: Address, nftID: UInt64, listingID: UInt64): [UInt64] {
    let storefrontRef = getAccount(account)
        .getCapability<&NFTStorefrontV2.Storefront{NFTStorefrontV2.StorefrontPublic}>(
            NFTStorefrontV2.StorefrontPublicPath
        )
        .borrow()
        ?? panic("Could not borrow public storefront from address")
    
    return storefrontRef.getDuplicateListingIDs(nftType: Type<@ExampleNFT.NFT>(), nftID: nftID, listingID: listingID)
}
