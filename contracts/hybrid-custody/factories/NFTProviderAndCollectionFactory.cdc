import "CapabilityFactory"
import "NonFungibleToken"

pub contract NFTProviderAndCollectionFactory {
    pub struct Factory: CapabilityFactory.Factory {
        pub fun getCapability(acct: &AuthAccount, path: CapabilityPath): Capability {
            return acct.getCapability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(path)
        }
    }
}