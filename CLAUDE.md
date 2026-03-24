# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Pre-commit requirement for Cadence changes

Any changes to `.cdc` files must pass both of the following before committing:

```sh
make test
make ci
```

`make test` runs Go code generation, Go tests, and all Cadence tests with coverage. `make ci` skips Go generation but otherwise mirrors the CI pipeline. Both must be green.

### Run all tests
```sh
flow test --cover --covercode="contracts/NFTStorefrontV2.cdc" tests/NFTStorefrontV2_test.cdc
flow test --cover --covercode="contracts/NFTStorefront.cdc" tests/NFTStorefrontV1_test.cdc
```

### Run a single test function
```sh
flow test --filter <TestFunctionName> tests/NFTStorefrontV2_test.cdc
```

### Deploy to emulator
```sh
flow emulator start
flow deploy --network emulator
```

### Install/update dependencies
```sh
flow dependencies install
```

## Architecture

### Contracts

**`contracts/NFTStorefrontV2.cdc`** — The canonical, recommended contract. All new integrations should target this version.

**`contracts/NFTStorefront.cdc`** — V1, no longer actively supported. Maintained for backwards compatibility only.

Both are deployed to the same address on mainnet (`0x4eb8a10cb9f87357`) and testnet.

### Core Resource Model

Each seller account holds a single `Storefront` resource (stored at `NFTStorefrontV2.StorefrontStoragePath`). Within it, individual `Listing` resources represent NFTs offered for sale. The key design properties:

- **Non-custodial**: NFTs remain in the seller's collection until purchase. A `Listing` holds an `auth(NonFungibleToken.Withdraw)` provider capability, not the NFT itself.
- **One NFT, many listings**: The same NFT can have multiple active `Listing`s simultaneously (e.g., one per marketplace, or one per accepted token type).
- **Generic types**: `sell_item.cdc` and `buy_item.cdc` accept `nftTypeIdentifier` and `ftTypeIdentifier` strings, resolved via `MetadataViews.resolveContractViewFromTypeIdentifier`. No NFT- or FT-specific imports needed in those transactions.

### Payment Flow (`Listing.purchase`)

`salePrice = commissionAmount + sum(saleCuts)`

On purchase:
1. Commission is routed to `commissionRecipient` (must be one of `marketplacesCapability` if that list is non-nil).
2. Each `SaleCut` is paid to its receiver capability; failures emit `UnpaidReceiver` rather than reverting.
3. The NFT is withdrawn from the seller's collection via the stored provider capability and returned to the caller.

### Ghost Listings

A listing becomes "ghosted" when the underlying NFT is no longer present in the provider capability (transferred out or sold via another listing). Ghost listings:
- Do not revert on detection but will revert on purchase attempt.
- Can be checked via `Listing.hasListingBecomeGhosted()`.
- Can be cleaned up via `transactions/cleanup_ghost_listing.cdc` or `transactions/cleanup_purchased_listings.cdc`.

### Key V2 Additions over V1

| Feature | V1 | V2 |
|---|---|---|
| Commission / marketplace cuts | No | Yes (`commissionAmount` + `marketplacesCapability`) |
| Listing expiry | No | Yes (`expiry: UInt64` unix timestamp) |
| Ghost listing detection | No | Yes (`hasListingBecomeGhosted()`) |
| Duplicate listing cleanup | No | Yes (`getDuplicateListingIDs` / `cleanupPurchasedListings`) |
| Custom dapp ID | No | Yes (`customID: String?`) |

### Transaction Layout

- `transactions/` — V2 storefront transactions (use these)
- `transactions-v1/` — V1 storefront transactions (legacy)
- `transactions/hybrid-custody/` — Selling NFTs from child accounts via HybridCustody
- `scripts/` — Read-only queries (listing details, ghost detection, etc.)

### Testing

Tests use the **Cadence Testing Framework** (`import Test`). Contract aliases for `testing` network are defined in `flow.json`. Test helper utilities are in `tests/test_helpers.cdc`. Security regression tests use `contracts/utility/test/MaliciousStorefrontV1.cdc` and `MaliciousStorefrontV2.cdc` to verify that a malicious storefront cannot substitute a different NFT during purchase.

### Contract Addresses

| Network | Address |
|---|---|
| Mainnet | `0x4eb8a10cb9f87357` |
| Testnet | `0x2d55b98eb200daef` (V2), `0x94b06cfca1d8a476` (V1) |
| Emulator | `0xf8d6e0586b0a20c7` |
| Testing framework | `0x0000000000000007` (V2), `0x0000000000000006` (V1) |
