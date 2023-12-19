import "CapabilityFactory"
import "FungibleToken"

pub contract FTAllFactory {
    pub struct Factory: CapabilityFactory.Factory {
        pub fun getCapability(acct: &AuthAccount, path: CapabilityPath): Capability {
            return acct.getCapability<&{FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance}>(path)
        }
    }
}