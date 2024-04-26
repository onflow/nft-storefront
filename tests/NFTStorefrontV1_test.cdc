import Test
import "test_helpers.cdc"
import "FungibleToken"
import "NonFungibleToken"

access(all) let buyer = Test.createAccount()
access(all) let seller = Test.createAccount()
access(all) let marketplace = Test.createAccount()
access(all) let storefrontAccount = Test.getAccount(0x0000000000000006)
access(all) let exampleNFTAccount = Test.getAccount(0x0000000000000008)
access(all) let exampleTokenAccount = Test.getAccount(0x0000000000000009)
access(all) var nftCount = 1

access(all)
fun setup() {
    let serviceAccount = Test.serviceAccount()

    var err = Test.deployContract(
        name: "NFTStorefront",
        path: "../contracts/NFTStorefront.cdc",
        arguments: [],
    )
    Test.expect(err, Test.beNil())

    err = Test.deployContract(
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
fun testSetupAccount() {
    let code = loadCode("setup_account.cdc", "transactions-v1")
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

    code = loadCode("sell_item.cdc", "transactions-v1")
    var tx = Test.Transaction(
        code: code,
        authorizers: [seller.address],
        signers: [seller],
        arguments: [
            nftID, // sale item id
            10.0 // sale item price
        ]
    )
    var txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())
}

access(all)
fun testBorrowNFT() {
    let getListingIDCode = loadCode("read_storefront_ids.cdc", "transactions-v1/scripts-v1")
    var result = Test.executeScript(getListingIDCode, [seller.address])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! [UInt64]).length, 1)
    let listingID = (result.returnValue! as! [UInt64])[0]!

    var code = loadCode("verify_listed_nft_exists.cdc", "transactions-v1/scripts-v1")
    result = Test.executeScript(code, [seller.address, listingID])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual(result.returnValue! as! Bool, true)
}

access(all)
fun testCleanupItem() {
    let getListingIDCode = loadCode("read_storefront_ids.cdc", "transactions-v1/scripts-v1")
    var result = Test.executeScript(getListingIDCode, [seller.address])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! [UInt64]).length, 1)
    let listingID = (result.returnValue! as! [UInt64])[0]!
    
    var code = loadCode("cleanup_item.cdc", "transactions-v1")
    var tx = Test.Transaction(
        code: code,
        authorizers: [buyer.address],
        signers: [buyer],
        arguments: [
            listingID,
            seller.address
        ]
    )
    let txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beFailed()) // can not cleanup an unpurchased listing.
}

access(all)
fun testBuyItem() {
    let getBalanceCode = loadCode("get_balance.cdc", "scripts/example-token")

    var result = Test.executeScript(getBalanceCode, [seller.address])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! UFix64), 0.0)

    let getListingIDCode = loadCode("read_storefront_ids.cdc", "transactions-v1/scripts-v1")
    result = Test.executeScript(getListingIDCode, [seller.address])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! [UInt64]).length, 1)
    let listingID = (result.returnValue! as! [UInt64])[0]!

    // Test that script executions run as expected
    let readListingDetailsCode = loadCode("read_storefront_ids.cdc", "transactions-v1/scripts-v1")
    let listingDetails = Test.executeScript(readListingDetailsCode, [seller.address, listingID])
    Test.assert(listingDetails != nil, message: "Received invalid result from reading listing details")

    let code = loadCode("buy_item.cdc", "transactions-v1")
    var tx = Test.Transaction(
        code: code,
        authorizers: [buyer.address],
        signers: [buyer],
        arguments: [
            listingID, // listing resource id
            seller.address // storefront address
        ]
    )
    let txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())

    result = Test.executeScript(getBalanceCode, [seller.address])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! UFix64), 10.0)

    result = Test.executeScript(getListingIDCode, [seller.address])
    Test.expect(result, Test.beSucceeded())
    Test.assertEqual((result.returnValue! as! [UInt64]).length, 0)
}

access(all)
fun testRemoveItem() {
    mintNFTToSeller()

    var code = loadCode("get_ids.cdc", "scripts/example-nft")
    var result = Test.executeScript(code, [seller.address, /public/exampleNFTCollection])
    let nftID = (result.returnValue! as! [UInt64])[0]
    listedNFTID = nftID

    code = loadCode("sell_item.cdc", "transactions-v1")
    var tx = Test.Transaction(
        code: code,
        authorizers: [seller.address],
        signers: [seller],
        arguments: [
            nftID, // sale item id
            10.0 // sale item price
        ]
    )
    var txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())

    let getListingIDCode = loadCode("read_storefront_ids.cdc", "transactions-v1/scripts-v1")
    result = Test.executeScript(getListingIDCode, [seller.address])
    let listingID = (result.returnValue! as! [UInt64])[0]!

    code = loadCode("remove_item.cdc", "transactions-v1")
    tx = Test.Transaction(
        code: code,
        authorizers: [seller.address],
        signers: [seller],
        arguments: [
            listingID
        ]
    )
    txResult = Test.executeTransaction(tx)
    Test.expect(txResult, Test.beSucceeded())

    result = Test.executeScript(getListingIDCode, [seller.address])
    Test.assertEqual((result.returnValue! as! [UInt64]).length, 0)
}



