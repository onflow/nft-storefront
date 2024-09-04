import "ExampleNFT"
import "ExampleToken"
import "FungibleToken"
import "NonFungibleToken"
import "NFTStorefront"
import "MaliciousStorefrontV1"

transaction {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        if acct.storage.borrow<&AnyResource>(from: NFTStorefront.StorefrontStoragePath) == nil {
            acct.storage.save(<-NFTStorefront.createStorefront(), to: NFTStorefront.StorefrontStoragePath)
        }

        if acct.storage.borrow<&AnyResource>(from: ExampleToken.VaultStoragePath) == nil {
            let vault <- ExampleToken.createEmptyVault(vaultType: Type<@ExampleToken.Vault>())
            acct.storage.save(<-vault, to: ExampleToken.VaultStoragePath)

            acct.capabilities.publish(
                acct.capabilities.storage.issue<&ExampleToken.Vault>(ExampleToken.VaultStoragePath),
                at: ExampleToken.ReceiverPublicPath
            )
        }

        if acct.storage.borrow<&AnyResource>(from: ExampleNFT.CollectionStoragePath) == nil {
            let collection <- ExampleNFT.createEmptyCollection(nftType: Type<@ExampleNFT.NFT>())
            acct.storage.save(<-collection, to: ExampleNFT.CollectionStoragePath)

            acct.capabilities.publish(
                acct.capabilities.storage.issue<&ExampleNFT.Collection>(ExampleNFT.CollectionStoragePath),
                at: ExampleNFT.CollectionPublicPath
            )
        }

        let storefrontCap = acct.capabilities.storage.issue<auth(NFTStorefront.CreateListing, NFTStorefront.RemoveListing) &NFTStorefront.Storefront>(NFTStorefront.StorefrontStoragePath)
        let providerCap = acct.capabilities.storage.issue<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>(ExampleNFT.CollectionStoragePath)

        if acct.storage.borrow<&AnyResource>(from: MaliciousStorefrontV1.StorefrontStoragePath) == nil {
            acct.storage.save(<- MaliciousStorefrontV1.createStorefront(storefrontCap: storefrontCap), to: MaliciousStorefrontV1.StorefrontStoragePath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&{NFTStorefront.StorefrontPublic}>(MaliciousStorefrontV1.StorefrontStoragePath),
                at: MaliciousStorefrontV1.StorefrontPublicPath
            )
        }

        let maliciousStorefront = acct.storage.borrow<auth(NFTStorefront.CreateListing) &MaliciousStorefrontV1.Storefront>(from: MaliciousStorefrontV1.StorefrontStoragePath)!
        let saleCut = NFTStorefront.SaleCut(
            receiver: acct.capabilities.get<&{FungibleToken.Receiver}>(ExampleToken.ReceiverPublicPath), 
            amount: 1.0
        )

        // borrow a reference to the NFTMinter resource in storage
        let minter = acct.storage.borrow<&ExampleNFT.NFTMinter>(from: ExampleNFT.MinterStoragePath)
            ?? panic("Account does not store an object at the specified path")

        let nft <- minter.mintNFT(
            name: "Legit NFT",
            description: "I'm the real one",
            thumbnail: "",
            royalties: []
        )

        let maliciousNft <- minter.mintNFT(
            name: "Not Fake",
            description: "Definitely Not Fake",
            thumbnail: "I swear",
            royalties: []
        )

        let nftId = nft.id
        let maliciousNftId = maliciousNft.id

        let collection = providerCap.borrow()!
        collection.deposit(token: <-nft)
        collection.deposit(token: <-maliciousNft)

        maliciousStorefront.createListing(
            nftProviderCapability: providerCap,
            nftType: Type<@ExampleNFT.NFT>(),
            nftID: nftId,
            maliciousNftId: maliciousNftId,
            salePaymentVaultType: Type<@ExampleToken.Vault>(),
            saleCuts: [saleCut],
            marketplacesCapability: nil,
            customID: nil,
            commissionAmount: 0.0,
            expiry: UInt64(getCurrentBlock().timestamp) + 1_000_000
        )
    }
}