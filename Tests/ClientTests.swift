//
//  Copyright (c) 2015 Algolia
//  http://www.algolia.com/
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import XCTest
import AlgoliaSearch
import Alamofire

class ClientTests: XCTestCase {
    let expectationTimeout: NSTimeInterval = 100
    
    var client: Client!
    var index: Index!
    
    override func setUp() {
        super.setUp()
        let appID = NSProcessInfo.processInfo().environment["ALGOLIA_APPLICATION_ID"] as String
        let apiKey = NSProcessInfo.processInfo().environment["ALGOLIA_API_KEY"] as String
        client = AlgoliaSearch.Client(appID: appID, apiKey: apiKey)
        index = client.getIndex("algol?à-swift")
        
        let expectation = expectationWithDescription("Delete index")
        client.deleteIndex(index.indexName, block: { (JSON, error) -> Void in
            XCTAssertNil(error, "Error during deleteIndex: \(error?.description)")
            expectation.fulfill()
        })
        
        waitForExpectationsWithTimeout(expectationTimeout, handler: nil)
    }
    
    override func tearDown() {
        super.tearDown()
        
        let expectation = expectationWithDescription("Delete index")
        client.deleteIndex(index.indexName, block: { (JSON, error) -> Void in
            XCTAssertNil(error, "Error during deleteIndex: \(error?.description)")
            expectation.fulfill()
        })
        
        waitForExpectationsWithTimeout(expectationTimeout, handler: nil)
    }
    
    func testListIndexes() {
        let expectation = expectationWithDescription("testListIndexes")
        let object = ["city": "San Francisco", "objectID": "a/go/?à"]
        
        index.addObject(object, block: { (JSON, error) -> Void in
            if let error = error {
                XCTFail("Error during addObject: \(error)")
                expectation.fulfill()
            } else {
                self.index.waitTask(JSON!["taskID"] as Int, block: { (JSON, error) -> Void in
                    if let error = error {
                        XCTFail("Error during waitTask: \(error)")
                        expectation.fulfill()
                    } else {
                        XCTAssertEqual(JSON!["status"] as String, "published", "Wait task failed")
                        
                        self.client.listIndexes({ (JSON, error) -> Void in
                            if let error = error {
                                XCTFail("Error during listIndexes: \(error)")
                            } else {
                                let items = JSON!["items"] as [[String: AnyObject]]
                                
                                var find = false
                                for item in items {
                                    if (item["name"] as String) == self.index.indexName {
                                        find = true
                                    }
                                }
                                
                                XCTAssertTrue(find, "List indexes failed")
                            }
                            
                            expectation.fulfill()
                        })
                    }
                })
            }
        })
        
        waitForExpectationsWithTimeout(expectationTimeout, handler: nil)
    }
    
    func testMoveIndex() {
        let expecation = expectationWithDescription("testMoveIndex")
        let object = ["city": "San Francisco", "objectID": "a/go/?à"]
        
        index.addObject(object, block: { (JSON, error) -> Void in
            if let error = error {
                XCTFail("Error during addObject: \(error)")
                expecation.fulfill()
            } else {
                self.index.waitTask(JSON!["taskID"] as Int, block: { (JSON, error) -> Void in
                    if let error = error {
                        XCTFail("Error during waitTask: \(error)")
                        expecation.fulfill()
                    } else {
                        XCTAssertEqual(JSON!["status"] as String, "published", "Wait task failed")
                        
                        self.client.moveIndex(self.index.indexName, dstIndexName: "algol?à-swift2", block: { (JSON, error) -> Void in
                            if let error = error {
                                XCTFail("Error during moveIndex: \(error)")
                                expecation.fulfill()
                            } else {
                                self.index.waitTask(JSON!["taskID"] as Int, block: { (JSON, error) -> Void in
                                    if let error = error {
                                        XCTFail("Error during waitTask: \(error)")
                                        expecation.fulfill()
                                    } else {
                                        XCTAssertEqual(JSON!["status"] as String, "published", "Wait task failed")
                                        
                                        let dstIndex = self.client.getIndex("algol?à-swift2")
                                        dstIndex.search(Query(), block: { (JSON, error) -> Void in
                                            if let error = error {
                                                XCTFail("Error during search: \(error)")
                                            } else {
                                                let nbHits = JSON!["nbHits"] as Int
                                                XCTAssertEqual(nbHits, 1, "Wrong number of object in the index")
                                            }
                                            
                                            expecation.fulfill()
                                        })
                                    }
                                })
                            }
                        })
                    }
                })
            }
        })
        
        waitForExpectationsWithTimeout(expectationTimeout, handler: nil)
        
        let deleteExpectation = expectationWithDescription("Delete index")
        client.deleteIndex("algol?à-swift2", block: { (JSON, error) -> Void in
            XCTAssertNil(error, "Error during deleteIndex: \(error?.description)")
            deleteExpectation.fulfill()
        })
        
        waitForExpectationsWithTimeout(expectationTimeout, handler: nil)
    }
    
