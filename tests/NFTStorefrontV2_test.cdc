import Test
import "test_helpers.cdc"
import "FungibleToken"
import "NonFungibleToken"
import "NFTStorefrontV2"
import "ExampleNFT"
import "ExampleToken"
import "FlowToken"

access(all) let buyer = Test.createAccount()
access(all) let seller = Test.createAccount()
access(all) let marketplace = Test.createAccount()
access(all) let storefrontAccount = Test.getAccount(0x0000000000000007)
access(all) let exampleNFTAccount = Test.getAccount(0x0000000000000008)
access(all) let exampleTokenAccount = Test.getAccount(0x0000000000000009)

access(all) let nftTypeIdentifier = "A.0000000000000008.ExampleNFT.NFT"
access(all) let ftTypeIdentifier = "A.0000000000000009.ExampleToken.Vault"
access(all) let flowTokenTypeIdentifier = "A.0000000000000003.FlowToken.Vault"

access(all) var nftCount = 1

access(all)
fun mintNFTToSeller() {
    // Mint some example NFTs
    let code = loadCode("mint_nft.cdc", "transactions/example-nft")
    let tx = Test.Transaction(
        code: code,
        authorizers: [exampleNFTAccount.address],
        signers: [exampleNFTAccount],
        arguments: [seller.address, "NFT".concat(nftCount.toString()), "nft descrip", "https://test", [], [], []]
    )
    nftCount = nftCount + 1
    let txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())
}

access(all)
fun setup() {
    let serviceAccount = Test.serviceAccount()

    // TODO: Remove this section once MetadataViews is updated on the emulator
    // with the resolveViewfromIdentifier function. 
    let metadataViewsCode = loadCode("MVbytes", "tests/transactions")
    var tx = Test.Transaction(
        code: loadCode("update_contract.cdc", "tests/transactions"),
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: ["MetadataViews", metadataViewsCode],
    )

    var txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())
    // TODO: End of section to remove

    var err = Test.deployContract(
        name: "NFTStorefrontV2",
        path: "../contracts/NFTStorefrontV2.cdc",
        arguments: [],
    )
    Test.expect(err, Test.beNil())

    err = Test.deployContract(
        name: "ExampleNFT",
        path: "../contracts/utility/ExampleNFT.cdc",
        arguments: [],
    )
    Test.expect(err, Test.beNil())

    err = Test.deployContract(
        name: "ExampleToken",
        path: "../contracts/utility/ExampleToken.cdc",
        arguments: [],
    )
    Test.expect(err, Test.beNil())

    // Setup example token
    var code = loadCode("setup_account.cdc", "transactions/example-token")
    tx = Test.Transaction(
        code: code,
        authorizers: [buyer.address],
        signers: [buyer],
        arguments: [],
    )
    txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())
    
    tx = Test.Transaction(
        code: code,
        authorizers: [seller.address],
        signers: [seller],
        arguments: [],
    )
    txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())

    tx = Test.Transaction(
        code: code,
        authorizers: [marketplace.address],
        signers: [marketplace],
        arguments: []
    )
    txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())

    // Setup example nft
    code = loadCode("setup_account.cdc", "transactions/example-nft")
    tx = Test.Transaction(
        code: code,
        authorizers: [buyer.address],
        signers: [buyer],
        arguments: [],
    )
    txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())

    tx = Test.Transaction(
        code: code,
        authorizers: [seller.address],
        signers: [seller],
        arguments: [],
    )
    txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())

    // Mint some example tokens
    code = loadCode("mint_tokens.cdc", "transactions/example-token")
    tx = Test.Transaction(
        code: code,
        authorizers: [exampleTokenAccount.address],
        signers: [exampleTokenAccount],
        arguments: [buyer.address, 200.0],
    )
    txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())

    mintNFTToSeller()

    let typ = Type<NonFungibleToken.Deposited>()
    let events = Test.eventsOfType(typ)
    Test.assertEqual(1, events.length)
}

access(all) var listingIDPurchased: UInt64 = 0

access(all)
fun testSetupAccount() {
    let code = loadCode("setup_account.cdc", "transactions")
    let tx = Test.Transaction(
        code: code,
        authorizers: [seller.address],
        signers: [seller],
        arguments: [],
    )
    let txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())
}

access(all) var listedNFTID: UInt64 = 0

