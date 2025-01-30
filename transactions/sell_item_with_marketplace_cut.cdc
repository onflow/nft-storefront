import FlowToken from "FlowToken"
import FungibleToken from "../contracts/utility/FungibleToken.cdc"
import NonFungibleToken from "../contracts/utility/NonFungibleToken.cdc"
import ExampleNFT from "../contracts/utility/ExampleNFT.cdc"
import MetadataViews from "../contracts/utility/MetadataViews.cdc"
import NFTStorefrontV2 from "../contracts/NFTStorefrontV2.cdc"

/// Transaction used to facilitate the creation of the listing under the signer's owned storefront resource.
/// It accepts the certain details from the signer,i.e. - 
///
/// `saleItemID` - ID of the NFT that is put on sale by the seller.
/// `saleItemPrice` - Amount of tokens (FT) buyer needs to pay for the purchase of listed NFT.
/// `customID` - Optional string to represent identifier of the dapp.
/// `expiry` - Unix timestamp at which created listing become expired.
/// `marketPlaceSaleCutReceiver` - Marketplace sale cut receiver.
/// `marketPlaceSaleCutPercentage` - Percentage of the sale price received by the marketplace.

/// If the given nft has a support of the RoyaltyView then royalties will added as the sale cut.

transaction(
    saleItemID: UInt64,
    saleItemPrice: UFix64,
    customID: String?,
    expiry: UInt64,
    marketPlaceSaleCutReceiver: Address,
    marketPlaceSaleCutPercentage: UFix64
) {
    let flowReceiver: Capability<&{FungibleToken.Receiver}>
    let exampleNFTProvider: Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>
    let storefront: auth(NFTStorefrontV2.CreateListing) &NFTStorefrontV2.Storefront
    var saleCuts: [NFTStorefrontV2.SaleCut]
    var marketplacesCapability: [Capability<&{FungibleToken.Receiver}>]

    prepare(acct: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue) &Account) {

        self.saleCuts = []
        self.marketplacesCapability = []

        let collectionData = ExampleNFT.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionData>()) as! MetadataViews.NFTCollectionData?
            ?? panic("Could not resolve NFTCollectionData view. The ExampleNFT contract needs to implement the NFTCollectionData Metadata view in order to execute this transaction")

        // Receiver for the sale cut.
        self.flowReceiver = acct.capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        assert(
            self.flowReceiver.borrow() != nil,
            message: "Missing or mis-typed FlowToken receiver"
        )

        self.exampleNFTProvider = acct.capabilities.storage.issue<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>(
                collectionData.storagePath
            )
        assert(
            self.exampleNFTProvider.check(),
            message: "Missing or mis-typed ExampleNFT provider"
        )

        let collection = acct.capabilities.borrow<&{NonFungibleToken.Collection}>(
                collectionData.publicPath
            ) ?? panic("Could not borrow a reference to the signer's collection")

        var totalRoyaltyCut = 0.0
        let nft = collection.borrowNFT(saleItemID)!
        // Check whether the NFT implements the MetadataResolver or not.
        if nft.getViews().contains(Type<MetadataViews.Royalties>()) {
            let royaltiesRef = nft.resolveView(Type<MetadataViews.Royalties>())?? panic("Unable to retrieve the royalties")
            let royalties = (royaltiesRef as! MetadataViews.Royalties).getRoyalties()
            for royalty in royalties {
                // TODO - Verify the type of the vault and it should exists
                self.saleCuts.append(
                    NFTStorefrontV2.SaleCut(
                        receiver: royalty.receiver,
                        amount: royalty.cut * saleItemPrice
                    )
                )
                totalRoyaltyCut = totalRoyaltyCut + royalty.cut * saleItemPrice
            }
        }
        // Append the cut for the seller.
        self.saleCuts.append(
            NFTStorefrontV2.SaleCut(
                receiver: self.flowReceiver,
                amount: saleItemPrice - totalRoyaltyCut - saleItemPrice * marketPlaceSaleCutPercentage
            )
        )
        assert(self.exampleNFTProvider.borrow() != nil, message: "Missing or mis-typed ExampleNFT.Collection provider")

        self.storefront = acct.storage.borrow<auth(NFTStorefrontV2.CreateListing) &NFTStorefrontV2.Storefront>(
                from: NFTStorefrontV2.StorefrontStoragePath
            ) ?? panic("Could not get a Storefront from the signer's account at path \(NFTStorefrontV2.StorefrontStoragePath)!"
                        .concat("Make sure the signer has initialized their account with a NFTStorefrontV2 storefront!"))

        // Here we are making a fair assumption that all given addresses would have
        // the capability to receive the `FlowToken`
        let marketPlaceCapability = getAccount(marketPlaceSaleCutReceiver).capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)

        // Append the cut for the marketplace.
        self.saleCuts.append(
            NFTStorefrontV2.SaleCut(
                receiver: marketPlaceCapability,
                amount: saleItemPrice * marketPlaceSaleCutPercentage
            )
        )
    }

    execute {
        // Create listing
        self.storefront.createListing(
            nftProviderCapability: self.exampleNFTProvider,
            nftType: Type<@ExampleNFT.NFT>(),
            nftID: saleItemID,
            salePaymentVaultType: Type<@FlowToken.Vault>(),
            saleCuts: self.saleCuts,
            marketplacesCapability: nil,
            customID: customID,
            commissionAmount: 0.0,
            expiry: expiry
        )
    }
}
