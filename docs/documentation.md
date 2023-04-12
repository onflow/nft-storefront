### Overview

The `NFTStorefrontV2` contract makes it simple for Sellers to list NFTs in dApp specific marketplaces. DApp developers leverage the APIs provided by the contract to manage listings being offered for sale and to transact NFT trades. 

![dapps_1](https://user-images.githubusercontent.com/14581509/191749748-714f9d8f-cb41-4be4-a3d2-ec84cb8b5ffb.png)

Listings made through a specific dApp can be simultaneously listed on third-party marketplaces beyond that dApp. Well-known third-party marketplaces listen for compatible NFT listing events enabling the automation of listings into their marketplace UIs.

![dapps_2](https://user-images.githubusercontent.com/14581509/191753605-e1c48a57-0c3c-4509-808b-8fee4e7d32e8.png)

Marketplaces facilitate a NFT trade through direct interaction with seller storefront resources. Flow's account based model ensures that NFTs listed for sale remain in the Seller account until traded, regardless of how many listings are posted across any number of marketplaces, for the same NFT.

![marketplace_1](https://user-images.githubusercontent.com/14581509/191755699-fe0570cb-80a3-408c-8eef-4051e3209481.png)

**Contract basics**

`NFTStorefrontV2` is a general purpose sales support contract for NFTs. Each account that wants to list NFTs for sale creates a `Storefront` resource to store in their account and lists individual sales within that Storefront as `Listing`s. There is usually one `Storefront` per account stored at `/storage/NFTStorefrontV2` and the contract supports all tokens using the [`NonFungibleToken`](https://github.com/onflow/flow-nft/blob/master/contracts/NonFungibleToken.cdc) standard.

Each listing defines a price, optional 0-n sale cuts to be deducted, with each [`saleCut`](https://github.com/onflow/nft-storefront/blob/160e97aa802405ad26a3164bcaff0fde7ee52ad2/contracts/NFTStorefrontV2.cdc#L104) amount sent to the linked address. Listings can specify an optional list of marketplace [receiver capabilities](https://developers.flow.com/cadence/language/capability-based-access-control) used to pay commission to that marketplace at time of sale. Royalties are paid as a [`saleCut`](https://github.com/onflow/nft-storefront/blob/160e97aa802405ad26a3164bcaff0fde7ee52ad2/contracts/NFTStorefrontV2.cdc#L104) for NFTs supporting the [Royalty Metadata View](https://github.com/onflow/flow-nft/blob/21c254438910c8a4b5843beda3df20e4e2559625/contracts/MetadataViews.cdc#L335) standard. [`SaleCut`](https://github.com/onflow/nft-storefront/blob/160e97aa802405ad26a3164bcaff0fde7ee52ad2/contracts/NFTStorefrontV2.cdc#L104) generalizes support for alternative models of revenue sharing at time of sale. 

The same NFT can be referenced in one or more listings across multiple marketplaces and the contract provides APIs to manage listings across those.

Interested parties can globally track `Listing` events on-chain and filter by NFT type, ID and other characteristics to determine which are of interest, simplifying the process of publishing a listed NFT for sale within your dApp marketplace UI.

## Selling NFTs

The `NFTStorefrontV2` offers a standardized process and the APIs for creating and managing the listings for a seller's NFTs.

## Creating a listing using the NFTStorefrontV2 contract

Users are required to create the `Storefront` resource once only in their account after which the same resource can be re-used, see [example](https://github.com/onflow/nft-storefront/blob/main/transactions/setup_account.cdc).

Listed below are some different ways which you might list your NFTs for sale.

### **Scenario 1:** A basic NFT listing that unlocks peer-to-peer trading across Flow

Sellers can create a basic listing using the [sell_item](https://github.com/onflow/nft-storefront/blob/main/transactions/sell_item.cdc) transaction providing the `marketplacesAddress` with an empty array. The seller can optionally configure [commission](#commission) to the facilitator of sale. All listings made using the `NFTStorefrontV2` standard are broadcast on-chain through the `ListingAvailable` event. 

### **Scenario 2:** Simultaneously list your NFT in multiple marketplaces

Sellers typically create a listing by specifying one or more `marketplacesAddress` and the corresponding `commissionReceivers` required for them. It is assumed that the seller has first confirmed the correct address values for specific marketplaces and their expected commissions, which differs between vendors. On receiving `ListingAvailable` events, marketplaces select listings matching their address and minimum expected commission. This enables multiple marketplaces to each publish the same NFT for sale in their UI with the full confidence that they will earn their required commission from facilitating the sale.

Example - Bob wants to list on marketplace 0xA, 0xB & 0xC and is willing to offer 10% commission on the sale price of the listing to interested marketplaces. In this diagram we see that all the marketplaces accept his listing given the commission amount!

   ![scenario_3](https://user-images.githubusercontent.com/14581509/190966834-8eda4ec4-e9bf-49ef-9dec-3c47a236d281.png)

An alternate approach is to create separate listing for each marketplace using the [sell_item_with_marketplace_cut](https://github.com/onflow/nft-storefront/blob/main/transactions/sell_item_with_marketplace_cut.cdc) transaction. This is targeted towards marketplaces which select listings purely based on [`saleCut`](https://github.com/onflow/nft-storefront/blob/160e97aa802405ad26a3164bcaff0fde7ee52ad2/contracts/NFTStorefrontV2.cdc#L104) amounts.

### **Scenario 3:** Supporting multiple token types (eg: FLOW, FUSD, etc) for your NFT listings

The `NFTStorefrontV2` contract has no default support for multiple token types in an individual listing. The simplest way to solve this is to create multiple listings for the same NFT, one for each different token.

**Example -** Alice wants to sell a kitty and is open to receiving FLOW and FUSD

![scenario_1](https://user-images.githubusercontent.com/14581509/190966672-e1793fa3-112c-4273-b2a3-e81b8c94fd70.png)

Sellers can create a basic `Listing` using the [sell_item](https://github.com/onflow/nft-storefront/blob/main/transactions/sell_item.cdc) transaction which requires certain details including the receiving token type [Capability](https://developers.flow.com/cadence/language/capability-based-access-control). This capability will transact the specified tokens when the NFT is sold. More detailed specifics are available [here](#fun-createListing()). 

To accept a different token type for the same NFT sellers must specify an alternate __Receiver token type__, eg: `salePaymentVaultType`, in another listing. The only difference between the two listings is that `salePaymentVaultType` specifies different token types while the NFT being sold remains the same for both. Another more advanced option for handling multiple token types is using the [`FungibleTokenSwitchboard`](https://github.com/onflow/flow-ft/blob/master/contracts/FungibleTokenSwitchboard.cdc) standard.

### Considerations

1. ***Ghost listings*** - *Ghost listings are listings which don’t have an underlying NFT in the seller’s account. However, the listing is still available for buyers to attempt to purchase and which fails*. 

    Ghost listings occur for two reasons: 

    1. When a seller's NFT is sold in one marketplace but listings for that NFT in other marketplaces are not removed.
    2. When the seller transfers out the listed NFT from the account that made the listings.

    If ghost listings are not removed, they will eventually result in a prospective purchaser’s transaction to fail which is annoying in isolated cases. However, ghost listings negatively impact everyone's user experience when they are widespread. To address this and ensure that listings are always accurate the [`cleanupPurchasedListings`](#fun-cleanupPurchasedListings) function has been provided. 

    The recommended standard practice is for marketplaces to execute the `cleanupPurchasedListing` function after the sale has completed within the same transaction. This requires minimal gas, ensures the best experience for all participants in the marketplace ecosystem and also significantly minimizes the likelihood of transaction failure.

    Ghost listings which are not cleaned up may be specifically problematic for sellers in the unique case when a **previously sold or gifted** NFT returns to the seller’s account some time later. In this case, previously ghost listings for which purchase attempts would have failed, once again become enabled to facilitate purchases. Since some time may have passed since the listing was created, ghost listings remaining against NFTs returned to an account may implicitly make the listing available for purchase below market rates. 
    
    To mitigate this, the storefront contract provides global access to all seller's inventory of ghost listings using the [`read_all_unique_ghost_listings`](../scripts/read_all_unique_ghost_listings.cdc) script. Sellers who have active listings for an NFT are strongly advised to purge ghost listings using the [`cleanup_ghost_listing`](../transactions/cleanup_ghost_listing.cdc) transaction when the listed NFT is transferred to another account, not sold through a marketplace.


2. ***Expired listings*** `NFTStorefrontV2` introduces a safety measure to flag an NFT listing as expired after a certain period. This can be set during listing creation to prevent the purchase through the listing after expiry has been reached. Once expiry has been reached the listing can no longer facilitate the purchase of the NFT. 

    We recommend that using the [`cleanupExpiredListings`](#fun-cleanupExpiredListings) function to manage expired listings. 
    
    ***Note:*** We recommend that marketplaces and dApps filter out expired listings as they cannot be purchased.

## Purchasing NFTs

Purchasing NFTs through the `NFTStorefrontV2` is simple. The buyer has to provide the payment vault and the `commissionRecipient`, if applicable, during the purchase. The [`purchase`](#fun-purchase) API offered by the `Listing` facilitates the trade with the buyer in the seller's `Storefront`.

During the listing purchase all `saleCuts` are paid automatically. This also includes distributing [royalties](#enabling-creator-royalties-for-nfts) for that NFT, if applicable. If the vault provided by the buyer lacks sufficient funds then the transaction will fail.

### Considerations

1. ***Auto cleanup*** the `NFTStorefrontV2` standard automates the cleanup of duplicate listings at time of sale. However, if an NFT has a large number of duplicate listings, it may slow the purchase and, in the worst case, may trigger an out-of-gas error.

    ***Note:*** We recommend maintaining <= 50(TBD) duplicate listings of any given NFT.

2. ***Unsupported receiver capability*** A common pitfall during the purchase of an NFT is if `saleCut` receivers don’t have a supported receiver capability because that entitled sale cut would transfer to first valid sale cut receiver. To mitigate this we recommend using the generic receiver from the [`FungibleTokenSwitchboard`](https://github.com/onflow/flow-ft/blob/master/contracts/FungibleTokenSwitchboard.cdc) contract, adding capabilities to support whichever token types the beneficiary wishes to receive. 

## Enabling creator royalties for NFTs

The `NFTStorefrontV2` contract optionally supports paying royalties to the minter account for secondary resales of a NFT. When seller NFTs support the [Royalty Metadata View](https://github.com/onflow/flow-nft/blob/21c254438910c8a4b5843beda3df20e4e2559625/contracts/MetadataViews.cdc#L335), `NFTStorefrontV2` stores the royalty amount as a `saleCut` based on the specified royalty percentage of the sale price, calculated at the time of listing. The `saleCut` amount is only paid to the minter at the time of sale. 

```cadence
// Check whether the NFT implements the MetadataResolver or not.
if nft.getViews().contains(Type<MetadataViews.Royalties>()) {
		// Resolve the royalty view
    let royaltiesRef = nft.resolveView(Type<MetadataViews.Royalties>())?? panic("Unable to retrieve the royalties")
	  // Fetch the royalties.
		let royalties = (royaltiesRef as! MetadataViews.Royalties).getRoyalties()
		// Append the royalties as the salecut
    for royalty in royalties {
        self.saleCuts.append(NFTStorefrontV2.SaleCut(receiver: royalty.receiver, amount: royalty.cut * effectiveSaleItemPrice))
        totalRoyaltyCut = totalRoyaltyCut + royalty.cut * effectiveSaleItemPrice
    }
}
```

Complete transaction available [here](https://github.com/onflow/nft-storefront/blob/main/transactions/sell_item.cdc).

`saleCut` only supports a single token receiver type and therefore beneficiaries of a `saleCut` can only receive the token type used for the purchase. To support different token types for saleCuts we recommend using the [FungibleTokenSwitchboard](https://github.com/onflow/flow-ft/blob/master/contracts/FungibleTokenSwitchboard.cdc) contract.

***Note:*** We recommend that marketplaces honor creator royalties across the Flow ecosystem

## Enabling marketplace commissions for NFT sales

`NFTStorefrontV2` enables optional commissions on trades for marketplaces which require it as a condition to list a NFT for sale. Commission & commission receivers are set by the seller during initial listing creation. At time of purchase the commission amount is paid once only to the commission receiver matching the marketplace receiver address which facilitated the sale. For NFT listings in marketplaces which don't require commission, commission receivers can be set as `nil`. The default behavior when `commissionRecipient`s are set to `nil` with a commission amount >0 results in a discount for the buyer who is paid the commission.

![scenario_2](https://user-images.githubusercontent.com/14581509/190966499-c176203f-b6a6-4422-860f-1bf6f2bcdbb6.png).

## APIs & Events offered by NFTStorefrontV2

## Resource Interface `ListingPublic`

```cadence
resource interface ListingPublic {
    pub fun borrowNFT(): &NonFungibleToken.NFT?
    pub fun purchase(
          payment: @FungibleToken.Vault, 
          commissionRecipient: Capability<&{FungibleToken.Receiver}>?,
      ): @NonFungibleToken.NFT
    pub fun getDetails(): ListingDetail
    pub fun getAllowedCommissionReceivers(): [Capability<&{FungibleToken.Receiver}>]?
}
```
An interface providing a useful public interface to a Listing.

### Functions

**fun `borrowNFT()`**

```cadence
fun borrowNFT(): &NonFungibleToken.NFT?
```
This will assert in the same way as the NFT standard borrowNFT()
if the NFT is absent, for example if it has been sold via another listing.

---

**fun `purchase()`**

```cadence
fun purchase(payment FungibleToken.Vault, commissionRecipient Capability<&{FungibleToken.Receiver}>?): NonFungibleToken.NFT
```
Facilitates the purchase of the listing by providing the payment vault
and the commission recipient capability if there is a non-zero commission for the given listing.
Respective saleCuts are transferred to beneficiaries and funtion return underlying or listed NFT.

---

**fun `getDetails()`**

```cadence
fun getDetails(): ListingDetails
```
Fetches the details of the listings

---

**fun `getAllowedCommissionReceivers()`**

```cadence
fun getAllowedCommissionReceivers(): [Capability<&{FungibleToken.Receiver}>]?
```
Fetches the allowed marketplaces capabilities or commission receivers for the underlying listing.
If it returns `nil` then commission paid to the receiver by default.

---

**fun `hasListingBecomeGhosted()`**

```cadence
pub fun hasListingBecomeGhosted(): Bool
```
Tells whether listed NFT is present in provided capability.
If it returns `false` then it means listing becomes ghost or sold out.

---

## Resource `Storefront`

```cadence
resource Storefront {
    pub fun createListing(
            nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
            nftType: Type,
            nftID: UInt64,
            salePaymentVaultType: Type,
            saleCuts: [SaleCut],
            marketplacesCapability: [Capability<&{FungibleToken.Receiver}>]?,
            customID: String?,
            commissionAmount: UFix64,
            expiry: UInt64
         ): UInt64
    pub fun removeListing(listingResourceID: UInt64)
    pub fun getListingIDs(): [UInt64]
    pub fun getDuplicateListingIDs(nftType: Type, nftID: UInt64, listingID: UInt64): [UInt64]
    pub fun cleanupExpiredListings(fromIndex: UInt64, toIndex: UInt64)
    pub fun borrowListing(listingResourceID: UInt64): &Listing{ListingPublic}?
}
```
A resource that allows it's owner to manage a list of Listings, and anyone to interact with them
in order to query their details and purchase the NFTs that they represent.

Implemented Interfaces:
  - `StorefrontManager`
  - `StorefrontPublic`


### Initializer

```cadence
fun init()
```

### Functions

**fun `createListing()`**

```cadence
fun createListing(nftProviderCapability Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>, nftType Type, nftID UInt64, salePaymentVaultType Type, saleCuts [SaleCut], marketplacesCapability [Capability<&{FungibleToken.Receiver}>]?, customID String?, commissionAmount UFix64, expiry UInt64): UInt64
```
insert
Create and publish a Listing for a NFT.

---

**fun `removeListing()`**

```cadence
fun removeListing(listingResourceID UInt64)
```
removeListing
Remove a Listing that has not yet been purchased from the collection and destroy it.

---

**fun `getListingIDs()`**

```cadence
fun getListingIDs(): [UInt64]
```
getListingIDs
Returns an array of the Listing resource IDs that are in the collection

---

**fun `getDuplicateListingIDs()`**

```cadence
fun getDuplicateListingIDs(nftType Type, nftID UInt64, listingID UInt64): [UInt64]
```
getDuplicateListingIDs
Returns an array of listing IDs that are duplicates of the given `nftType` and `nftID`.

---

**fun `cleanupExpiredListings()`**

```cadence
fun cleanupExpiredListings(fromIndex UInt64, toIndex UInt64)
```
cleanupExpiredListings
Cleanup the expired listing by iterating over the provided range of indexes.

---

**fun `borrowListing()`**

```cadence
fun borrowListing(listingResourceID UInt64): &Listing{ListingPublic}?
```
borrowListing
Returns a read-only view of the listing for the given listingID if it is contained by this collection.

---

## Resource Interface `StorefrontPublic`

```cadence
resource interface StorefrontPublic {
    pub fun getListingIDs(): [UInt64]
    pub fun getDuplicateListingIDs(nftType: Type, nftID: UInt64, listingID: UInt64): [UInt64]
    pub fun cleanupExpiredListings(fromIndex: UInt64, toIndex: UInt64)
    pub fun borrowListing(listingResourceID: UInt64): &Listing{ListingPublic}?
    pub fun cleanupPurchasedListings(listingResourceID: UInt64)
    pub fun getExistingListingIDs(nftType: Type, nftID: UInt64): [UInt64]
    pub fun cleanupGhostListings(listingResourceID: UInt64)
}
```

StorefrontPublic
An interface to allow listing and borrowing Listings, and purchasing items via Listings
in a Storefront.

### Functions

**fun `getListingIDs()`**

```cadence
fun getListingIDs(): [UInt64]
```
getListingIDs Returns an array of the Listing resource IDs that are in the collection

---

**fun `getDuplicateListingIDs()`**

```cadence
fun getDuplicateListingIDs(nftType Type, nftID UInt64, listingID UInt64): [UInt64]
```
getDuplicateListingIDs Returns an array of listing IDs that are duplicates of the given nftType and nftID.

---

**fun `borrowListing()`**

```cadence
fun borrowListing(listingResourceID UInt64): &Listing{ListingPublic}?
```
borrowListing Returns a read-only view of the listing for the given listingID if it is contained by this collection.

---

**fun `cleanupExpiredListings()`**

```cadence
fun cleanupExpiredListings(fromIndex UInt64, toIndex UInt64)
```
cleanupExpiredListings Cleanup the expired listing by iterating over the provided range of indexes.

---

**fun `cleanupPurchasedListings()`**

```cadence
fun cleanupPurchasedListings(listingResourceID: UInt64)
```
cleanupPurchasedListings
Allows anyone to remove already purchased listings.

---

**fun `getExistingListingIDs()`**

```cadence
fun getExistingListingIDs(nftType Type, nftID UInt64): [UInt64]
```
getExistingListingIDs
Returns an array of listing IDs of the given `nftType` and `nftID`.

---

**fun `cleanupGhostListings()`**

```cadence
pub fun cleanupGhostListings(listingResourceID: UInt64)
```
cleanupGhostListings
Allow callers to clean up ghost listings for this seller. Listings which remain orphaned on marketplaces because the stored provider capability cannot acquire the NFT any more.

---

## Events

**event `StorefrontInitialized`**

```cadence
event StorefrontInitialized(storefrontResourceID: UInt64)
```
A Storefront resource has been created. Consumers can now expect events from this Storefront. Note that we do not specify an address: we cannot and should not. Created resources do not have an owner address, and may be moved
after creation in ways we cannot check. `ListingAvailable` events can be used to determine the address
of the owner of the Storefront at the time of the listing but only at that exact moment in that specific transaction. If the seller moves the Storefront while the listing is valid it will not be possible to transact trades for the assocaited listings.

---

**event `StorefrontDestroyed`**

```cadence
event StorefrontDestroyed(storefrontResourceID: UInt64)
```
A Storefront has been destroyed. Event consumers can now stop processing events from this Storefront.
Note - we do not specify an address.

---

**event `ListingAvailable`**

```cadence
event ListingAvailable(storefrontAddress: Address, listingResourceID: UInt64, nftType: Type, nftUUID: UInt64, nftID: UInt64, salePaymentVaultType: Type, salePrice: UFix64, customID: String?, commissionAmount: UFix64, commissionReceivers: [Address]?, expiry: UInt64)
```

Above event gets emitted when a listing has been created and added to a Storefront resource. The Address values here are valid when the event is emitted, but the state of the accounts they refer to may change outside of the
`NFTStorefrontV2` workflow, so be careful to check when using them.

---

**event `ListingCompleted`**

```cadence
event ListingCompleted(listingResourceID: UInt64, storefrontResourceID: UInt64, purchased: Bool, nftType: Type, nftUUID: UInt64, nftID: UInt64, salePaymentVaultType: Type, salePrice: UFix64, customID: String?, commissionAmount: UFix64, commissionReceiver: Address?, expiry: UInt64)
```
The listing has been resolved. It has either been purchased, removed or destroyed.

---

**event `UnpaidReceiver`**

```cadence
event UnpaidReceiver(receiver: Address, entitledSaleCut: UFix64)
```
A entitled receiver has not been paid during the sale of the NFT.

---


**Holistic process flow diagram of NFTStorefrontV2 -** 

![NFT Storefront Process flow](https://user-images.githubusercontent.com/14581509/191960793-ff153e5d-2934-410c-b724-5c5dffd2c20f.png)


## Glossary

<a name="saleCut"></a>SaleCut - A struct consists a recipient and amount of token, eg: cut that must be sent to recipient when a NFT get sold.
