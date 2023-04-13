import path from "path";
import {
    emulator,
    init,
    getAccountAddress,
    deployContractByName,
    sendTransaction,
    shallPass,
    executeScript,
    shallRevert,
    getFlowBalance,
    mintFlow,
} from "flow-js-testing";
import fs from "fs";

const setup_nft_catalog_tx = fs.readFileSync(
    path.resolve(__dirname, "../../mocks/transactions/setup_nft_catalog.cdc"),
    { encoding: "utf8", flag: "r" }
);
const setup_nft_catalog_admin_proxy_tx = fs.readFileSync(
    path.resolve(__dirname, "../../mocks/transactions/setup_catalog_admin_proxy.cdc"),
    { encoding: "utf8", flag: "r" }
);
const setup_nft_account_tx = fs.readFileSync(
    path.resolve(__dirname, "../../mocks/transactions/setup_nft_account.cdc"),
    { encoding: "utf8", flag: "r" }
);
const mint_nft_tx = fs.readFileSync(
    path.resolve(__dirname, "../../mocks/transactions/mint_nft.cdc"),
    { encoding: "utf8", flag: "r" }
);
const get_owned_nft_ids_script = fs.readFileSync(
    path.resolve(__dirname, "../../mocks/scripts/get_owned_nft_ids.cdc"),
    { encoding: "utf8", flag: "r" }
);
const setup_account_to_receive_royalty_tx = fs.readFileSync(
    path.resolve(
        __dirname,
        "../../mocks/transactions/setup_account_to_receive_royalty.cdc"
    ),
    { encoding: "utf8", flag: "r" }
);

function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

async function deployContract(param) {
    const [result, error] = await deployContractByName(param);
    if (error != null) {
        console.log(`Error in deployment - ${error}`);
        emulator.stop();
        process.exit(1);
    }
}

async function getCurrentTimestamp() {
    const code = `
    pub fun main(): UInt64 {
      return UInt64(getCurrentBlock().timestamp)
    }
  `;
    return await executeScript({ code });
}

async function getListingKeys(account) {
    const read_storefront_ids_script = fs.readFileSync(
        path.resolve(__dirname, "../../../../scripts/read_storefront_ids.cdc"),
        { encoding: "utf8", flag: "r" }
    );
    const [scriptResult, sError] = await executeScript({
        code: read_storefront_ids_script,
        args: [account],
    });
    return scriptResult;
}

async function getDuplicateListingIDs(account, nftId, listingId) {
    const read_duplicate_listing_ids_script = fs.readFileSync(
        path.resolve(
            __dirname,
            "../../../../scripts/read_duplicate_listing_ids.cdc"
        ),
        { encoding: "utf8", flag: "r" }
    );
    const [scriptResult, sError] = await executeScript({
        code: read_duplicate_listing_ids_script,
        args: [account, nftId, listingId],
    });
    return scriptResult;
}

async function getListingDetails(account, resourceId) {
    const read_listing_details_script = fs.readFileSync(
        path.resolve(__dirname, "../../../../scripts/read_listing_details.cdc"),
        { encoding: "utf8", flag: "r" }
    );
    const [scriptResult, sError] = await executeScript({
        code: read_listing_details_script,
        args: [account, resourceId],
    });
    return scriptResult;
}

async function getAllowedCommissionReceivers(account, resourceId) {
    const read_allowed_commission_receivers = fs.readFileSync(
        path.resolve(
            __dirname,
            "../../../../scripts/read_allowed_commission_receivers.cdc"
        ),
        { encoding: "utf8", flag: "r" }
    );
    const [scriptResult, sError] = await executeScript({
        code: read_allowed_commission_receivers,
        args: [account, resourceId],
    });
    return scriptResult;
}

async function getRoyaltyBalance(account) {
    const code = `import FlowToken from 0x0ae53cb6e3f42a79
  import MetadataViews from "../../../../contracts/utility/MetadataViews.cdc"
  import FungibleToken from "../../../../contracts/utility/FungibleToken.cdc"

  pub fun main(target: Address): UFix64 {
    let cap = getAccount(target).getCapability<&{FungibleToken.Balance}>(MetadataViews.getRoyaltyReceiverPublicPath())
    let vaultRef = cap.borrow() ?? panic("Could not borrow Balance reference to the Vault")
    return vaultRef.balance
  }
  `;
    const [balance, sError] = await executeScript({
        code: code,
        args: [account],
    });
    return balance;
}

