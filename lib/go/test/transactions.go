package test

import (
	"fmt"
	"testing"

	"github.com/onflow/cadence"
	emulator "github.com/onflow/flow-emulator"
	fttemplates "github.com/onflow/flow-ft/lib/go/templates"
	"github.com/onflow/flow-go-sdk"
	sdk "github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	nfttemplates "github.com/onflow/flow-nft/lib/go/templates"
)

func setupExampleNFTCollection(
	t *testing.T,
	b *emulator.Blockchain,
	userAddress flow.Address,
	userSigner crypto.Signer,
	nftAddress, exampleNFTAddress, metadataAddress flow.Address,
) {
	script := nfttemplates.GenerateSetupAccountScript(
		nftAddress,
		exampleNFTAddress,
		metadataAddress,
	)

	tx := flow.NewTransaction().
		SetScript(script).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(userAddress)

	serviceSigner, _ := b.ServiceKey().Signer()

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, userAddress},
		[]crypto.Signer{serviceSigner, userSigner},
		false,
	)
}

func mintExampleNFT(
	t *testing.T,
	b *emulator.Blockchain,
	receiverAddress flow.Address,
	nftAddress, exampleNFTAddress, metadataAddress flow.Address,
	exampleNFTSigner crypto.Signer,
) {
	script := nfttemplates.GenerateMintNFTScript(nftAddress, exampleNFTAddress, metadataAddress, flow.HexToAddress(emulatorFTAddress))

	tx := flow.NewTransaction().
		SetScript(script).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(exampleNFTAddress)

	cuts := []cadence.Value{}
	royaltyDescriptions := []cadence.Value{}
	royaltyBeneficiaries := []cadence.Value{}

	tx.AddArgument(cadence.NewAddress(receiverAddress))
	tx.AddArgument(cadenceString("StorefrontNFT"))
	tx.AddArgument(cadenceString("here for money!"))
	tx.AddArgument(cadenceString("xx.png"))
	tx.AddArgument(cadence.NewArray(cuts))
	tx.AddArgument(cadence.NewArray(royaltyDescriptions))
	tx.AddArgument(cadence.NewArray(royaltyBeneficiaries))

	serviceSigner, _ := b.ServiceKey().Signer()

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, exampleNFTAddress},
		[]crypto.Signer{serviceSigner, exampleNFTSigner},
		false,
	)
}

func fundAccount(
	t *testing.T,
	b *emulator.Blockchain,
	receiverAddress flow.Address,
	amount string,
) {
	script := fttemplates.GenerateMintTokensScript(
		ftAddress,
		flowTokenAddress,
		flowTokenName,
	)

	tx := flow.NewTransaction().
		SetScript(script).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(b.ServiceKey().Address)

	tx.AddArgument(cadence.NewAddress(receiverAddress))
	tx.AddArgument(cadenceUFix64(amount))

	serviceSigner, _ := b.ServiceKey().Signer()

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address},
		[]crypto.Signer{serviceSigner},
		false,
	)
}

func sellItem(
	t *testing.T,
	b *emulator.Blockchain,
	contracts Contracts,
	userAddress sdk.Address,
	userSigner crypto.Signer,
	tokenID uint64,
	price string,
	shouldFail bool,
) uint64 {
	tx := flow.NewTransaction().
		SetScript(nftStorefrontGenerateSellItemScript(contracts)).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(userAddress)

	tx.AddArgument(cadence.NewUInt64(tokenID))
	tx.AddArgument(cadenceUFix64(price))

	serviceSigner, _ := b.ServiceKey().Signer()

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, userAddress},
		[]crypto.Signer{serviceSigner, userSigner},
		shouldFail,
	)

	// Get the most recently created ListingAvailable event resource ID
	eventType := fmt.Sprintf("A.%s.NFTStorefront.ListingAvailable", contracts.NFTStorefrontAddress.Hex())
	listingResourceID := uint64(0)

	var i uint64
	i = 0
	for i < 1000 {
		results, _ := b.GetEventsByHeight(i, eventType)
		for _, event := range results {
			if event.Type == eventType {
				listingResourceID = event.Value.Fields[1].(cadence.UInt64).ToGoValue().(uint64)
			}
		}
		i = i + 1
	}

	return listingResourceID
}

func buyItem(
	b *emulator.Blockchain,
	t *testing.T,
	contracts Contracts,
	userAddress sdk.Address,
	userSigner crypto.Signer,
	marketCollectionAddress sdk.Address,
	offerResourceID uint64,
	shouldFail bool,
) {
	tx := flow.NewTransaction().
		SetScript(nftStorefrontGenerateBuyItemScript(contracts)).
		SetGasLimit(200).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(userAddress)

	tx.AddArgument(cadence.NewUInt64(offerResourceID))
	tx.AddArgument(cadence.NewAddress(marketCollectionAddress))

	serviceSigner, _ := b.ServiceKey().Signer()

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, userAddress},
		[]crypto.Signer{serviceSigner, userSigner},
		shouldFail,
	)
}

func removeItem(
	b *emulator.Blockchain,
	t *testing.T,
	contracts Contracts,
	userAddress sdk.Address,
	userSigner crypto.Signer,
	offerResourceID uint64,
	shouldFail bool,
) {
	tx := flow.NewTransaction().
		SetScript(nftStorefrontGenerateRemoveItemScript(contracts)).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(userAddress)

	tx.AddArgument(cadence.NewUInt64(offerResourceID))

	serviceSigner, _ := b.ServiceKey().Signer()

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, userAddress},
		[]crypto.Signer{serviceSigner, userSigner},
		shouldFail,
	)
}
