package contracts_test

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/onflow/nft-storefront/lib/go/contracts"
)

const addrA = "0A"

func TestNFTStorefrontV2Contract(t *testing.T) {
	contract := contracts.NFTStorefrontV2(addrA, addrA)
	assert.NotNil(t, contract)
}
