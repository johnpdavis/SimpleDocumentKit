import XCTest
@testable import SimpleDocumentKit

final class SimpleDocumentKitTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(SimpleDocumentKit().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}