import "ExampleToken"
import "FungibleToken"
import "NonFungibleToken"
import "ExampleNFT"
import "NFTStorefront"
import "MetadataViews"

transaction(saleItemID: UInt64, saleItemPrice: UFix64) {

    let exampleTokenReceiver: Capability<&{FungibleToken.Receiver}>
    let exampleNFTProvider: Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>
    let storefront: auth(NFTStorefront.CreateListing) &NFTStorefront.Storefront

    prepare(acct: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue) &Account) {

        let collectionDataOpt = ExampleNFT.resolveContractView(resourceType: Type<@ExampleNFT.NFT>(), viewType: Type<MetadataViews.NFTCollectionData>())
            ?? panic("Missing collection data")
        let collectionData = collectionDataOpt as! MetadataViews.NFTCollectionData

        self.exampleTokenReceiver = acct.capabilities.get<&{FungibleToken.Receiver}>(/public/exampleTokenReceiver)
        assert(self.exampleTokenReceiver.check(), message: "Missing or mis-typed ExampleToken Receiver")

        // The storage path for storing a withdraw capability to the nft collection
        // Should preferrably be defined in the nft contract
        let nftProviderCapPath = /storage/ExampleNFTProviderCap
        var nftProviderCap = acct.storage.copy<Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>>(from: nftProviderCapPath)
        if nftProviderCap == nil || !nftProviderCap!.check() {
            self.exampleNFTProvider = acct.capabilities.storage.issue<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>(
                collectionData.storagePath
            )
            assert(self.exampleNFTProvider.check(), message: "Missing or mis-typed ExampleNFT provider")
             // save capability to storage
            acct.storage.save(
                self.exampleNFTProvider,
                to: nftProviderCapPath
            )
        } else{
            self.exampleNFTProvider = nftProviderCap!
        }

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

        self.storefront = acct.storage.borrow<auth(NFTStorefront.CreateListing) &NFTStorefront.Storefront>(
                from: NFTStorefront.StorefrontStoragePath
            ) ?? panic("Missing or mis-typed NFTStorefront Storefront")
    }

    execute {
        let saleCut = NFTStorefront.SaleCut(
            receiver: self.exampleTokenReceiver,
            amount: saleItemPrice
        )
        self.storefront.createListing(
            nftProviderCapability: self.exampleNFTProvider,
            nftType: Type<@ExampleNFT.NFT>(),
            nftID: saleItemID,
            salePaymentVaultType: Type<@ExampleToken.Vault>(),
            saleCuts: [saleCut]
        )
    }
}
