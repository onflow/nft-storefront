// Third-party imports
import "MetadataViews"

// HC-owned imports
import "CapabilityFactory"
import "CapabilityDelegator"
import "CapabilityFilter"

/// HybridCustody defines a framework for sharing accounts via account linking.
/// In the contract, there are three main resources:
///
/// 1. OwnedAccount - A resource which maintains an AuthAccount Capability, and handles publishing and revoking access
///    of that account via another resource called a ChildAccount
/// 2. ChildAccount - A second resource which exists on the same account as the OwnedAccount and contains the filters
///    and retrieval patterns governing the scope of parent account access. A Capability on this resource is shared to
///    the parent account, enabling Hybrid Custody access to the underlying account.
/// 3. Manager - A resource setup by the parent which manages all child accounts shared with it. The Manager resource
///    also maintains a set of accounts that it "owns", meaning it has a capability to the full OwnedAccount resource
///    and would then also be able to manage the child account's links as it sees fit.
/// 
/// Contributors (please add to this list if you contribute!):
/// - Austin Kline - https://twitter.com/austin_flowty
/// - Deniz Edincik - https://twitter.com/bluesign
/// - Giovanni Sanchez - https://twitter.com/gio_incognito
/// - Ashley Daffin - https://twitter.com/web3ashlee
/// - Felipe Ribeiro - https://twitter.com/Frlabs33
///
/// Repo reference: https://github.com/onflow/hybrid-custody
///
pub contract HybridCustody {

    /* --- Canonical Paths --- */
    //
    // Note: Paths for ChildAccount & Delegator are derived from the parent's address
    //
    pub let OwnedAccountStoragePath: StoragePath
    pub let OwnedAccountPublicPath: PublicPath
    pub let OwnedAccountPrivatePath: PrivatePath

    pub let ManagerStoragePath: StoragePath
    pub let ManagerPublicPath: PublicPath
    pub let ManagerPrivatePath: PrivatePath

    pub let LinkedAccountPrivatePath: PrivatePath
    pub let BorrowableAccountPrivatePath: PrivatePath

    /* --- Events --- */
    //
    /// Manager creation event
    pub event CreatedManager(id: UInt64)
    /// OwnedAccount creation event
    pub event CreatedOwnedAccount(id: UInt64, child: Address)
    /// ChildAccount added/removed from Manager
    ///     active  : added to Manager
    ///     !active : removed from Manager
    pub event AccountUpdated(id: UInt64?, child: Address, parent: Address, active: Bool)
    /// OwnedAccount added/removed or sealed
    ///     active && owner != nil  : added to Manager 
    ///     !active && owner == nil : removed from Manager
    pub event OwnershipUpdated(id: UInt64, child: Address, previousOwner: Address?, owner: Address?, active: Bool)
    /// ChildAccount ready to be redeemed by emitted pendingParent
    pub event ChildAccountPublished(
        ownedAcctID: UInt64,
        childAcctID: UInt64,
        capDelegatorID: UInt64,
        factoryID: UInt64,
        filterID: UInt64,
        filterType: Type,
        child: Address,
        pendingParent: Address
    )
    /// OwnedAccount granted ownership to a new address, publishing a Capability for the pendingOwner
    pub event OwnershipGranted(ownedAcctID: UInt64, child: Address, previousOwner: Address?, pendingOwner: Address)
    /// Account has been sealed - keys revoked, new AuthAccount Capability generated
    pub event AccountSealed(id: UInt64, address: Address, parents: [Address])

    /// An OwnedAccount shares the BorrowableAccount capability to itelf with ChildAccount resources
    ///
    pub resource interface BorrowableAccount {
        access(contract) fun borrowAccount(): &AuthAccount
        pub fun check(): Bool
    }

    /// Public methods anyone can call on an OwnedAccount
    ///
    pub resource interface OwnedAccountPublic {
        /// Returns the addresses of all parent accounts
        pub fun getParentAddresses(): [Address]

        /// Returns associated parent addresses and their redeemed status - true if redeemed, false if pending
        pub fun getParentStatuses(): {Address: Bool}

        /// Returns true if the given address is a parent of this child and has redeemed it. Returns false if the given
        /// address is a parent of this child and has NOT redeemed it. Returns nil if the given address it not a parent
        /// of this child account.
        pub fun getRedeemedStatus(addr: Address): Bool?

        /// A callback function to mark a parent as redeemed on the child account.
        access(contract) fun setRedeemed(_ addr: Address)
    }

    /// Private interface accessible to the owner of the OwnedAccount
    ///
    pub resource interface OwnedAccountPrivate {
        /// Deletes the ChildAccount resource being used to share access to this OwnedAccount with the supplied parent
        /// address, and unlinks the paths it was using to reach the underlying account.
        pub fun removeParent(parent: Address): Bool

        /// Sets up a new ChildAccount resource for the given parentAddress to redeem. This child account uses the
        /// supplied factory and filter to manage what can be obtained from the child account, and a new
        /// CapabilityDelegator resource is created for the sharing of one-off capabilities. Each of these pieces of
        /// access control are managed through the child account.
        pub fun publishToParent(
            parentAddress: Address,
            factory: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>,
            filter: Capability<&{CapabilityFilter.Filter}>
        ) {
            pre {
                factory.check(): "Invalid CapabilityFactory.Getter Capability provided"
                filter.check(): "Invalid CapabilityFilter Capability provided"
            }
        }

        /// Passes ownership of this child account to the given address. Once executed, all active keys on the child
        /// account will be revoked, and the active AuthAccount Capability being used by to obtain capabilities will be
        /// rotated, preventing anyone without the newly generated Capability from gaining access to the account.
        pub fun giveOwnership(to: Address)

        /// Revokes all keys on an account, unlinks all currently active AuthAccount capabilities, then makes a new one
        /// and replaces the OwnedAccount's underlying AuthAccount Capability with the new one to ensure that all
        /// parent accounts can still operate normally.
        /// Unless this method is executed via the giveOwnership function, this will leave an account **without** an
        /// owner.
        /// USE WITH EXTREME CAUTION.
        pub fun seal()

        // setCapabilityFactoryForParent
        // Override the existing CapabilityFactory Capability for a given parent. This will allow the owner of the
        // account to start managing their own factory of capabilities to be able to retrieve
        pub fun setCapabilityFactoryForParent(parent: Address, cap: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>) {
            pre {
                cap.check(): "Invalid CapabilityFactory.Getter Capability provided"
            }
        }

        /// Override the existing CapabilityFilter Capability for a given parent. This will allow the owner of the
        /// account to start managing their own filter for retrieving Capabilities on Private Paths
        pub fun setCapabilityFilterForParent(parent: Address, cap: Capability<&{CapabilityFilter.Filter}>) {
            pre {
                cap.check(): "Invalid CapabilityFilter Capability provided"
            }
        }

        /// Adds a capability to a parent's managed @ChildAccount resource. The Capability can be made public,
        /// permitting anyone to borrow it.
        pub fun addCapabilityToDelegator(parent: Address, cap: Capability, isPublic: Bool) {
            pre {
                cap.check<&AnyResource>(): "Invalid Capability provided"
            }
        }

        /// Removes a Capability from the CapabilityDelegator used by the specified parent address
        pub fun removeCapabilityFromDelegator(parent: Address, cap: Capability)

        /// Returns the address of this OwnedAccount
        pub fun getAddress(): Address
        
        /// Checks if this OwnedAccount is a child of the specified address
        pub fun isChildOf(_ addr: Address): Bool

        /// Returns all addresses which are parents of this OwnedAccount
        pub fun getParentAddresses(): [Address]

        /// Borrows this OwnedAccount's AuthAccount Capability
        pub fun borrowAccount(): &AuthAccount?

        /// Returns the current owner of this account, if there is one
        pub fun getOwner(): Address?

        /// Returns the pending owner of this account, if there is one
        pub fun getPendingOwner(): Address?

        /// A callback which is invoked when a parent redeems an owned account
        access(contract) fun setOwnerCallback(_ addr: Address)
        
        /// Destroys all outstanding AuthAccount capabilities on this owned account, and creates a new one for the
        /// OwnedAccount to use
        pub fun rotateAuthAccount()

        /// Revokes all keys on this account
        pub fun revokeAllKeys()
    }

    /// Public methods exposed on a ChildAccount resource. OwnedAccountPublic will share some methods here, but isn't
    /// necessarily the same.
    ///
    pub resource interface AccountPublic {
        pub fun getPublicCapability(path: PublicPath, type: Type): Capability?
        pub fun getPublicCapFromDelegator(type: Type): Capability?
        pub fun getAddress(): Address
        pub fun getCapabilityFactoryManager(): &{CapabilityFactory.Getter}?
        pub fun getCapabilityFilter(): &{CapabilityFilter.Filter}?
    }

    /// Methods accessible to the designated parent of a ChildAccount
    ///
    pub resource interface AccountPrivate {
        pub fun getCapability(path: CapabilityPath, type: Type): Capability? {
            post {
                result == nil || [true, nil].contains(self.getManagerCapabilityFilter()?.allowed(cap: result!)):
                    "Capability is not allowed by this account's Parent"
            }
        }
        pub fun getPublicCapability(path: PublicPath, type: Type): Capability?
        pub fun getManagerCapabilityFilter():  &{CapabilityFilter.Filter}?
        pub fun getPublicCapFromDelegator(type: Type): Capability?
        pub fun getPrivateCapFromDelegator(type: Type): Capability? {
            post {
                result == nil || [true, nil].contains(self.getManagerCapabilityFilter()?.allowed(cap: result!)):
                    "Capability is not allowed by this account's Parent"
            }
        }
        access(contract) fun redeemedCallback(_ addr: Address)
        access(contract) fun setManagerCapabilityFilter(_ managerCapabilityFilter: Capability<&{CapabilityFilter.Filter}>?) {
            pre {
                managerCapabilityFilter == nil || managerCapabilityFilter!.check(): "Invalid Manager Capability Filter"
            }
        }
        access(contract) fun parentRemoveChildCallback(parent: Address)
    }

    /// Entry point for a parent to obtain, maintain and access Capabilities or perform other actions on child accounts
    ///
    pub resource interface ManagerPrivate {
        pub fun addAccount(cap: Capability<&{AccountPrivate, AccountPublic, MetadataViews.Resolver}>)
        pub fun borrowAccount(addr: Address): &{AccountPrivate, AccountPublic, MetadataViews.Resolver}?
        pub fun removeChild(addr: Address)
        pub fun addOwnedAccount(cap: Capability<&{OwnedAccountPrivate, OwnedAccountPublic, MetadataViews.Resolver}>)
        pub fun borrowOwnedAccount(addr: Address): &{OwnedAccountPrivate, OwnedAccountPublic, MetadataViews.Resolver}?
        pub fun removeOwned(addr: Address)
        pub fun setManagerCapabilityFilter(cap: Capability<&{CapabilityFilter.Filter}>?, childAddress: Address) {
            pre {
                cap == nil || cap!.check(): "Invalid Manager Capability Filter"
            }
        }
    }

    /// Functions anyone can call on a manager to get information about an account such as What child accounts it has
    /// Functions anyone can call on a manager to get information about an account such as what child accounts it has
    pub resource interface ManagerPublic {
        pub fun borrowAccountPublic(addr: Address): &{AccountPublic, MetadataViews.Resolver}?
        pub fun getChildAddresses(): [Address]
        pub fun getOwnedAddresses(): [Address]
        pub fun getChildAccountDisplay(address: Address): MetadataViews.Display?
        access(contract) fun removeParentCallback(child: Address)
    }

    /// A resource for an account which fills the Parent role of the Child-Parent account management Model. A Manager
    /// can redeem or remove child accounts, and obtain any capabilities exposed by the child account to them.
    ///
    pub resource Manager: ManagerPrivate, ManagerPublic, MetadataViews.Resolver {

        /// Mapping of restricted access child account Capabilities indexed by their address
        pub let childAccounts: {Address: Capability<&{AccountPrivate, AccountPublic, MetadataViews.Resolver}>}
        /// Mapping of unrestricted owned account Capabilities indexed by their address
        pub let ownedAccounts: {Address: Capability<&{OwnedAccountPrivate, OwnedAccountPublic, MetadataViews.Resolver}>}

        /// A bucket of structs so that the Manager resource can be easily extended with new functionality.
        pub let data: {String: AnyStruct}
        /// A bucket of resources so that the Manager resource can be easily extended with new functionality.
        pub let resources: @{String: AnyResource}

        /// An optional filter to gate what capabilities are permitted to be returned from a child account For example,
        /// Dapper Wallet parent account's should not be able to retrieve any FungibleToken Provider capabilities.
        pub var filter: Capability<&{CapabilityFilter.Filter}>?

        // display metadata for a child account exists on its parent
        pub let childAccountDisplays: {Address: MetadataViews.Display}

        /// Sets the Display on the ChildAccount. If nil, the display is removed.
        ///
        pub fun setChildAccountDisplay(address: Address, _ d: MetadataViews.Display?) {
            pre {
                self.childAccounts[address] != nil: "There is no child account with this address"
            }

            if d == nil {
                self.childAccountDisplays.remove(key: address)
                return
            }

            self.childAccountDisplays[address] = d
        }

        /// Adds a ChildAccount Capability to this Manager. If a default Filter is set in the manager, it will also be
        /// added to the ChildAccount
        ///
        pub fun addAccount(cap: Capability<&{AccountPrivate, AccountPublic, MetadataViews.Resolver}>) {
            pre {
                self.childAccounts[cap.address] == nil: "There is already a child account with this address"
            }

            let acct = cap.borrow()
                ?? panic("child account capability could not be borrowed")

            self.childAccounts[cap.address] = cap
            
            emit AccountUpdated(id: acct.uuid, child: cap.address, parent: self.owner!.address, active: true)

            acct.redeemedCallback(self.owner!.address)
            acct.setManagerCapabilityFilter(self.filter)
        }

        /// Sets the default Filter Capability for this Manager. Does not propagate to child accounts.
        ///
        pub fun setDefaultManagerCapabilityFilter(cap: Capability<&{CapabilityFilter.Filter}>?) {
            pre {
                cap == nil || cap!.check(): "supplied capability must be nil or check must pass"
            }

            self.filter = cap
        }
        
        /// Sets the Filter Capability for this Manager, propagating to the specified child account
        ///
        pub fun setManagerCapabilityFilter(cap: Capability<&{CapabilityFilter.Filter}>?, childAddress: Address) {
            let acct = self.borrowAccount(addr: childAddress) 
                ?? panic("child account not found")

            acct.setManagerCapabilityFilter(cap)
        }

        /// Removes specified child account from the Manager's child accounts. Callbacks to the child account remove
        /// any associated resources and Capabilities
        ///
        pub fun removeChild(addr: Address) {
            let cap = self.childAccounts.remove(key: addr)
                ?? panic("child account not found")

            self.childAccountDisplays.remove(key: addr)
            
            if !cap.check() {
                // Emit event if invalid capability
                emit AccountUpdated(id: nil, child: cap.address, parent: self.owner!.address, active: false)
                return
            }

            let acct = cap.borrow()!
            // Get the child account id before removing capability
            let id: UInt64 = acct.uuid

            acct.parentRemoveChildCallback(parent: self.owner!.address) 

            emit AccountUpdated(id: id, child: cap.address, parent: self.owner!.address, active: false)
        }

        /// Contract callback that removes a child account from the Manager's child accounts in the event a child
        /// account initiates unlinking parent from child
        ///
        access(contract) fun removeParentCallback(child: Address) {
            self.childAccounts.remove(key: child)
            self.childAccountDisplays.remove(key: child)
        }

        /// Adds an owned account to the Manager's list of owned accounts, setting the Manager account as the owner of
        /// the given account
        ///
        pub fun addOwnedAccount(cap: Capability<&{OwnedAccountPrivate, OwnedAccountPublic, MetadataViews.Resolver}>) {
            pre {
                self.ownedAccounts[cap.address] == nil: "There is already an owned account with this address"
            }

            let acct = cap.borrow()
                ?? panic("owned account capability could not be borrowed")

            // for safety, rotate the auth account capability to prevent any outstanding capabilities from the previous owner
            // and revoke all outstanding keys.
            acct.rotateAuthAccount()
            acct.revokeAllKeys()

            self.ownedAccounts[cap.address] = cap

            emit OwnershipUpdated(id: acct.uuid, child: cap.address, previousOwner: acct.getOwner(), owner: self.owner!.address, active: true)
            acct.setOwnerCallback(self.owner!.address)
        }

        /// Returns a reference to a child account
        ///
        pub fun borrowAccount(addr: Address): &{AccountPrivate, AccountPublic, MetadataViews.Resolver}? {
            let cap = self.childAccounts[addr]
            if cap == nil {
                return nil
            }

            return cap!.borrow()
        }

        /// Returns a reference to a child account's public AccountPublic interface
        ///
        pub fun borrowAccountPublic(addr: Address): &{AccountPublic, MetadataViews.Resolver}? {
            let cap = self.childAccounts[addr]
            if cap == nil {
                return nil
            }

            return cap!.borrow()
        }

        /// Returns a reference to an owned account
        ///
        pub fun borrowOwnedAccount(addr: Address): &{OwnedAccountPrivate, OwnedAccountPublic, MetadataViews.Resolver}? {
            if let cap = self.ownedAccounts[addr] {
                return cap.borrow()
            }

            return nil
        }

        /// Removes specified child account from the Manager's child accounts. Callbacks to the child account remove
        /// any associated resources and Capabilities
        ///
        pub fun removeOwned(addr: Address) {
            if let acct = self.ownedAccounts.remove(key: addr) {
                if acct.check() {
                    acct.borrow()!.seal()
                }
                let id: UInt64? = acct.borrow()?.uuid ?? nil

                emit OwnershipUpdated(id: id!, child: addr, previousOwner: self.owner!.address, owner: nil, active: false)
            }
            // Don't emit an event if nothing was removed
        }

        /// Removes the owned Capabilty on the specified account, relinquishing access to the account and publishes a
        /// Capability for the specified account. See `OwnedAccount.giveOwnership()` for more details on this method.
        /// 
        /// **NOTE:** The existence of this method does not imply that it is the only way to receive access to a
        /// OwnedAccount Capability or that only the labeled `to` account has said access. Rather, this is a convenient
        /// mechanism intended to easily transfer 'root' access on this account to another account and an attempt to
        /// minimize access vectors.
        ///
        pub fun giveOwnership(addr: Address, to: Address) {
            let acct = self.ownedAccounts.remove(key: addr)
                ?? panic("account not found")

            acct.borrow()!.giveOwnership(to: to)
        }

        /// Returns an array of child account addresses
        ///
        pub fun getChildAddresses(): [Address] {
            return self.childAccounts.keys
        }

        /// Returns an array of owned account addresses
        ///
        pub fun getOwnedAddresses(): [Address] {
            return self.ownedAccounts.keys
        }

        /// Retrieves the parent-defined display for the given child account
        ///
        pub fun getChildAccountDisplay(address: Address): MetadataViews.Display? {
            return self.childAccountDisplays[address]
        }

        /// Returns the types of supported views - none at this time
        ///
        pub fun getViews(): [Type] {
            return []
        }

        /// Resolves the given view if supported - none at this time
        ///
        pub fun resolveView(_ view: Type): AnyStruct? {
            return nil
        }

        init(filter: Capability<&{CapabilityFilter.Filter}>?) {
            pre {
                filter == nil || filter!.check(): "Invalid CapabilityFilter Filter capability provided"
            }
            self.childAccounts = {}
            self.ownedAccounts = {}
            self.childAccountDisplays = {}
            self.filter = filter

            self.data = {}
            self.resources <- {}
        }

        destroy () {
            destroy self.resources
        }
    }

    /// The ChildAccount resource sits between a child account and a parent and is stored on the same account as the
    /// child account. Once created, a private capability to the child account is shared with the intended parent. The
    /// parent account will accept this child capability into its own manager resource and use it to interact with the
    /// child account.
    /// 
    /// Because the ChildAccount resource exists on the child account itself, whoever owns the child account will be
    /// able to manage all ChildAccount resources it shares, without worrying about whether the upstream parent can do
    /// anything to prevent it.
    /// 
    pub resource ChildAccount: AccountPrivate, AccountPublic, MetadataViews.Resolver {
        /// A Capability providing access to the underlying child account
        access(self) let childCap: Capability<&{BorrowableAccount, OwnedAccountPublic, MetadataViews.Resolver}>

        /// The CapabilityFactory Manager is a ChildAccount's way of limiting what types can be asked for by its parent
        /// account. The CapabilityFactory returns Capabilities which can be casted to their appropriate types once
        /// obtained, but only if the child account has configured their factory to allow it. For instance, a
        /// ChildAccount might choose to expose NonFungibleToken.Provider, but not FungibleToken.Provider
        pub var factory: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>

        /// The CapabilityFilter is a restriction put at the front of obtaining any non-public Capability. Some wallets
        /// might want to give access to NonFungibleToken.Provider, but only to **some** of the collections it manages,
        /// not all of them.
        pub var filter: Capability<&{CapabilityFilter.Filter}>

        /// The CapabilityDelegator is a way to share one-off capabilities from the child account. These capabilities
        /// can be public OR private and are separate from the factory which returns a capability at a given path as a 
        /// certain type. When using the CapabilityDelegator, you do not have the ability to specify which path a
        /// capability came from. For instance, Dapper Wallet might choose to expose a Capability to their Full TopShot
        /// collection, but only to the path that the collection exists in.
        pub let delegator: Capability<&CapabilityDelegator.Delegator{CapabilityDelegator.GetterPublic, CapabilityDelegator.GetterPrivate}>

        /// managerCapabilityFilter is a component optionally given to a child account when a manager redeems it. If
        /// this filter is not nil, any Capability returned through the `getCapability` function checks that the
        /// manager allows access first.
        access(self) var managerCapabilityFilter: Capability<&{CapabilityFilter.Filter}>?

        /// A bucket of structs so that the ChildAccount resource can be easily extended with new functionality.
        access(self) let data: {String: AnyStruct}

        /// A bucket of resources so that the ChildAccount resource can be easily extended with new functionality.
        access(self) let resources: @{String: AnyResource}

        /// ChildAccount resources have a 1:1 association with parent accounts, the named parent Address here is the 
        /// one with a Capability on this resource.
        pub let parent: Address

        /// Returns the Address of the underlying child account
        ///
        pub fun getAddress(): Address {
            return self.childCap.address
        }

        /// Callback setting the child account as redeemed by the provided parent Address
        ///
        access(contract) fun redeemedCallback(_ addr: Address) {
            self.childCap.borrow()!.setRedeemed(addr)
        }

        /// Sets the given filter as the managerCapabilityFilter for this ChildAccount
        ///
        access(contract) fun setManagerCapabilityFilter(
            _ managerCapabilityFilter: Capability<&{CapabilityFilter.Filter}>?
        ) {
            self.managerCapabilityFilter = managerCapabilityFilter
        }

        /// Sets the CapabiltyFactory.Manager Capability
        ///
        pub fun setCapabilityFactory(cap: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>) {
            self.factory = cap
        }
 
        /// Sets the Filter Capability as the one provided
        ///
        pub fun setCapabilityFilter(cap: Capability<&{CapabilityFilter.Filter}>) {
            self.filter = cap
        }

        /// The main function to a child account's capabilities from a parent account. When a PrivatePath type is used,
        /// the CapabilityFilter will be borrowed and the Capability being returned will be checked against it to
        /// ensure that borrowing is permitted. If not allowed, nil is returned.
        /// Also know that this method retrieves Capabilities via the CapabilityFactory path. To retrieve arbitrary 
        /// Capabilities, see `getPrivateCapFromDelegator()` and `getPublicCapFromDelegator()` which use the
        /// `Delegator` retrieval path.
        ///
        pub fun getCapability(path: CapabilityPath, type: Type): Capability? {
            let child = self.childCap.borrow() ?? panic("failed to borrow child account")

            let f = self.factory.borrow()!.getFactory(type)
            if f == nil {
                return nil
            }

            let acct = child.borrowAccount()
            let cap = f!.getCapability(acct: acct, path: path)

            // Check that private capabilities are allowed by either internal or manager filter (if assigned)
            // If not allowed, return nil
            if path.getType() == Type<PrivatePath>() && (
                self.filter.borrow()!.allowed(cap: cap) == false || 
                (self.getManagerCapabilityFilter()?.allowed(cap: cap) ?? true) == false
            ) {
                return nil
            }

            return cap
        }

        /// Retrieves a private Capability from the Delegator or nil none is found of the given type. Useful for
        /// arbitrary Capability retrieval
        ///
        pub fun getPrivateCapFromDelegator(type: Type): Capability? {
            if let d = self.delegator.borrow() {
                return d.getPrivateCapability(type)
            }

            return nil
        }

        /// Retrieves a public Capability from the Delegator or nil none is found of the given type. Useful for
        /// arbitrary Capability retrieval
        ///
        pub fun getPublicCapFromDelegator(type: Type): Capability? {
            if let d = self.delegator.borrow() {
                return d.getPublicCapability(type)
            }
            return nil
        }

        /// Enables retrieval of public Capabilities of the given type from the specified path or nil if none is found.
        /// Callers should be aware this method uses the `CapabilityFactory` retrieval path.
        ///
        pub fun getPublicCapability(path: PublicPath, type: Type): Capability? {
            return self.getCapability(path: path, type: type)
        }

        /// Returns a reference to the stored managerCapabilityFilter if one exists
        ///
        pub fun getManagerCapabilityFilter():  &{CapabilityFilter.Filter}? {
            return self.managerCapabilityFilter != nil ? self.managerCapabilityFilter!.borrow() : nil
        }

        /// Sets the child account as redeemed by the given Address
        ///
        access(contract) fun setRedeemed(_ addr: Address) {
            let acct = self.childCap.borrow()!.borrowAccount()
            if let o = acct.borrow<&OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath) {
                o.setRedeemed(addr)
            }
        }

        /// Returns a reference to the stored delegator, generally used for arbitrary Capability retrieval
        ///
        pub fun borrowCapabilityDelegator(): &CapabilityDelegator.Delegator? {
            let path = HybridCustody.getCapabilityDelegatorIdentifier(self.parent)
            return self.childCap.borrow()!.borrowAccount().borrow<&CapabilityDelegator.Delegator>(
                from: StoragePath(identifier: path)!
            )
        }

        /// Returns a list of supported metadata views
        ///
        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>()
            ]
        }

        /// Resolves a view of the given type if supported
        ///
        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    let childAddress = self.getAddress()
                    let manager = getAccount(self.parent).getCapability<&HybridCustody.Manager{HybridCustody.ManagerPublic}>(HybridCustody.ManagerPublicPath)

                    if !manager.check() {
                        return nil
                    }

                    return manager!.borrow()!.getChildAccountDisplay(address: childAddress)
            }
            return nil
        }

        /// Callback to enable parent-initiated removal all the child account and its associated resources &
        /// Capabilities
        ///
        access(contract) fun parentRemoveChildCallback(parent: Address) {
            if !self.childCap.check() {
                return
            }

            let child: &AnyResource{HybridCustody.BorrowableAccount} = self.childCap.borrow()!
            if !child.check() {
                return
            }

            let acct = child.borrowAccount()
            if let ownedAcct = acct.borrow<&OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath) {
                ownedAcct.removeParent(parent: parent)
            }
        }

        init(
            _ childCap: Capability<&{BorrowableAccount, OwnedAccountPublic, MetadataViews.Resolver}>,
            _ factory: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>,
            _ filter: Capability<&{CapabilityFilter.Filter}>,
            _ delegator: Capability<&CapabilityDelegator.Delegator{CapabilityDelegator.GetterPublic, CapabilityDelegator.GetterPrivate}>,
            _ parent: Address
        ) {
            pre {
                childCap.check(): "Provided childCap Capability is invalid"
                factory.check(): "Provided factory Capability is invalid"
                filter.check(): "Provided filter Capability is invalid"
                delegator.check(): "Provided delegator Capability is invalid"
            }
            self.childCap = childCap
            self.factory = factory
            self.filter = filter
            self.delegator = delegator
            self.managerCapabilityFilter = nil // this will get set when a parent account redeems
            self.parent = parent

            self.data = {}
            self.resources <- {}
        }

        /// Returns a capability to this child account's CapabilityFilter
        ///
        pub fun getCapabilityFilter(): &{CapabilityFilter.Filter}? {
            return self.filter.check() ? self.filter.borrow() : nil
        }

        /// Returns a capability to this child account's CapabilityFactory
        ///
        pub fun getCapabilityFactoryManager(): &{CapabilityFactory.Getter}? {
            return self.factory.check() ? self.factory.borrow() : nil
        }

        destroy () {
            destroy <- self.resources
        }
    }

    /// A resource which sits on the account it manages to make it easier for apps to configure the behavior they want 
    /// to permit. An OwnedAccount can be used to create ChildAccount resources and share them, publishing them to
    /// other addresses.
    /// 
    /// The OwnedAccount can also be used to pass ownership of an account off to another address, or to relinquish
    /// ownership entirely, marking the account as owned by no one. Note that even if there isn't an owner, the parent
    /// accounts would still exist, allowing a form of Hybrid Custody which has no true owner over an account, but
    /// shared partial ownership.
    ///
    pub resource OwnedAccount: OwnedAccountPrivate, BorrowableAccount, OwnedAccountPublic, MetadataViews.Resolver {
        /// Capability on the underlying account object
        access(self) var acct: Capability<&AuthAccount>

        /// Mapping of current and pending parents, true and false respectively
        pub let parents: {Address: Bool}
        /// Address of the pending owner, if one exists
        pub var pendingOwner: Address?
        /// Address of the current owner, if one exists
        pub var acctOwner: Address?
        /// Owned status of this account
        pub var currentlyOwned: Bool

        /// A bucket of structs so that the OwnedAccount resource can be easily extended with new functionality.
        access(self) let data: {String: AnyStruct}

        /// A bucket of resources so that the OwnedAccount resource can be easily extended with new functionality.
        access(self) let resources: @{String: AnyResource}

        /// display is its own field on the OwnedAccount resource because only the owner of the child account should be
        /// able to set this field.
        access(self) var display: MetadataViews.Display?

        /// Callback that sets this OwnedAccount as redeemed by the parent
        ///
        access(contract) fun setRedeemed(_ addr: Address) {
            pre {
                self.parents[addr] != nil: "address is not waiting to be redeemed"
            }

            self.parents[addr] = true
        }

        /// Callback that sets the owner once redeemed
        ///
        access(contract) fun setOwnerCallback(_ addr: Address) {
            pre {
                self.pendingOwner == addr: "Address does not match pending owner!"
            }
            self.pendingOwner = nil
            self.acctOwner = addr
        }


        /// A helper method to make it easier to manage what parents an account has configured. The steps to sharing this
        /// OwnedAccount with a new parent are:
        /// 
        /// 1. Create a new CapabilityDelegator for the ChildAccount resource being created. We make a new one here because
        ///    CapabilityDelegator types are meant to be shared explicitly. Making one shared base-line of capabilities might
        ///    introduce unforseen behavior where an app accidentally shared something to all accounts when it only meant
        ///    to go to one of them. It is better for parent accounts to have less access than they might have anticipated,
        ///    than for a child to have given out access it did not intend to.
        /// 2. Create a new Capability<&{BorrowableAccount}> which has its own unique path for the parent to share this
        ///    child account with. We make new ones each time so that you can revoke access from one parent, without
        ///    destroying them all. A new link is made each time based on the address being shared to allow this
        ///    fine-grained control, but it is all managed by the OwnedAccount resource itself.
        /// 3. A new @ChildAccount resource is created and saved, using the CapabilityDelegator made in step one, and our
        ///    CapabilityFactory and CapabilityFilter Capabilities. Once saved, public and private links are configured for
        ///    the ChildAccount.
        /// 4. Publish the newly made private link to the designated parent's inbox for them to claim on their @Manager
        ///    resource.
        ///
        pub fun publishToParent(
            parentAddress: Address,
            factory: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>,
            filter: Capability<&{CapabilityFilter.Filter}>
        ) {
            pre{
                self.parents[parentAddress] == nil: "Address pending or already redeemed as parent"
            }
            let capDelegatorIdentifier = HybridCustody.getCapabilityDelegatorIdentifier(parentAddress)

            let identifier = HybridCustody.getChildAccountIdentifier(parentAddress)
            let childAccountStorage = StoragePath(identifier: identifier)!

            let capDelegatorStorage = StoragePath(identifier: capDelegatorIdentifier)!
            let acct = self.borrowAccount()

            assert(acct.borrow<&AnyResource>(from: capDelegatorStorage) == nil, message: "conflicting resource found in capability delegator storage slot for parentAddress")
            assert(acct.borrow<&AnyResource>(from: childAccountStorage) == nil, message: "conflicting resource found in child account storage slot for parentAddress")

            if acct.borrow<&CapabilityDelegator.Delegator>(from: capDelegatorStorage) == nil {
                let delegator <- CapabilityDelegator.createDelegator()
                acct.save(<-delegator, to: capDelegatorStorage)
            }

            let capDelegatorPublic = PublicPath(identifier: capDelegatorIdentifier)!
            let capDelegatorPrivate = PrivatePath(identifier: capDelegatorIdentifier)!

            acct.link<&CapabilityDelegator.Delegator{CapabilityDelegator.GetterPublic}>(
                capDelegatorPublic,
                target: capDelegatorStorage
            )
            acct.link<&CapabilityDelegator.Delegator{CapabilityDelegator.GetterPublic, CapabilityDelegator.GetterPrivate}>(
                capDelegatorPrivate,
                target: capDelegatorStorage
            )
            let delegator = acct.getCapability<&CapabilityDelegator.Delegator{CapabilityDelegator.GetterPublic, CapabilityDelegator.GetterPrivate}>(
                capDelegatorPrivate
            )
            assert(delegator.check(), message: "failed to setup capability delegator for parent address")

            let borrowableCap = self.borrowAccount().getCapability<&{BorrowableAccount, OwnedAccountPublic, MetadataViews.Resolver}>(
                HybridCustody.OwnedAccountPrivatePath
            )
            let childAcct <- create ChildAccount(borrowableCap, factory, filter, delegator, parentAddress)

            let childAccountPrivatePath = PrivatePath(identifier: identifier)!

            acct.save(<-childAcct, to: childAccountStorage)
            acct.link<&ChildAccount{AccountPrivate, AccountPublic, MetadataViews.Resolver}>(childAccountPrivatePath, target: childAccountStorage)
            
            let delegatorCap = acct.getCapability<&ChildAccount{AccountPrivate, AccountPublic, MetadataViews.Resolver}>(childAccountPrivatePath)
            assert(delegatorCap.check(), message: "Delegator capability check failed")

            acct.inbox.publish(delegatorCap, name: identifier, recipient: parentAddress)
            self.parents[parentAddress] = false

            emit ChildAccountPublished(
                ownedAcctID: self.uuid,
                childAcctID: delegatorCap.borrow()!.uuid,
                capDelegatorID: delegator.borrow()!.uuid,
                factoryID: factory.borrow()!.uuid,
                filterID: filter.borrow()!.uuid,
                filterType: filter.borrow()!.getType(),
                child: self.getAddress(),
                pendingParent: parentAddress
            )
        }

        /// Checks the validity of the encapsulated account Capability
        ///
        pub fun check(): Bool {
            return self.acct.check()
        }

        /// Returns a reference to the encapsulated account object
        ///
        pub fun borrowAccount(): &AuthAccount {
            return self.acct.borrow()!
        }

        /// Returns the addresses of all associated parents pending and active
        ///
        pub fun getParentAddresses(): [Address] {
            return self.parents.keys
        }

        /// Returns whether the given address is a parent of this account
        ///
        pub fun isChildOf(_ addr: Address): Bool {
            return self.parents[addr] != nil
        }

        /// Returns nil if the given address is not a parent, false if the parent has not redeemed the child account
        /// yet, and true if they have
        ///
        pub fun getRedeemedStatus(addr: Address): Bool? {
            return self.parents[addr]
        }

        /// Returns associated parent addresses and their redeemed status
        ///
        pub fun getParentStatuses(): {Address: Bool} {
            return self.parents
        }

        /// Unlinks all paths configured when publishing an account, and destroy's the @ChildAccount resource 
        /// configured for the provided parent address. Once done, the parent will not have any valid capabilities with
        /// which to access the child account.
        ///
        pub fun removeParent(parent: Address): Bool {
            if self.parents[parent] == nil {
                return false
            }
            let identifier = HybridCustody.getChildAccountIdentifier(parent)
            let capDelegatorIdentifier = HybridCustody.getCapabilityDelegatorIdentifier(parent)

            let acct = self.borrowAccount()
            acct.unlink(PrivatePath(identifier: identifier)!)
            acct.unlink(PublicPath(identifier: identifier)!)

            acct.unlink(PrivatePath(identifier: capDelegatorIdentifier)!)
            acct.unlink(PublicPath(identifier: capDelegatorIdentifier)!)

            destroy <- acct.load<@AnyResource>(from: StoragePath(identifier: identifier)!)
            destroy <- acct.load<@AnyResource>(from: StoragePath(identifier: capDelegatorIdentifier)!)

            self.parents.remove(key: parent)
            emit AccountUpdated(id: self.uuid, child: self.acct.address, parent: parent, active: false)

            let parentManager = getAccount(parent).getCapability<&Manager{ManagerPublic}>(HybridCustody.ManagerPublicPath)
            if parentManager.check() {
                parentManager.borrow()?.removeParentCallback(child: self.owner!.address)
            }

            return true
        }

        /// Returns the address of the encapsulated account
        ///
        pub fun getAddress(): Address {
            return self.acct.address
        }

        /// Returns the address of the pending owner if one is assigned. Pending owners are assigned when ownership has
        /// been granted, but has not yet been redeemed.
        ///
        pub fun getPendingOwner(): Address? {
            return self.pendingOwner
        }

        /// Returns the address of the current owner if one is assigned. Current owners are assigned when ownership has
        /// been redeemed.
        ///
        pub fun getOwner(): Address? {
            if !self.currentlyOwned {
                return nil
            }
            return self.acctOwner != nil ? self.acctOwner! : self.owner!.address
        }

        /// This method is used to transfer ownership of the child account to a new address.
        /// Ownership here means that one has unrestricted access on this OwnedAccount resource, giving them full
        /// access to the account.
        ///
        /// **NOTE:** The existence of this method does not imply that it is the only way to receive access to a
        /// OwnedAccount Capability or that only the labeled 'acctOwner' has said access. Rather, this is a convenient
        /// mechanism intended to easily transfer 'root' access on this account to another account and an attempt to
        /// minimize access vectors.
        ///
        pub fun giveOwnership(to: Address) {
            self.seal()
            
            let acct = self.borrowAccount()
            // Unlink existing owner's Capability if owner exists
            if self.acctOwner != nil {
                acct.unlink(
                    PrivatePath(identifier: HybridCustody.getOwnerIdentifier(self.acctOwner!))!
                )
            }
            // Link a Capability for the new owner, retrieve & publish
            let identifier =  HybridCustody.getOwnerIdentifier(to)
            let cap = acct.link<&{OwnedAccountPrivate, OwnedAccountPublic, MetadataViews.Resolver}>(
                    PrivatePath(identifier: identifier)!,
                    target: HybridCustody.OwnedAccountStoragePath
                ) ?? panic("failed to link child account capability")

            acct.inbox.publish(cap, name: identifier, recipient: to)

            self.pendingOwner = to
            self.currentlyOwned = true

            emit OwnershipGranted(ownedAcctID: self.uuid, child: self.acct.address, previousOwner: self.getOwner(), pendingOwner: to)
        }

        /// Revokes all keys on the underlying account
        ///
        pub fun revokeAllKeys() {
            let acct = self.borrowAccount()

            // Revoke all keys
            acct.keys.forEach(fun (key: AccountKey): Bool {
                if !key.isRevoked {
                    acct.keys.revoke(keyIndex: key.keyIndex)
                }
                return true
            })
        }

        /// Cancels all existing AuthAccount capabilities, and creates a new one. The newly created capability will 
        /// then be used by the child account for accessing its AuthAccount going forward.
        ///
        /// This is used when altering ownership of an account, and can also be used as a safeguard for anyone who
        /// assumes ownership of an account to guarantee that the previous owner doesn't maintain admin access to the
        /// account via other AuthAccount Capabilities.
        ///
        pub fun rotateAuthAccount() {
            let acct = self.borrowAccount()

            // Find all active AuthAccount capabilities so they can be removed after we make the new auth account cap
            let pathsToUnlink: [PrivatePath] = []
            acct.forEachPrivate(fun (path: PrivatePath, type: Type): Bool {
                if type.identifier == "Capability<&AuthAccount>" {
                    pathsToUnlink.append(path)
                }
                return true
            })

            // Link a new AuthAccount Capability
            // NOTE: This path cannot be sufficiently randomly generated, an app calling this function could build a
            // capability to this path before it is made, thus maintaining ownership despite making it look like they
            // gave it away. Until capability controllers, this method should not be fully trusted.
            let authAcctPath = "HybridCustodyRelinquished_"
                .concat(HybridCustody.account.address.toString())
                .concat(getCurrentBlock().height.toString())
                .concat(unsafeRandom().toString()) // ensure that the path is different from the previous one
            let acctCap = acct.linkAccount(PrivatePath(identifier: authAcctPath)!)!

            self.acct = acctCap
            let newAcct = self.acct.borrow()!

            // cleanup, remove all previously found paths. We had to do it in this order because we will be unlinking
            // the existing path which will cause a deference issue with the originally borrowed auth account
            for  p in pathsToUnlink {
                newAcct.unlink(p)
            }
        }

        /// Revokes all keys on an account, unlinks all currently active AuthAccount capabilities, then makes a new one
        /// and replaces the @OwnedAccount's underlying AuthAccount Capability with the new one to ensure that all parent
        /// accounts can still operate normally.
        /// Unless this method is executed via the giveOwnership function, this will leave an account **without** an owner.
        ///
        /// USE WITH EXTREME CAUTION.
        ///
        pub fun seal() {
            self.rotateAuthAccount()
            self.revokeAllKeys() // There needs to be a path to giving ownership that doesn't revoke keys   
            emit AccountSealed(id: self.uuid, address: self.acct.address, parents: self.parents.keys)
            self.currentlyOwned = false
        }

        /// Retrieves a reference to the ChildAccount associated with the given parent account if one exists.
        ///
        pub fun borrowChildAccount(parent: Address): &ChildAccount? {
            let identifier = HybridCustody.getChildAccountIdentifier(parent)
            return self.borrowAccount().borrow<&ChildAccount>(from: StoragePath(identifier: identifier)!)
        }

        /// Sets the CapabilityFactory Manager for the specified parent in the associated ChildAccount.
        ///
        pub fun setCapabilityFactoryForParent(
            parent: Address,
            cap: Capability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>
        ) {
            let p = self.borrowChildAccount(parent: parent) ?? panic("could not find parent address")
            p.setCapabilityFactory(cap: cap)
        }

        /// Sets the Filter for the specified parent in the associated ChildAccount.
        ///
        pub fun setCapabilityFilterForParent(parent: Address, cap: Capability<&{CapabilityFilter.Filter}>) {
            let p = self.borrowChildAccount(parent: parent) ?? panic("could not find parent address")
            p.setCapabilityFilter(cap: cap)
        }

        /// Retrieves a reference to the Delegator associated with the given parent account if one exists.
        ///
        pub fun borrowCapabilityDelegatorForParent(parent: Address): &CapabilityDelegator.Delegator? {
            let identifier = HybridCustody.getCapabilityDelegatorIdentifier(parent)
            return self.borrowAccount().borrow<&CapabilityDelegator.Delegator>(from: StoragePath(identifier: identifier)!)
        }

        /// Adds the provided Capability to the Delegator associated with the given parent account.
        ///
        pub fun addCapabilityToDelegator(parent: Address, cap: Capability, isPublic: Bool) {
            let p = self.borrowChildAccount(parent: parent) ?? panic("could not find parent address")
            let delegator = self.borrowCapabilityDelegatorForParent(parent: parent)
                ?? panic("could not borrow capability delegator resource for parent address")
            delegator.addCapability(cap: cap, isPublic: isPublic)
        }

        /// Removes the provided Capability from the Delegator associated with the given parent account.
        ///
        pub fun removeCapabilityFromDelegator(parent: Address, cap: Capability) {
            let p = self.borrowChildAccount(parent: parent) ?? panic("could not find parent address")
            let delegator = self.borrowCapabilityDelegatorForParent(parent: parent)
                ?? panic("could not borrow capability delegator resource for parent address")
            delegator.removeCapability(cap: cap)
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return self.display
            }
            return nil
        }

        /// Sets this OwnedAccount's display to the one provided
        ///
        pub fun setDisplay(_ d: MetadataViews.Display) {
            self.display = d
        }

        init(
            _ acct: Capability<&AuthAccount>
        ) {
            self.acct = acct

            self.parents = {}
            self.pendingOwner = nil
            self.acctOwner = nil
            self.currentlyOwned = true

            self.data = {}
            self.resources <- {}
            self.display = nil
        }

        destroy () {
            destroy <- self.resources
        }
    }

    /// Utility function to get the path identifier for a parent address when interacting with a ChildAccount and its
    /// parents
    ///
    pub fun getChildAccountIdentifier(_ addr: Address): String {
        return "ChildAccount_".concat(addr.toString())
    }

    /// Utility function to get the path identifier for a parent address when interacting with a Delegator and its
    /// parents
    ///
    pub fun getCapabilityDelegatorIdentifier(_ addr: Address): String {
        return "ChildCapabilityDelegator_".concat(addr.toString())
    }

    /// Utility function to get the path identifier for a parent address when interacting with an OwnedAccount and its
    /// owners
    ///
    pub fun getOwnerIdentifier(_ addr: Address): String {
        return "HybridCustodyOwnedAccount_".concat(HybridCustody.account.address.toString()).concat(addr.toString())
    }

    /// Returns an OwnedAccount wrapping the provided AuthAccount Capability.
    ///
    pub fun createOwnedAccount(
        acct: Capability<&AuthAccount>
    ): @OwnedAccount {
        pre {
            acct.check(): "invalid auth account capability"
        }

        let ownedAcct <- create OwnedAccount(acct)
        emit CreatedOwnedAccount(id: ownedAcct.uuid, child: acct.borrow()!.address)
        return <- ownedAcct
    }

    /// Returns a new Manager with the provided Filter as default (if not nil).
    ///
    pub fun createManager(filter: Capability<&{CapabilityFilter.Filter}>?): @Manager {
        pre {
            filter == nil || filter!.check(): "Invalid CapabilityFilter Filter capability provided"
        }
        let manager <- create Manager(filter: filter)
        emit CreatedManager(id: manager.uuid)
        return <- manager
    }

    init() {
        let identifier = "HybridCustodyChild_".concat(self.account.address.toString())
        self.OwnedAccountStoragePath = StoragePath(identifier: identifier)!
        self.OwnedAccountPrivatePath = PrivatePath(identifier: identifier)!
        self.OwnedAccountPublicPath = PublicPath(identifier: identifier)!

        self.LinkedAccountPrivatePath = PrivatePath(identifier: "LinkedAccountPrivatePath_".concat(identifier))!
        self.BorrowableAccountPrivatePath = PrivatePath(identifier: "BorrowableAccountPrivatePath_".concat(identifier))!

        let managerIdentifier = "HybridCustodyManager_".concat(self.account.address.toString())
        self.ManagerStoragePath = StoragePath(identifier: managerIdentifier)!
        self.ManagerPublicPath = PublicPath(identifier: managerIdentifier)!
        self.ManagerPrivatePath = PrivatePath(identifier: managerIdentifier)!
    }
}
