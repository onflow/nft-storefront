# NFT Storefront

The NFTStorefront contract lets you create a non-custodial NFT marketplace which standardizes buying and selling of NFTs in a decentralized way across Flow. Marketplaces and dApp developers can trustlessly consume listings offered across the entire chain, making those available to buy in their marketplace UIs. Adopters of the standard benefit from simplified listing aggregation, increased marketplace audience reach, and in-built support for commissions.

Furthermore, the contract supports sellers who want to list and manage NFTs for sale simultaneously across any number of marketplaces. Sellers benefit from improved management of listings across multiple marketplaces, support for royalties, and additional ways to split revenues.

Both marketplaces and sellers benefit from the robust security guarantees of Flow's account model when trading NFTs. Through this standard a NFT trade takes place from peer-to-peer, directly from the Storefront resource in the sellers Account to the purchasers account. At the same time, the standard ensures that marketplaces or other recipients may receive royalties, fees or commissions with no risk to the seller.

We highly recommend sellers, marketplace developers and integrators onboard the NFTStorefrontV2 contract for seamless integration into Flow's ecosystem-wide NFT marketplace functionality in your applications!

## Contract Addresses 

|Name|Testnet|Mainnet|
|----|-------|-------|
|[NFTStorefront](contracts/NFTStorefront.cdc)|[0x94b06cfca1d8a476](https://flow-view-source.com/testnet/account/0x94b06cfca1d8a476/contract/NFTStorefront)|[0x4eb8a10cb9f87357](https://flowscan.org/contract/A.4eb8a10cb9f87357.NFTStorefront)|
|[NFTStorefrontV2 (recommended)](contracts/NFTStorefrontV2.cdc)|[0x2d55b98eb200daef](https://flow-view-source.com/testnet/account/0x2d55b98eb200daef/contract/NFTStorefrontV2)|[0x4eb8a10cb9f87357](https://flowscan.org/contract/A.4eb8a10cb9f87357.NFTStorefrontV2)|

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
