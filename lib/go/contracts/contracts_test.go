package contracts

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

func Test_StorefrontContract(t *testing.T) {
	code := NFTStorefront(1, "0x1", "0x2")
	codeV2 := NFTStorefront(2, "0x1", "0x2")

	assert.NotNil(t, code)
	assert.True(t, strings.Contains(string(code), `import FungibleToken from 0x1`))
	assert.True(t, strings.Contains(string(code), `import NonFungibleToken from 0x2`))
	assert.True(t, strings.Contains(string(codeV2), `import FungibleToken from 0x1`))
	assert.True(t, strings.Contains(string(codeV2), `import NonFungibleToken from 0x2`))
}
