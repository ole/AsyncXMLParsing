import Foundation

struct XML: AsyncSequence {
  let xml: String

  enum Element: Equatable {
    case element(name: String)
  }

  __consuming func makeAsyncIterator() -> AsyncThrowingStream<Element, Error>.AsyncIterator {
    let parser = XMLParser(data: Data(xml.utf8))
    let parserDelegate = ParserDelegate()
    parser.delegate = parserDelegate
    let stream = AsyncThrowingStream(XML.Element.self, bufferingPolicy: .unbounded) { continuation in
      parserDelegate.continuation = continuation
    }
    Task {
      withExtendedLifetime(parserDelegate) {
        parser.parse()
      }
    }
    return stream.makeAsyncIterator()
  }
}

extension XML {
  final class ParserDelegate: NSObject, XMLParserDelegate {
    var continuation: AsyncThrowingStream<XML.Element, Error>.Continuation! = nil

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
      self.continuation.yield(.element(name: elementName))
    }

    func parserDidEndDocument(_ parser: XMLParser) {
      self.continuation.finish(throwing: nil)
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
      self.continuation.finish(throwing: parseError)
    }

    func parser(_ parser: XMLParser, validationErrorOccurred validationError: Error) {
      self.continuation.finish(throwing: validationError)
    }
  }
}
