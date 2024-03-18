import NFTStorefront from "../contracts/NFTStorefront.cdc"

// This transaction installs the Storefront ressource in an account.

transaction {
    prepare(acct: auth(IssueStorageCapabilityController, PublishCapability, Storage) &Account) {

        // If the account doesn't already have a Storefront
        if acct.storage.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath) == nil {

            // Create a new empty .Storefront
            let storefront <- NFTStorefront.createStorefront()
            
            // save it to the account
            acct.storage.save(<-storefront, to: NFTStorefront.StorefrontStoragePath)

            // create a public capability for the .Storefront & publish
            let storefrontPublicCap = acct.capabilities.storage.issue<&{NFTStorefront.StorefrontPublic}>(
                    NFTStorefront.StorefrontStoragePath
                )
            acct.capabilities.publish(storefrontPublicCap, at: NFTStorefront.StorefrontPublicPath)
        }
    }
}
