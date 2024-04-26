// Helper functions. All of the following were taken from
// https://github.com/onflow/Offers/blob/fd380659f0836e5ce401aa99a2975166b2da5cb0/lib/cadence/test/Offers.cdc
// - deploy
// - scriptExecutor
// - txExecutor

import Test

access(all)
fun deploy(_ contractName: String, _ path: String) {
    let err = Test.deployContract(
        name: contractName,
        path: path,
        arguments: [],
    )

    Test.expect(err, Test.beNil())
}

access(all)
fun scriptExecutor(_ scriptName: String, _ arguments: [AnyStruct]): AnyStruct? {
    let scriptCode = loadCode(scriptName, "scripts")
    let scriptResult = Test.executeScript(scriptCode, arguments)

    if let failureError = scriptResult.error {
        panic(
            "Failed to execute the script because -:  ".concat(failureError.message)
        )
    }

    return scriptResult.returnValue
}

access(all)
fun expectScriptFailure(
    _ scriptName: String,
    _ arguments: [AnyStruct],
    _ message: String
) {
    let scriptCode = loadCode(scriptName, "scripts")
    let scriptResult = Test.executeScript(scriptCode, arguments)

    Test.assertError(
        scriptResult,
        errorMessage: message
    )
}

/*
access(all)
fun txExecutor(
    _ txName: String,
    _ signers: [Test.Account],
    _ arguments: [AnyStruct],
    _ expectedError: String?
): Bool {
    let txCode = loadCode(txName, "transactions")

    let authorizers: [Address] = []
    for signer in signers {
        authorizers.append(signer.address)
    }

    let tx = Test.Transaction(
        code: txCode,
        authorizers: authorizers,
        signers: signers,
        arguments: arguments,
    )

    let txResult = Test.executeTransaction(tx)
    if let err = txResult.error {
        if let expectedErrorMessage = expectedError {
            Test.assertError(
                txResult,
                errorMessage: expectedErrorMessage
            )
            return true
        }
    } else {
        if let expectedErrorMessage = expectedError {
            panic("Expecting error - ".concat(expectedErrorMessage).concat(". While no error triggered"))
        }
    }

    Test.expect(txResult, Test.beSucceeded())
    return true
}
*/
access(all)
fun loadCode(_ fileName: String, _ baseDirectory: String): String {
    return Test.readFile("../".concat(baseDirectory).concat("/").concat(fileName))
}