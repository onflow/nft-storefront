import FlowToken from "FlowToken"
import FungibleToken from "FungibleToken"
import NonFungibleToken from "NonFungibleToken"
import ExampleNFT from "ExampleNFT"
import NFTStorefront from "NFTStorefront"

transaction(saleItemID: UInt64, saleItemPrice: UFix64) {

    let flowReceiver: Capability<&{FungibleToken.Receiver}>
    let exampleNFTProvider: Capability<auth(NonFungibleToken.Withdrawable) &{NonFungibleToken.Collection}>
    let storefront: auth(NFTStorefront.Creatable) &NFTStorefront.Storefront

    prepare(acct: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue) &Account) {

        let collectionData = ExampleNFT.getCollectionData(nftType: Type<@ExampleNFT.NFT>())
            ?? panic("Missing collection data")

        self.flowReceiver = acct.capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)!
        assert(self.flowReceiver.check(), message: "Missing or mis-typed FlowToken Receiver")

        self.exampleNFTProvider = acct.capabilities.storage.issue<auth(NonFungibleToken.Withdrawable) &{NonFungibleToken.Collection}>(
                collectionData.storagePath
            )
        assert(self.exampleNFTProvider.check(), message: "Missing or mis-typed ExampleNFT provider")

        // If the account doesn't already have a Storefront
        if acct.storage.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath) == nil {
            // Save a new .Storefront to account storage
            acct.storage.save(
                <- NFTStorefront.createStorefront(),
                to: NFTStorefront.StorefrontStoragePath
            )
            // create a public capability for the .Storefront & publish
            let storefrontPublicCap = acct.capabilities.storage.issue<&{NFTStorefront.StorefrontPublic}>(
                NFTStorefront.StorefrontStoragePath
            )
            acct.capabilities.publish(storefrontPublicCap, at: NFTStorefront.StorefrontPublicPath)
        }

        self.storefront = acct.storage.borrow<auth(NFTStorefront.Creatable) &NFTStorefront.Storefront>(
                from: NFTStorefront.StorefrontStoragePath
            ) ?? panic("Missing or mis-typed NFTStorefront Storefront")
    }

    execute {
        let saleCut = NFTStorefront.SaleCut(
            receiver: self.flowReceiver,
            amount: saleItemPrice
        )
        self.storefront.createListing(
            nftProviderCapability: self.exampleNFTProvider,
            nftType: Type<@ExampleNFT.NFT>(),
            nftID: saleItemID,
            salePaymentVaultType: Type<@FlowToken.Vault>(),
            saleCuts: [saleCut]
        )
    }
}