access(all)
fun testSellItem() {
    var code = loadCode("get_ids.cdc", "scripts/example-nft")

    var result = Test.executeScript(code, [seller.address, /public/exampleNFTCollection])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! [UInt64]).length, 1)
    let nftID = (result.returnValue! as! [UInt64])[0]
    listedNFTID = nftID

    code = loadCode("sell_item.cdc", "transactions")
    var tx = Test.Transaction(
        code: code,
        authorizers: [seller.address],
        signers: [seller],
        arguments: [
            nftID, // sale item id
            10.0, // sale item price
            "Custom", // custom id
            0.1, // commission amount
            UInt64(2025908543), // 10 years in the future
            [], // Marketplaces address
            nftTypeIdentifier, // nft type
            ftTypeIdentifier // ft type
        ],
    )
    var txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())
}

access(all)
fun testBuyItem() {
    let getBalanceCode = loadCode("get_balance.cdc", "scripts/example-token")

    var result = Test.executeScript(getBalanceCode, [seller.address])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! UFix64), 0.0)

    let getListingIDCode = loadCode("read_storefront_ids.cdc", "scripts")
    result = Test.executeScript(getListingIDCode, [seller.address])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! [UInt64]).length, 1)
    let listingID = (result.returnValue! as! [UInt64])[0]!
    listingIDPurchased = listingID

    // Test that script executions run as expected
    let allowedCommissionReceivers = scriptExecutor("read_allowed_commission_receivers.cdc", [seller.address, listingID])
    let listingDetails = scriptExecutor("read_listing_details.cdc", [seller.address, listingID])
    Test.assert(listingDetails != nil, message: "Received invalid result from reading listing details")
    let duplicateListingIDs = scriptExecutor(
        "read_duplicate_listing_ids.cdc",
        [seller.address, listedNFTID, listingID, nftTypeIdentifier]
    )
    Test.assertEqual((duplicateListingIDs as! [UInt64]?)!.length, 0)

    let code = loadCode("buy_item.cdc", "transactions")
    var tx = Test.Transaction(
        code: code,
        authorizers: [buyer.address],
        signers: [buyer],
        arguments: [
            listingID, // listing resource id
            seller.address, // storefront address
            seller.address, // commision recipient
            nftTypeIdentifier // nft type
        ],
    )
    let txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())

    result = Test.executeScript(getBalanceCode, [seller.address])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! UFix64), 10.0)
}


access(all)
fun testCleanupPurchasedListings() {
    let cleanupCode = loadCode("cleanup_purchased_listings.cdc", "transactions")
    
    // The listing ID should exist in the seller acount still
    // even though that it has been purchased at this point
    let getListingIDCode = loadCode("read_storefront_ids.cdc", "scripts")

    // We can clean up the unused listing id from a different
    // signer account.
    let tx = Test.Transaction(
        code: cleanupCode,
        authorizers: [buyer.address],
        signers: [buyer],
        arguments: [seller.address, listingIDPurchased]
    )
    let txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())

    // The listing ID should not exist anymore in the seller account
    let result = Test.executeScript(getListingIDCode, [seller.address])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! [UInt64]).length, 0)
}

access(all)
fun testCleanupGhostListings() {
    // Mint a new NFT
    mintNFTToSeller()

    // Get the newly minted NFT's ID
    var code = loadCode("get_ids.cdc", "scripts/example-nft")
    var result = Test.executeScript(code, [seller.address, /public/exampleNFTCollection])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! [UInt64]).length, 1)
    let nftID = (result.returnValue! as! [UInt64])[0]

    // Create a new listing for that ID.
    code = loadCode("sell_item.cdc", "transactions")
    var tx = Test.Transaction(
        code: code,
        authorizers: [seller.address],
        signers: [seller],
        arguments: [
            nftID, // sale item id
            10.0, // sale item price
            "Custom", // custom id
            0.1, // commission amount
            UInt64(2025908543), // 10 years in the future
            [], // Marketplaces address
            nftTypeIdentifier, // nft type
            ftTypeIdentifier // ft type
        ],
    )
    var txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())

    let getListingIDCode = loadCode("read_storefront_ids.cdc", "scripts")
    result = Test.executeScript(getListingIDCode, [seller.address])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! [UInt64]).length, 1)
    let ghostedListingID = (result.returnValue! as! [UInt64])[0]

    // Check if the listing is ghosted.
    var listingIsAvailable = scriptExecutor("has_listing_become_ghosted.cdc", [seller.address, ghostedListingID])
    Test.assertEqual(listingIsAvailable!, true)

    // Burn the NFT
    let burnNFTCode = loadCode("burn_nft.cdc", "transactions/example-nft")
    tx = Test.Transaction(
        code: burnNFTCode,
        authorizers: [seller.address],
        signers: [seller],
        arguments: [
            nftID
        ]
    )
    txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())

    // Check if the listing is ghosted.
    listingIsAvailable = scriptExecutor("has_listing_become_ghosted.cdc", [seller.address, ghostedListingID])
    Test.assertEqual(listingIsAvailable!, false)

    let allGhostListingIDs = scriptExecutor("read_all_unique_ghost_listings.cdc", [seller.address])
    Test.assertEqual((allGhostListingIDs as! [UInt64]?)!.length, 1)

    // Try cleaning up the ghost listing
    let cleanupGhostListingsCode = loadCode("cleanup_ghost_listing.cdc", "transactions")
    tx = Test.Transaction(
        code: cleanupGhostListingsCode,
        authorizers: [buyer.address],
        signers: [buyer],
        arguments: [ghostedListingID, seller.address]
    )
    txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())
    
    // Confirm the listing was removed.
    result = Test.executeScript(getListingIDCode, [seller.address])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! [UInt64]).length, 0)
}


