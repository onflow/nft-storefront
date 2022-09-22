# Primer
NFTStorefront contract comes to life to fulfil the growing demand of non-custodial marketplace on FLOW blockchain. p2p dapps can create a NFT marketplace using the API's offered by the NFTStorefrontV2 contract and allow the sellers to list the NFTs to their dApp or may allow to create listing for the different marketplaces like OpenSea, Rariable, BloctoBay etc.

![dapps_1](https://user-images.githubusercontent.com/14581509/191749748-714f9d8f-cb41-4be4-a3d2-ec84cb8b5ffb.png)

Above clearly depicts how dApps can leverage the NFTStorefrontV2 and create there own marketplace allow p2p purcahses, While below diagram shows how dApps can facilitate the creation of NFT listings for different marketplaces and how marketplaces can filter there listings.

![dapps_2](https://user-images.githubusercontent.com/14581509/191753605-e1c48a57-0c3c-4509-808b-8fee4e7d32e8.png)

While with the help of NFTStorefrontV2, marketplaces can tap into vibrant FLOW NFT ecosystem and allow NFT holders to list their NFTs and enable creator royalties as well.

![marketplace_1](https://user-images.githubusercontent.com/14581509/191755699-fe0570cb-80a3-408c-8eef-4051e3209481.png)

## Functional Overview

A general purpose sale support contract for NFTs implementing the Flow `NonFungibleToken` standard.
Each account that wants to list NFTs for sale creates a `Storefront` resource to store in their account and lists individual sales within that Storefront as Listings. There is usually one Storefront per account stored at the `/storage/NFTStorefrontV2` and it can handle sales of all NFT types. 

Each Listing can define one or more sale cuts taken out of the sale price to go to one or more addresses. Cuts can be used to pay listing fees, royalties, or other such considerations. Also listing can include a commission as one of these sale cuts that is paid to whoever facilitates the purchase. 

Listing can have optional list of marketplace receiver capabilities, Used to receive the commission for fullfiling the listing. A NFT may be listed in one or more Listings, the validity of each listing can easily be checked.

Since the Storefront can support any NFT and Fungible Token type, purchasers can watch for the `Listing` events’ NFT types and IDs to catch sales of moments that interest them. More importantly, marketplace apps and other sale aggregator apps can watch for `Listing` events and list items of interest for their users to buy through their UIs easily. They should be incentivized to do this because sales can provide commissions for marketplaces that show and execute the final sale.

# Selling NFTs

NFTStorefront offers a generic process for creating the listing for an NFT. Users should possess the `Storefront` resource under their account to create the listing using the storefront contract. It provides all the essential APIs to manage their listings independently. However, many marketplaces create a single storefront resource to manage different individual listings. We recommend creating the listing under the user-owned storefront resource to make it trustless and platform-independent.

**Journey for creating a successful listing using the NFTStorefrontV2 contract.**

As recommended above, the first step is to create and store the [Storefront resource](#resource-storefront) in the user account using the [setup_account](https://github.com/onflow/nft-storefront/blob/main/transactions/setup_account.cdc) transaction. 

The next step is to create a listing under the newly created storefront resource or if user (repeatitive) already holds the storefront resource then use the existing resource. Seller can comes with multiple requirement for listing their NFTs, We try our best to cover most of them below.

**Scenario 1:** Selling NFTs corresponds to more than one crypto currencies , i.e. FLOW, FUSD etc.

The NFTStorefront contract doesn’t support selling an NFT for multiple different currencies with a single listing. However, this can be achieved by creating multiple listings for the same NFT for each different currency.

**Example -** Alice wants to sell a kitty and is open to receiving FLOW and FUSD

![scenario_1](https://user-images.githubusercontent.com/14581509/190966672-e1793fa3-112c-4273-b2a3-e81b8c94fd70.png)

Putting a NFT on sell called listing, Seller can create listing using [sell_item](https://github.com/onflow/nft-storefront/blob/main/transactions/sell_item.cdc) transaction by providing some required details to list a NFT,i.e Receving currency type, [Capability](https://developers.flow.com/cadence/language/capability-based-access-control) from where NFT will be deducted etc. If interested look [here](#fun-createListing()) for more details. 

To receive different currency seller has to provide different __Receiver currency type__ ,i.e `salePaymentVaultType` As depicted in the above diagram, There are two listing formation with almost same inputs the only differentiator is the `salePaymentVaultType` parameter that needs to be different when creating the same NFT listings with different sale currency types. 

**Scenario 2:**  Peer-to-Peer (p2p) listing of NFT: A listing anyone can fulfill.

Dapps can leverage the NFTStorefrontV2 to facilitate the creation of listing for the seller independent of any marketplace, Dapps or marketplaces can list those listings on their platforms or seller can settle it p2p.

The seller can use [sell_item](https://github.com/onflow/nft-storefront/blob/main/transactions/sell_item.cdc) transaction to create a p2p listing, providing the `marketplacesAddress` with an empty array. The seller also has a choice of providing a [commission](#commission) to the facilitator of the sale which can also act as a discount if the facilitator and the purchaser are the same.

**Scenario 3:** Seller wants to list its NFT to different marketplaces.

`NFTStorefrontV2` offers 2 different ways of doing it.

- The seller can create a listing and provide the `marketplacesAddress` that it wants to have a listing on using [sell_item](https://github.com/onflow/nft-storefront/blob/main/transactions/sell_item.cdc) transaction.
    
    Marketplaces can listen for `ListingAvailable` events and check whether their address is included in the `commissionReceivers` list; If yes then marketplace would get rewarded during the successful fulfillment of the listing.
    
    Example - Bob wants to list on marketplace 0xA, 0xB & 0xC and is willing to offer 10% commission on the sale price of the listing to the marketplaces.
    
    ![scenario_3](https://user-images.githubusercontent.com/14581509/190966834-8eda4ec4-e9bf-49ef-9dec-3c47a236d281.png)
    

- Another way to accomplish this is to create separate listings for each marketplace that a user wants their listing on using [sell_item_with_marketplace_cut](https://github.com/onflow/nft-storefront/blob/main/transactions/sell_item_with_marketplace_cut.cdc) transaction. In this case, marketplace would be incentivized by earning one of the part of the [`saleCut`](https://github.com/onflow/nft-storefront/blob/160e97aa802405ad26a3164bcaff0fde7ee52ad2/contracts/NFTStorefrontV2.cdc#L104) by appending marketplace saleCut in `saleCuts` array during the creation of the listing.


### Considerations

1. **Ghost listings -** *Ghost listings are listings which don’t have an underlying NFT in the seller’s account but the listing is still available for buyers to attempt to purchase*. StorefrontV2 is not immune to ghost listings. Normally, ghost listings will cause a purchaser’s transaction to fail, which is annoying, but isn’t a significant problem. Ghost listings become a problem for the seller when the listed NFT comes back to the seller’s account after its original sale. The moment it comes back, the ghost listing will no longer be invalid anymore and anyone can purchase it even if the seller doesn’t want to sell it at that price anymore.
    
    **Note -** *We recommend to marketplaces and p2p dApps to create some kind of off-chain notification service that tells its users (i.e. seller’s) to remove the listings if the don’t hold the NFT anymore in the same account.*
    
2. **Expired listings -** NFTStorefrontV2 introduces a safety measure to specify that a listing will expire after a certain period of time that can be set during the creation of a listing so no one can purchase the listing anymore. It is not a fool-proof safety measure but it does give some safe ground to the sellers for the ghost listings & stale listings.
    
    
    **Note -** *It is recommended for marketplaces and p2p dApps to not show the expired listings on their dashboards.*

# Purchase NFTs

Purchasing NFTs through the NFTStorefrontV2 is simple. The buyer just has to provide the payment vault and the `commissionRecipient` , if applicable, during the purchase. p2p dApps don’t need any intermediaries to facilitate the purchase of listings. [`purchase`](#fun-purchase) api offered by the `Listing` resource get used to facilitate the purchase of NFT.

During the purchase of a listing, all saleCuts are paid automatically. This includes the [royalties](#enabling-creator-royalties-for-nfts) of the NFT as well. If the vault provided by the buyer doesn’t have sufficient funds, then the transaction will fail.

### Considerations

1. **Auto cleanup -** NFTStorefrontV2 offers a unique ability to do auto cleanup of duplicate listings during a purchase. It comes with a drawback if one NFT has thousands of duplicate listings, then it will become the bottleneck during the purchase of one of the listings as it will likely trigger an out of gas error. 

    **Note -** *It is NOT recommended to have more than 50 (TBD) duplicate listings of any given NFT.*

2. **Unsupported receiver capability** - There is a common pitfall during the purchase of an NFT that some saleCut receivers don’t have a supported receiver capability because of that entitled sale cut would transfer to first valid sale cut receiver. However it can be partially solved by providing the generic receiver using the `FungibleTokenSwitchboard` contract and add all the currencies capabilities that beneficiary wants to receive. More on the ``FungibleTokenSwitchboard` can be read [here](https://github.com/onflow/flow-ft#fungible-token-switchboard)


# Enabling creator royalties for NFTs

NFTStorefrontV2 contract support royalties but it doesn't mandate, It is a choice of marketplaces whether they want to support the creator royalties during listing or not. However, we encourage the marketplaces to support the royalties to stimulate the artists participation in FLOW ecosystem.

If seller's NFT supports [Royalty Metadata View](https://github.com/onflow/flow-nft/blob/21c254438910c8a4b5843beda3df20e4e2559625/contracts/MetadataViews.cdc#L335) standard then marketplaces can support royalties during the fulfillment of a listing. NFTStorefrontV2 can dynamically fetch the royalty details during the creation of the listing and turn it into the `saleCut` of the listing.

```solidity
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

full transaction can be viewed [here](https://github.com/onflow/nft-storefront/blob/main/transactions/sell_item.cdc).

`saleCut` only supports single receiver type, because of that beneficiary of saleCut doesn't able to receive different currency as the royalty or a general sale percentage cut. To resolve this we recommend to use the [FungibleTokenSwitchboard](https://github.com/onflow/flow-ft/blob/master/contracts/FungibleTokenSwitchboard.cdc) contract. It defines a generic receiver for fungible tokens, so that a user can always provide their generic receiver, regardless of what fungible token they want to receive. The switchboard will manage the routing of funds to the respective Vault. You can read more about this [here](https://github.com/onflow/flow-ft#fungible-token-switchboard).

# Enabling marketplace commissions for NFT sales [TODO]

![scenario_2](https://user-images.githubusercontent.com/14581509/190966499-c176203f-b6a6-4422-860f-1bf6f2bcdbb6.png)


To incentivize the marketplaces to show the sale on their app, the seller can specify a commission for the sale that is taken during the fulfillment of the listing. Here, the commission can only be claimed by one of the marketplace addresses provided during the creation of the listing.

An explicitly commissionAmount is set to zero and provided `nil` value to marketplacesAddresses during the creation of listing while

# APIs & Events offered by NFTStorefrontV2

## Resource Interface `ListingPublic`

```cadence
resource interface ListingPublic {
    pub fun borrowNFT(): &NonFungibleToken.NFT?
    pub fun purchase(
          payment: @FungibleToken.Vault, 
          commissionRecipient: Capability<&{FungibleToken.Receiver}>?,
      ): @NonFungibleToken.NFT
    pub fun getDetails(): ListingDetails
    pub fun getAllowedCommissionReceivers(): [Capability<&{FungibleToken.Receiver}>]?
}
```

ListingPublic
An interface providing a useful public interface to a Listing.
## Functions

### fun `borrowNFT()`

```cadence
fun borrowNFT(): &NonFungibleToken.NFT?
```
This will assert in the same way as the NFT standard borrowNFT()
if the NFT is absent, for example if it has been sold via another listing.

---

### fun `purchase()`

```cadence
fun purchase(payment FungibleToken.Vault, commissionRecipient Capability<&{FungibleToken.Receiver}>?): NonFungibleToken.NFT
```
Facilitates the purchase of the listing by providing the payment vault
and the commission recipient capability if there is a non-zero commission for the given listing.
Respective saleCuts are transferred to beneficiaries and funtion return underlying or listed NFT.

---

### fun `getDetails()`

```cadence
fun getDetails(): ListingDetails
```
Fetches the details of the listings

---

### fun `getAllowedCommissionReceivers()`

```cadence
fun getAllowedCommissionReceivers(): [Capability<&{FungibleToken.Receiver}>]?
```
Fetches the allowed marketplaces capabilities or commission receivers for the underlying listing.
If it returns `nil` then commission is up to grab by anyone.

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

Storefront
A resource that allows its owner to manage a list of Listings, and anyone to interact with them
in order to query their details and purchase the NFTs that they represent.

Implemented Interfaces:
  - `StorefrontManager`
  - `StorefrontPublic`


### Initializer

```cadence
fun init()
```


## Functions

### fun `createListing()`

```cadence
fun createListing(nftProviderCapability Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>, nftType Type, nftID UInt64, salePaymentVaultType Type, saleCuts [SaleCut], marketplacesCapability [Capability<&{FungibleToken.Receiver}>]?, customID String?, commissionAmount UFix64, expiry UInt64): UInt64
```
insert
Create and publish a Listing for an NFT.

---

### fun `removeListing()`

```cadence
fun removeListing(listingResourceID UInt64)
```
removeListing
Remove a Listing that has not yet been purchased from the collection and destroy it.

---

### fun `getListingIDs()`

```cadence
fun getListingIDs(): [UInt64]
```
getListingIDs
Returns an array of the Listing resource IDs that are in the collection

---

### fun `getDuplicateListingIDs()`

```cadence
fun getDuplicateListingIDs(nftType Type, nftID UInt64, listingID UInt64): [UInt64]
```
getDuplicateListingIDs
Returns an array of listing IDs that are duplicates of the given `nftType` and `nftID`.

---

### fun `cleanupExpiredListings()`

```cadence
fun cleanupExpiredListings(fromIndex UInt64, toIndex UInt64)
```
cleanupExpiredListings
Cleanup the expired listing by iterating over the provided range of indexes.

---

### fun `borrowListing()`

```cadence
fun borrowListing(listingResourceID UInt64): &Listing{ListingPublic}?
```
borrowListing
Returns a read-only view of the listing for the given listingID if it is contained by this collection.

---

# Resource Interface `StorefrontPublic`

```cadence
resource interface StorefrontPublic {
    pub fun getListingIDs(): [UInt64]
    pub fun getDuplicateListingIDs(nftType: Type, nftID: UInt64, listingID: UInt64): [UInt64]
    pub fun cleanupExpiredListings(fromIndex: UInt64, toIndex: UInt64)
    pub fun borrowListing(listingResourceID: UInt64): &Listing{ListingPublic}?
    pub fun cleanupPurchasedListings(listingResourceID: UInt64)
    pub fun getExistingListingIDs(nftType: Type, nftID: UInt64): [UInt64]
}
```

StorefrontPublic
An interface to allow listing and borrowing Listings, and purchasing items via Listings
in a Storefront.
## Functions

### fun `getListingIDs()`

```cadence
fun getListingIDs(): [UInt64]
```
getListingIDs Returns an array of the Listing resource IDs that are in the collection

---

### fun `getDuplicateListingIDs()`

```cadence
fun getDuplicateListingIDs(nftType Type, nftID UInt64, listingID UInt64): [UInt64]
```
getDuplicateListingIDs Returns an array of listing IDs that are duplicates of the given nftType and nftID.

---

### fun `borrowListing()`

```cadence
fun borrowListing(listingResourceID UInt64): &Listing{ListingPublic}?
```
borrowListing Returns a read-only view of the listing for the given listingID if it is contained by this collection.

---

### fun `cleanupExpiredListings()`

```cadence
fun cleanupExpiredListings(fromIndex UInt64, toIndex UInt64)
```
cleanupExpiredListings Cleanup the expired listing by iterating over the provided range of indexes.

---

### fun `cleanupPurchasedListings()`

```cadence
fun cleanupPurchasedListings(listingResourceID: UInt64)
```
cleanupPurchasedListings
Allows anyone to remove already purchased listings.

---

### fun `getExistingListingIDs()`

```cadence
fun getExistingListingIDs(nftType Type, nftID UInt64): [UInt64]
```
getExistingListingIDs
Returns an array of listing IDs of the given `nftType` and `nftID`.

---

## Events

### event `StorefrontInitialized`

```cadence
event StorefrontInitialized(storefrontResourceID: UInt64)
```
A Storefront resource has been created. Consumers can now expect events from this Storefront. Note that we do not specify an address: we cannot and should not. Created resources do not have an owner address, and may be moved
after creation in ways we cannot check. `ListingAvailable` events can be used to determine the address
of the owner of the Storefront at the time of the listing but only at that precise moment in that precise transaction. If the seller moves the Storefront while the listing is valid, that is on them.

---

### event `StorefrontDestroyed`

```cadence
event StorefrontDestroyed(storefrontResourceID: UInt64)
```
A Storefront has been destroyed. Event consumers can now stop processing events from this Storefront.
Note - we do not specify an address.

---

### event `ListingAvailable`

```cadence
event ListingAvailable(storefrontAddress: Address, listingResourceID: UInt64, nftType: Type, nftUUID: UInt64, nftID: UInt64, salePaymentVaultType: Type, salePrice: UFix64, customID: String?, commissionAmount: UFix64, commissionReceivers: [Address]?, expiry: UInt64)
```

Above event gets emitted when a listing has been created and added to a Storefront resource. The Address values here are valid when the event is emitted, but the state of the accounts they refer to may change outside of the
NFTStorefrontV2 workflow, so be careful to check when using them.

---

### event `ListingCompleted`

```cadence
event ListingCompleted(listingResourceID: UInt64, storefrontResourceID: UInt64, purchased: Bool, nftType: Type, nftUUID: UInt64, nftID: UInt64, salePaymentVaultType: Type, salePrice: UFix64, customID: String?, commissionAmount: UFix64, commissionReceiver: Address?, expiry: UInt64)
```
The listing has been resolved. It has either been purchased, removed or destroyed.

---

### event `UnpaidReceiver`

```cadence
event UnpaidReceiver(receiver: Address, entitledSaleCut: UFix64)
```
A entitled receiver has not been paid during the sale of the NFT.

---


**Holistic process flow diagram of NFTStorefrontV2 -** 

[NFT Storefront Process flow | Lucidchart](https://lucid.app/lucidchart/a0015c93-183d-4ab5-8a28-8909cc34b25d/edit?viewport_loc=-565%2C-377%2C3743%2C1941%2Cm-5o7ONTd-nK&invitationId=inv_f6e78c34-46da-41b4-a229-95eae82e8e9f#)


## Glossary

<a name="saleCut"></a>SaleCut - A struct consists a recipient and amount of token ,i.e. cut that must be sent to recipient when a NFT get sold.