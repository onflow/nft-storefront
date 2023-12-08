/// This transaction is what an account would run
/// to set itself up to receive NFTs

import "NonFungibleToken"
import "ExampleNFT"
import "MetadataViews"

transaction {

    prepare(signer: AuthAccount) {
        // Return early if the account already has a collection
        if signer.borrow<&ExampleNFT.Collection>(from: ExampleNFT.CollectionStoragePath) == nil {
            // Create a new empty collection
            let collection <- ExampleNFT.createEmptyCollection()

            // save it to the account
            signer.save(<-collection, to: ExampleNFT.CollectionStoragePath)
        }

        // create a public capability for the collection
        if signer.getCapability<&{NonFungibleToken.CollectionPublic, ExampleNFT.ExampleNFTCollectionPublic, MetadataViews.ResolverCollection}>(
                ExampleNFT.CollectionPublicPath
            ).check() == false {
            signer.unlink(ExampleNFT.CollectionPublicPath)
            signer.link<&{NonFungibleToken.CollectionPublic, ExampleNFT.ExampleNFTCollectionPublic, MetadataViews.ResolverCollection}>(
                ExampleNFT.CollectionPublicPath,
                target: ExampleNFT.CollectionStoragePath
            )
        }

        let providerPath: PrivatePath = /private/exampleNFTProvider
        if signer.getCapability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(providerPath).check() == false {
            signer.unlink(/private/exampleNFTProvider)
            signer.link<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(
                providerPath,
                target: ExampleNFT.CollectionStoragePath
            )
        }
    }
}
