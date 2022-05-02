import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from "../contracts/utility/FungibleToken.cdc"
import NonFungibleToken from "../contracts/utility/NonFungibleToken.cdc"
import ExampleNFT from "../contracts/utility/ExampleNFT.cdc"
import MetadataViews from "../contracts/utility/MetadataViews.cdc"
import NFTStorefront from "../contracts/NFTStorefront.cdc"

transaction(saleItemID: UInt64, saleItemPrice: UFix64, customID: String?, commissionAmount: UFix64, expiry: UInt64, marketplacesCap: [Capability<&AnyResource{FungibleToken.Receiver}>]?) {
    let flowReceiver: Capability<&AnyResource{FungibleToken.Receiver}>
    let exampleNFTProvider: Capability<&AnyResource{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
    let storefront: &NFTStorefront.Storefront
    var saleCuts: [NFTStorefront.SaleCut]

    prepare(acct: AuthAccount) {
        // We need a provider capability, but one is not provided by default so we create one if needed.
        let exampleNFTCollectionProviderPrivatePath = /private/exampleNFTCollectionProviderForNFTStorefront

        self.flowReceiver = acct.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)!
        assert(self.flowReceiver.borrow() != nil, message: "Missing or mis-typed FlowToken receiver")

        if !acct.getCapability<&ExampleNFT.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(exampleNFTCollectionProviderPrivatePath)!.check() {
            acct.link<&ExampleNFT.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(exampleNFTCollectionProviderPrivatePath, target: /storage/NFTCollection)
        }

        self.exampleNFTProvider = acct.getCapability<&ExampleNFT.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(exampleNFTCollectionProviderPrivatePath)!
        let metadataResolver = acct.getCapability<&ExampleNFT.Collection{MetadataViews.ResolverCollection}>(exampleNFTCollectionProviderPrivatePath)
        var totalRoyaltyCut = 0.0
        let effectiveSaleItemPrice = saleItemPrice - commissionAmount
        // Check whether the NFT implements the MetadataResolver or not.
        if metadataResolver.check<&ExampleNFT.Collection{MetadataViews.ResolverCollection}>() {
            resolverRef = metadataResolver.borrowViewResolver(id: saleItemID)
            let viewTypes = resolverRef.getViews()
            if viewTypes.contains(MetadataViews.Royalties) {
                let royalties = resolverRef.resolveView(MetadataViews.Royalties).getRoyalties()
                for royalty in royalties {
                    // TODO - Verify the type of the valut and it should exists
                    saleCuts.append(NFTStorefront.SaleCut(receiver: royalty.receiver, amount: royalty.cut * effectiveSaleItemPrice))
                    totalRoyaltyCut = totalRoyaltyCut + royalty.cut * effectiveSaleItemPrice
                }
            }
        }
        saleCuts.append(NFTStorefront.SaleCut(
            receiver: self.flowReceiver,
            amount: effectiveSaleItemPrice - totalRoyaltyCut
        ))
        assert(self.exampleNFTProvider.borrow() != nil, message: "Missing or mis-typed ExampleNFT.Collection provider")

        self.storefront = acct.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath)
            ?? panic("Missing or mis-typed NFTStorefront Storefront")
    }

    execute {
        self.storefront.createListing(
            nftProviderCapability: self.exampleNFTProvider,
            nftType: Type<@ExampleNFT.NFT>(),
            nftID: saleItemID,
            salePaymentVaultType: Type<@FlowToken.Vault>(),
            saleCuts: [saleCut],
            marketplacesCap: marketplacesCap,
            customID: customID,
            commissionAmount: commissionAmount,
            expiry: expiry
        )
    }
}
