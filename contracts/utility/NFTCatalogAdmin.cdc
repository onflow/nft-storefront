import NFTCatalog from "./NFTCatalog.cdc"

// NFTCatalogAdmin
//
// An admin contract that defines an    admin resource and
// a proxy resource to receive a capability that lets you make changes to the NFT Catalog
// and manage proposals

pub contract NFTCatalogAdmin {

    // AddProposalAccepted
    // Emitted when a proposal to add a new catalog item has been approved by an admin
    pub event AddProposalAccepted(
        proposer: Address,
        collectionIdentifier : String,
        contractName : String,
        contractAddress : Address,
        displayName : String
    )

    // UpdateProposalAccepted
    // Emitted when a proposal to update a catalog item has been approved by an admin
    pub event UpdateProposalAccepted(
        proposer: Address,
        collectionIdentifier : String,
        contractName : String,
        contractAddress : Address,
        displayName : String
    )

    // ProposalRejected
    // Emitted when a proposal to add or update a catalog item has been rejected.
    pub event ProposalRejected(
        proposer: Address,
        collectionIdentifier : String,
        contractName : String,
        contractAddress : Address,
        displayName : String
    )

    pub let AdminPrivatePath: PrivatePath
    pub let AdminStoragePath: StoragePath

    pub let AdminProxyPublicPath: PublicPath
    pub let AdminProxyStoragePath: StoragePath

    // Admin
    // Admin resource to manage NFT Catalog
    pub resource Admin {

        pub fun addCatalogEntry(collectionIdentifier: String, metadata : NFTCatalog.NFTCatalogMetadata) {
            NFTCatalog.addCatalogEntry(collectionIdentifier: collectionIdentifier, metadata : metadata)
        }

        pub fun updateCatalogEntry(collectionIdentifier : String , metadata : NFTCatalog.NFTCatalogMetadata) {
            NFTCatalog.updateCatalogEntry(collectionIdentifier: collectionIdentifier, metadata : metadata)
        }

        pub fun removeCatalogEntry(collectionIdentifier : String) {
            NFTCatalog.removeCatalogEntry(collectionIdentifier : collectionIdentifier)
        }

        pub fun approveCatalogProposal(proposalID : UInt64) {
            pre {
                NFTCatalog.getCatalogProposalEntry(proposalID : proposalID) != nil : "Invalid Proposal ID"
                NFTCatalog.getCatalogProposalEntry(proposalID : proposalID)!.status == "IN_REVIEW" : "Invalid Proposal"
            }
            let catalogProposalEntry = NFTCatalog.getCatalogProposalEntry(proposalID : proposalID)!
            let newCatalogProposalEntry = NFTCatalog.NFTCatalogProposal(collectionIdentifier : catalogProposalEntry.collectionIdentifier, metadata : catalogProposalEntry.metadata, message : catalogProposalEntry.message, status: "APPROVED", proposer: catalogProposalEntry.proposer)
            NFTCatalog.updateCatalogProposal(proposalID : proposalID, proposalMetadata : newCatalogProposalEntry)

            if NFTCatalog.getCatalogEntry(collectionIdentifier : NFTCatalog.getCatalogProposalEntry(proposalID : proposalID)!.collectionIdentifier) == nil {
                NFTCatalog.addCatalogEntry(collectionIdentifier: newCatalogProposalEntry.collectionIdentifier, metadata : newCatalogProposalEntry.metadata)
                emit AddProposalAccepted(
                    proposer: newCatalogProposalEntry.proposer,
                    collectionIdentifier : newCatalogProposalEntry.collectionIdentifier,
                    contractName : newCatalogProposalEntry.metadata.contractName,
                    contractAddress : newCatalogProposalEntry.metadata.contractAddress,
                    displayName : newCatalogProposalEntry.metadata.collectionDisplay.name
                )
            } else {
                NFTCatalog.updateCatalogEntry(collectionIdentifier: newCatalogProposalEntry.collectionIdentifier, metadata: newCatalogProposalEntry.metadata)
                emit UpdateProposalAccepted(
                    proposer: newCatalogProposalEntry.proposer,
                    collectionIdentifier : newCatalogProposalEntry.collectionIdentifier,
                    contractName : newCatalogProposalEntry.metadata.contractName,
                    contractAddress : newCatalogProposalEntry.metadata.contractAddress,
                    displayName : newCatalogProposalEntry.metadata.collectionDisplay.name
                )
            }
        }

        pub fun rejectCatalogProposal(proposalID : UInt64) {
            pre {
                NFTCatalog.getCatalogProposalEntry(proposalID : proposalID) != nil : "Invalid Proposal ID"
                NFTCatalog.getCatalogProposalEntry(proposalID : proposalID)!.status == "IN_REVIEW" : "Invalid Proposal"
            }
            let catalogProposalEntry = NFTCatalog.getCatalogProposalEntry(proposalID : proposalID)!
            let newCatalogProposalEntry = NFTCatalog.NFTCatalogProposal(collectionIdentifier : catalogProposalEntry.collectionIdentifier, metadata : catalogProposalEntry.metadata, message : catalogProposalEntry.message, status: "REJECTED", proposer: catalogProposalEntry.proposer)
            NFTCatalog.updateCatalogProposal(proposalID : proposalID, proposalMetadata : newCatalogProposalEntry)
            emit ProposalRejected(
                proposer: newCatalogProposalEntry.proposer,
                collectionIdentifier : newCatalogProposalEntry.collectionIdentifier,
                contractName : newCatalogProposalEntry.metadata.contractName,
                contractAddress : newCatalogProposalEntry.metadata.contractAddress,
                displayName : newCatalogProposalEntry.metadata.collectionDisplay.name
            )
        }

        pub fun removeCatalogProposal(proposalID : UInt64) {
            pre {
                NFTCatalog.getCatalogProposalEntry(proposalID : proposalID) != nil : "Invalid Proposal ID"
            }
            NFTCatalog.removeCatalogProposal(proposalID : proposalID)
        }

        init () {}

    }

    // AdminProxy
    // A proxy resource that can store
    // a capability to admin controls
    pub resource interface IAdminProxy {
        pub fun addCapability(capability : Capability<&Admin>)
        pub fun hasCapability() : Bool
    }

    pub resource AdminProxy : IAdminProxy {
        
        access(self) var capability : Capability<&Admin>?

        pub fun addCapability(capability : Capability<&Admin>) {
            pre {
                capability.check() : "Invalid Admin Capability"
                self.capability == nil : "Admin Proxy already set"
            }
            self.capability = capability
        }

        pub fun getCapability() : Capability<&Admin>? {
            return self.capability
        }

        pub fun hasCapability() : Bool {
            return self.capability != nil
        }

        init() {
            self.capability = nil
        }
        
    }

    pub fun createAdminProxy() : @AdminProxy {
        return <- create AdminProxy()
    }

    init () {
        self.AdminProxyPublicPath = /public/nftCatalogAdminProxy
        self.AdminProxyStoragePath = /storage/nftCatalogAdminProxy
        
        self.AdminPrivatePath = /private/nftCatalogAdmin
        self.AdminStoragePath = /storage/nftCatalogAdmin

        let admin    <- create Admin()

        self.account.save(<-admin, to: self.AdminStoragePath)
        self.account.link<&Admin>(self.AdminPrivatePath, target: self.AdminStoragePath)
    }
}