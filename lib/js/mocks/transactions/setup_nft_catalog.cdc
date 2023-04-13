import NonFungibleToken from "../../../../contracts/utility/NonFungibleToken.cdc"
import MetadataViews from "../../../../contracts/utility/MetadataViews.cdc"
import NFTCatalog from "../../../../contracts/utility/NFTCatalog.cdc"
import ExampleNFT from "../../../../contracts/utility/ExampleNFT.cdc"
import NFTCatalogAdmin from "../../../../contracts/utility/NFTCatalogAdmin.cdc"

// This transaction sets up a fake NFT catalog for testing.

transaction {
    prepare(signer: AuthAccount) {
        let adminResource = signer.borrow<&NFTCatalogAdmin.Admin>(from: NFTCatalogAdmin.AdminStoragePath)!
        adminResource.addCatalogEntry(
            collectionIdentifier: "ExampleNFT", 
            metadata: NFTCatalog.NFTCatalogMetadata(
                contractName: "ExampleNFT", 
                contractAddress: 0xf8d6e0586b0a20c7, 
                nftType: Type<@ExampleNFT.NFT>(), 
                collectionData: NFTCatalog.NFTCollectionData(
                    storagePath: /storage/exampleNFTCollection, 
                    publicPath: /public/exampleNFTCollection, 
                    privatePath: /private/exampleNFTCollection,
                    publicLinkedType: Type<&ExampleNFT.Collection{ExampleNFT.ExampleNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                    privateLinkedType: Type<&ExampleNFT.Collection{ExampleNFT.ExampleNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>()),
                collectionDisplay: MetadataViews.NFTCollectionDisplay(
                    name: "ExampleNFT", 
                    description: "ExampleNFT", 
                    externalURL: MetadataViews.ExternalURL("https://example.com/image.png"),
                    squareImage: MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg"
                        ),
                        mediaType: "image/svg+xml"
                    ),
                    bannerImage: MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg"
                        ),
                        mediaType: "image/svg+xml"
                    ),
                    socials: {})
            )
        )
    }
}
