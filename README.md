# NFT Storefront

The NFT storefront is a general-purpose Cadence 
contract for trading NFTs on Flow.

## Features 

- :shopping: A single storefront can combine listings for multiple NFTs of any type
- :currency_exchange:	NFTs can be exchanged for any fungible token that [implements the standard](https://github.com/onflow/flow-ft) (e.g. `FLOW`, `FUSD`)

## Contract Addresses 

|Name|Testnet|Mainnet|
|----|-------|-------|
|[NFTStorefront](contracts/NFTStorefront.cdc)|`TBD`|`TBD`|

## Usage

Each account that wants to offer NFTs for sale installs a `Storefront`,
and then lists individual sales within that `Storefront` as `SaleOffer` resources.

There is one `Storefront` per account that handles sales of all NFT types
for that account.

Each `SaleOffer` can list one or more cut percentages. 
Each cut is delivered to a predefined address. 
Cuts can be used to pay listing fees or other considerations.

Each NFT may be listed in one or more `SaleOffer`. 
The validity of each `SaleOffer` can easily be checked.

Purchasers can watch for `SaleOffer` events and check the NFT type and
ID to see if they wish to buy the offered item.

Marketplaces and other aggregators can watch for `SaleOffer` events
and list items of interest.
