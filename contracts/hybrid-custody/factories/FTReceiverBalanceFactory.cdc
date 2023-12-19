import "CapabilityFactory"
import "FungibleToken"

pub contract FTReceiverBalanceFactory {
    pub struct Factory: CapabilityFactory.Factory {
        pub fun getCapability(acct: &AuthAccount, path: CapabilityPath): Capability {
            return acct.getCapability<&{FungibleToken.Receiver, FungibleToken.Balance}>(path)
        }
    }
}