import NonFungibleToken from "NonFungibleToken"
import ExampleNFT from "ExampleNFT"

access(all) fun main(address: Address): [UInt64] {
    let collectionData = ExampleNFT.getCollectionData(nftType: Type<@ExampleNFT.NFT>())
        ?? panic("Could not get ExampleNFT Collection data")
    
    return getAccount(address).capabilities.borrow<&{NonFungibleToken.Collection}>(
            collectionData.publicPath
        )?.getIDs() ?? panic("No Collection Capability found for the given address")
}