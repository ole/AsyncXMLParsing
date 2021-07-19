import Foundation

struct XML: AsyncSequence {
  let xml: String

  enum Element: Equatable {
    case element(name: String)
    case text(String)
    case comment(String)
    case cdata(Data)
  }

  __consuming func makeAsyncIterator() -> AsyncThrowingStream<Element, Error>.AsyncIterator {
    let parser = XMLParser(data: Data(xml.utf8))
    let parserDelegate = ParserDelegate()
    parser.delegate = parserDelegate
    let stream = AsyncThrowingStream(XML.Element.self, bufferingPolicy: .unbounded) { continuation in
      parserDelegate.continuation = continuation
    }
    // Don’t use `Task { … }` for the parse operation because `XMLParser` blocks its thread.
    DispatchQueue.global().async {
      withExtendedLifetime(parserDelegate) {
        _ = parser.parse()
      }
    }
    return stream.makeAsyncIterator()
  }
}

extension XML {
  final class ParserDelegate: NSObject, XMLParserDelegate {
    var continuation: AsyncThrowingStream<XML.Element, Error>.Continuation! = nil
    private var accumulatedText: String = ""

    private func yieldAccumulatedTextIfAny() {
      guard !self.accumulatedText.isEmpty else {
        return
      }
      defer {
        self.accumulatedText = ""
      }
      let isAllWhitespace = self.accumulatedText.allSatisfy(\.isWhitespace)
      guard !isAllWhitespace else {
        return
      }
      self.continuation.yield(.text(self.accumulatedText))
    }

    func parser(
      _ parser: XMLParser,
      didStartElement elementName: String,
      namespaceURI: String?,
      qualifiedName qName: String?,
      attributes attributeDict: [String : String] = [:]
    ) {
      yieldAccumulatedTextIfAny()
      self.continuation.yield(.element(name: elementName))
    }

    func parser(
      _ parser: XMLParser,
      didEndElement elementName: String,
      namespaceURI: String?,
      qualifiedName qName: String?
    ) {
      yieldAccumulatedTextIfAny()
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
      self.accumulatedText.append(string)
    }

    func parser(_ parser: XMLParser, foundComment comment: String) {
      self.continuation.yield(.comment(comment))
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
      self.continuation.yield(.cdata(CDATABlock))
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
