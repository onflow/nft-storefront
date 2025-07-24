# NFT Storefront Contract Standard

The NFT Storefront contract standard is a cornerstone of the Open Marketplace ecosystem on Flow. An open market ecosystem promotes the 
free flow of NFT listings across the network, emitted as events and consumed by other marketplaces (or any other consumer). Marketplaces may filter 
listings consumed based on commission rates they may receive. Listings may be created with variable commission, royalties or other fractional revenue, paying to multiple accounts. NFT listings are not NFTs, they are Resources which can be transacted with using the `purchase` [function](https://github.com/onflow/nft-storefront/blob/jp-update-structure/contracts/NFTStorefrontV2.cdc#L300) to obtain the token indicated by the listing. 

The `NFTStorefrontV2` contract lets you create a non-custodial NFT marketplace to simplify integration with off-chain applications/UIs. The contract supports sellers who want to list and manage NFTs for sale simultaneously across any number of marketplaces. Listing expiry, orphaned and ghost listing cleanup are also of value for integrators to minimize overheads and ensure the best UX. 

Marketplaces and sellers also benefit from the robust security guarantees of Flow's account model when trading NFTs. Through this standard a NFT trade takes place from peer-to-peer, directly from the Storefront Resource in the sellers account to the purchasers account. At the same time, the standard ensures that marketplaces or other recipients may receive royalties, fees or commissions with no risk to the seller.

Sellers or marketplaces can optionally configure their NFTStorefront to be limited or closed. However, those wishing to participate in the Open Marketplace ecosystem on Flow are required to use the NFTStorefront standard. 

Detailed docs: [docs/documentation.md](docs/documentation.md)
Flow.com docs: [NFT Storefront Standard](https://developers.flow.com/build/core-contracts/nft-storefront)

# Contract Addresses 

|Name|Emulator|Testing Framework|Testnet|Previewnet|Mainnet|
|----|----|------|-------|------|-------|
|[NFTStorefront](contracts/NFTStorefront.cdc)| N/A | N/A |[0x94b06cfca1d8a476](https://flow-view-source.com/testnet/account/0x94b06cfca1d8a476/contract/NFTStorefront)|[0x6df5e52755433994](contracts/NFTStorefront.cdc)|[0x4eb8a10cb9f87357](https://flowscan.org/contract/A.4eb8a10cb9f87357.NFTStorefront)|
|[NFTStorefrontV2 (recommended)](contracts/NFTStorefrontV2.cdc)|`0xf8d6e0586b0a20c7`| `0x0000000000000001` |[0x2d55b98eb200daef](https://flow-view-source.com/testnet/account/0x2d55b98eb200daef/contract/NFTStorefrontV2)|[0x6df5e52755433994](contracts/NFTStorefrontV2.cdc)|[0x4eb8a10cb9f87357](https://flowscan.org/contract/A.4eb8a10cb9f87357.NFTStorefrontV2)|

# Usage

If you'd like to test with the `NFTStorefrontV2` Smart contract on the emulator,
it is automatically deployed to `0xf8d6e0586b0a20c7` or `0x0000000000000001` in the Cadence Testing Framework.

If you'd like to test with the `NFTStorefrontV2` Smart contract in your project,
add it to your project by using the flow dependency manager:

```
flow dependencies install mainnet://0x4eb8a10cb9f87357.NFTStorefrontV2
```

Use the addresses mentioned above for the `emulator` and `testing` import addresses in your project's flow.json.

Detailed docs for how to manage listings are available on
[the flow developer docs website](https://developers.flow.com/build/core-contracts/nft-storefront)

# Brief Overview

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

See further docs and examples on [the developer docs site](https://developers.flow.com/build/core-contracts/nft-storefront).
