import FungibleToken from 0xFUNGIBLETOKENADDRESS
import NonFungibleToken from 0xNONFUNGIBLETOKEN
import Kibble from 0xKIBBLE
import KittyItems from 0xKITTYITEMS
import NFTStorefront from 0xNFTSTOREFRONT

transaction(saleOfferResourceID: UInt64, storefrontAddress: Address) {
    let paymentVault: @FungibleToken.Vault
    let kittyItemsCollection: &KittyItems.Collection{NonFungibleToken.Receiver}
    let storefront: &NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}
    let saleOffer: &NFTStorefront.SaleOffer{NFTStorefront.SaleOfferPublic}

    prepare(acct: AuthAccount) {
        self.storefront = getAccount(storefrontAddress)
            .getCapability<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(
                NFTStorefront.StorefrontPublicPath
            )!
            .borrow()
            ?? panic("Could not borrow Storefront from provided address")

        self.saleOffer = self.storefront.borrowSaleOffer(saleOfferResourceID: saleOfferResourceID)
                    ?? panic("No Offer with that ID in Storefront")
        let price = self.saleOffer.getDetails().salePrice

        let mainKibbleVault = acct.borrow<&Kibble.Vault>(from: Kibble.VaultStoragePath)
            ?? panic("Cannot borrow Kibble vault from acct storage")
        self.paymentVault <- mainKibbleVault.withdraw(amount: price)

        self.kittyItemsCollection = acct.borrow<&KittyItems.Collection{NonFungibleToken.Receiver}>(
            from: KittyItems.CollectionStoragePath
        ) ?? panic("Cannot borrow KittyItems collection receiver from acct")
    }

    execute {
        let kittyItem <- self.saleOffer.accept(
            payment: <-self.paymentVault
        )

        self.kittyItemsCollection.deposit(token: <-kittyItem)

        /* //-
        error: Execution failed:
        computation limited exceeded: 100
        */
        // Be kind and recycle
        //self.storefront.cleanup(saleOfferResourceID: saleOfferResourceID)
    }

    //- Post to check item is in collection?
}