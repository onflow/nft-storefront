# Flow NFT Storefront Contract Standard

**A production-ready, non-custodial NFT marketplace smart contract standard for the Flow blockchain**

The NFT Storefront contract is the cornerstone of Flow's Open Marketplace ecosystem, enabling peer-to-peer NFT trading with robust security guarantees, automated royalty distribution, and multi-marketplace listing support.

## What It Does

NFT Storefront provides a standardized way to:
- **List NFTs for sale** across multiple marketplaces simultaneously from a single listing
- **Execute secure peer-to-peer trades** directly from seller to buyer accounts
- **Automate revenue splits** including royalties, marketplace commissions, and custom sale cuts
- **Manage listing lifecycle** with expiry, ghost listing cleanup, and duplicate listing handling
- **Enable marketplace interoperability** through standardized events and APIs

## Who It's For

**For Marketplace Developers (Intermediate to Advanced)**
- Building NFT marketplaces on Flow
- Integrating existing marketplaces with the Flow ecosystem
- Implementing custom marketplace logic with commission structures

**For NFT Project Developers (Beginner to Intermediate)**
- Enabling secondary sales for your NFT collections
- Implementing creator royalties
- Setting up peer-to-peer trading for your community

**For dApp Developers (Intermediate)**
- Adding NFT trading functionality to games or applications
- Building hybrid custody solutions with NFT trading

## Key Features

- **Non-custodial**: NFTs remain in seller's account until purchased
- **Multi-marketplace support**: List once, sell anywhere
- **Automated royalties**: Built-in support for creator earnings via MetadataViews
- **Flexible commissions**: Variable marketplace fees with multiple recipients
- **Listing management**: Expiry dates, ghost listing cleanup, duplicate handling
- **Event-driven**: Real-time listing discovery through on-chain events
- **Security-focused**: Leverages Flow's account model for safe trades

## Quick Start

### Installation

Install the contract dependency using Flow CLI:

```bash
flow dependencies install mainnet://0x4eb8a10cb9f87357.NFTStorefrontV2
```

### Contract Addresses

