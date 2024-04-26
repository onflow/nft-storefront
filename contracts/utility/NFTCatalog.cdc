import "MetadataViews"

// NFTCatalog
//
// A general purpose NFT registry for Flow NonFungibleTokens.
//
// Each catalog entry stores data about the NFT including
// its collection identifier, nft type, storage and public paths, etc.
//
// To make an addition to the catalog you can propose an NFT and provide its metadata.
// An Admin can approve a proposal which would add the NFT to the catalog

access(all) contract NFTCatalog {
    // EntryAdded
    // An NFT collection has been added to the catalog
    access(all) event EntryAdded(
        collectionIdentifier : String,
        contractName : String,
        contractAddress : Address,
        nftType : Type,
        storagePath: StoragePath,
        publicPath: PublicPath,
        publicLinkedType : Type,
        displayName : String,
        description: String,
        externalURL : String
    )

    // EntryUpdated
    // An NFT Collection has been updated in the catalog
    access(all) event EntryUpdated(
        collectionIdentifier : String,
        contractName : String,
        contractAddress : Address,
        nftType : Type,
        storagePath: StoragePath,
        publicPath: PublicPath,
        publicLinkedType : Type,
        displayName : String,
        description: String,
        externalURL : String
    )

    // EntryRemoved
    // An NFT Collection has been removed from the catalog
    access(all) event EntryRemoved(collectionIdentifier : String, nftType: Type)

    // ProposalEntryAdded
    // A new proposal to make an addtion to the catalog has been made
    access(all) event ProposalEntryAdded(proposalID : UInt64, collectionIdentifier : String, message: String, status: String, proposer : Address)

    // ProposalEntryUpdated
    // A proposal has been updated
    access(all) event ProposalEntryUpdated(proposalID : UInt64, collectionIdentifier : String, message: String, status: String, proposer : Address)

    // ProposalEntryRemoved
    // A proposal has been removed from storage
    access(all) event ProposalEntryRemoved(proposalID : UInt64)

    access(all) let ProposalManagerStoragePath: StoragePath

    access(all) let ProposalManagerPublicPath: PublicPath

    access(self) let catalog: {String : NFTCatalog.NFTCatalogMetadata} // { collectionIdentifier -> Metadata }
    access(self) let catalogTypeData: {String : {String : Bool}} // Additional view to go from { NFT Type Identifier -> {Collection Identifier : Bool } }

    access(self) let catalogProposals : {UInt64 : NFTCatalogProposal} // { ProposalID : Metadata }

    access(self) var totalProposals : UInt64

    // NFTCatalogProposalManager
    // Used to authenticate proposals made to the catalog

    access(all) entitlement ProposalActionOwner

    access(all) resource NFTCatalogProposalManager {
            access(self) var currentProposalEntry: String?

            access(all) fun getCurrentProposalEntry(): String? {
                return self.currentProposalEntry
            }

            access(ProposalActionOwner) fun setCurrentProposalEntry(identifier: String?) {
                self.currentProposalEntry = identifier
            }

            init () {
                self.currentProposalEntry = nil
            }
    }


    access(all) resource Snapshot {
        access(all) var catalogSnapshot: {String : NFTCatalogMetadata}
        access(all) var shouldUseSnapshot: Bool

        access(all) fun setPartialSnapshot(_ snapshotKey: String, _ snapshotEntry: NFTCatalogMetadata) {
            self.catalogSnapshot[snapshotKey] = snapshotEntry
        }

        access(all) fun setShouldUseSnapshot(_ shouldUseSnapshot: Bool) {
            self.shouldUseSnapshot = shouldUseSnapshot
        }

        access(all) view fun getCatalogSnapshot(): {String : NFTCatalogMetadata} {
            return self.catalogSnapshot
        }

        init() {
            self.shouldUseSnapshot = false
            self.catalogSnapshot = {}
        }
    }

    access(all) fun createEmptySnapshot(): @Snapshot {
        return <- create Snapshot()
    }

    // NFTCollectionData
    // Represents information about an NFT collection resource
    // Note: Not suing the struct from Metadata standard due to
    // inability to store functions
    access(all) struct NFTCollectionData {

        access(all) let storagePath : StoragePath
        access(all) let publicPath : PublicPath
        access(all) let publicLinkedType: Type

        init(
            storagePath : StoragePath,
            publicPath : PublicPath,
            publicLinkedType : Type,
        ) {
            self.storagePath = storagePath
            self.publicPath = publicPath
            self.publicLinkedType = publicLinkedType
        }
    }

    // NFTCatalogMetadata
    // Represents data about an NFT
    access(all) struct NFTCatalogMetadata {
        access(all) let contractName : String
        access(all) let contractAddress : Address
        access(all) let nftType: Type
        access(all) let collectionData: NFTCollectionData
        access(all) let collectionDisplay: MetadataViews.NFTCollectionDisplay

        init (contractName : String, contractAddress : Address, nftType: Type, collectionData : NFTCollectionData, collectionDisplay : MetadataViews.NFTCollectionDisplay) {
            self.contractName = contractName
            self.contractAddress = contractAddress
            self.nftType = nftType
            self.collectionData = collectionData
            self.collectionDisplay = collectionDisplay
        }
    }

    // NFTCatalogProposal
    // Represents a proposal to the catalog
    // Includes data about an NFT
    access(all) struct NFTCatalogProposal {
        access(all) let collectionIdentifier : String
        access(all) let metadata : NFTCatalogMetadata
        access(all) let message : String
        access(all) let status : String
        access(all) let proposer : Address
        access(all) let createdTime : UFix64

        init(collectionIdentifier : String, metadata : NFTCatalogMetadata, message : String, status : String, proposer : Address) {
            self.collectionIdentifier = collectionIdentifier
            self.metadata = metadata
            self.message = message
            self.status = status
            self.proposer = proposer
            self.createdTime = getCurrentBlock().timestamp
        }
    }

    /*
        DEPRECATED
        If obtaining all elements from the catalog is essential, please
        use the getCatalogKeys and forEachCatalogKey methods instead.
     */
    access(all) view fun getCatalog() : {String : NFTCatalogMetadata} {
        let snapshot = self.account.storage.borrow<&NFTCatalog.Snapshot>(from: /storage/CatalogSnapshot)
        if snapshot != nil {
            let snapshot = snapshot!
            if snapshot.shouldUseSnapshot {
                return snapshot.getCatalogSnapshot()
            } else {
                return self.catalog
            }
        } else {
            return self.catalog
        }
    }

    access(all) view fun getCatalogKeys(): [String] {
        return self.catalog.keys
    }

    access(all) fun forEachCatalogKey(_ function: fun (String): Bool) {
        self.catalog.forEachKey(function)
    }

    access(all) view fun getCatalogEntry(collectionIdentifier : String) : NFTCatalogMetadata? {
        return self.catalog[collectionIdentifier]
    }

    access(all) view fun getCollectionsForType(nftTypeIdentifier: String) : {String : Bool}? {
        return self.catalogTypeData[nftTypeIdentifier]
    }

    access(all) view fun getCatalogTypeData() : {String : {String : Bool}} {
        return self.catalogTypeData
    }

    // Propose an NFT collection to the catalog
    // @param collectionIdentifier: The unique name assinged to this nft collection
    // @param metadata: The Metadata for the NFT collection that will be stored in the catalog
    // @param message: A message to the catalog owners
    // @param proposer: Who is making the proposition(the address needs to be verified)
    access(all) fun proposeNFTMetadata(collectionIdentifier : String, metadata : NFTCatalogMetadata, message : String, proposer : Address) : UInt64 {
        let proposerManagerRef = getAccount(proposer).capabilities.borrow<&NFTCatalogProposalManager>(
            NFTCatalog.ProposalManagerPublicPath
        ) ?? panic("Proposer needs to set up a manager")

        assert(proposerManagerRef.getCurrentProposalEntry()! == collectionIdentifier, message: "Expected proposal entry does not match entry for the proposer")

        let catalogProposal = NFTCatalogProposal(collectionIdentifier : collectionIdentifier, metadata : metadata, message : message, status: "IN_REVIEW", proposer: proposer)
        self.totalProposals = self.totalProposals + 1
        self.catalogProposals[self.totalProposals] = catalogProposal

        emit ProposalEntryAdded(proposalID : self.totalProposals, collectionIdentifier : collectionIdentifier, message: catalogProposal.message, status: catalogProposal.status, proposer: catalogProposal.proposer)
        return self.totalProposals
    }

    // Withdraw a proposal from the catalog
    // @param proposalID: The ID of proposal you want to withdraw
    access(all) fun withdrawNFTProposal(proposalID : UInt64) {
        pre {
            self.catalogProposals[proposalID] != nil : "Invalid Proposal ID"
        }
        let proposal = self.catalogProposals[proposalID]!
        let proposer = proposal.proposer

        let proposerManagerRef = getAccount(proposer).capabilities.borrow<&NFTCatalogProposalManager>(
            NFTCatalog.ProposalManagerPublicPath
        ) ?? panic("Proposer needs to set up a manager")

        assert(proposerManagerRef.getCurrentProposalEntry()! == proposal.collectionIdentifier, message: "Expected proposal entry does not match entry for the proposer")

        self.removeCatalogProposal(proposalID : proposalID)
    }

    access(all) view fun getCatalogProposals() : {UInt64 : NFTCatalogProposal} {
        return self.catalogProposals
    }

    access(all) view fun getCatalogProposalEntry(proposalID : UInt64) : NFTCatalogProposal? {
        return self.catalogProposals[proposalID]
    }

    access(all) view fun getCatalogProposalKeys() : [UInt64] {
        return self.catalogProposals.keys
    }

    access(all) fun forEachCatalogProposalKey(_ function: fun (UInt64): Bool) {
        self.catalogProposals.forEachKey(function)
    }

    access(all) fun createNFTCatalogProposalManager(): @NFTCatalogProposalManager {
        return <-create NFTCatalogProposalManager()
    }

    access(account) fun addCatalogEntry(collectionIdentifier : String, metadata: NFTCatalogMetadata) {
        pre {
            self.catalog[collectionIdentifier] == nil : "The nft name has already been added to the catalog"
        }

        self.addCatalogTypeEntry(collectionIdentifier : collectionIdentifier , metadata: metadata)

        self.catalog[collectionIdentifier] = metadata

        emit EntryAdded(
            collectionIdentifier : collectionIdentifier,
            contractName : metadata.contractName,
            contractAddress : metadata.contractAddress,
            nftType: metadata.nftType,
            storagePath: metadata.collectionData.storagePath,
            publicPath: metadata.collectionData.publicPath,
            publicLinkedType : metadata.collectionData.publicLinkedType,
            displayName : metadata.collectionDisplay.name,
            description: metadata.collectionDisplay.description,
            externalURL : metadata.collectionDisplay.externalURL.url
        )
    }

    access(account) fun updateCatalogEntry(collectionIdentifier : String , metadata: NFTCatalogMetadata) {
        pre {
            self.catalog[collectionIdentifier] != nil : "Invalid collection identifier"
        }
        // remove previous nft type entry
        self.removeCatalogTypeEntry(collectionIdentifier : collectionIdentifier , metadata: metadata)
        // add updated nft type entry
        self.addCatalogTypeEntry(collectionIdentifier : collectionIdentifier , metadata: metadata)

        self.catalog[collectionIdentifier] = metadata

        let nftType = metadata.nftType

        emit EntryUpdated(
            collectionIdentifier : collectionIdentifier,
            contractName : metadata.contractName,
            contractAddress : metadata.contractAddress,
            nftType: metadata.nftType,
            storagePath: metadata.collectionData.storagePath,
            publicPath: metadata.collectionData.publicPath,
            publicLinkedType : metadata.collectionData.publicLinkedType,
            displayName : metadata.collectionDisplay.name,
            description: metadata.collectionDisplay.description,
            externalURL : metadata.collectionDisplay.externalURL.url
        )
    }

    access(account) fun removeCatalogEntry(collectionIdentifier : String) {
        pre {
            self.catalog[collectionIdentifier] != nil : "Invalid collection identifier"
        }

        let removedType = self.removeCatalogTypeEntry(collectionIdentifier : collectionIdentifier , metadata: self.catalog[collectionIdentifier]!)
        self.catalog.remove(key: collectionIdentifier)

        emit EntryRemoved(collectionIdentifier : collectionIdentifier, nftType: removedType)
    }

    // This function is not preferred, and was used for the following issue:
    // https://github.com/onflow/cadence/issues/2649
    // If a contract's type is no longer resolvable in cadence and crashing,
    // this function can be used to remove it from the catalog.
    access(account) fun removeCatalogEntryUnsafe(collectionIdentifier: String, nftTypeIdentifier: String) {
        // Remove the catalog entry
        self.catalog.remove(key: collectionIdentifier)

        // Remove the type entry
        if (self.catalogTypeData[nftTypeIdentifier]!.keys.length == 1) {
            self.catalogTypeData.remove(key: nftTypeIdentifier)
        } else {
            self.catalogTypeData[nftTypeIdentifier]!.remove(key: collectionIdentifier)
        }
    }

    access(account) fun updateCatalogProposal(proposalID: UInt64, proposalMetadata : NFTCatalogProposal) {
        self.catalogProposals[proposalID] = proposalMetadata

        emit ProposalEntryUpdated(proposalID : proposalID, collectionIdentifier : proposalMetadata.collectionIdentifier, message: proposalMetadata.message, status: proposalMetadata.status, proposer: proposalMetadata.proposer)
    }

    access(account) fun removeCatalogProposal(proposalID : UInt64) {
        self.catalogProposals.remove(key : proposalID)

        emit ProposalEntryRemoved(proposalID : proposalID)
    }

    access(contract) fun addCatalogTypeEntry(collectionIdentifier : String , metadata: NFTCatalogMetadata) {
        if self.catalogTypeData[metadata.nftType.identifier] != nil {
            let typeData : {String : Bool} = self.catalogTypeData[metadata.nftType.identifier]!
            assert(self.catalogTypeData[metadata.nftType.identifier]![collectionIdentifier] == nil, message : "The nft name has already been added to the catalog")
            typeData[collectionIdentifier] = true
            self.catalogTypeData[metadata.nftType.identifier] = typeData
        } else {
            let typeData : {String : Bool} = {}
            typeData[collectionIdentifier] = true
            self.catalogTypeData[metadata.nftType.identifier] = typeData
        }
    }

    access(contract) fun removeCatalogTypeEntry(collectionIdentifier : String , metadata: NFTCatalogMetadata): Type {
        let prevMetadata = self.catalog[collectionIdentifier]!
        let prevCollectionsForType = self.catalogTypeData[prevMetadata.nftType.identifier]!
        prevCollectionsForType.remove(key : collectionIdentifier)
        if prevCollectionsForType.length == 0 {
            self.catalogTypeData.remove(key: prevMetadata.nftType.identifier)
        } else {
            self.catalogTypeData[prevMetadata.nftType.identifier] = prevCollectionsForType
        }

        return metadata.nftType
    }

    init() {
        self.ProposalManagerStoragePath = /storage/nftCatalogProposalManager
        self.ProposalManagerPublicPath = /public/nftCatalogProposalManager

        self.totalProposals = 0
        self.catalog = {}
        self.catalogTypeData = {}

        self.catalogProposals = {}
    }

}
 