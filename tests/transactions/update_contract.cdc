transaction(name: String, code: String) {
	prepare(signer: auth(Contracts) &Account) {
		signer.contracts.update(name: name, code: code.decodeHex())
	}
}