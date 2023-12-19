import "CapabilityFactory"
import "FungibleToken"

pub contract FTProviderFactory {
    pub struct Factory: CapabilityFactory.Factory {
        pub fun getCapability(acct: &AuthAccount, path: CapabilityPath): Capability {
            return acct.getCapability<&{FungibleToken.Provider}>(path)
        }
    }
}