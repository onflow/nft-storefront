.PHONY: test
test:
	$(MAKE) test -C lib/go

.PHONY: ci
ci:
	$(MAKE) ci -C lib/go

.PHONY: update-mainnet
update-mainnet:
	$(MAKE) flow accounts update-contract NFTStorefrontV2 ./contracts/NFTStorefrontV2.cdc --signer mainnet-account --network mainnet -f ./flow.mainnet.json

.PHONY: update-testnet
update-testnet:
	$(MAKE) flow accounts update-contract NFTStorefrontV2 ./contracts/NFTStorefrontV2.cdc --signer testnet-account --network testnet -f ./flow.testnet.json