async function doesFlowTokenReceiverCapabilityExists(account) {
    const check_capability_script = `import FlowToken from 0x0ae53cb6e3f42a79
    import FungibleToken from "../../../../contracts/utility/FungibleToken.cdc"

    pub fun main(target: Address): Bool {
      let cap = getAccount(target).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
      return cap.check()
    }
    `;
    const [isCapabilityExists, sError] = await executeScript({
        code: check_capability_script,
        args: [account],
    });
    return isCapabilityExists;
}

describe("NFTStorefrontV2", () => {
    let exampleNFTContractAddress;
    let nftStorefrontContractAddress;
    let fungibleTokenContractAddress;
    let metadataViewsContractAddress;
    let catalogContractAddress;
    let nonFungibleTokenContractAddress;
    let viewResolver;
    let seller_1;
    let seller_2;
    let buyer_1;
    let buyer_2;
    let artist_1;
    let artist_2;
    let marketplace_1;
    let marketplace_2;

    beforeEach(async () => {
        const basePath = path.resolve(__dirname, "../../../../");
        // You can specify different port to parallelize execution of describe blocks
        const port = 8080;
        // Setting logging flag to true will pipe emulator output to console
        const logging = false;

        await init(basePath, { port });
        await emulator.start(port, { logging });

        // Deployed at address which has the alias - nftStoreFrontV2
        nftStorefrontContractAddress = await getAccountAddress(
            "nftStoreFrontV2"
        );
        // Deployed at address which has the alias - fungibleToken
        fungibleTokenContractAddress = await getAccountAddress("fungibleToken");
        // Deployed at address which has the alias - metadataViews
        metadataViewsContractAddress = await getAccountAddress("metadataViews");
        // Deployed at address which has the alias - viewResolver
        viewResolver = await getAccountAddress("viewResolver");
        // Deployed at address which has the alias - nftCatalog
        catalogContractAddress = await getAccountAddress("nftCatalog");
        // Deployed at address which has the alias - nonFungibleToken
        nonFungibleTokenContractAddress = await getAccountAddress(
            "nonFungibleToken"
        );
        // Deployed at address which has the alias - exampleNFT
        exampleNFTContractAddress = await getAccountAddress("exampleNFT");

        await deployContract({
            to: fungibleTokenContractAddress,
            name: "utility/FungibleToken",
        });
        await deployContract({
            to: nonFungibleTokenContractAddress,
            name: "utility/NonFungibleToken",
        });
        await deployContract({ 
            to: viewResolver,
            name: "utility/ViewResolver"
        });
        await deployContract({
            to: metadataViewsContractAddress,
            name: "utility/MetadataViews",
        });
        await deployContract({
            to: catalogContractAddress,
            name: "utility/NFTCatalog",
        });
        await deployContract({
            to: catalogContractAddress,
            name: "utility/NFTCatalogAdmin",
        });
        await deployContract({
            to: nftStorefrontContractAddress,
            name: "NFTStorefrontV2",
        });
        await deployContract({
            to: exampleNFTContractAddress,
            name: "utility/ExampleNFT",
        });

        seller_1 = await getAccountAddress("seller_1");
        seller_2 = await getAccountAddress("seller_2");
        buyer_1 = await getAccountAddress("buyer_1");
        buyer_2 = await getAccountAddress("buyer_2");
        artist_1 = await getAccountAddress("artist_1");
        artist_2 = await getAccountAddress("artist_2");
        marketplace_1 = await getAccountAddress("marketplace_1");
        marketplace_2 = await getAccountAddress("marketplace_2");

        await shallPass(
            sendTransaction({
                code: setup_nft_catalog_admin_proxy_tx,
                args: [],
                signers: [catalogContractAddress],
            })
        );
        
        await shallPass(
            sendTransaction({
                code: setup_nft_catalog_tx,
                args: [],
                signers: [catalogContractAddress],
            })
        );
    });

    // Stop emulator, so it could be restarted
    afterEach(async () => {
        return emulator.stop();
    });

    test("should able to install the storefront manager in the account", async () => {
        await shallPass(
            sendTransaction({
                name: "setup_account",
                args: [],
                signers: [seller_1],
            })
        );
    });

    test("should successfully list the sale item", async () => {
        // step 1 : Setup a collection for seller_1
        await shallPass(
            sendTransaction({
                code: setup_nft_account_tx,
                args: [],
                signers: [seller_1],
            })
        );

        // step 2: Mint NFT for seller_1 with no royalties
        await shallPass(
            sendTransaction({
                code: mint_nft_tx,
                args: [
                    seller_1,
                    "NFT1",
                    "This is to sell",
                    "abc.jpeg",
                    [],
                    [],
                    [],
                ],
                signers: [exampleNFTContractAddress],
            })
        );

        // Verify the Id of the NFT that get minted
        const [result, e] = await executeScript({
            code: get_owned_nft_ids_script,
            args: [seller_1],
        });
        expect(result.length).toBe(1);
        expect(result[0]).toEqual(0);

        // Check the capability for the flow token
        expect(
            await doesFlowTokenReceiverCapabilityExists(seller_1)
        ).toBeTruthy();

        // Step 3: List NFT to sell, It would list the nft for the sale with commission can be grab by anyone.

        // Step 3.a: Below transaction would fail because seller_1 doesn't have the storefront manager install in the account.
        const currentTimestamp = parseInt(await getCurrentTimestamp());
        const [txResult, error] = await shallRevert(
            sendTransaction({
                name: "sell_item_via_catalog",
                args: [
                    "ExampleNFT",
                    0,
                    "50.50",
                    "TopShot Platform",
                    "10.50",
                    currentTimestamp + 500,
                    [],
                ],
                signers: [seller_1],
            })
        );

        // Make sure transaction did not go through.
        expect(txResult).toEqual(null);

        // TODO: Create some utility that would allow to match the error string with the thrown error.
        console.log(
            `Error for the transaction that need to reverted - ${error}`
        );

        // Step 3.b: Install the storefront manager in the seller_1 account.
        await shallPass(
            sendTransaction({
                name: "setup_account",
                args: [],
                signers: [seller_1],
            })
        );

        // Step 3.c: Should success as seller_1 has the storefront manager resource
        const [txResult_2, error_2] = await shallPass(
            sendTransaction({
                name: "sell_item_via_catalog",
                // Use 0 for the commission amount to make sure it supports the creation of the sale at 0 commission.
                args: [
                    "ExampleNFT",
                    0,
                    "50.50",
                    "TopShot Platform",
                    "0",
                    currentTimestamp + 500,
                    [],
                ],
                signers: [seller_1],
            })
        );

        // Make sure transaction did go through.
        expect(error_2).toEqual(null);

        // Validate the details
        let listingKeys = await getListingKeys(seller_1);
        expect(listingKeys.length).toEqual(1);

        let listingDetails = await getListingDetails(seller_1, listingKeys[0]);
        expect(listingDetails.purchased).toBeFalsy();
        expect(parseInt(listingDetails.expiry)).toEqual(currentTimestamp + 500);
        expect(listingDetails.customID).toEqual("TopShot Platform");
        expect(listingDetails.salePrice).toEqual("50.50000000");
    });

    test("should successfully list the sale item with royalty and marketplace address", async () => {
        // step 1 : Setup a collection for seller_1
        await shallPass(
            sendTransaction({
                code: setup_nft_account_tx,
                args: [],
                signers: [seller_1],
            })
        );

        // step 2: Mint NFT for seller_1 with royalties fail because the artists don't have the receiver capability.
        const [txResult_nft_mint, error_nft_mint] = await shallRevert(
            sendTransaction({
                code: mint_nft_tx,
                args: [
                    seller_1,
                    "NFT1",
                    "This is to sell",
                    "abc.jpeg",
                    ["0.1", "0.25"],
                    ["Artist_1", "Artist_2"],
                    [artist_1, artist_2],
                ],
                signers: [exampleNFTContractAddress],
            })
        );

        // Make sure transaction did not go through.
        expect(txResult_nft_mint).toEqual(null);

        // step 3: Mint NFT for seller_1 with royalties
        // step 3.a: Provide the receiver capability.

        // For artist_1
        await shallPass(
            sendTransaction({
                code: setup_account_to_receive_royalty_tx,
                args: [],
                signers: [artist_1],
            })
        );

        // For artist_2
        await shallPass(
            sendTransaction({
                code: setup_account_to_receive_royalty_tx,
                args: [],
                signers: [artist_2],
            })
        );

        await shallPass(
            sendTransaction({
                code: mint_nft_tx,
                args: [
                    seller_1,
                    "NFT1",
                    "This is to sell",
                    "abc.jpeg",
                    ["0.1", "0.25"],
                    ["Artist_1", "Artist_2"],
                    [artist_1, artist_2],
                ],
                signers: [exampleNFTContractAddress],
            })
        );

        // Verify the Id of the NFT that get minted
        const [result, e] = await executeScript({
            code: get_owned_nft_ids_script,
            args: [seller_1],
        });
        expect(result.length).toBe(1);
        expect(result[0]).toEqual(0);

        // Check the capability for the flow token
        expect(
            await doesFlowTokenReceiverCapabilityExists(seller_1)
        ).toBeTruthy();

        // Step 4: List NFT to sell, It would list the nft for the sale with commission can be grab by anyone.
        const currentTimestamp = parseInt(await getCurrentTimestamp());

        // Step 4.a: Install the storefront manager in the seller_1 account.
        await shallPass(
            sendTransaction({
                name: "setup_account",
                args: [],
                signers: [seller_1],
            })
        );

        // Step 4.b: Should success as seller_1 has the storefront manager resource with marketplace address
        const [txResult_2, error_2] = await shallPass(
            sendTransaction({
                name: "sell_item_via_catalog",
                args: [
                    "ExampleNFT",
                    0,
                    "50.50",
                    "TopShot Platform",
                    "10.50",
                    currentTimestamp + 500,
                    [marketplace_1, marketplace_2],
                ],
                signers: [seller_1],
            })
        );

        // Make sure transaction did go through.
        expect(error_2).toEqual(null);

        // Validate the details
        let listingKeys = await getListingKeys(seller_1);
        expect(listingKeys.length).toEqual(1);

        let listingDetails = await getListingDetails(seller_1, listingKeys[0]);
        expect(listingDetails.purchased).toBeFalsy();
        expect(parseInt(listingDetails.expiry)).toEqual(currentTimestamp + 500);
        expect(listingDetails.customID).toEqual("TopShot Platform");
        expect(listingDetails.salePrice).toEqual("50.50000000");
        // Make sure that anybody can retrieve the list of the marketplaces capability supported by the listing.
        const allowedCommissionRecv = await getAllowedCommissionReceivers(
            seller_1,
            listingKeys[0]
        );
        console.log(allowedCommissionRecv);
        expect(allowedCommissionRecv[0].address).toEqual(marketplace_1);
        expect(allowedCommissionRecv[1].address).toEqual(marketplace_2);
    });

    test("should successfully list the same item multiple times and then purchase one of the listing that removes other duplicates programmatically", async () => {
        // step 1 : Setup a collection for seller_1
        await shallPass(
            sendTransaction({
                code: setup_nft_account_tx,
                args: [],
                signers: [seller_1],
            })
        );

        // step 2: Mint NFT for seller_1 with royalties
        // step 2.a: Provide the receiver capability.

        // For artist_1
        await shallPass(
            sendTransaction({
                code: setup_account_to_receive_royalty_tx,
                args: [],
                signers: [artist_1],
            })
        );

        // For artist_2
        await shallPass(
            sendTransaction({
                code: setup_account_to_receive_royalty_tx,
                args: [],
                signers: [artist_2],
            })
        );

        // Mint the NFT
        await shallPass(
            sendTransaction({
                code: mint_nft_tx,
                args: [
                    seller_1,
                    "NFT1",
                    "This is to sell",
                    "abc.jpeg",
                    ["0.1", "0.25"],
                    ["Artist_1", "Artist_2"],
                    [artist_1, artist_2],
                ],
                signers: [exampleNFTContractAddress],
            })
        );

        // Verify the Id of the NFT that get minted
        const [result, e] = await executeScript({
            code: get_owned_nft_ids_script,
            args: [seller_1],
        });
        expect(result.length).toBe(1);
        expect(result[0]).toEqual(0);

        // Check the capability for the flow token
        expect(
            await doesFlowTokenReceiverCapabilityExists(seller_1)
        ).toBeTruthy();

        // Step 4: List NFT to sell, It would list the nft for the sale with commission can be grab by anyone.
        const currentTimestamp = parseInt(await getCurrentTimestamp());

        // Step 4.a: Install the storefront manager in the seller_1 account.
        await shallPass(
            sendTransaction({
                name: "setup_account",
                args: [],
                signers: [seller_1],
            })
        );

        // Step 4.b: Should success as seller_1 has the storefront manager resource with marketplace address
        let [txResult_2, error_2] = await shallPass(
            sendTransaction({
                name: "sell_item_via_catalog",
                args: [
                    "ExampleNFT",
                    0,
                    "50.50",
                    "TopShot Platform",
                    "10.50",
                    currentTimestamp + 500,
                    [marketplace_1, marketplace_2],
                ],
                signers: [seller_1],
            })
        );

        // Make sure transaction did go through.
        expect(error_2).toEqual(null);

        // Validate the details
        let listingKeys = await getListingKeys(seller_1);
        expect(listingKeys.length).toEqual(1);

        let listingDetails = await getListingDetails(seller_1, listingKeys[0]);
        expect(listingDetails.purchased).toBeFalsy();
        expect(parseInt(listingDetails.expiry)).toEqual(currentTimestamp + 500);
        expect(listingDetails.customID).toEqual("TopShot Platform");
        expect(listingDetails.salePrice).toEqual("50.50000000");

        const artist_1_flow_balance_before = await getRoyaltyBalance(artist_1);
        const artist_2_flow_balance_before = await getRoyaltyBalance(artist_2);
        const [marketplace_1_flow_balance_before] = await getFlowBalance(
            marketplace_1
        );
        const [marketplace_2_flow_balance_before] = await getFlowBalance(
            marketplace_2
        );

        // Again list the same NFT
        // Step 5: Should success as seller_1 has the storefront manager resource with marketplace address
        [txResult_2, error_2] = await shallPass(
            sendTransaction({
                name: "sell_item_via_catalog",
                args: [
                    "ExampleNFT",
                    0,
                    "50.50",
                    "TopShot Platform Duplicate List",
                    "12.50",
                    currentTimestamp + 800,
                    [
                        await getAccountAddress("marketplace_3"),
                        await getAccountAddress("marketplace_4"),
                    ],
                ],
                signers: [seller_1],
            })
        );

        const listingKeys_2 = await getListingKeys(seller_1);
        expect(listingKeys_2.length).toEqual(2);

        let duplicateListing = await getDuplicateListingIDs(
            seller_1,
            listingDetails.nftID,
            listingKeys[0]
        );
        expect(duplicateListing.length).toEqual(1);

        //////////////
        // Purchase///
        //////////////

        // Mint effective salePrice amount to buyer_1
        await mintFlow(buyer_1, "1000.0");
        const [flowBalance] = await getFlowBalance(buyer_1);
        console.log(`Flow balance for buyer 1 - ${flowBalance}`);

        // Should fail as buyer don't have the NFT collection receiver.
        const [txResult_purchase, error_purchase] = await shallRevert(
            sendTransaction({
                name: "buy_item_via_catalog",
                args: ["ExampleNFT", listingKeys[0], seller_1, seller_2],
                signers: [buyer_1],
            })
        );

        // Make sure the transaction fails
        expect(txResult_purchase).toEqual(null);

        console.log(
            `Error during first attempt of purchase - ${error_purchase}`
        );

        // Install NFT receiver in the buyer account
        await shallPass(
            sendTransaction({
                code: setup_nft_account_tx,
                args: [],
                signers: [buyer_1],
            })
        );

        // Should fail as commission can only be send to marketplaces.
        const [txResult_purchase_2, error_purchase_2] = await shallRevert(
            sendTransaction({
                name: "buy_item_via_catalog",
                args: ["ExampleNFT", listingKeys[0], seller_1, seller_2],
                signers: [buyer_1],
            })
        );

        // Make sure the transaction fails
        expect(txResult_purchase_2).toEqual(null);

        console.log(
            `Error during Second attempt of purchase - ${error_purchase_2}`
        );

        const [seller_1_balance_before] = await getFlowBalance(seller_1);
        // Should successfully purchase the nft
        const [txResult_purchase_3, error_purchase_3] = await shallPass(
            sendTransaction({
                name: "buy_item_via_catalog",
                args: ["ExampleNFT", listingKeys[0], seller_1, marketplace_1],
                signers: [buyer_1],
            })
        );

        // Make sure the transaction fails
        expect(error_purchase_3).toEqual(null);

        // Verify the royalty and commission received by the entitled capabilities.
        const artist_1_flow_balance_after = await getRoyaltyBalance(artist_1);
        const artist_2_flow_balance_after = await getRoyaltyBalance(artist_2);
        const [marketplace_1_flow_balance_after] = await getFlowBalance(
            marketplace_1
        );
        const [marketplace_2_flow_balance_after] = await getFlowBalance(
            marketplace_2
        );
        const [seller_1_balance_after] = await getFlowBalance(seller_1);

        expect(
            parseFloat(marketplace_1_flow_balance_after) -
                parseFloat(marketplace_1_flow_balance_before)
        ).toEqual(parseFloat("10.50"));
        expect(
            parseFloat(marketplace_2_flow_balance_after) -
                parseFloat(marketplace_2_flow_balance_before)
        ).toEqual(parseFloat("0.0"));
        expect(
            parseFloat(artist_1_flow_balance_after) -
                parseFloat(artist_1_flow_balance_before)
        ).toEqual(parseFloat("4.0"));
        expect(
            parseFloat(artist_2_flow_balance_after) -
                parseFloat(artist_2_flow_balance_before)
        ).toEqual(parseFloat("10.0"));
        expect(
            parseFloat(seller_1_balance_after) -
                parseFloat(seller_1_balance_before)
        ).toEqual(parseFloat("26.0"));

        // Verify the buyer got the NFT.
        const [nft_ids] = await executeScript({
            code: get_owned_nft_ids_script,
            args: [buyer_1],
        });
        expect(nft_ids.length).toBe(1);
        expect(result[0]).toEqual(0);

        // Duplicate listing get deleted.
        const listingKeys_3 = await getListingKeys(seller_1);
        expect(listingKeys_3.length).toEqual(1);
    });

    test("should successfully list the item with the zero commission receipt and buy with it", async () => {
        // step 1 : Setup a collection for seller_1
        await shallPass(
            sendTransaction({
                code: setup_nft_account_tx,
                args: [],
                signers: [seller_1],
            })
        );

        // step 2: Mint NFT for seller_1 with royalties
        // step 2.a: Provide the receiver capability.

        // For artist_1
        await shallPass(
            sendTransaction({
                code: setup_account_to_receive_royalty_tx,
                args: [],
                signers: [artist_1],
            })
        );

        // For artist_2
        await shallPass(
            sendTransaction({
                code: setup_account_to_receive_royalty_tx,
                args: [],
                signers: [artist_2],
            })
        );

        // Mint the NFT
        await shallPass(
            sendTransaction({
                code: mint_nft_tx,
                args: [
                    seller_1,
                    "NFT1",
                    "This is to sell",
                    "abc.jpeg",
                    ["0.1", "0.25"],
                    ["Artist_1", "Artist_2"],
                    [artist_1, artist_2],
                ],
                signers: [exampleNFTContractAddress],
            })
        );

        // Verify the Id of the NFT that get minted
        const [result, e] = await executeScript({
            code: get_owned_nft_ids_script,
            args: [seller_1],
        });
        expect(result.length).toBe(1);
        expect(result[0]).toEqual(0);

        // Check the capability for the flow token
        expect(
            await doesFlowTokenReceiverCapabilityExists(seller_1)
        ).toBeTruthy();

        // Step 4: List NFT to sell, It would list the nft for the sale with commission can be grab by anyone.
        const currentTimestamp = parseInt(await getCurrentTimestamp());

        // Step 4.a: Install the storefront manager in the seller_1 account.
        await shallPass(
            sendTransaction({
                name: "setup_account",
                args: [],
                signers: [seller_1],
            })
        );

        // Step 4.b: Should success as seller_1 has the storefront manager resource with marketplace address
        let [txResult_2, error_2] = await shallPass(
            sendTransaction({
                name: "sell_item_via_catalog",
                args: [
                    "ExampleNFT",
                    0,
                    "50.50",
                    "TopShot Platform",
                    "0.0",
                    currentTimestamp + 500,
                    [marketplace_1, marketplace_2],
                ],
                signers: [seller_1],
            })
        );

        // Make sure transaction did go through.
        expect(error_2).toEqual(null);

        // Validate the details
        let listingKeys = await getListingKeys(seller_1);
        expect(listingKeys.length).toEqual(1);

        let listingDetails = await getListingDetails(seller_1, listingKeys[0]);
        expect(listingDetails.purchased).toBeFalsy();
        expect(parseInt(listingDetails.expiry)).toEqual(currentTimestamp + 500);
        expect(listingDetails.customID).toEqual("TopShot Platform");
        expect(listingDetails.salePrice).toEqual("50.50000000");

        //////////////
        // Purchase///
        //////////////

        // Mint effective salePrice amount to buyer_1
        await mintFlow(buyer_1, "1000.0");
        const [flowBalance] = await getFlowBalance(buyer_1);
        console.log(`Flow balance for buyer 1 - ${flowBalance}`);

        // Install NFT receiver in the buyer account
        await shallPass(
            sendTransaction({
                code: setup_nft_account_tx,
                args: [],
                signers: [buyer_1],
            })
        );

        // Should fail as commission can only be send to marketplaces.
        const [txResult_purchase, error_purchase] = await shallPass(
            sendTransaction({
                name: "buy_item_via_catalog",
                args: ["ExampleNFT", listingKeys[0], seller_1, null],
                signers: [buyer_1],
            })
        );

        // Make sure the transaction fails
        expect(error_purchase).toEqual(null);

        // Verify the buyer got the NFT.
        const [nft_ids] = await executeScript({
            code: get_owned_nft_ids_script,
            args: [buyer_1],
        });
        expect(nft_ids.length).toBe(1);
        expect(result[0]).toEqual(0);
    });

    test("Cleanup expired listings", async () => {
        // step 1 : Setup a collection for seller_1
        await shallPass(
            sendTransaction({
                code: setup_nft_account_tx,
                args: [],
                signers: [seller_1],
            })
        );

        // step 2: Mint NFT for seller_1 with no royalties
        await shallPass(
            sendTransaction({
                code: mint_nft_tx,
                args: [
                    seller_1,
                    "NFT1",
                    "This is to sell",
                    "abc.jpeg",
                    [],
                    [],
                    [],
                ],
                signers: [exampleNFTContractAddress],
            })
        );

        // step 2: Mint NFT for seller_1 with no royalties
        await shallPass(
            sendTransaction({
                code: mint_nft_tx,
                args: [
                    seller_1,
                    "NFT2",
                    "This is to sell as well",
                    "xyz.jpeg",
                    [],
                    [],
                    [],
                ],
                signers: [exampleNFTContractAddress],
            })
        );

        // step 2: Mint NFT for seller_1 with no royalties
        await shallPass(
            sendTransaction({
                code: mint_nft_tx,
                args: [
                    seller_1,
                    "NFT3",
                    "This is to sell as well",
                    "ama.jpeg",
                    [],
                    [],
                    [],
                ],
                signers: [exampleNFTContractAddress],
            })
        );

        // Step 3: Install the storefront manager in the seller_1 account.
        await shallPass(
            sendTransaction({
                name: "setup_account",
                args: [],
                signers: [seller_1],
            })
        );

        const currentTimestamp = parseInt(await getCurrentTimestamp());

        // Step 3.c: Should successfully create the multiple listings
        await shallPass(
            sendTransaction({
                name: "sell_item_via_catalog",
                args: [
                    "ExampleNFT",
                    0,
                    "50.50",
                    "TopShot Platform 1",
                    "10.50",
                    currentTimestamp + 2,
                    [],
                ],
                signers: [seller_1],
            })
        );

        let listingKeysT = await getListingKeys(seller_1);
        console.log(JSON.stringify(listingKeysT));

        await shallPass(
            sendTransaction({
                name: "sell_item_via_catalog",
                args: [
                    "ExampleNFT",
                    1,
                    "50.50",
                    "TopShot Platform 2",
                    "10.50",
                    currentTimestamp + 3,
                    [],
                ],
                signers: [seller_1],
            })
        );

        listingKeysT = await getListingKeys(seller_1);
        console.log(JSON.stringify(listingKeysT));

        await shallPass(
            sendTransaction({
                name: "sell_item_via_catalog",
                args: [
                    "ExampleNFT",
                    2,
                    "50.50",
                    "TopShot Platform 3",
                    "10.50",
                    currentTimestamp + 4,
                    [],
                ],
                signers: [seller_1],
            })
        );

        listingKeysT = await getListingKeys(seller_1);
        console.log(JSON.stringify(listingKeysT));

        await shallPass(
            sendTransaction({
                name: "sell_item_via_catalog",
                args: [
                    "ExampleNFT",
                    2,
                    "50.50",
                    "TopShot Platform 4",
                    "10.50",
                    currentTimestamp + 15,
                    [],
                ],
                signers: [seller_1],
            })
        );

        listingKeysT = await getListingKeys(seller_1);
        console.log(JSON.stringify(listingKeysT));

        console.log(`Timestamp before the time jump - ${currentTimestamp}`);

        // For waiting
        await sleep(16000);

        ////////////////////
        /////// Purchase //
        ///////////////////

        // Mint effective salePrice amount to buyer_1
        await mintFlow(buyer_1, "1000.0");

        // Install NFT receiver in the buyer account
        await shallPass(
            sendTransaction({
                code: setup_nft_account_tx,
                args: [],
                signers: [buyer_1],
            })
        );

        // Validate the details
        let listingKeys = await getListingKeys(seller_1);
        expect(listingKeys.length).toEqual(4);
        console.log(JSON.stringify(listingKeys));

        console.log(
            `Timestamp after the time jump - ${parseInt(
                await getCurrentTimestamp()
            )}`
        );

        // Should fail because listing is expired.
        const [txResult_purchase, error_purchase] = await shallRevert(
            sendTransaction({
                name: "buy_item_via_catalog",
                args: ["ExampleNFT", listingKeys[0], seller_1, seller_2],
                signers: [buyer_1],
            })
        );

        // Make sure the transaction fails
        expect(txResult_purchase).toEqual(null);

        console.log(
            `Error during first attempt of purchase - ${error_purchase}`
        );

        // Fail to cleanup the listing as provided range is out of bound
        let [txResult_cleanup, error_cleanup] = await shallRevert(
            sendTransaction({
                name: "cleanup_expired_listings",
                args: [0, 6, seller_1],
                signers: [buyer_1],
            })
        );

        // Make sure the transaction succeed
        expect(txResult_cleanup).toEqual(null);

        // Fail to cleanup the listing because of incorrect start index
        [txResult_cleanup, error_cleanup] = await shallRevert(
            sendTransaction({
                name: "cleanup_expired_listings",
                args: [5, 3, seller_1],
                signers: [buyer_1],
            })
        );

        // Make sure the transaction succeed
        expect(txResult_cleanup).toEqual(null);

        // Cleanup the listings
        [txResult_cleanup, error_cleanup] = await shallPass(
            sendTransaction({
                name: "cleanup_expired_listings",
                args: [0, 3, seller_1],
                signers: [buyer_1],
            })
        );

        // Make sure the transaction succeed
        expect(error_cleanup).toEqual(null);
    });
});
