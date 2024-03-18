import ExampleToken from "../contracts/utility/ExampleToken.cdc"
import FungibleToken from "../contracts/utility/FungibleToken.cdc"
import NonFungibleToken from "../contracts/utility/NonFungibleToken.cdc"
import ExampleNFT from "../contracts/utility/ExampleNFT.cdc"
import NFTStorefront from "../contracts/NFTStorefront.cdc"
import MetadataViews from "../contracts/utility/MetadataViews"

transaction(listingResourceID: UInt64, storefrontAddress: Address) {

    let paymentVault: @{FungibleToken.Vault}
    let exampleNFTReceiver: &{NonFungibleToken.Receiver}
    let storefront: &{NFTStorefront.StorefrontPublic}
    let listing: &{NFTStorefront.ListingPublic}

    prepare(acct: auth(BorrowValue) &Account) {
        self.storefront = getAccount(storefrontAddress).capabilities.borrow<&{NFTStorefront.StorefrontPublic}>(
                NFTStorefront.StorefrontPublicPath
            ) ?? panic("Could not borrow StorefrontPublic from provided address")

        self.listing = self.storefront.borrowListing(listingResourceID: listingResourceID)
                    ?? panic("No Offer with that ID in Storefront")
        let price = self.listing.getDetails().salePrice

        let mainVault = acct.storage.borrow<auth(FungibleToken.Withdraw) &ExampleToken.Vault>(from: /storage/exampleTokenVault)
            ?? panic("Cannot borrow ExampleToken vault from acct storage")
        self.paymentVault <- mainVault.withdraw(amount: price)

        let collectionDataOpt = ExampleNFT.resolveContractView(resourceType: Type<@ExampleNFT.NFT>(), viewType: Type<MetadataViews.NFTCollectionData>())
            ?? panic("Missing collection data")
        let collectionData = collectionDataOpt as! MetadataViews.NFTCollectionData


        self.exampleNFTReceiver = acct.capabilities.borrow<&{NonFungibleToken.Receiver}>(collectionData.publicPath)
            ?? panic("Cannot borrow NFT collection receiver from account")
    }

    execute {
        let item <- self.listing.purchase(
            payment: <-self.paymentVault
        )

        self.exampleNFTReceiver.deposit(token: <-item)

        /*
        error: Execution failed:
        computation limited exceeded: 100
        */
        // Be kind and recycle
        self.storefront.cleanup(listingResourceID: listingResourceID)
    }

    //- Post to check item is in collection?
}
