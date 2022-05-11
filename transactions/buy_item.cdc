import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from "../contracts/utility/FungibleToken.cdc"
import NonFungibleToken from "../contracts/utility/NonFungibleToken.cdc"
import ExampleNFT from "../contracts/utility/ExampleNFT.cdc"
import NFTStorefrontV2 from "../contracts/NFTStorefrontV2.cdc"

transaction(listingResourceID: UInt64, storefrontAddress: Address, commissionRecipient: Address) {
    let paymentVault: @FungibleToken.Vault
    let exampleNFTCollection: &ExampleNFT.Collection{NonFungibleToken.Receiver}
    let storefront: &NFTStorefrontV2.Storefront{NFTStorefrontV2.StorefrontPublic}
    let listing: &NFTStorefrontV2.Listing{NFTStorefrontV2.ListingPublic}
    let commissionRecipientCap: Capability<&{FungibleToken.Receiver}>

    prepare(acct: AuthAccount) {
        self.storefront = getAccount(storefrontAddress)
            .getCapability<&NFTStorefrontV2.Storefront{NFTStorefrontV2.StorefrontPublic}>(
                NFTStorefrontV2.StorefrontPublicPath
            )!
            .borrow()
            ?? panic("Could not borrow Storefront from provided address")

        self.listing = self.storefront.borrowListing(listingResourceID: listingResourceID)
                    ?? panic("No Offer with that ID in Storefront")
        let price = self.listing.getDetails().salePrice

        let mainFlowVault = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Cannot borrow FlowToken vault from acct storage")
        self.paymentVault <- mainFlowVault.withdraw(amount: price)

        self.exampleNFTCollection = acct.borrow<&ExampleNFT.Collection{NonFungibleToken.Receiver}>(
            from: ExampleNFT.CollectionStoragePath
        ) ?? panic("Cannot borrow NFT collection receiver from account")
        self.commissionRecipientCap = getAccount(commissionRecipient).getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        assert(self.commissionRecipientCap.check(), message: "Commission Recipient doesn't have flowtoken receiving capability")
    }

    execute {
        let item <- self.listing.purchase(
            payment: <-self.paymentVault,
            commissionRecipient: self.commissionRecipientCap
        )

        self.exampleNFTCollection.deposit(token: <-item)
    }

    //- Post to check item is in collection?
}
