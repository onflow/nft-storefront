import "NFTStorefrontV2"

/// This transaction installs the Storefront ressource in an account.
///
transaction {
    prepare(acct: auth(IssueStorageCapabilityController, PublishCapability, Storage) &Account) {

        // If the account doesn't already have a Storefront
        if acct.storage.borrow<&NFTStorefrontV2.Storefront>(from: NFTStorefrontV2.StorefrontStoragePath) == nil {

            // Create a new empty Storefront
            let storefront <- NFTStorefrontV2.createStorefront() as! @NFTStorefrontV2.Storefront
            
            // save it to the account
            acct.storage.save(<-storefront, to: NFTStorefrontV2.StorefrontStoragePath)

            // create a public capability for the Storefront
            let storefrontPublicCap = acct.capabilities.storage.issue<&{NFTStorefrontV2.StorefrontPublic}>(
                    NFTStorefrontV2.StorefrontStoragePath
                )
            acct.capabilities.publish(storefrontPublicCap, at: NFTStorefrontV2.StorefrontPublicPath)
        }
    }
}
 