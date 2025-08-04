import "FungibleToken"
import "FungibleTokenMetadataViews"
import "NonFungibleToken"
import "MetadataViews"
import "NFTStorefrontV2"

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
    marketPlaceSaleCutPercentage: UFix64,
    nftTypeIdentifier: String,
    ftTypeIdentifier: String
) {
    let ftReceiver: Capability<&{FungibleToken.Receiver}>
    let nftProvider: Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>
    let storefront: auth(NFTStorefrontV2.CreateListing) &NFTStorefrontV2.Storefront
    var saleCuts: [NFTStorefrontV2.SaleCut]
    var marketplacesCapability: [Capability<&{FungibleToken.Receiver}>]

    prepare(acct: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue, StorageCapabilities) &Account) {

        // If the account doesn't already have a Storefront
        // Create a new empty Storefront
        if acct.storage.borrow<&NFTStorefrontV2.Storefront>(from: NFTStorefrontV2.StorefrontStoragePath) == nil {

            // Create a new empty Storefront
            let storefront <- NFTStorefrontV2.createStorefront() as! @NFTStorefrontV2.Storefront
            
            // save it to the account
            acct.storage.save(<-storefront, to: NFTStorefrontV2.StorefrontStoragePath)

            // create a public capability for the Storefront
            let storefrontPublicCap = acct.capabilities.storage.issue<&{NFTStorefrontV2.StorefrontPublic}>(
                    NFTStorefrontV2.StorefrontStoragePath
                )
            acct.capabilities.publish(storefrontPublicCap, at: NFTStorefrontV2.StorefrontPublicPath)
        }

        // Get the metadata views for the NFT and FT types that are used in this transaction
        let collectionData = MetadataViews.resolveContractViewFromTypeIdentifier(
            resourceTypeIdentifier: nftTypeIdentifier,
            viewType: Type<MetadataViews.NFTCollectionData>()
        ) as? MetadataViews.NFTCollectionData
            ?? panic("Could not construct valid NFT type and view from identifier \(nftTypeIdentifier)")

        let vaultData = MetadataViews.resolveContractViewFromTypeIdentifier(
            resourceTypeIdentifier: ftTypeIdentifier,
            viewType: Type<FungibleTokenMetadataViews.FTVaultData>()
        ) as? FungibleTokenMetadataViews.FTVaultData
            ?? panic("Could not construct valid FT type and view from identifier \(ftTypeIdentifier)")

        self.saleCuts = []
        self.marketplacesCapability = []

        // Receiver for the sale cut.
        self.ftReceiver = acct.capabilities.get<&{FungibleToken.Receiver}>(vaultData.receiverPath)
        assert(
            self.ftReceiver.borrow() != nil,
            message: "Missing or mis-typed Fungible Token receiver for token \(ftTypeIdentifier) at path \(vaultData.receiverPath)"
        )

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

        self.nftProvider = nftProviderCap!

        let collection = acct.capabilities.borrow<&{NonFungibleToken.Collection}>(
                collectionData.publicPath
            ) ?? panic("Could not borrow a reference to the signer's collection")

        var totalRoyaltyCut = 0.0
        let nft = collection.borrowNFT(saleItemID)!
        // Check whether the NFT implements the MetadataResolver or not.
        if nft.getViews().contains(Type<MetadataViews.Royalties>()) {
            let royaltiesRef = nft.resolveView(Type<MetadataViews.Royalties>())
                ?? panic("Unable to retrieve the Royalties metadata from the NFT for sale with ID \(nft.id).")
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
                receiver: self.ftReceiver,
                amount: saleItemPrice - totalRoyaltyCut - saleItemPrice * marketPlaceSaleCutPercentage
            )
        )
        assert(self.nftProvider.borrow() != nil, message: "Missing or mis-typed NFT Collection provider")

        self.storefront = acct.storage.borrow<auth(NFTStorefrontV2.CreateListing) &NFTStorefrontV2.Storefront>(
                from: NFTStorefrontV2.StorefrontStoragePath
            ) ?? panic("Could not get a Storefront from the signer's account at path \(NFTStorefrontV2.StorefrontStoragePath)!"
                        .concat("Make sure the signer has initialized their account with a NFTStorefrontV2 storefront!"))

        // Here we are making a fair assumption that all given addresses would have
        // the capability to receive the fungible token
        let marketPlaceCapability = getAccount(marketPlaceSaleCutReceiver).capabilities.get<&{FungibleToken.Receiver}>(vaultData.receiverPath)

        // Append the cut for the marketplace.
        self.saleCuts.append(
            NFTStorefrontV2.SaleCut(
                receiver: marketPlaceCapability,
                amount: saleItemPrice * marketPlaceSaleCutPercentage
            )
        )
    }

    execute {
        let nftType = CompositeType(nftTypeIdentifier)!
        let ftType = CompositeType(ftTypeIdentifier)!

        // Create listing
        self.storefront.createListing(
            nftProviderCapability: self.nftProvider,
            nftType: nftType,
            nftID: saleItemID,
            salePaymentVaultType: ftType,
            saleCuts: self.saleCuts,
            marketplacesCapability: nil,
            customID: customID,
            commissionAmount: 0.0,
            expiry: expiry
        )
    }
}
