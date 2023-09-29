import FlowToken from "FlowToken"
import FungibleToken from "../contracts/utility/FungibleToken.cdc"
import NonFungibleToken from "../contracts/utility/NonFungibleToken.cdc"
import MetadataViews from "../contracts/utility/MetadataViews.cdc"
import NFTCatalog from "../contracts/utility/NFTCatalog.cdc"
import NFTStorefrontV2 from "../contracts/NFTStorefrontV2.cdc"

/// Transaction used to facilitate the creation of the listing under the signer's owned storefront resource.
/// It accepts the certain details from the signer,i.e. - 
///
/// `saleItemID` - ID of the NFT that is put on sale by the seller.
/// `saleItemPrice` - Amount of tokens (FT) buyer needs to pay for the purchase of listed NFT.
/// `customID` - Optional string to represent identifier of the dapp.
/// `commissionAmount` - Commission amount that will be taken away by the purchase facilitator.
/// `expiry` - Unix timestamp at which created listing become expired.
/// `marketplacesAddress` - List of addresses that are allowed to get the commission.

/// If the given nft has a support of the RoyaltyView then royalties will added as the sale cut.

transaction(
    collectionIdentifier: String,
    saleItemID: UInt64,
    saleItemPrice: UFix64,
    customID: String?,
    commissionAmount: UFix64,
    expiry: UInt64,
    marketplacesAddress: [Address]
) {

    let flowReceiver: Capability<&AnyResource{FungibleToken.Receiver}>
    let catalog: {String : NFTCatalog.NFTCatalogMetadata}
    let collectionCap: Capability<auth(NonFungibleToken.Withdrawable) &{NonFungibleToken.Collection}>
    let storefront: auth(NFTStorefrontV2.Creatable) &NFTStorefrontV2.Storefront
    var saleCuts: [NFTStorefrontV2.SaleCut]
    var marketplacesCapability: [Capability<&AnyResource{FungibleToken.Receiver}>]

    prepare(acct: AuthAccount) {
        self.catalog = NFTCatalog.getCatalog()
        assert(self.catalog.containsKey(collectionIdentifier), message: "Provided collection is not in the NFT Catalog.")
        let value = self.catalog[collectionIdentifier]!

        self.saleCuts = []
        self.marketplacesCapability = []

        // We'll need to know where to target an issued Collection capability
        let collectionData = ExampleNFT.getCollectionData(nftType: Type<@ExampleNFT.NFT>())
            ?? panic("Missing collection data")

        // Receiver for the sale cut.
        self.flowReceiver = acct.capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)!
        assert(self.flowReceiver.borrow() != nil, message: "Missing or mis-typed FlowToken receiver")

        // Check if the Provider capability exists or not if `no` then create a new link for the same.
        self.collectionCap = acct.capabilities.storage.issue<auth(NonFungibleToken.Withdrawable) &{NonFungibleToken.Collection}>(
                collectionData.storagePath
            )
        assert(self.collectionCap.check(), message: "Could not borrow a reference to the collection")

        var totalRoyaltyCut = 0.0
        let effectiveSaleItemPrice = saleItemPrice - commissionAmount
        let views = collection.borrowViewResolver(id: saleItemID)
        // Check whether the NFT implements the MetadataResolver or not.
        if views.getViews().contains(Type<MetadataViews.Royalties>()) {
            let royaltiesRef = views.resolveView(Type<MetadataViews.Royalties>())?? panic("Unable to retrieve the royalties")
            let royalties = (royaltiesRef as! MetadataViews.Royalties).getRoyalties()
            for royalty in royalties {
                // TODO - Verify the type of the vault and it should exists
                self.saleCuts.append(
                    NFTStorefrontV2.SaleCut(
                        receiver: royalty.receiver,
                        amount: royalty.cut * effectiveSaleItemPrice
                    )
                )
                totalRoyaltyCut = totalRoyaltyCut + (royalty.cut * effectiveSaleItemPrice)
            }
        }

        // Append the cut for the seller.
        self.saleCuts.append(
            NFTStorefrontV2.SaleCut(
                receiver: self.flowReceiver,
                amount: effectiveSaleItemPrice - totalRoyaltyCut
            )
        )

        self.storefront = acct.storage.borrow<auth(NFTStorefrontV2.Creatable) &NFTStorefrontV2.Storefront>(
                from: NFTStorefrontV2.StorefrontStoragePath
            ) ?? panic("Missing or mis-typed NFTStorefront Storefront")

        for marketplace in marketplacesAddress {
            // Here we are making a fair assumption that all given addresses would have
            // the capability to receive the `FlowToken`
            self.marketplacesCapability.append(
                getAccount(marketplace).capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                    ?? panic("Problem getting Marketplace FlowToken Receiver")
            )
        }
    }

    execute {
        // Create listing
        self.storefront.createListing(
            nftProviderCapability: self.collectionCap,
            nftType: self.catalog[collectionIdentifier]!.nftType,
            nftID: saleItemID,
            salePaymentVaultType: Type<@FlowToken.Vault>(),
            saleCuts: self.saleCuts,
            marketplacesCapability: self.marketplacesCapability.length == 0 ? nil : self.marketplacesCapability,
            customID: customID,
            commissionAmount: commissionAmount,
            expiry: expiry
        )
    }
}
