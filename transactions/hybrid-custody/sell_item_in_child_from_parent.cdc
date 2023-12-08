import "NonFungibleToken"
import "MetadataViews"
import "FungibleToken"
import "FlowToken"

import "HybridCustody"

import "NFTStorefrontV2"

/// Cross-account NFT listing transaction
///
/// Lists an NFT located in the signer's child account for sale in the storefront of the signing parent account with
/// the parent account as beneficiary of the sale.
///
transaction(
    childAddress: Address,
    collectionProviderPath: PrivatePath,
    collectionPublicPath: PublicPath,
    nftTypeIdentifier: String,
    saleItemID: UInt64,
    saleItemPrice: UFix64,
    customID: String?,
    commissionAmount: UFix64,
    expiry: UInt64,
    marketplacesAddress: [Address]
) {
    let flowReceiverCap: Capability<&{FungibleToken.Receiver}>
    let providerCap: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
    let storefront: &NFTStorefrontV2.Storefront
    var saleCuts: [NFTStorefrontV2.SaleCut]
    var marketplaceCaps: [Capability<&{FungibleToken.Receiver}>]
    let nftType: Type

    prepare(acct: AuthAccount) {
        self.saleCuts = []
        self.marketplaceCaps = []
        self.nftType = CompositeType(nftTypeIdentifier) ?? panic("Invalid NFT Type Identifier provided")
        
        // Configure Storefront if one doesn't yet exist
        if acct.borrow<&NFTStorefrontV2.Storefront>(from: NFTStorefrontV2.StorefrontStoragePath) == nil {
            acct.save(<-NFTStorefrontV2.createStorefront(), to: NFTStorefrontV2.StorefrontStoragePath)
            acct.link<&NFTStorefrontV2.Storefront{NFTStorefrontV2.StorefrontPublic}>(
                NFTStorefrontV2.StorefrontPublicPath,
                target: NFTStorefrontV2.StorefrontStoragePath
            )
        }
        // Borrow a reference to the signer's Storefront
        self.storefront = acct.borrow<&NFTStorefrontV2.Storefront>(from: NFTStorefrontV2.StorefrontStoragePath)
            ?? panic("Missing or mis-typed NFTStorefront Storefront")

        // Get a FlowToken Receiver as beneficiary of listing & validate
        self.flowReceiverCap = acct.getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        assert(self.flowReceiverCap.check(), message: "Missing or mis-typed FlowToken receiver")

        // Get reference to the child account
        let manager = acct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("Could not borrow reference to HybridCustody Manager")
        let childAccount = manager.borrowAccount(addr: childAddress)
            ?? panic("No child account exists for the given address")

        // Get the NFT provider capability from the child account & validate
        self.providerCap = childAccount.getCapability(
                path: collectionProviderPath,
                type: Type<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>()
            ) as! Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>?
            ?? panic("NFT Provider Capability is not accessible from child account for specified path")
        assert(self.providerCap.check(), message: "Missing or mis-typed Provider Capability")
        
        // Borrow the NFT as ViewResolver to get Royalties information
        let collection = getAccount(childAddress).getCapability<&{MetadataViews.ResolverCollection}>(
                collectionPublicPath
            ).borrow()
            ?? panic("Could not borrow a reference to the child account's collection")
        var totalRoyaltyCut = 0.0
        let effectiveSaleItemPrice = saleItemPrice - commissionAmount
        let resolver = collection.borrowViewResolver(id: saleItemID)
        assert(resolver.getType() == self.nftType, message: "NFT Type mismatch")

        // Check whether the NFT implements the MetadataResolver or not.
        if resolver.getViews().contains(Type<MetadataViews.Royalties>()) {
            let royaltiesRef = resolver.resolveView(Type<MetadataViews.Royalties>())?? panic("Unable to retrieve the royalties")
            let royalties = (royaltiesRef as! MetadataViews.Royalties).getRoyalties()
            for royalty in royalties {
                self.saleCuts.append(
                    NFTStorefrontV2.SaleCut(receiver: royalty.receiver, amount: royalty.cut * effectiveSaleItemPrice)
                )
                totalRoyaltyCut = totalRoyaltyCut + royalty.cut * effectiveSaleItemPrice
            }
        }
        self.saleCuts.append(NFTStorefrontV2.SaleCut(
            receiver: self.flowReceiverCap,
            amount: effectiveSaleItemPrice - totalRoyaltyCut
        ))

        for marketplace in marketplacesAddress {
            // Here we are making a fair assumption that all given addresses would have
            // the capability to receive the `FlowToken`
            self.marketplaceCaps.append(
                getAccount(marketplace).getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            )
        }
    }

    execute {
        // Create listing
        self.storefront.createListing(
            nftProviderCapability: self.providerCap,
            nftType: self.nftType,
            nftID: saleItemID,
            salePaymentVaultType: Type<@FlowToken.Vault>(),
            saleCuts: self.saleCuts,
            marketplacesCapability: self.marketplaceCaps.length == 0 ? nil : self.marketplaceCaps,
            customID: customID,
            commissionAmount: commissionAmount,
            expiry: expiry
        )
    }
}
