import "FungibleToken"
import "NonFungibleToken"

/// NFTStorefrontV2
///
/// A general purpose sale support contract for NFTs that implement the Flow NonFungibleToken standard.
/// 
/// Each account that wants to list NFTs for sale installs a Storefront,
/// and lists individual sales within that Storefront as Listings.
/// There is one Storefront per account, it handles sales of all NFT types
/// for that account.
///
/// Each Listing can have one or more "cuts" of the sale price that
/// goes to one or more addresses. Cuts can be used to pay listing fees
/// or other considerations. 
/// Each Listing can include a commission amount that is paid to whoever facilitates
/// the purchase. The seller can also choose to provide an optional list of marketplace 
/// receiver capabilities. In this case, the commission amount must be transferred to
/// one of the capabilities in the list.
///
/// Each NFT may be listed in one or more Listings, the validity of each
/// Listing can easily be checked.
/// 
/// Purchasers can watch for Listing events and check the NFT type and
/// ID to see if they wish to buy the listed item.
/// Marketplaces and other aggregators can watch for Listing events
/// and list items of interest.
///
access(all) contract NFTStorefrontV2 {

    access(all) entitlement CreateListing
    access(all) entitlement RemoveListing

    /// StorefrontInitialized
    /// A Storefront resource has been created.
    /// Event consumers can now expect events from this Storefront.
    /// Note that we do not specify an address: we cannot and should not.
    /// Created resources do not have an owner address, and may be moved
    /// after creation in ways we cannot check.
    /// ListingAvailable events can be used to determine the address
    /// of the owner of the Storefront (...its location) at the time of
    /// the listing but only at that precise moment in that precise transaction.
    /// If the seller moves the Storefront while the listing is valid, 
    /// that is on them.
    ///
    access(all) event StorefrontInitialized(storefrontResourceID: UInt64)

    /// ListingAvailable
    /// A listing has been created and added to a Storefront resource.
    /// The Address values here are valid when the event is emitted, but
    /// the state of the accounts they refer to may change outside of the
    /// NFTStorefrontV2 workflow, so be careful to check when using them.
    ///
    access(all) event ListingAvailable(
        storefrontAddress: Address,
        listingResourceID: UInt64,
        nftType: Type,
        nftUUID: UInt64, 
        nftID: UInt64,
        salePaymentVaultType: Type,
        salePrice: UFix64,
        customID: String?,
        commissionAmount: UFix64,
        commissionReceivers: [Address]?,
        expiry: UInt64
    )

    /// ListingCompleted
    /// The listing has been resolved. It has either been purchased, removed or destroyed.
    ///
    access(all) event ListingCompleted(
        listingResourceID: UInt64, 
        storefrontResourceID: UInt64, 
        purchased: Bool,
        nftType: Type,
        nftUUID: UInt64,
        nftID: UInt64,
        salePaymentVaultType: Type,
        salePrice: UFix64,
        customID: String?,
        commissionAmount: UFix64,
        commissionReceiver: Address?,
        expiry: UInt64
    )

    /// UnpaidReceiver
    /// A entitled receiver has not been paid during the sale of the NFT.
    ///
    access(all) event UnpaidReceiver(receiver: Address, entitledSaleCut: UFix64)

    /// StorefrontStoragePath
    /// The location in storage that a Storefront resource should be located.
    access(all) let StorefrontStoragePath: StoragePath

    /// StorefrontPublicPath
    /// The public location for a Storefront link.
    access(all) let StorefrontPublicPath: PublicPath


    /// SaleCut
    /// A struct representing a recipient that must be sent a certain amount
    /// of the payment when a token is sold.
    ///
    access(all) struct SaleCut {
        /// The receiver for the payment.
        /// Note that we do not store an address to find the Vault that this represents,
        /// as the link or resource that we fetch in this way may be manipulated,
        /// so to find the address that a cut goes to you must get this struct and then
        /// call receiver.borrow()!.owner.address on it.
        /// This can be done efficiently in a script.
        access(all) let receiver: Capability<&{FungibleToken.Receiver}>

        /// The amount of the payment FungibleToken that will be paid to the receiver.
        access(all) let amount: UFix64

        /// initializer
        ///
        init(receiver: Capability<&{FungibleToken.Receiver}>, amount: UFix64) {
            self.receiver = receiver
            self.amount = amount
        }
    }


    /// ListingDetails
    /// A struct containing a Listing's data.
    ///
    access(all) struct ListingDetails {
        /// The Storefront that the Listing is stored in.
        /// Note that this resource cannot be moved to a different Storefront,
        /// so this is OK. If we ever make it so that it *can* be moved,
        /// this should be revisited.
        access(all) var storefrontID: UInt64
        /// Whether this listing has been purchased or not.
        access(all) var purchased: Bool
        /// The Type of the NonFungibleToken.NFT that is being listed.
        access(all) let nftType: Type
        /// The Resource ID of the NFT which can only be set in the contract
        access(all) let nftUUID: UInt64
        /// The unique identifier of the NFT that will get sell.
        access(all) let nftID: UInt64
        /// The Type of the FungibleToken that payments must be made in.
        access(all) let salePaymentVaultType: Type
        /// The amount that must be paid in the specified FungibleToken.
        access(all) let salePrice: UFix64
        /// This specifies the division of payment between recipients.
        access(all) let saleCuts: [SaleCut]
        /// Allow different dapp teams to provide custom strings as the distinguished string
        /// that would help them to filter events related to their customID.
        access(all) var customID: String?
        /// Commission available to be claimed by whoever facilitates the sale.
        access(all) let commissionAmount: UFix64
        /// Expiry of listing
        access(all) let expiry: UInt64

        /// Irreversibly set this listing as purchased.
        ///
        access(contract) fun setToPurchased() {
            self.purchased = true
        }

        access(contract) fun setCustomID(customID: String?){
            self.customID = customID
        }

        /// Initializer
        ///
        init (
            nftType: Type,
            nftUUID: UInt64,
            nftID: UInt64,
            salePaymentVaultType: Type,
            saleCuts: [SaleCut],
            storefrontID: UInt64,
            customID: String?,
            commissionAmount: UFix64,
            expiry: UInt64
        ) {

            pre {
                // Validate the expiry
                expiry > UInt64(getCurrentBlock().timestamp): "Expiry should be in the future"
                // Validate the length of the sale cut
                saleCuts.length > 0: "Listing must have at least one payment cut recipient"
            }

            self.storefrontID = storefrontID
            self.purchased = false
            self.nftType = nftType
            self.nftUUID = nftUUID
            self.nftID = nftID
            self.salePaymentVaultType = salePaymentVaultType
            self.customID = customID
            self.commissionAmount = commissionAmount
            self.expiry = expiry
            self.saleCuts = saleCuts

            // Calculate the total price from the cuts
            var salePrice = commissionAmount
            // Perform initial check on capabilities, and calculate sale price from cut amounts.
            for cut in self.saleCuts {
                // Make sure we can borrow the receiver.
                // We will check this again when the token is sold.
                cut.receiver.borrow()
                    ?? panic("Cannot borrow receiver")
                // Add the cut amount to the total price
                salePrice = salePrice + cut.amount
            }
            assert(salePrice > 0.0, message: "Listing must have non-zero price")

            // Store the calculated sale price
            self.salePrice = salePrice
        }
    }


    /// ListingPublic
    /// An interface providing a useful public interface to a Listing.
    ///
    access(all) resource interface ListingPublic {
        /// borrowNFT
        /// This will assert in the same way as the NFT standard borrowNFT()
        /// if the NFT is absent, for example if it has been sold via another listing.
        ///
        access(all) fun borrowNFT(): &{NonFungibleToken.NFT}?

        /// purchase
        /// Purchase the listing, buying the token.
        /// This pays the beneficiaries and returns the token to the buyer.
        ///
        access(all) fun purchase(
            payment: @{FungibleToken.Vault}, 
            commissionRecipient: Capability<&{FungibleToken.Receiver}>?,
        ): @{NonFungibleToken.NFT}

        /// getDetails
        /// Fetches the details of the listing.
        access(all) view fun getDetails(): ListingDetails

        /// getAllowedCommissionReceivers
        /// Fetches the allowed marketplaces capabilities or commission receivers.
        /// If it returns `nil` then commission is up to grab by anyone.
        access(all) view fun getAllowedCommissionReceivers(): [Capability<&{FungibleToken.Receiver}>]?

        /// hasListingBecomeGhosted
        /// Tells whether listed NFT is present in provided capability.
        /// If it returns `false` then it means listing becomes ghost or sold out.
        access(all) view fun hasListingBecomeGhosted(): Bool

    }


    /// Listing
    /// A resource that allows an NFT to be sold for an amount of a given FungibleToken,
    /// and for the proceeds of that sale to be split between several recipients.
    /// 
    access(all) resource Listing: ListingPublic {
        /// The simple (non-Capability, non-complex) details of the sale
        access(self) let details: ListingDetails

        /// A capability allowing this resource to withdraw the NFT with the given ID from its collection.
        /// This capability allows the resource to withdraw *any* NFT, so you should be careful when giving
        /// such a capability to a resource and always check its code to make sure it will use it in the
        /// way that it claims.
        access(contract) let nftProviderCapability: Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>

        /// An optional list of marketplaces capabilities that are approved 
        /// to receive the marketplace commission.
        access(contract) let marketplacesCapability: [Capability<&{FungibleToken.Receiver}>]?

        /// borrowNFT
        /// Return the reference of the NFT that is listed for sale.
        /// if the NFT is absent, for example if it has been sold via another listing.
        /// it will return nil.
        ///
        access(all) fun borrowNFT(): &{NonFungibleToken.NFT}? {
            let ref = self.nftProviderCapability.borrow()!.borrowNFT(self.details.nftID)
            if ref.isInstance(self.details.nftType) && ref?.id == self.details.nftID {
                return ref as &{NonFungibleToken.NFT}?  
            } 
            return nil
        }

        /// getDetails
        /// Get the details of listing.
        ///
        access(all) view fun getDetails(): ListingDetails {
            return self.details
        }

        /// getAllowedCommissionReceivers
        /// Fetches the allowed marketplaces capabilities or commission receivers.
        /// If it returns `nil` then commission is up to grab by anyone.
        access(all) view fun getAllowedCommissionReceivers(): [Capability<&{FungibleToken.Receiver}>]? {
            return self.marketplacesCapability
        }

        /// hasListingBecomeGhosted
        /// Tells whether listed NFT is present in provided capability.
        /// If it returns `false` then it means listing becomes ghost or sold out.
        access(all) view fun hasListingBecomeGhosted(): Bool {
            if let providerRef = self.nftProviderCapability.borrow() {
                return providerRef.borrowNFT(self.details.nftID) != nil
            }
            return false
        }

        /// purchase
        /// Purchase the listing, buying the token.
        /// This pays the beneficiaries and commission to the facilitator and returns extra token to the buyer.
        /// This also cleans up duplicate listings for the item being purchased.
        access(all) fun purchase(
            payment: @{FungibleToken.Vault}, 
            commissionRecipient: Capability<&{FungibleToken.Receiver}>?,
        ): @{NonFungibleToken.NFT} {

            pre {
                self.details.purchased == false: "listing has already been purchased"
                payment.isInstance(self.details.salePaymentVaultType): "payment vault is not requested fungible token"
                payment.balance == self.details.salePrice: "payment vault does not contain requested price"
                self.details.expiry > UInt64(getCurrentBlock().timestamp): "Listing is expired"
                self.owner != nil : "Resource doesn't have the assigned owner"
            }
            
            // Make sure the listing cannot be purchased again.
            self.details.setToPurchased() 
            
            if self.details.commissionAmount > 0.0 {
                // If commission recipient is nil, Throw panic.
                let commissionReceiver = commissionRecipient ?? panic("Commission recipient can't be nil")
                if self.marketplacesCapability != nil {
                    var isCommissionRecipientHasValidType = false
                    var isCommissionRecipientAuthorised = false
                    for cap in self.marketplacesCapability! {
                        // Check 1: Should have the same type
                        if cap.getType() == commissionReceiver.getType() {
                            isCommissionRecipientHasValidType = true
                            // Check 2: Should have the valid market address that holds approved capability.
                            if cap.address == commissionReceiver.address && cap.check() {
                                isCommissionRecipientAuthorised = true
                                break
                            }
                        }
                    }
                    assert(isCommissionRecipientHasValidType, message: "Given recipient does not has valid type")
                    assert(isCommissionRecipientAuthorised, message: "Given recipient is not authorised to receive the commission")
                }
                let commissionPayment <- payment.withdraw(amount: self.details.commissionAmount)
                let recipient = commissionReceiver.borrow() ?? panic("Unable to borrow the recipient capability")
                recipient.deposit(from: <- commissionPayment)
            }
            // Fetch the token to return to the purchaser.
            let nft <-self.nftProviderCapability.borrow()!.withdraw(withdrawID: self.details.nftID)
            // Neither receivers nor providers are trustworthy, they must implement the correct
            // interface but beyond complying with its pre/post conditions they are not guaranteed
            // to implement the functionality behind the interface in any given way.
            // Therefore we cannot trust the Collection resource behind the interface,
            // and we must check the NFT resource it gives us to make sure that it is the correct one.
            assert(nft.getType() == self.details.nftType, message: "withdrawn NFT is not of specified type")
            assert(nft.id == self.details.nftID, message: "withdrawn NFT does not have specified ID")

            // Fetch the duplicate listing for the given NFT
            // Access the StoreFrontManager resource reference to remove the duplicate listings if purchase would happen successfully.
            let storeFrontPublicRef = getAccount(self.owner!.address).capabilities.borrow<&{NFTStorefrontV2.StorefrontPublic}>(
                    NFTStorefrontV2.StorefrontPublicPath
                ) ?? panic("Unable to borrow the storeFrontManager resource")
            let duplicateListings = storeFrontPublicRef.getDuplicateListingIDs(
                    nftType: self.details.nftType,
                    nftID: self.details.nftID,
                    listingID: self.uuid
                )

            // Let's force removal of the listing in this storefront for the NFT that is being purchased. 
            for listingID in duplicateListings {
                storeFrontPublicRef.cleanup(listingResourceID: listingID)
            }

            // Rather than aborting the transaction if any receiver is absent when we try to pay it,
            // we send the cut to the first valid receiver.
            // The first receiver should therefore either be the seller, or an agreed recipient for
            // any unpaid cuts.
            var residualReceiver: &{FungibleToken.Receiver}? = nil
            // Pay the commission 
            // Pay each beneficiary their amount of the payment.

            for cut in self.details.saleCuts {
                if let receiver = cut.receiver.borrow() {
                   let paymentCut <- payment.withdraw(amount: cut.amount)
                    receiver.deposit(from: <-paymentCut)
                    if (residualReceiver == nil) {
                        residualReceiver = receiver
                    }
                } else {
                    emit UnpaidReceiver(receiver: cut.receiver.address, entitledSaleCut: cut.amount)
                }
            }

            assert(residualReceiver != nil, message: "No valid payment receivers")

            // At this point, if all receivers were active and available, then the payment Vault will have
            // zero tokens left, and this will functionally be a no-op that consumes the empty vault
            residualReceiver!.deposit(from: <-payment)

            // If the listing is purchased, we regard it as completed here.
            // Otherwise we regard it as completed in the destructor.

            var commissionReceiver: Address?  = nil
            if (self.details.commissionAmount != 0.0) {
                commissionReceiver = commissionRecipient!.address
            }

            emit ListingCompleted(
                listingResourceID: self.uuid,
                storefrontResourceID: self.details.storefrontID,
                purchased: self.details.purchased,
                nftType: self.details.nftType,
                nftUUID: self.details.nftUUID,
                nftID: self.details.nftID,
                salePaymentVaultType: self.details.salePaymentVaultType,
                salePrice: self.details.salePrice,
                customID: self.details.customID,
                commissionAmount: self.details.commissionAmount,
                commissionReceiver: commissionReceiver,
                expiry: self.details.expiry
            )

            return <-nft
        }

        // destructor event
        //
        access(all) event ResourceDestroyed(
            listingResourceID: UInt64 = self.uuid,
            storefrontResourceID: UInt64 = self.details.storefrontID,
            purchased: Bool = self.details.purchased,
            nftType: String = self.details.nftType.identifier,
            nftUUID: UInt64 = self.details.nftUUID,
            nftID: UInt64 = self.details.nftID,
            salePaymentVaultType: String = self.details.salePaymentVaultType.identifier,
            salePrice: UFix64 = self.details.salePrice,
            customID: String? = self.details.customID,
            commissionAmount: UFix64 = self.details.commissionAmount,
            commissionReceiver: Address? = nil,
            expiry: UInt64 = self.details.expiry
        )

        /// initializer
        ///
        init (
            nftProviderCapability: Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>,
            nftType: Type,
            nftUUID: UInt64,
            nftID: UInt64,
            salePaymentVaultType: Type,
            saleCuts: [SaleCut],
            marketplacesCapability: [Capability<&{FungibleToken.Receiver}>]?,
            storefrontID: UInt64,
            customID: String?,
            commissionAmount: UFix64,
            expiry: UInt64
        ) {
            // Store the sale information
            self.details = ListingDetails(
                nftType: nftType,
                nftUUID: nftUUID,
                nftID: nftID,
                salePaymentVaultType: salePaymentVaultType,
                saleCuts: saleCuts,
                storefrontID: storefrontID,
                customID: customID,
                commissionAmount: commissionAmount,
                expiry: expiry
            )

            // Store the NFT provider
            self.nftProviderCapability = nftProviderCapability
            self.marketplacesCapability = marketplacesCapability

            // Check that the provider contains the NFT.
            // We will check it again when the token is sold.
            // We cannot move this into a function because initializers cannot call member functions.
            let provider = self.nftProviderCapability.borrow()
            assert(provider != nil, message: "cannot borrow nftProviderCapability")

            // This will precondition assert if the token is not available.
            let nft = provider!.borrowNFT(self.details.nftID)
            assert(nft!.getType() == self.details.nftType, message: "token is not of specified type")
            assert(nft?.id == self.details.nftID, message: "token does not have specified ID")
        }
    }

    /// StorefrontManager
    /// An interface for adding and removing Listings within a Storefront,
    /// intended for use by the Storefront's owner
    ///
    access(all) resource interface StorefrontManager {
        /// createListing
        /// Allows the Storefront owner to create and insert Listings.
        ///
        access(CreateListing) fun createListing(
            nftProviderCapability: Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>,
            nftType: Type,
            nftID: UInt64,
            salePaymentVaultType: Type,
            saleCuts: [SaleCut],
            marketplacesCapability: [Capability<&{FungibleToken.Receiver}>]?,
            customID: String?,
            commissionAmount: UFix64,
            expiry: UInt64
        ): UInt64

        /// removeListing
        /// Allows the Storefront owner to remove any sale listing, accepted or not.
        ///
        access(RemoveListing) fun removeListing(listingResourceID: UInt64)
    }

    /// StorefrontPublic
    /// An interface to allow listing and borrowing Listings, and purchasing items via Listings
    /// in a Storefront.
    ///
    access(all) resource interface StorefrontPublic {
        access(all) view fun getListingIDs(): [UInt64]
        access(all) fun getDuplicateListingIDs(nftType: Type, nftID: UInt64, listingID: UInt64): [UInt64]
        access(all) view fun borrowListing(listingResourceID: UInt64): &{ListingPublic}?
        access(all) fun cleanupExpiredListings(fromIndex: UInt64, toIndex: UInt64)
        access(contract) fun cleanup(listingResourceID: UInt64)
        access(all) fun getExistingListingIDs(nftType: Type, nftID: UInt64): [UInt64]
        access(all) fun cleanupPurchasedListings(listingResourceID: UInt64)
        access(all) fun cleanupGhostListings(listingResourceID: UInt64)
   }

    /// Storefront
    /// A resource that allows its owner to manage a list of Listings, and anyone to interact with them
    /// in order to query their details and purchase the NFTs that they represent.
    ///
    access(all) resource Storefront : StorefrontManager, StorefrontPublic {
        // Resource destroyed event
        access(all) event ResourceDestroyed(
            storefrontResourceID: UInt64 = self.uuid
        )

        /// The dictionary of Listing uuids to Listing resources.
        access(contract) var listings: @{UInt64: Listing}
        /// Dictionary to keep track of listing ids for same NFTs listing.
        /// nftType.identifier -> nftID -> [listing resource ID]
        access(contract) var listedNFTs: {String: {UInt64 : [UInt64]}}

        /// insert
        /// Create and publish a Listing for an NFT.
        ///
         access(CreateListing) fun createListing(
            nftProviderCapability: Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>,
            nftType: Type,
            nftID: UInt64,
            salePaymentVaultType: Type,
            saleCuts: [SaleCut],
            marketplacesCapability: [Capability<&{FungibleToken.Receiver}>]?,
            customID: String?,
            commissionAmount: UFix64,
            expiry: UInt64
         ): UInt64 {
            
            // let's ensure that the seller does indeed hold the NFT being listed
            let collectionRef = nftProviderCapability.borrow()
                ?? panic("Could not borrow reference to collection")
            let nftRef = collectionRef.borrowNFT(nftID)
                ?? panic("Could not borrow a reference to the desired NFT ID")

            // Instead of letting an arbitrary value be set for the UUID of a given NFT, the contract
            // should fetch it itself     
            let uuid = nftRef.uuid
            let listing <- create Listing(
                nftProviderCapability: nftProviderCapability,
                nftType: nftType,
                nftUUID: uuid,
                nftID: nftID,
                salePaymentVaultType: salePaymentVaultType,
                saleCuts: saleCuts,
                marketplacesCapability: marketplacesCapability,
                storefrontID: self.uuid,
                customID: customID,
                commissionAmount: commissionAmount,
                expiry: expiry
            )
        
            let listingResourceID = listing.uuid
            let listingPrice = listing.getDetails().salePrice
            // Add the new listing to the dictionary.
            let oldListing <- self.listings[listingResourceID] <- listing
            // Note that oldListing will always be nil, but we have to handle it.

            destroy oldListing

            // Add the `listingResourceID` in the tracked listings.
            self.addDuplicateListing(nftIdentifier: nftType.identifier, nftID: nftID, listingResourceID: listingResourceID)

            // Scraping addresses from the capabilities to emit in the event.
            var allowedCommissionReceivers : [Address]? = nil
            if let allowedReceivers = marketplacesCapability {
                // Small hack here to make `allowedCommissionReceivers` variable compatible to
                // array properties.
                allowedCommissionReceivers = []
                for receiver in allowedReceivers {
                    allowedCommissionReceivers!.append(receiver.address)
                }
            }

            emit ListingAvailable(
                storefrontAddress: self.owner?.address!,
                listingResourceID: listingResourceID,
                nftType: nftType,
                nftUUID: uuid,
                nftID: nftID,
                salePaymentVaultType: salePaymentVaultType,
                salePrice: listingPrice,
                customID: customID,
                commissionAmount: commissionAmount,
                commissionReceivers: allowedCommissionReceivers,
                expiry: expiry
            )

            return listingResourceID
        }

        /// addDuplicateListing
        /// Helper function that allows to add duplicate listing of given nft in a map.
        /// 
        access(contract) fun addDuplicateListing(nftIdentifier: String, nftID: UInt64, listingResourceID: UInt64) {
             if !self.listedNFTs.containsKey(nftIdentifier) {
                self.listedNFTs.insert(key: nftIdentifier, {nftID: [listingResourceID]})
            } else {
                if !self.listedNFTs[nftIdentifier]!.containsKey(nftID) {
                    self.listedNFTs[nftIdentifier]!.insert(key: nftID, [listingResourceID])
                } else {
                    self.listedNFTs[nftIdentifier]![nftID]!.append(listingResourceID)
                } 
            }
        }

        /// removeDuplicateListing
        /// Helper function that allows to remove duplicate listing of given nft from a map.
        /// 
        access(contract) fun removeDuplicateListing(nftIdentifier: String, nftID: UInt64, listingResourceID: UInt64) {
            // Remove the listing from the listedNFTs dictionary.
            let listingIndex = self.listedNFTs[nftIdentifier]![nftID]!.firstIndex(of: listingResourceID) ?? panic("Should contain the index")
            self.listedNFTs[nftIdentifier]![nftID]!.remove(at: listingIndex)
        }
        
        /// removeListing
        /// Remove a Listing that has not yet been purchased from the collection and destroy it.
        /// It can only be executed by the StorefrontManager resource owner.
        ///
        access(RemoveListing) fun removeListing(listingResourceID: UInt64) {
            let listing <- self.listings.remove(key: listingResourceID)
                ?? panic("missing Listing")
            let listingDetails = listing.getDetails()
            self.removeDuplicateListing(nftIdentifier: listingDetails.nftType.identifier, nftID: listingDetails.nftID, listingResourceID: listingResourceID)
            // This will emit a ListingCompleted event.
            destroy listing
        }

        /// getListingIDs
        /// Returns an array of the Listing resource IDs that are in the collection
        ///
        access(all) view fun getListingIDs(): [UInt64] {
            return self.listings.keys
        }

        /// getExistingListingIDs
        /// Returns an array of listing IDs of the given `nftType` and `nftID`.
        ///
        access(all) fun getExistingListingIDs(nftType: Type, nftID: UInt64): [UInt64] {
            if self.listedNFTs[nftType.identifier] == nil || self.listedNFTs[nftType.identifier]![nftID] == nil {
                return []
            }
            var listingIDs = self.listedNFTs[nftType.identifier]![nftID]!
            return listingIDs
        }

        /// cleanupPurchasedListings
        /// Allows anyone to remove already purchased listings.
        ///
        access(all) fun cleanupPurchasedListings(listingResourceID: UInt64) {
            pre {
                self.listings[listingResourceID] != nil: "could not find listing with given id"
                self.borrowListing(listingResourceID: listingResourceID)!.getDetails().purchased == true: "listing not purchased yet"
            }
            let listing <- self.listings.remove(key: listingResourceID)!
            let listingDetails = listing.getDetails()
            self.removeDuplicateListing(nftIdentifier: listingDetails.nftType.identifier, nftID: listingDetails.nftID, listingResourceID: listingResourceID)

            destroy listing
        }

        /// getDuplicateListingIDs
        /// Returns an array of listing IDs that are duplicates of the given `nftType` and `nftID`.
        ///
        access(all) fun getDuplicateListingIDs(nftType: Type, nftID: UInt64, listingID: UInt64): [UInt64] {
            var listingIDs = self.getExistingListingIDs(nftType: nftType, nftID: nftID)

            // Verify that given listing Id also a part of the `listingIds`
            let doesListingExist = listingIDs.contains(listingID)
            // Find out the index of the existing listing.
            if doesListingExist {
                var index: Int = 0
                for id in listingIDs {
                    if id == listingID {
                        break
                    }
                    index = index + 1
                }
                listingIDs.remove(at:index)
                return listingIDs
            } 
           return []
        }

        /// cleanupExpiredListings
        /// Cleanup the expired listing by iterating over the provided range of indexes.
        ///
        access(all) fun cleanupExpiredListings(fromIndex: UInt64, toIndex: UInt64) {
            pre {
                fromIndex <= toIndex : "Incorrect start index"
                Int(toIndex - fromIndex) < self.getListingIDs().length : "Provided range is out of bound"
            }
            var index = fromIndex
            let listingsIDs = self.getListingIDs()
            while index <= toIndex {
                // There is a possibility that some index may not have the listing.
                // because of that instead of failing the transaction, Execution moved to next index or listing.
                
                if let listing = self.borrowListing(listingResourceID: listingsIDs[index]) {
                    if listing.getDetails().expiry <= UInt64(getCurrentBlock().timestamp) {
                        self.cleanup(listingResourceID: listingsIDs[index])
                    }
                }
                index = index + UInt64(1) 
            }
        } 

        /// borrowSaleItem
        /// Returns a read-only view of the SaleItem for the given listingID if it is contained by this collection.
        ///
        access(all) view fun borrowListing(listingResourceID: UInt64): &{ListingPublic}? {
            return &self.listings[listingResourceID]
        }

        /// cleanup
        /// Remove an listing, When given listing is duplicate or expired
        /// Only contract is allowed to execute it.
        ///
        access(contract) fun cleanup(listingResourceID: UInt64) {
            pre {
                self.listings[listingResourceID] != nil: "Could not find listing with given id"
            }
            let listing <- self.listings.remove(key: listingResourceID)!
            let listingDetails = listing.getDetails()
            self.removeDuplicateListing(nftIdentifier: listingDetails.nftType.identifier, nftID: listingDetails.nftID, listingResourceID: listingResourceID)

            destroy listing
        }

        /// cleanupGhostListings
        /// Allow anyone to cleanup ghost listings
        /// Listings will become ghost listings if stored provider capability doesn't hold
        /// the NFT anymore.
        ///
        /// @param listingResourceID ID of the listing resource which would get removed if it become ghost listing.
        access(all) fun cleanupGhostListings(listingResourceID: UInt64) {
            pre {
                self.listings[listingResourceID] != nil: "Could not find listing with given id"
            }
            let listingRef = self.borrowListing(listingResourceID: listingResourceID)!
            let details = listingRef.getDetails()
            assert(!details.purchased, message: "Given listing is already purchased")
            assert(!listingRef.hasListingBecomeGhosted(), message: "Listing is not ghost listing")
            let listing <- self.listings.remove(key: listingResourceID)!
            let duplicateListings = self.getDuplicateListingIDs(nftType: details.nftType, nftID: details.nftID, listingID: listingResourceID)

            // Let's force removal of the listing in this storefront for the NFT that is being ghosted. 
            for listingID in duplicateListings {
                self.cleanup(listingResourceID: listingID)
            }
            destroy listing
        }

        /// constructor
        ///
        init () {
            self.listings <- {}
            self.listedNFTs = {}

            // Let event consumers know that this storefront exists
            emit StorefrontInitialized(storefrontResourceID: self.uuid)
        }
    }

    /// createStorefront
    /// Make creating a Storefront publicly accessible.
    ///
    access(all) fun createStorefront(): @Storefront {
        return <-create Storefront()
    }

    init () {
        self.StorefrontStoragePath = /storage/NFTStorefrontV2
        self.StorefrontPublicPath = /public/NFTStorefrontV2
    }
}
