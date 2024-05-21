import "NFTCatalog"

// NFTCatalogAdmin
//
// An admin contract that defines an    admin resource and
// a proxy resource to receive a capability that lets you make changes to the NFT Catalog
// and manage proposals

access(all) contract NFTCatalogAdmin {

    access(all) entitlement CatalogActions

    // AddProposalAccepted
    // Emitted when a proposal to add a new catalog item has been approved by an admin
    access(all) event AddProposalAccepted(
        proposer: Address,
        collectionIdentifier : String,
        contractName : String,
        contractAddress : Address,
        displayName : String
    )

    // UpdateProposalAccepted
    // Emitted when a proposal to update a catalog item has been approved by an admin
    access(all) event UpdateProposalAccepted(
        proposer: Address,
        collectionIdentifier : String,
        contractName : String,
        contractAddress : Address,
        displayName : String
    )

    // ProposalRejected
    // Emitted when a proposal to add or update a catalog item has been rejected.
    access(all) event ProposalRejected(
        proposer: Address,
        collectionIdentifier : String,
        contractName : String,
        contractAddress : Address,
        displayName : String
    )

    access(all) let AdminPrivatePath: PrivatePath
    access(all) let AdminStoragePath: StoragePath

    access(all) let AdminProxyPublicPath: PublicPath
    access(all) let AdminProxyStoragePath: StoragePath

    // Admin
    // Admin resource to manage NFT Catalog
    access(all) resource Admin {

        access(CatalogActions) fun addCatalogEntry(collectionIdentifier: String, metadata : NFTCatalog.NFTCatalogMetadata) {
            NFTCatalog.addCatalogEntry(collectionIdentifier: collectionIdentifier, metadata : metadata)
        }

        access(CatalogActions) fun updateCatalogEntry(collectionIdentifier : String , metadata : NFTCatalog.NFTCatalogMetadata) {
            NFTCatalog.updateCatalogEntry(collectionIdentifier: collectionIdentifier, metadata : metadata)
        }

        access(CatalogActions) fun removeCatalogEntry(collectionIdentifier : String) {
            NFTCatalog.removeCatalogEntry(collectionIdentifier : collectionIdentifier)
        }

        access(CatalogActions) fun removeCatalogEntryUnsafe(collectionIdentifier : String, nftTypeIdentifier: String) {
            NFTCatalog.removeCatalogEntryUnsafe(collectionIdentifier : collectionIdentifier, nftTypeIdentifier: nftTypeIdentifier)
        }

        access(CatalogActions) fun approveCatalogProposal(proposalID : UInt64) {
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

        access(CatalogActions) fun rejectCatalogProposal(proposalID : UInt64) {
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

        access(CatalogActions) fun removeCatalogProposal(proposalID : UInt64) {
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
    access(all) resource interface IAdminProxy {
        access(all) fun addCapability(capability : Capability<auth(CatalogActions) &Admin>)
        access(all) fun hasCapability() : Bool
    }

    access(all) resource AdminProxy : IAdminProxy {
        
        access(self) var capability : Capability<auth(CatalogActions) &Admin>?

        access(all) fun addCapability(capability : Capability<auth(CatalogActions) &Admin>) {
            pre {
                capability.check() : "Invalid Admin Capability"
                self.capability == nil : "Admin Proxy already set"
            }
            self.capability = capability
        }

        access(all) view fun getCapability() : Capability<auth(CatalogActions) &Admin>? {
            return self.capability
        }

        access(all) view fun hasCapability() : Bool {
            return self.capability != nil
        }

        init() {
            self.capability = nil
        }
        
    }

    access(all) fun createAdminProxy() : @AdminProxy {
        return <- create AdminProxy()
    }

    init () {
        self.AdminProxyPublicPath = /public/nftCatalogAdminProxy
        self.AdminProxyStoragePath = /storage/nftCatalogAdminProxy
        
        self.AdminPrivatePath = /private/nftCatalogAdmin
        self.AdminStoragePath = /storage/nftCatalogAdmin

        let admin    <- create Admin()

        self.account.storage.save(<-admin, to: self.AdminStoragePath)
    }
}