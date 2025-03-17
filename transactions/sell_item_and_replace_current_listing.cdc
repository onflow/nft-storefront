import ExampleToken from "../contracts/utility/ExampleToken.cdc"
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
/// `commissionAmount` - Commission amount that will be taken away by the purchase facilitator.
/// `expiry` - Unix timestamp at which created listing become expired.
/// `marketplacesAddress` - List of addresses that are allowed to get the commission.

/// If the given nft has a support of the RoyaltyView then royalties will added as the sale cut.

transaction(
    saleItemID: UInt64,
    saleItemPrice: UFix64,
    customID: String?,
    commissionAmount: UFix64,
    expiry: UInt64,
    marketplacesAddress: [Address]
) {

    let tokenReceiver: Capability<&{FungibleToken.Receiver}>
    let exampleNFTProvider: Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>
    let storefront: auth(NFTStorefrontV2.CreateListing, NFTStorefrontV2.RemoveListing) &NFTStorefrontV2.Storefront
    var saleCuts: [NFTStorefrontV2.SaleCut]
    var marketplacesCapability: [Capability<&{FungibleToken.Receiver}>]

    prepare(acct: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue, StorageCapabilities) &Account) {
        self.saleCuts = []
        self.marketplacesCapability = []

        let collectionData = ExampleNFT.resolveContractView(resourceType: nil, viewType: Type<MetadataViews.NFTCollectionData>()) as! MetadataViews.NFTCollectionData?
            ?? panic("ViewResolver does not resolve NFTCollectionData view")

        // Receiver for the sale cut.
        self.tokenReceiver = acct.capabilities.get<&{FungibleToken.Receiver}>(/public/exampleTokenReceiver)
        assert(self.tokenReceiver.borrow() != nil, message: "Missing or mis-typed ExampleToken receiver")

        var nftProviderCap: Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>? = nil
        // check if there is an existing capability/capability controller for the storage path
        let nftCollectionControllers = acct.capabilities.storage.getControllers(forPath: collectionData.storagePath)
        for controller in nftCollectionControllers {
            if let maybeProviderCap = controller.capability as? Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>? {
                nftProviderCap = maybeProviderCap
                break
            }
        }

        // if there are no capabilities created for that storage path
        // or if existing capability is no longer valid, issue a new one
        if nftProviderCap == nil || nftProviderCap?.check() ?? false {
            nftProviderCap = acct.capabilities.storage.issue<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>(
                collectionData.storagePath
            )
        }
        assert(nftProviderCap?.check() ?? false, message: "Could not assign Provider Capability")

        self.exampleNFTProvider = nftProviderCap!

        let collection = acct.capabilities.borrow<&{NonFungibleToken.Collection}>(
                collectionData.publicPath
            ) ?? panic("Could not borrow a reference to the signer's collection")

        var totalRoyaltyCut = 0.0
        let effectiveSaleItemPrice = saleItemPrice - commissionAmount
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
                        amount: royalty.cut * effectiveSaleItemPrice
                    )
                )
                totalRoyaltyCut = totalRoyaltyCut + (royalty.cut * effectiveSaleItemPrice)
            }
        }
        // Append the cut for the seller.
        self.saleCuts.append(
            NFTStorefrontV2.SaleCut(
                receiver: self.tokenReceiver,
                amount: effectiveSaleItemPrice - totalRoyaltyCut
            )
        )
        assert(self.exampleNFTProvider.borrow() != nil, message: "Missing or mis-typed ExampleNFT.Collection provider")

        self.storefront = acct.storage.borrow<auth(NFTStorefrontV2.CreateListing, NFTStorefrontV2.RemoveListing) &NFTStorefrontV2.Storefront>(
                from: NFTStorefrontV2.StorefrontStoragePath
            ) ?? panic("Missing or mis-typed NFTStorefront Storefront")

        for marketplace in marketplacesAddress {
            // Here we are making a fair assumption that all given addresses would have
            // the capability to receive the `ExampleToken`
            self.marketplacesCapability.append(
                getAccount(marketplace).capabilities.get<&{FungibleToken.Receiver}>(/public/exampleTokenReceiver)
            )
        }
    }

    execute {
        // check for existing listings of the NFT
        var existingListingIDs = self.storefront.getExistingListingIDs(
            nftType: Type<@ExampleNFT.NFT>(),
            nftID: saleItemID
        )
        // remove existing listings
        for listingID in existingListingIDs {
            self.storefront.removeListing(listingResourceID: listingID)
        }
        // Create listing
        self.storefront.createListing(
            nftProviderCapability: self.exampleNFTProvider,
            nftType: Type<@ExampleNFT.NFT>(),
            nftID: saleItemID,
            salePaymentVaultType: Type<@ExampleToken.Vault>(),
            saleCuts: self.saleCuts,
            marketplacesCapability: self.marketplacesCapability.length == 0 ? nil : self.marketplacesCapability,
            customID: customID,
            commissionAmount: commissionAmount,
            expiry: expiry
        )
    }
}
