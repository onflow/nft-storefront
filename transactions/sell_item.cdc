import FungibleToken from 0xFUNGIBLETOKENADDRESS
import NonFungibleToken from 0xNONFUNGIBLETOKEN
import Kibble from 0xKIBBLE
import KittyItems from 0xKITTYITEMS
import NFTStorefront from 0xNFTSTOREFRONT

transaction(saleItemID: UInt64, saleItemPrice: UFix64) {
    let kibbleReceiver: Capability<&Kibble.Vault{FungibleToken.Receiver}>
    let kittyItemsProvider: Capability<&KittyItems.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
    let storefront: &NFTStorefront.Storefront

    prepare(acct: AuthAccount) {
        // We need a provider capability, but one is not provided by default so we create one if needed.
        let KittyItemsCollectionProviderPrivatePath = /private/KittyItemsCollectionProviderForNFTStorefront

        self.kibbleReceiver = acct.getCapability<&Kibble.Vault{FungibleToken.Receiver}>(Kibble.ReceiverPublicPath)!
        assert(self.kibbleReceiver.borrow() != nil, message: "Missing or mis-typed Kibble receiver")

        if !acct.getCapability<&KittyItems.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(KittyItemsCollectionProviderPrivatePath)!.check() {
            acct.link<&KittyItems.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(KittyItemsCollectionProviderPrivatePath, target: KittyItems.CollectionStoragePath)
        }

        self.kittyItemsProvider = acct.getCapability<&KittyItems.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(KittyItemsCollectionProviderPrivatePath)!
        assert(self.kittyItemsProvider.borrow() != nil, message: "Missing or mis-typed KittyItemsCollection provider")

        self.storefront = acct.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath)
            ?? panic("Missing or mis-typed NFTStorefront Storefront")
    }

    execute {
        let saleCut = NFTStorefront.SaleCut(
            receiver: self.kibbleReceiver,
            amount: saleItemPrice
        )
        self.storefront.createSaleOffer(
            nftProviderCapability: self.kittyItemsProvider,
            nftType: Type<@KittyItems.NFT>(),
            nftID: saleItemID,
            salePaymentVaultType: Type<@Kibble.Vault>(),
            saleCuts: [saleCut]
        )
    }
}