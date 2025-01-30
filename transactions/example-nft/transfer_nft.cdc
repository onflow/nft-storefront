/// This transaction is for transferring and NFT from
/// one account to another

import "NonFungibleToken"
import "ExampleNFT"

transaction(recipient: Address, withdrawID: UInt64) {

    /// Reference to the withdrawer's collection
    let withdrawRef: auth(NonFungibleToken.Withdraw) &ExampleNFT.Collection

    /// Reference of the collection to deposit the NFT to
    let depositRef: &{NonFungibleToken.Receiver}

    prepare(signer: auth(BorrowValue) &Account) {
        // borrow a reference to the signer's NFT collection
        self.withdrawRef = signer.storage.borrow<auth(NonFungibleToken.Withdraw) &ExampleNFT.Collection>(
                from: ExampleNFT.CollectionStoragePath)
            ?? panic("The signer does not store a "
                        .concat(contractName)
                        .concat(".Collection object at the path ")
                        .concat(collectionData.storagePath.toString())
                        .concat("The signer must initialize their account with this collection first!"))

        // get the recipients public account object
        let recipient = getAccount(recipient)

        // borrow a public reference to the receivers collection
        self.depositRef = recipient.capabilities.get<&{NonFungibleToken.Receiver}>(
                ExampleNFT.CollectionPublicPath
            ).borrow()
                ?? panic("The recipient does not have a NonFungibleToken Receiver at "
                    .concat(ExampleNFT.CollectionPublicPath.toString())
                    .concat(" that is capable of receiving an NFT.")
                    .concat("The recipient must initialize their account with this collection and receiver first!"))

    }

    execute {

        // withdraw the NFT from the owner's collection
        let nft <- self.withdrawRef.withdraw(withdrawID: withdrawID)

        // Deposit the NFT in the recipient's collection
        self.depositRef.deposit(token: <-nft)
    }

    post {
        !self.withdrawRef.getIDs().contains(withdrawID): "Original owner should not have the NFT anymore"
        self.depositRef.getIDs().contains(withdrawID): "The reciever should now own the NFT"
    }
}
