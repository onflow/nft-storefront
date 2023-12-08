/// CapabilityDelegator is a contract used to share Capabiltities to other accounts. It is used by the
/// HybridCustody contract to allow more flexible sharing of Capabilities when an app wants to share things
/// that aren't the NFT-standard interface types.
/// 
/// Inside of CapabilityDelegator is a resource called `Delegator` which maintains a mapping of public and private
/// Capabilities. They cannot and should not be mixed. A public `Delegator` is able to be borrowed by anyone, whereas a
/// private `Delegator` can only be borrowed from the child account when you have access to the full `ChildAccount` 
/// resource.
///
pub contract CapabilityDelegator {

    /* --- Canonical Paths --- */
    //
    pub let StoragePath: StoragePath
    pub let PrivatePath: PrivatePath
    pub let PublicPath: PublicPath
    
    /* --- Events --- */
    //
    pub event DelegatorCreated(id: UInt64)
    pub event DelegatorUpdated(id: UInt64, capabilityType: Type, isPublic: Bool, active: Bool)

    /// Private interface for Capability retrieval
    ///
    pub resource interface GetterPrivate {
        pub fun getPrivateCapability(_ type: Type): Capability? {
            post {
                result == nil || type.isSubtype(of: result.getType()): "incorrect returned capability type"
            }
        }
        pub fun findFirstPrivateType(_ type: Type): Type?
        pub fun getAllPrivate(): [Capability]
    }

    /// Exposes public Capability retrieval
    ///
    pub resource interface GetterPublic {
        pub fun getPublicCapability(_ type: Type): Capability? {
            post {
                result == nil || type.isSubtype(of: result.getType()): "incorrect returned capability type "
            }
        }

        pub fun findFirstPublicType(_ type: Type): Type?
        pub fun getAllPublic(): [Capability]
    }

    /// This Delegator is used to store Capabilities, partitioned by public and private access with corresponding
    /// GetterPublic and GetterPrivate conformances.AccountCapabilityController
    ///
    pub resource Delegator: GetterPublic, GetterPrivate {
        access(self) let privateCapabilities: {Type: Capability}
        access(self) let publicCapabilities: {Type: Capability}

        // ------ Begin Getter methods
        //
        /// Returns the public Capability of the given Type if it exists
        ///
        pub fun getPublicCapability(_ type: Type): Capability? {
            return self.publicCapabilities[type]
        }

        /// Returns the private Capability of the given Type if it exists
        ///
        ///
        /// @param type: Type of the Capability to retrieve
        /// @return Capability of the given Type if it exists, nil otherwise
        ///
        pub fun getPrivateCapability(_ type: Type): Capability? {
            return self.privateCapabilities[type]
        }

        /// Returns all public Capabilities
        ///
        /// @return List of all public Capabilities
        ///
        pub fun getAllPublic(): [Capability] {
            return self.publicCapabilities.values
        }

        /// Returns all private Capabilities
        ///
        /// @return List of all private Capabilities
        ///
        pub fun getAllPrivate(): [Capability] {
            return self.privateCapabilities.values
        }

        /// Returns the first public Type that is a subtype of the given Type
        ///
        /// @param type: Type to check for subtypes
        /// @return First public Type that is a subtype of the given Type, nil otherwise
        ///
        pub fun findFirstPublicType(_ type: Type): Type? {
            for t in self.publicCapabilities.keys {
                if t.isSubtype(of: type) {
                    return t
                }
            }

            return nil
        }

        /// Returns the first private Type that is a subtype of the given Type
        ///
        /// @param type: Type to check for subtypes
        /// @return First private Type that is a subtype of the given Type, nil otherwise
        ///
        pub fun findFirstPrivateType(_ type: Type): Type? {
            for t in self.privateCapabilities.keys {
                if t.isSubtype(of: type) {
                    return t
                }
            }

            return nil
        }
        // ------- End Getter methods

        /// Adds a Capability to the Delegator
        ///
        /// @param cap: Capability to add
        /// @param isPublic: Whether the Capability should be public or private
        ///
        pub fun addCapability(cap: Capability, isPublic: Bool) {
            pre {
                cap.check<&AnyResource>(): "Invalid Capability provided"
            }
            if isPublic {
                self.publicCapabilities.insert(key: cap.getType(), cap)
            } else {
                self.privateCapabilities.insert(key: cap.getType(), cap)
            }
            emit DelegatorUpdated(id: self.uuid, capabilityType: cap.getType(), isPublic: isPublic, active: true)
        }

        /// Removes a Capability from the Delegator
        ///
        /// @param cap: Capability to remove
        ///
        pub fun removeCapability(cap: Capability) {
            if let removedPublic = self.publicCapabilities.remove(key: cap.getType()) {
                emit DelegatorUpdated(id: self.uuid, capabilityType: cap.getType(), isPublic: true, active: false)
            }
            
            if let removedPrivate = self.privateCapabilities.remove(key: cap.getType()) {
                emit DelegatorUpdated(id: self.uuid, capabilityType: cap.getType(), isPublic: false, active: false)
            }
        }

        init() {
            self.privateCapabilities = {}
            self.publicCapabilities = {}
        }
    }

    /// Creates a new Delegator and returns it
    /// 
    /// @return Newly created Delegator
    ///
    pub fun createDelegator(): @Delegator {
        let delegator <- create Delegator()
        emit DelegatorCreated(id: delegator.uuid)
        return <- delegator
    }
    
    init() {
        let identifier = "CapabilityDelegator_".concat(self.account.address.toString())
        self.StoragePath = StoragePath(identifier: identifier)!
        self.PrivatePath = PrivatePath(identifier: identifier)!
        self.PublicPath = PublicPath(identifier: identifier)!
    }
}
 