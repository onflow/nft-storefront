package contracts_test

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/onflow/nft-storefront/lib/go/contracts"
)

const (
	addressA          = "0x0A"
	addressB          = "0x0B"
	addressStorefront = "0x0EEE"
)

func TestNFTStorefrontContract(t *testing.T) {
	contract := contracts.NFTStorefront(addrA, addrB)
	assert.NotNil(t, contract)
	assert.Contains(t, string(contract), addrA)
	assert.Contains(t, string(contract), addrB)
}

func TestRemoveItemTransaction(t *testing.T) {
	contract := contracts.ReadWithAddresses(contracts.RemoveItemTransaction, map[string]string{
		"NFTStorefront": addrStorefront,
	})
	assert.NotNil(t, contract)
	assert.Contains(t, string(contract), addrStorefront)
}

func TestGetListingDetailsScript(t *testing.T) {
	contract := contracts.ReadWithAddresses(contracts.GetListingDetailsScript, map[string]string{
		"NFTStorefront": addrStorefront,
	})
	assert.NotNil(t, contract)
	assert.Contains(t, string(contract), addrStorefront)
}
