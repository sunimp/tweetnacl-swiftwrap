//
//  NaclSecretbox_Tests.swift
//
//  Created by Sun on 2016/12/13.
//

import Foundation

@testable import TweetNacl
import XCTest

class NaclSecretbox_Tests: XCTestCase {
    // MARK: Overridden Properties

    override class var defaultTestSuite: XCTestSuite {
        let testSuite = XCTestSuite(name: NSStringFromClass(self))
        
        let fileURL = Bundle.module.url(forResource: "SecretboxTestData", withExtension: "json")
        let fileData = try! Data(contentsOf: fileURL!)
        let jsonDecoder = JSONDecoder()
        let arrayOfData = try! jsonDecoder.decode([[String]].self, from: fileData)
        
        for array in arrayOfData {
            addTestsWithArray(array: array, toTestSuite: testSuite)
        }
        
        return testSuite
    }

    // MARK: Properties

    public var data: [String]?

    // MARK: Overridden Functions

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    // MARK: Class Functions

    private class func addTestsWithArray(array: [String], toTestSuite testSuite: XCTestSuite) {
        // Returns an array of NSInvocation, which are not available in Swift, but still seems to work.
        let invocations = testInvocations
        for invocation in invocations {
            // We can't directly use the NSInvocation type in our source, but it appears
            // that we can pass it on through.
            let testCase = NaclSecretbox_Tests(invocation: invocation)
            
            // Normally the "parameterized" values are passed during initialization.
            // This is a "good enough" workaround. You'll see that I simply force unwrap
            // the optional at the callspot.
            testCase.data = array
            
            testSuite.addTest(testCase)
        }
    }

    // MARK: Functions

    func testSecretBox() {
        let key = Data(base64Encoded: data![0])!
        let nonce = Data(base64Encoded: data![1])!
        let encodedMessage = data![2]
        let msg = Data(base64Encoded: encodedMessage)!
        let goodBox = data![3]
        
        do {
            let box = try NaclSecretBox.secretBox(message: msg, nonce: nonce, key: key)
            let boxEncoded = box.base64EncodedString()
            
            XCTAssertEqual(boxEncoded, goodBox)
            
            let openedBox = try NaclSecretBox.open(box: box, nonce: nonce, key: key)
            XCTAssertNotNil(openedBox)
            XCTAssertEqual(openedBox.base64EncodedString(), encodedMessage)
        } catch {
            XCTFail()
        }
    }
}