| Network | Address | Explorer |
|---------|---------|----------|
| **Mainnet** | `0x4eb8a10cb9f87357` | [View](https://flowscan.org/contract/A.4eb8a10cb9f87357.NFTStorefrontV2) |
| **Testnet** | `0x2d55b98eb200daef` | [View](https://flow-view-source.com/testnet/account/0x2d55b98eb200daef/contract/NFTStorefrontV2) |
| **Emulator** | `0xf8d6e0586b0a20c7` | - |
| **Testing Framework** | `0x0000000000000001` | - |

### Basic Usage Examples

#### 1. Setup Storefront (One-time setup)

```bash
flow transactions send ./transactions/setup_account.cdc
```

Or using Cadence:
```cadence
import NFTStorefrontV2 from 0x4eb8a10cb9f87357

transaction {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        if acct.storage.borrow<&NFTStorefrontV2.Storefront>(from: NFTStorefrontV2.StorefrontStoragePath) == nil {
            let storefront <- NFTStorefrontV2.createStorefront()
            acct.storage.save(<-storefront, to: NFTStorefrontV2.StorefrontStoragePath)

            let cap = acct.capabilities.storage.issue<&NFTStorefrontV2.Storefront>(NFTStorefrontV2.StorefrontStoragePath)
            acct.capabilities.publish(cap, at: NFTStorefrontV2.StorefrontPublicPath)
        }
    }
}
```

#### 2. List an NFT for Sale

```bash
# Basic listing
flow transactions send ./transactions/sell_item.cdc \
  --arg Address:0xNFTReceiverAddress \
  --arg UInt64:1234 \
  --arg UFix64:10.0

# With marketplace commission
flow transactions send ./transactions/sell_item_with_marketplace_cut.cdc \
  --arg Address:0xMarketplaceAddress \
  --arg UFix64:0.05
```

#### 3. Purchase a Listed NFT

```bash
flow transactions send ./transactions/buy_item.cdc \
  --arg UInt64:listingResourceID \
  --arg Address:0xStorefrontAddress
```

#### 4. Remove a Listing

```bash
flow transactions send ./transactions/remove_item.cdc \
  --arg UInt64:listingResourceID
```

#### 5. Cleanup Ghost Listings

```bash
flow transactions send ./transactions/cleanup_ghost_listing.cdc \
  --arg UInt64:listingResourceID
```

## Technology Stack

- **Language**: Cadence (Flow's smart contract language)
- **Blockchain**: Flow
- **Standards**:
  - NonFungibleToken (NFT standard)
  - FungibleToken (payment standard)
  - MetadataViews (royalty standard)
- **Testing**: Cadence Testing Framework
- **Dependencies**:
  - NonFungibleToken
  - FungibleToken
  - MetadataViews
  - ViewResolver

## Project Structure

```
nft-storefront/
├── contracts/
│   ├── NFTStorefrontV2.cdc          # Main contract (recommended)
│   ├── NFTStorefront.cdc             # Legacy V1 contract
│   └── utility/                      # Test utilities
├── transactions/
│   ├── setup_account.cdc             # Initialize storefront
│   ├── sell_item.cdc                 # Create basic listing
│   ├── sell_item_with_marketplace_cut.cdc  # Listing with commission
│   ├── buy_item.cdc                  # Purchase NFT
│   ├── remove_item.cdc               # Remove listing
│   ├── cleanup_ghost_listing.cdc     # Clean ghost listings
│   └── cleanup_expired_listings.cdc  # Clean expired listings
├── scripts/
│   ├── read_storefront_ids.cdc       # Query all listings
│   ├── read_listing_details.cdc      # Get listing info
│   └── has_listing_become_ghosted.cdc # Check ghost status
└── tests/
    ├── NFTStorefrontV2_test.cdc      # V2 test suite
    └── NFTStorefrontV1_test.cdc      # V1 test suite
```

## Documentation & Resources

- **Detailed Documentation**: [docs/documentation.md](docs/documentation.md)
- **Flow Developer Docs**: [NFT Storefront Standard](https://developers.flow.com/build/core-contracts/nft-storefront)
- **Contract Source**: [NFTStorefrontV2.cdc](contracts/NFTStorefrontV2.cdc)
- **GitHub Repository**: [onflow/nft-storefront](https://github.com/onflow/nft-storefront)

## Common Integration Patterns

### For Marketplace Developers

1. **Listen for ListingAvailable events** to discover new listings
2. **Filter listings by commission requirements** that match your marketplace
3. **Call purchase()** with your marketplace's commission receiver capability
4. **Execute cleanupPurchasedListings()** after successful sales

### For NFT Projects

1. **Implement MetadataViews.Royalties** in your NFT contract
2. **Guide users** to list using provided transactions
3. **Monitor ListingAvailable events** for your NFT type
4. **Promote across marketplaces** that support the standard

### For dApp Developers

1. **Create Storefront resource** for users on first sale
2. **Use sell_item transaction** with your custom parameters
3. **Handle multiple token types** by creating multiple listings per NFT
4. **Implement cleanup logic** for better UX

## Running Tests

```bash
# Run all tests
flow test tests/NFTStorefrontV2_test.cdc

# Start emulator for manual testing
flow emulator start

# Deploy contracts to emulator
flow project deploy --network emulator
```

## Key Concepts

- **Storefront**: Account-level resource that manages all listings for a seller
- **Listing**: Individual NFT sale offer with price, cuts, and conditions
- **SaleCut**: Payment split sent to specific address (royalties, commissions, seller)
- **Ghost Listing**: Listing without underlying NFT (should be cleaned up)
- **Commission Receiver**: Marketplace capability that receives commission on sale

## Security Considerations

- NFTs never leave seller account until purchase completes
- All payment splits execute atomically in single transaction
- Expired listings automatically prevent purchases
- Ghost listing detection prevents failed transactions
- Capability-based access control ensures proper authorization

## Migration from V1 to V2

NFTStorefrontV2 adds:
- Listing expiry functionality
- Ghost listing detection and cleanup
- Improved marketplace commission handling
- Better duplicate listing management
- Enhanced event emissions

See migration guide: [V1 to V2 Migration](docs/documentation.md#migration)

## SEO Keywords & Topics

Flow blockchain, NFT marketplace, Cadence smart contracts, non-custodial NFT trading, NFT storefront, Flow NFT standard, marketplace integration, creator royalties, peer-to-peer NFT sales, Flow dApp development, NFT listing management, multi-marketplace NFT, Flow NFT API, blockchain marketplace development, NFT trading platform, Flow ecosystem, secondary NFT sales

## Contributing

We welcome contributions! Please follow these guidelines:

1. **Fork the repository** and create a feature branch
2. **Write tests** for new functionality
3. **Follow Cadence best practices** and style guidelines
4. **Update documentation** for any API changes
5. **Submit a pull request** with clear description

### Development Setup

```bash
# Clone repository
git clone https://github.com/onflow/nft-storefront.git
cd nft-storefront

# Install Flow CLI (if not installed)
sh -ci "$(curl -fsSL https://raw.githubusercontent.com/onflow/flow-cli/master/install.sh)"

# Install dependencies
flow dependencies install

# Run tests
flow test tests/
```

## Support & Community

- **Issues**: [GitHub Issues](https://github.com/onflow/nft-storefront/issues)
- **Discord**: [Flow Discord](https://discord.gg/flow)
- **Developer Portal**: [Flow Developers](https://developers.flow.com)

## License

The works in these files are licensed under the [Apache License 2.0](LICENSE).

## Authors & Maintainers

Maintained by the Flow Foundation and community contributors.

**Core Contributors**:
- Flow Foundation Team
- Community developers

## Version History

- **V2 (Current)**: Enhanced features with expiry, ghost listing management, improved events
- **V1 (Legacy)**: Original storefront implementation (still supported on mainnet)

---

*Built on Flow - The blockchain for open worlds*
