import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from "../contracts/utility/FungibleToken.cdc"
import NonFungibleToken from "../contracts/utility/NonFungibleToken.cdc"
import ExampleNFT from "../contracts/utility/ExampleNFT.cdc"
import NFTStorefront from "../contracts/NFTStorefront.cdc"

transaction(saleItemID: UInt64, saleItemPrice: UFix64) {
    let flowReceiver: Capability<&FlowToken.Vault{FungibleToken.Receiver}>
    let exampleNFTProvider: Capability<&ExampleNFT.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
    let storefront: &NFTStorefront.Storefront

    prepare(acct: AuthAccount) {
        // We need a provider capability, but one is not provided by default so we create one if needed.
        let exampleNFTCollectionProviderPrivatePath = /private/exampleNFTCollectionProviderForNFTStorefront

        self.flowReceiver = acct.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)!
        assert(self.flowReceiver.borrow() != nil, message: "Missing or mis-typed FlowToken receiver")

        if !acct.getCapability<&ExampleNFT.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(exampleNFTCollectionProviderPrivatePath)!.check() {
            acct.link<&ExampleNFT.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(exampleNFTCollectionProviderPrivatePath, target: ExampleNFT.CollectionStoragePath)
        }

        self.exampleNFTProvider = acct.getCapability<&ExampleNFT.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(exampleNFTCollectionProviderPrivatePath)!
        assert(self.exampleNFTProvider.borrow() != nil, message: "Missing or mis-typed ExampleNFT.Collection provider")

        self.storefront = acct.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath)
            ?? panic("Missing or mis-typed NFTStorefront Storefront")
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
