/// This transaction is what an account would run
/// to set itself up to receive NFTs

import NonFungibleToken from "NonFungibleToken"
import ExampleNFT from "ExampleNFT"
import MetadataViews from "MetadataViews"
import ViewResolver from "ViewResolver"

transaction {

    prepare(signer: auth(StorageCapabilities, PublishCapability, BorrowValue, SaveValue) &Account) {
        let collectionData = ExampleNFT.getCollectionData(nftType: Type<@ExampleNFT.NFT>())
            ?? panic("Missing collection data")
        
        // Return early if the account already has a collection
        if signer.storage.borrow<&ExampleNFT.Collection>(from: collectionData.storagePath) != nil {
            return
        }

        // Create a new empty collection
        let collection <- ExampleNFT.createEmptyCollection(collectionType: Type<@ExampleNFT.Collection>())

        // save it to the account
        signer.storage.save(<-collection, to: collectionData.storagePath)

        // create a public capability for the collection
        let collectionCap = signer.capabilities.storage.issue<&{NonFungibleToken.Collection}>(collectionData.storagePath)

        signer.capabilities.publish(collectionCap, at: collectionData.publicPath)
    }
}
