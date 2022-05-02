import path from "path";
import { emulator, init, getAccountAddress } from "flow-js-testing";

// Increase timeout if your tests failing due to timeout
jest.setTimeout(10000);

describe("basic-test", ()=>{
  beforeEach(async () => {
    const basePath = path.resolve(__dirname, "../../cadence"); 
		// You can specify different port to parallelize execution of describe blocks
    const port = 8080; 
		// Setting logging flag to true will pipe emulator output to console
    const logging = false;
    
    await init(basePath, { port });
    return emulator.start(port, logging);
  });
  
 // Stop emulator, so it could be restarted
  afterEach(async () => {
    return emulator.stop();
  });
  
  test("+++", async () => {
    // WRITE YOUR ASSERTS HERE
  })
})
