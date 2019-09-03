import XCTest
@testable import SQSSwiftRuntime

final class SQSSwiftRuntimeTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(SQSSwiftRuntime().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