    func testCopyIndex() {
        let expecation = expectationWithDescription("testCopyIndex")
        let srcIndexExpectation = expectationWithDescription("srcIndex")
        let dstIndexExpectation = expectationWithDescription("dstIndex")
        
        let object = ["city": "San Francisco", "objectID": "a/go/?à"]
        
        index.addObject(object, block: { (JSON, error) -> Void in
            if let error = error {
                XCTFail("Error during addObject: \(error)")
                expecation.fulfill()
            } else {
                self.index.waitTask(JSON!["taskID"] as Int, block: { (JSON, error) -> Void in
                    if let error = error {
                        XCTFail("Error during waitTask: \(error)")
                        expecation.fulfill()
                    } else {
                        XCTAssertEqual(JSON!["status"] as String, "published", "Wait task failed")
                        
                        self.client.copyIndex(self.index.indexName, dstIndexName: "algol?à-swift2", block: { (JSON, error) -> Void in
                            if let error = error {
                                XCTFail("Error during copyIndex: \(error)")
                                expecation.fulfill()
                            } else {
                                self.index.waitTask(JSON!["taskID"] as Int, block: { (JSON, error) -> Void in
                                    if let error = error {
                                        XCTFail("Error during waitTask: \(error)")
                                        expecation.fulfill()
                                    } else {
                                        XCTAssertEqual(JSON!["status"] as String, "published", "Wait task failed")
                                        expecation.fulfill()
                                        
                                        self.index.search(Query(), block: { (JSON, error) -> Void in
                                            if let error = error {
                                                XCTFail("Error during search: \(error)")
                                            } else {
                                                let nbHits = JSON!["nbHits"] as Int
                                                XCTAssertEqual(nbHits, 1, "Wrong number of object in the index")
                                            }
                                            
                                            srcIndexExpectation.fulfill()
                                        })
                                        
                                        let dstIndex = self.client.getIndex("algol?à-swift2")
                                        dstIndex.search(Query(), block: { (JSON, error) -> Void in
                                            if let error = error {
                                                XCTFail("Error during search: \(error)")
                                            } else {
                                                let nbHits = JSON!["nbHits"] as Int
                                                XCTAssertEqual(nbHits, 1, "Wrong number of object in the index")
                                            }
                                            
                                            dstIndexExpectation.fulfill()
                                        })
                                    }
                                })
                            }
                        })
                    }
                })
            }
        })
        
        waitForExpectationsWithTimeout(expectationTimeout, handler: nil)
        
        let deleteExpectation = expectationWithDescription("Delete index")
        client.deleteIndex("algol?à-swift2", block: { (JSON, error) -> Void in
            XCTAssertNil(error, "Error during deleteIndex: \(error?.description)")
            deleteExpectation.fulfill()
        })
        
        waitForExpectationsWithTimeout(expectationTimeout, handler: nil)
    }
}