access(all)
fun testSellItemWithMarketplaceCut() {
    mintNFTToSeller()

    var code = loadCode("get_ids.cdc", "scripts/example-nft")

    var result = Test.executeScript(code, [seller.address, /public/exampleNFTCollection])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! [UInt64]).length, 1)
    let nftID = (result.returnValue! as! [UInt64])[0]

    code = loadCode("sell_item_with_marketplace_cut.cdc", "transactions")
    var tx = Test.Transaction(
        code: code,
        authorizers: [seller.address],
        signers: [seller],
        arguments: [
            nftID, // sale item id
            10.0, // sale item price
            "Custom1", // custom id
            UInt64(2025908543), // 10 years in the future
            seller.address, // set the buyer as the marketplace sale cut receiver
            0.1, // Marketplaces address
            nftTypeIdentifier, // nft type
            flowTokenTypeIdentifier // ft type
        ],
    )
    let txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())

    // The listing ID should exist in the seller acount
    let getListingIDCode = loadCode("read_storefront_ids.cdc", "scripts")
    result = Test.executeScript(getListingIDCode, [seller.address])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! [UInt64]).length, 1)
}

access(all)
fun testSellItemAndReplaceCurrentListing() {
    var getIDsCode = loadCode("get_ids.cdc", "scripts/example-nft")
    let getListingIDCode = loadCode("read_storefront_ids.cdc", "scripts")

    var result = Test.executeScript(getIDsCode, [seller.address, /public/exampleNFTCollection])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! [UInt64]).length, 1)
    let nftID = (result.returnValue! as! [UInt64])[0]

    // The listing ID should exist in the seller acount
    result = Test.executeScript(getListingIDCode, [seller.address])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! [UInt64]).length, 1)
    let originalListingID = (result.returnValue! as! [UInt64])[0]!

    let code = loadCode("sell_item_and_replace_current_listing.cdc", "transactions")
    let timestamp: UInt64 = UInt64(getCurrentBlock().timestamp) + 1000
    var tx = Test.Transaction(
        code: code,
        authorizers: [seller.address],
        signers: [seller],
        arguments: [
            nftID, // sale item id
            10.0, // sale item price
            "Custom1", // custom id
            0.1, // commission amount
            timestamp, // way in the past (testing expired listing next)
            [seller.address], // set the buyer as the marketplace sale cut receiver
            nftTypeIdentifier, // nft type
            ftTypeIdentifier // ft type
        ],
    )
    let txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())

    // The listing ID should still be different from before, but
    // replaced the previous one.
    result = Test.executeScript(getListingIDCode, [seller.address])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! [UInt64]).length, 1)
    let listingIDAfterRelist = (result.returnValue! as! [UInt64])[0]!
    Test.assert(originalListingID != listingIDAfterRelist, message: "Listing ID should be different from the original after relisting")
}

