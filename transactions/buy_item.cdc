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
transaction(listingResourceID: UInt64,
            storefrontAddress: Address,
            commissionRecipient: Address?) {

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
            ) ?? panic("Could not get a Storefront from the provided address \(storefrontAddress)!")

        // Borrow the listing
        self.listing = self.storefront.borrowListing(listingResourceID: listingResourceID)
            ?? panic("Could not get a listing with ID \(listingResourceID) from the storefront in account \(storefrontAddress)")
        let price = self.listing.getDetails().salePrice

        // Access the vault of the buyer to pay the sale price of the listing.
        let mainVault = acct.storage.borrow<auth(FungibleToken.Withdraw) &ExampleToken.Vault>(from: /storage/exampleTokenVault)
            ?? panic("The signer does not store an ExampleToken.Vault object at the path /storage/exampleTokenVault "
                    .concat(". The signer must initialize their account with this vault first!"))
        self.paymentVault <- mainVault.withdraw(amount: price)

        // Access the buyer's NFT collection to store the purchased NFT.
        let collectionData = ExampleNFT.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionData>()) as! MetadataViews.NFTCollectionData?
            ?? panic("Could not resolve NFTCollectionData view. The ExampleNFT contract needs to implement the NFTCollectionData Metadata view in order to execute this transaction")

        self.exampleNFTReceiver = acct.capabilities.borrow<&{NonFungibleToken.Receiver}>(collectionData.publicPath)
            ?? panic("Cannot borrow an NFT collection receiver from the signer's account at path \(collectionData.publicPath).")

        // Fetch the commission amt.
        let commissionAmount = self.listing.getDetails().commissionAmount

        if commissionRecipient != nil && commissionAmount != 0.0 {
            // Access the capability to receive the commission.
            let _commissionRecipientCap = getAccount(commissionRecipient!).capabilities.get<&{FungibleToken.Receiver}>(
                    /public/exampleTokenReceiver
                )
            assert(_commissionRecipientCap.check(), message: "Commission Recipient doesn't have ExampleToken receiving capability")
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
