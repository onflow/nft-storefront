import ExampleToken from "ExampleToken"
import FungibleToken from "FungibleToken"
import NonFungibleToken from "NonFungibleToken"
import ExampleNFT from "ExampleNFT"
import NFTStorefrontV2 from "NFTStorefrontV2"
import MetadataViews from "MetadataViews"

/// Transaction facilitates the purcahse of listed NFT. It takes the storefront address, listing resource that need to be
/// purchased & a address that will takeaway the commission.
///
/// Buyer of the listing (,i.e. underling NFT) would authorize and sign the transaction and if purchase happens then
/// transacted NFT would store in buyer's collection.
///
transaction(listingResourceID: UInt64, storefrontAddress: Address, commissionRecipient: Address?) {

    let paymentVault: @{FungibleToken.Vault}
    let exampleNFTReceiver: &{NonFungibleToken.Receiver}
    let storefront: &{NFTStorefrontV2.StorefrontPublic}
    let listing: &{NFTStorefrontV2.ListingPublic}
    var commissionRecipientCap: Capability<&{FungibleToken.Receiver}>?

    prepare(acct: auth(BorrowValue) &Account) {
        self.commissionRecipientCap = nil
        // Access the storefront public resource of the seller to purchase the listing.
        self.storefront = getAccount(storefrontAddress).capabilities.borrow<&{NFTStorefrontV2.StorefrontPublic}>(
                NFTStorefrontV2.StorefrontPublicPath
            ) ?? panic("Could not borrow Storefront from provided address")

        // Borrow the listing
        self.listing = self.storefront.borrowListing(listingResourceID: listingResourceID)
            ?? panic("No Offer with that ID in Storefront")
        let price = self.listing.getDetails().salePrice

        // Access the vault of the buyer to pay the sale price of the listing.
        let mainVault = acct.storage.borrow<auth(FungibleToken.Withdraw) &ExampleToken.Vault>(from: /storage/exampleTokenVault)
            ?? panic("Cannot borrow ExampleToken vault from acct storage")
        self.paymentVault <- mainVault.withdraw(amount: price)

        // Access the buyer's NFT collection to store the purchased NFT.
        let collectionData = ExampleNFT.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionData>()) as! MetadataViews.NFTCollectionData?
            ?? panic("ViewResolver does not resolve NFTCollectionData view")
        self.exampleNFTReceiver = acct.capabilities.borrow<&{NonFungibleToken.Receiver}>(collectionData.publicPath)
            ?? panic("Cannot borrow NFT collection receiver from account")

        // Fetch the commission amt.
        let commissionAmount = self.listing.getDetails().commissionAmount

        if commissionRecipient != nil && commissionAmount != 0.0 {
            // Access the capability to receive the commission.
            let _commissionRecipientCap = getAccount(commissionRecipient!).capabilities.get<&{FungibleToken.Receiver}>(
                    /public/exampleTokenReceiver
                ) ?? panic("Problem getting commission recipient's ExampleToken Receiver")
            assert(_commissionRecipientCap.check(), message: "Commission Recipient doesn't have exampletoken receiving capability")
            self.commissionRecipientCap = _commissionRecipientCap
        } else if commissionAmount == 0.0 {
            self.commissionRecipientCap = nil
        } else {
            panic("Commission recipient can not be empty when commission amount is non zero")
        }
    }

    execute {
        // Purchase the NFT
        let item <- self.listing.purchase(
            payment: <-self.paymentVault,
            commissionRecipient: self.commissionRecipientCap
        )
        // Deposit the NFT in the buyer's collection.
        self.exampleNFTReceiver.deposit(token: <-item)
    }
}
