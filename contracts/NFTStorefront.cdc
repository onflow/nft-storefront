import "FungibleToken"
import "NonFungibleToken"
import "Burner"

/// NB: This contract is no longer supported. NFT Storefront V2 is recommended
///
/// NFTStorefront. 
///
/// A general purpose sale support contract for Flow NonFungibleTokens.
/// 
/// Each account that wants to list NFTs for sale installs a Storefront,
/// and lists individual sales within that Storefront as Listings.
/// There is one Storefront per account, it handles sales of all NFT types
/// for that account.
///
/// Each Listing can have one or more "cut"s of the sale price that
/// goes to one or more addresses. Cuts can be used to pay listing fees
/// or other considerations.
/// Each NFT may be listed in one or more Listings, the validity of each
/// Listing can easily be checked.
/// 
/// Purchasers can watch for Listing events and check the NFT type and
/// ID to see if they wish to buy the listed item.
/// Marketplaces and other aggregators can watch for Listing events
/// and list items of interest.
///
access(all) contract NFTStorefront {

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

    /// StorefrontDestroyed
    /// A Storefront has been destroyed.
    /// Event consumers can now stop processing events from this Storefront.
    /// Note that we do not specify an address.
    ///
    access(all) event StorefrontDestroyed(storefrontResourceID: UInt64)

    /// ListingAvailable
    /// A listing has been created and added to a Storefront resource.
    /// The Address values here are valid when the event is emitted, but
    /// the state of the accounts they refer to may be changed outside of the
    /// NFTStorefront workflow, so be careful to check when using them.
    ///
    access(all) event ListingAvailable(
        storefrontAddress: Address,
        listingResourceID: UInt64,
        nftType: Type,
        nftID: UInt64,
        ftVaultType: Type,
        price: UFix64
    )

    /// ListingCompleted
    /// The listing has been resolved. It has either been purchased, or removed and destroyed.
    ///
    access(all) event ListingCompleted(
        listingResourceID: UInt64, 
        storefrontResourceID: UInt64, 
        purchased: Bool,
        nftType: Type,
        nftID: UInt64
    )

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
        /// The ID of the NFT within that type.
        access(all) let nftID: UInt64
        /// The Type of the FungibleToken that payments must be made in.
        access(all) let salePaymentVaultType: Type
        /// The amount that must be paid in the specified FungibleToken.
        access(all) let salePrice: UFix64
        /// This specifies the division of payment between recipients.
        access(all) let saleCuts: [SaleCut]

        /// setToPurchased
        /// Irreversibly set this listing as purchased.
        ///
        access(contract) fun setToPurchased() {
            self.purchased = true
        }

        /// initializer
        ///
        init (
            nftType: Type,
            nftID: UInt64,
            salePaymentVaultType: Type,
            saleCuts: [SaleCut],
            storefrontID: UInt64
        ) {
            self.storefrontID = storefrontID
            self.purchased = false
            self.nftType = nftType
            self.nftID = nftID
            self.salePaymentVaultType = salePaymentVaultType
            // Store the cuts
            assert(saleCuts.length > 0, message: "Listing must have at least one payment cut recipient")
            self.saleCuts = saleCuts

            // Calculate the total price from the cuts
            var salePrice = 0.0
            // Perform initial check on capabilities, and calculate sale price from cut amounts.
            for cut in self.saleCuts {
                // Make sure we can borrow the receiver.
                // We will check this again when the token is sold.
                cut.receiver.borrow()
                    ?? panic("Cannot borrow receiver")
                // Add the cut amount to the total price
                salePrice = salePrice + cut.amount
            }
            assert(salePrice > 0.0, message: "The Listing must have non-zero price")

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
        access(all) fun purchase(payment: @{FungibleToken.Vault}): @{NonFungibleToken.NFT}

        /// getDetails
        ///
        access(all) fun getDetails(): ListingDetails

    }


    /// Listing
    /// A resource that allows an NFT to be sold for an amount of a given FungibleToken,
    /// and for the proceeds of that sale to be split between several recipients.
    /// 
    access(all) resource Listing: ListingPublic, Burner.Burnable {
        // Event to be emitted when this listing is destroyed.
        // If the listing has not been purchased, we regard it as completed here.
        // There is a separate event in purchase for purchased listings
        access(all) event ResourceDestroyed(
            listingResourceID: UInt64 = self.uuid,
            storefrontResourceID: UInt64 = self.details.storefrontID,
            purchased: Bool = self.details.purchased,
            nftType: String = self.details.nftType.identifier,
            nftID: UInt64 = self.details.nftID
        )

        access(contract) fun burnCallback() {
            // If the listing has not been purchased, we regard it as completed here.
            // Otherwise we regard it as completed in purchase().
            // This is because we destroy the listing in Storefront.removeListing()
            // or Storefront.cleanup() .
            // If we change this destructor, revisit those functions.
            if !self.details.purchased {
                emit ListingCompleted(
                    listingResourceID: self.uuid,
                    storefrontResourceID: self.details.storefrontID,
                    purchased: self.details.purchased,
                    nftType: self.details.nftType,
                    nftID: self.details.nftID
                )
            }
        }

        /// The simple (non-Capability, non-complex) details of the sale
        access(self) let details: ListingDetails

        /// A capability allowing this resource to withdraw the NFT with the given ID from its collection.
        /// This capability allows the resource to withdraw *any* NFT, so you should be careful when giving
        /// such a capability to a resource and always check its code to make sure it will use it in the
        /// way that it claims.
        access(contract) let nftProviderCapability: Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>

        /// borrowNFT
        /// This will assert in the same way as the NFT standard borrowNFT()
        /// if the NFT is absent, for example if it has been sold via another listing.
        ///
        access(all) fun borrowNFT(): &{NonFungibleToken.NFT}? {
            let ref = self.nftProviderCapability.borrow()!.borrowNFT(self.getDetails().nftID)
            assert(ref != nil, message: "NFTStorefront.Listing.borrowNFT: Could not borrow a reference to the NFT in the listing!")
            assert(
                ref!.isInstance(self.getDetails().nftType),
                message: "NFTStorefront.Listing.borrowNFT: The type of the NFT provided by the owner <\(ref!.getType().toString()) does not match the type in the listing <\(self.getDetails().nftType.toString())!"
            )
            assert(
                ref?.id == self.getDetails().nftID,
                message: "NFTStorefront.Listing.borrowNFT: The ID \(ref!.id) (of the NFT provided by the owner does not match the ID \(self.getDetails().nftID) in the listing!"
            )
            return (ref as &{NonFungibleToken.NFT}?)
        }

        /// getDetails
        /// Get the details of the current state of the Listing as a struct.
        /// This avoids having more public variables and getter methods for them, and plays
        /// nicely with scripts (which cannot return resources). 
        ///
        access(all) fun getDetails(): ListingDetails {
            return self.details
        }
        
        /// purchase
        /// Purchase the listing, buying the token.
        /// This pays the beneficiaries and returns the token to the buyer.
        ///
        access(all) fun purchase(payment: @{FungibleToken.Vault}): @{NonFungibleToken.NFT} {
            pre {
                self.details.purchased == false:
                    "NFTStorefront.Listing.purchase: Cannot purchase the listing with ID \(self.getDetails().nftID). The listing has already been purchased!"
                payment.isInstance(self.details.salePaymentVaultType):
                    "NFTStorefront.Listing.purchase: Cannot purchase the listing with ID \(self.getDetails().nftID). The fungible token used as payment <\(payment.getType()) is not the requested type <\(self.details.salePaymentVaultType)."
                payment.balance == self.details.salePrice:
                    "NFTStorefront.Listing.purchase: Cannot purchase the listing with ID \(self.getDetails().nftID). The payment vault does not contain the requested price of \(self.details.salePrice)."
            }

            // Make sure the listing cannot be purchased again.
            self.details.setToPurchased()

            // Fetch the token to return to the purchaser.
            let nft <-self.nftProviderCapability.borrow()!.withdraw(withdrawID: self.details.nftID)
            // Neither receivers nor providers are trustworthy, they must implement the correct
            // interface but beyond complying with its pre/post conditions they are not gauranteed
            // to implement the functionality behind the interface in any given way.
            // Therefore we cannot trust the Collection resource behind the interface,
            // and we must check the NFT resource it gives us to make sure that it is the correct one.
            assert(
                nft.isInstance(self.details.nftType),
                message: "NFTStorefront.Listing.purchase: Cannot purchase listing! The type of the NFT provided by the seller <\(nft.getType()) does not match the type in the listing details <\(self.details.nftType)!"
            )
            assert(
                nft.id == self.details.nftID,
                message: "NFTStorefront.Listing.purchase: Cannot purchase listing! The ID \(nft.id) of the NFT provided by the seller does not match the ID \(self.details.nftID) in the listing details!"
            )

            // Rather than aborting the transaction if any receiver is absent when we try to pay it,
            // we send the cut to the first valid receiver.
            // The first receiver should therefore either be the seller, or an agreed recipient for
            // any unpaid cuts.
            var residualReceiver: &{FungibleToken.Receiver}? = nil

            // Pay each beneficiary their amount of the payment.
            for cut in self.details.saleCuts {
                if let receiver = cut.receiver.borrow() {
                   let paymentCut <- payment.withdraw(amount: cut.amount)
                    receiver.deposit(from: <-paymentCut)
                    if (residualReceiver == nil) {
                        residualReceiver = receiver
                    }
                }
            }

            assert(
                residualReceiver != nil,
                message: "NFTStorefront.Listing.purchase: No valid payment receivers"
            )

            // At this point, if all recievers were active and availabile, then the payment Vault will have
            // zero tokens left, and this will functionally be a no-op that consumes the empty vault
            residualReceiver!.deposit(from: <-payment)

            // If the listing is purchased, we regard it as completed here.
            // Otherwise we regard it as completed in the destructor.        

            emit ListingCompleted(
                listingResourceID: self.uuid,
                storefrontResourceID: self.details.storefrontID,
                purchased: self.details.purchased,
                nftType: self.details.nftType,
                nftID: self.details.nftID
            )

            return <-nft
        }

        /// initializer
        ///
        init (
            nftProviderCapability: Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>,
            nftType: Type,
            nftID: UInt64,
            salePaymentVaultType: Type,
            saleCuts: [SaleCut],
            storefrontID: UInt64
        ) {
            // Store the sale information
            self.details = ListingDetails(
                nftType: nftType,
                nftID: nftID,
                salePaymentVaultType: salePaymentVaultType,
                saleCuts: saleCuts,
                storefrontID: storefrontID
            )

            // Store the NFT provider
            self.nftProviderCapability = nftProviderCapability

            // Check that the provider contains the NFT.
            // We will check it again when the token is sold.
            // We cannot move this into a function because initializers cannot call member functions.
            let provider = self.nftProviderCapability.borrow()
            assert(
                provider != nil,
                message: "NFTStorefront.Listing.init: Cannot initialize Listing! Unable to borrow NFT Provider Capability!"
            )

            let nft = provider!.borrowNFT(self.details.nftID)
            // This will precondition assert if the token is not available.
            assert(
                nft != nil,
                message: "NFTStorefront.Listing.init: Cannot initialize Listing! Could not borrow a reference to the NFT for sale!"
            )
            assert(
                nft!.isInstance(self.details.nftType),
                message: "NFTStorefront.Listing.init: Cannot initialize Listing! The type of the token for sale <\(nft.getType())> is not of specified type in the listing <\(self.details.nftType)>"
            )
            assert(
                nft?.id == self.details.nftID,
                message: "NFTStorefront.Listing.init: Cannot initialize Listing! The ID of the token \(nft!.id) does not have the ID specified in the listing \(self.details.nftID)"
            )
        }
    }

    /// StorefrontManager
    /// An interface for adding and removing Listings within a Storefront,
    /// intended for use by the Storefront's own
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
            saleCuts: [SaleCut]
        ): UInt64
        /// removeListing
        /// Allows the Storefront owner to remove any sale listing, acepted or not.
        ///
        access(RemoveListing) fun removeListing(listingResourceID: UInt64)
    }

    /// StorefrontPublic
    /// An interface to allow listing and borrowing Listings, and purchasing items via Listings
    /// in a Storefront.
    ///
    access(all) resource interface StorefrontPublic {
        access(all) view fun getListingIDs(): [UInt64]
        access(all) view fun borrowListing(listingResourceID: UInt64): &{ListingPublic}? {
            post {
                result == nil || result!.getType() == Type<@Listing>():
                    "Cannot borrow a non-NFTStorefront.Listing!"
            }
        }
        access(all) fun cleanup(listingResourceID: UInt64)
   }

    /// Storefront
    /// A resource that allows its owner to manage a list of Listings, and anyone to interact with them
    /// in order to query their details and purchase the NFTs that they represent.
    ///
    access(all) resource Storefront: StorefrontManager, StorefrontPublic {
        // Event to be emitted when this storefront is destroyed.
        access(all) event ResourceDestroyed(
            storefrontResourceID: UInt64 = self.uuid
        )

        /// The dictionary of Listing uuids to Listing resources.
        access(self) var listings: @{UInt64: Listing}

        /// insert
        /// Create and publish a Listing for an NFT.
        ///
         access(CreateListing) fun createListing(
            nftProviderCapability: Capability<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>,
            nftType: Type,
            nftID: UInt64,
            salePaymentVaultType: Type,
            saleCuts: [SaleCut]
         ): UInt64 {
            let listing <- create Listing(
                nftProviderCapability: nftProviderCapability,
                nftType: nftType,
                nftID: nftID,
                salePaymentVaultType: salePaymentVaultType,
                saleCuts: saleCuts,
                storefrontID: self.uuid
            )

            let listingResourceID = listing.uuid
            let listingPrice = listing.getDetails().salePrice

            // Add the new listing to the dictionary.
            let oldListing <- self.listings[listingResourceID] <- listing
            // Note that oldListing will always be nil, but we have to handle it.

            Burner.burn(<-oldListing)

            emit ListingAvailable(
                storefrontAddress: self.owner?.address!,
                listingResourceID: listingResourceID,
                nftType: nftType,
                nftID: nftID,
                ftVaultType: salePaymentVaultType,
                price: listingPrice
            )

            return listingResourceID
        }
        

        /// removeListing
        /// Remove a Listing that has not yet been purchased from the collection and destroy it.
        ///
        access(RemoveListing) fun removeListing(listingResourceID: UInt64) {
            let listing <- self.listings.remove(key: listingResourceID)
                ?? panic("NFTStorefront.Storefront.removeListing: Could not find listing to remove with the given ID \(listingResourceID)")
    
            // This will emit a ListingCompleted event.
            Burner.burn(<-listing)
        }

        /// getListingIDs
        /// Returns an array of the Listing resource IDs that are in the collection
        ///
        access(all) view fun getListingIDs(): [UInt64] {
            return self.listings.keys
        }

        /// borrowSaleItem
        /// Returns a read-only view of the SaleItem for the given listingID if it is contained by this collection.
        ///
        access(all) view fun borrowListing(listingResourceID: UInt64): &{ListingPublic}? {
            if self.listings[listingResourceID] != nil {
                return &self.listings[listingResourceID] as &{ListingPublic}?
            } else {
                return nil
            }
        }

        /// cleanup
        /// Remove an listing *if* it has been purchased.
        /// Anyone can call, but at present it only benefits the account owner to do so.
        /// Kind purchasers can however call it if they like.
        ///
        access(all) fun cleanup(listingResourceID: UInt64) {
            pre {
                self.listings[listingResourceID] != nil:
                    "NFTStorefront.Storefront.cleanup: Could not find listing to clean up with the given id \(listingResourceID)"
            }

            let listing <- self.listings.remove(key: listingResourceID)!
            assert(listing.getDetails().purchased == true, message: "listing is not purchased, only admin can remove")
            Burner.burn(<-listing)
        }

        /// constructor
        ///
        init () {
            self.listings <- {}

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
        self.StorefrontStoragePath = /storage/NFTStorefront
        self.StorefrontPublicPath = /public/NFTStorefront
    }
}
