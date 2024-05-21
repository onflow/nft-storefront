#allowAccountLinking

import "MetadataViews"

import "HybridCustody"
import "CapabilityFactory"
import "CapabilityFilter"
import "CapabilityDelegator"

/// This transaction configures an OwnedAccount in the signer if needed, and proceeds to create a ChildAccount 
/// using CapabilityFactory.Manager and CapabilityFilter.Filter Capabilities from the given addresses. A
/// Capability on the ChildAccount is then published to the specified parent account. 
///
transaction(
        parent: Address,
        factoryAddress: Address,
        filterAddress: Address,
        name: String?,
        desc: String?,
        thumbnailURL: String?
    ) {
    
    prepare(acct: AuthAccount) {
        // Configure OwnedAccount if it doesn't exist
        if acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath) == nil {
            var acctCap = acct.getCapability<&AuthAccount>(HybridCustody.LinkedAccountPrivatePath)
            if !acctCap.check() {
                acctCap = acct.linkAccount(HybridCustody.LinkedAccountPrivatePath)!
            }
            let ownedAccount <- HybridCustody.createOwnedAccount(acct: acctCap)
            acct.save(<-ownedAccount, to: HybridCustody.OwnedAccountStoragePath)
        }

        // check that paths are all configured properly
        acct.unlink(HybridCustody.OwnedAccountPrivatePath)
        acct.link<&HybridCustody.OwnedAccount{HybridCustody.BorrowableAccount, HybridCustody.OwnedAccountPublic, MetadataViews.Resolver}>(HybridCustody.OwnedAccountPrivatePath, target: HybridCustody.OwnedAccountStoragePath)

        acct.unlink(HybridCustody.OwnedAccountPublicPath)
        acct.link<&HybridCustody.OwnedAccount{HybridCustody.OwnedAccountPublic, MetadataViews.Resolver}>(HybridCustody.OwnedAccountPublicPath, target: HybridCustody.OwnedAccountStoragePath)

        let owned = acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
            ?? panic("owned account not found")
        
        // Set the display metadata for the OwnedAccount
        if name != nil && desc != nil && thumbnailURL != nil {
            let thumbnail = MetadataViews.HTTPFile(url: thumbnailURL!)
            let display = MetadataViews.Display(name: name!, description: desc!, thumbnail: thumbnail!)
            owned.setDisplay(display)
        }

        // Get CapabilityFactory & CapabilityFilter Capabilities
        let factory = getAccount(factoryAddress).getCapability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>(CapabilityFactory.PublicPath)
        assert(factory.check(), message: "factory address is not configured properly")

        let filter = getAccount(filterAddress).getCapability<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath)
        assert(filter.check(), message: "capability filter is not configured properly")

        // Finally publish a ChildAccount capability on the signing account to the specified parent
        owned.publishToParent(parentAddress: parent, factory: factory, filter: filter)
    }
}