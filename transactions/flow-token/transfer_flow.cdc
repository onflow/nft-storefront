import "FungibleToken"
import "FlowToken"

transaction(recipient: Address, amount: UFix64) {
    
    let providerVault: &FlowToken.Vault
    let receiver: &{FungibleToken.Receiver}
    
    prepare(signer: AuthAccount) {
        self.providerVault = signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)!
        self.receiver = getAccount(recipient).getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            .borrow()
            ?? panic("Could not borrow receiver reference")
    }

    execute {
        self.receiver.deposit(
            from: <-self.providerVault.withdraw(
                amount: amount
            )
        )
    }
}
