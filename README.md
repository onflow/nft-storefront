# NFT Storefront

The NFT storefront is a general-purpose Cadence 
contract for trading NFTs on Flow.

`NFTStorefront` uses modern Cadence [run-time type](https://docs.onflow.org/cadence/language/run-time-types/)
facilities to implement a marketplace that can take any currency in order to vend any token in a safe and secure way. 
This means that only one instance of the contract is needed (see below for its address on Testnet and Mainnet), 
and its resources, transactions, and scripts can be used by any account to create any marketplace.

## Contract Addresses 

|Name|Testnet|Mainnet|
|----|-------|-------|
|[NFTStorefront](contracts/NFTStorefront.cdc)|[0x94b06cfca1d8a476](https://flow-view-source.com/testnet/account/0x94b06cfca1d8a476/contract/NFTStorefront)|[0x4eb8a10cb9f87357](https://flowscan.org/contract/A.4eb8a10cb9f87357.NFTStorefront)|

## Usage

Each account that wants to offer NFTs for sale installs a `Storefront`,
and then lists individual sales within that `Storefront` as `Listing` resources.

There is one `Storefront` per account that handles sales of all NFT types
for that account.

Each `Listing` can list one or more cut percentages.
Each cut is delivered to a predefined address. 
Cuts can be used to pay listing fees or other considerations.

Each NFT may be listed in one or more `Listing` resources.
The validity of each `Listing` can easily be checked.

Purchasers can watch for `Listing` events and check the NFT type and
ID to see if they wish to buy the offered item.

Marketplaces and other aggregators can watch for `Listing` events
and list items of interest.
