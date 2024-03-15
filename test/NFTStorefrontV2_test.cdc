import Test
import "test_helpers.cdc"
import "FungibleToken"
import "NonFungibleToken"


access(all) let buyer = Test.createAccount()
access(all) let seller = Test.createAccount()
access(all) let marketplace = Test.createAccount()
access(all) let exampleNFTAccount = Test.getAccount(0x0000000000000008)
access(all) let exampleTokenAccount = Test.getAccount(0x0000000000000009)
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

    deploy("NFTStorefrontV2", "../contracts/NFTStorefrontV2.cdc")

    var err = Test.deployContract(
        name: "ExampleNFT",
        path: "../contracts/utility/exampleNFT.cdc",
        arguments: [],
    )
    Test.expect(err, Test.beNil())

    err = Test.deployContract(
        name: "ExampleToken",
        path: "../contracts/utility/exampleToken.cdc",
        arguments: [],
    )
    Test.expect(err, Test.beNil())

    // Setup example token
    var code = loadCode("setup_account.cdc", "transactions/example-token")
    var tx = Test.Transaction(
        code: code,
        authorizers: [buyer.address],
        signers: [buyer],
        arguments: [],
    )
    var txResult = Test.executeTransaction(tx)
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

access(all)
fun testSellItem() {
    var code = loadCode("get_ids.cdc", "scripts/example-nft")

    var result = Test.executeScript(code, [seller.address, /public/cadenceExampleNFTCollection])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! [UInt64]).length, 1)
    let nftID = (result.returnValue! as! [UInt64])[0]

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
            [] // Marketplaces address
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

    let code = loadCode("buy_item.cdc", "transactions")
    var tx = Test.Transaction(
        code: code,
        authorizers: [buyer.address],
        signers: [buyer],
        arguments: [
            listingID, // listing resource id
            seller.address, // storefront address
            seller.address // commision recipient
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
    var result = Test.executeScript(code, [seller.address, /public/cadenceExampleNFTCollection])
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
            [] // Marketplaces address
        ],
    )
    var txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())

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

    // Check that the listing still exists as a ghost listing
    let getListingIDCode = loadCode("read_storefront_ids.cdc", "scripts")
    
    result = Test.executeScript(getListingIDCode, [seller.address])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! [UInt64]).length, 1)
    let ghostedListingID = (result.returnValue! as! [UInt64])[0]

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

    var result = Test.executeScript(code, [seller.address, /public/cadenceExampleNFTCollection])
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
            0.1 // Marketplaces address
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

    var result = Test.executeScript(getIDsCode, [seller.address, /public/cadenceExampleNFTCollection])
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
            [seller.address] // set the buyer as the marketplace sale cut receiver
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

    var result = Test.executeScript(code, [seller.address, /public/cadenceExampleNFTCollection])
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
            0.1 // Marketplaces address
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
}
