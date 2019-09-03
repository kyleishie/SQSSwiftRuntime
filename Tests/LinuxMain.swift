import XCTest

import SQSSwiftRuntimeTests

var tests = [XCTestCaseEntry]()
tests += SQSSwiftRuntimeTests.allTests()
XCTMain(tests)
