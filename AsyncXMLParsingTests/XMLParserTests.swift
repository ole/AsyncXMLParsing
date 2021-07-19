import XCTest
@testable import AsyncXMLParsing

class XMLParserTests: XCTestCase {
  func testSample1() async throws {
    let inputFile = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "sample1.xml", withExtension: nil))
    let input = try String(decoding: Data(contentsOf: inputFile), as: UTF8.self)
    let expected: [XML.Element] = [
      .element(name: "plist"),
      .element(name: "dict"),
      .element(name: "key"),
      .element(name: "string"),
      .element(name: "key"),
      .element(name: "integer"),
    ]

    let actual = try await XML(xml: input).reduce(into: []) { partialResult, xmlElement in
      partialResult.append(xmlElement)
    }
    XCTAssertEqual(actual, expected)
  }
}