access(all)
fun testCleanupExpiredListings() {
    let cleanupExpiredListingsCode = loadCode("cleanup_expired_listings.cdc", "transactions")
    let getListingIDCode = loadCode("read_storefront_ids.cdc", "scripts")

    // Attempt to cleanup expired listings, and no change should occur because listings aren't expired.
    var result = Test.executeScript(getListingIDCode, [seller.address])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! [UInt64]).length, 1)

    let tx = Test.Transaction(
        code: cleanupExpiredListingsCode,
        authorizers: [buyer.address],
        signers: [buyer],
        arguments: [
            UInt64(0), // fromIndex
            UInt64(0), // toIndex
            seller.address // storefrontAddress
        ]
    )
    var txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())

    // Ensure that the listing was not removed because it is not expired
    result = Test.executeScript(getListingIDCode, [seller.address])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! [UInt64]).length, 1)

    // Move 20000 ms into the future, because the current expiration was set to the current timestamp + 1000
    // This should make the currently existing listing expired
    Test.moveTime(by: 2000.0) 

    // Attempt to cleanup expired listings again, and amount of listings should go to 0 now
    txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())

    // Ensure that the listing was removed because it should be expired now
    result = Test.executeScript(getListingIDCode, [seller.address])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! [UInt64]).length, 0)

}

access(all)
fun testRemoveItem() {

    // list the new NFT for sale
    var code = loadCode("get_ids.cdc", "scripts/example-nft")

    var result = Test.executeScript(code, [seller.address, /public/exampleNFTCollection])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! [UInt64]).length, 1)
    let nftID = (result.returnValue! as! [UInt64])[0]

    code = loadCode("sell_item_with_marketplace_cut.cdc", "transactions")
    var tx = Test.Transaction(
        code: code,
        authorizers: [seller.address],
        signers: [seller],
        arguments: [
            nftID, // sale item id
            10.0, // sale item price
            "Custom1", // custom id
            UInt64(2025908543), // 10 years in the future
            seller.address, // set the buyer as the marketplace sale cut receiver
            0.1, // Marketplaces address
            nftTypeIdentifier, // nft type
            flowTokenTypeIdentifier // ft type
        ],
    )
    var txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())

    let getListingIDCode = loadCode("read_storefront_ids.cdc", "scripts")
    result = Test.executeScript(getListingIDCode, [seller.address])
    let listingID = (result.returnValue! as! [UInt64])[0]

    // Remove the listing
    let removeItemCode = loadCode("remove_item.cdc", "transactions")
    tx = Test.Transaction(
        code: removeItemCode,
        authorizers: [seller.address],
        signers: [seller],
        arguments: [listingID]
    )
    txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())

    // Test that the proper events were emitted
    var typ = Type<NFTStorefrontV2.ListingCompleted>()
    var events = Test.eventsOfType(typ)
    Test.assertEqual(5, events.length)

    let completedEvent = events[4] as! NFTStorefrontV2.ListingCompleted
    Test.assertEqual(listingID, completedEvent.listingResourceID)
    Test.assertEqual(false, completedEvent.purchased)
    Test.assertEqual(Type<@ExampleNFT.NFT>(), completedEvent.nftType)
    Test.assertEqual(nftID, completedEvent.nftID)
    Test.assertEqual(Type<@FlowToken.Vault>(), completedEvent.salePaymentVaultType)
    Test.assertEqual(UFix64(10.0), completedEvent.salePrice)
    Test.assertEqual("Custom1", completedEvent.customID!)
    Test.assertEqual(UFix64(0.0), completedEvent.commissionAmount)
    Test.assertEqual(nil, completedEvent.commissionReceiver)
    Test.assertEqual(UInt64(2025908543), completedEvent.expiry)
}

access(all)
fun testSellMaliciousListing() {

    var err = Test.deployContract(
        name: "MaliciousStorefrontV2",
        path: "../contracts/utility/test/MaliciousStorefrontV2.cdc",
        arguments: [],
    )
    Test.expect(err, Test.beNil())

    var code = loadCode("../tests/transactions/create_malicious_listing_v2.cdc", "transactions")
    var tx = Test.Transaction(
        code: code,
        authorizers: [exampleNFTAccount.address],
        signers: [exampleNFTAccount],
        arguments: [],
    )
    var txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())

    var typ = Type<NFTStorefrontV2.ListingAvailable>()
    var events = Test.eventsOfType(typ)

    let listingEvent = events[events.length-1] as! NFTStorefrontV2.ListingAvailable
    let listingID = listingEvent.listingResourceID

    code = loadCode("buy_item.cdc", "transactions")
    tx = Test.Transaction(
        code: code,
        authorizers: [buyer.address],
        signers: [buyer],
        arguments: [
            listingID, // listing resource id
            exampleNFTAccount.address, // storefront address
            exampleNFTAccount.address, // commision recipient
            nftTypeIdentifier // nft type
        ],
    )
    txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beFailed())
    Test.assertError(
        txResult,
        errorMessage: "Cannot borrow a non-NFTStorefrontV2.Listing!"
    )
}