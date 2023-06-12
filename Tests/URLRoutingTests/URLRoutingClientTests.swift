import Parsing
import URLRouting
import XCTest

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

class URLRoutingClientTests: XCTestCase {
  #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
    func testJSONDecoder_noDecoder() async throws {
      struct Response: Equatable, Decodable {
        let decodableValue: String
      }
      enum AppRoute {
        case test
      }
      let sut = URLRoutingClient<AppRoute>(request: { _ in
        ("{\"decodableValue\":\"result\"}".data(using: .utf8)!, URLResponse())
      })
      let response = try await sut.decodedResponse(for: .test, as: Response.self)
      XCTAssertEqual(response.value, .init(decodableValue: "result"))
    }
    
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
    func testJSONDecoder_customDecoder() async throws {
      struct Response: Equatable, Decodable {
        let decodableValue: String
      }
      enum AppRoute {
        case test
      }
      let customDecoder = JSONDecoder()
      customDecoder.keyDecodingStrategy = .convertFromSnakeCase
      let sut = URLRoutingClient<AppRoute>(
        request: { _ in
          ("{\"decodable_value\":\"result\"}".data(using: .utf8)!, URLResponse())
        }, decoder: customDecoder)
      let response = try await sut.decodedResponse(for: .test, as: Response.self)
      XCTAssertEqual(response.value, .init(decodableValue: "result"))
    }
    
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
    func testJSONDecoder_customDecoderForRequest() async throws {
      struct Response: Equatable, Decodable {
        let decodableValue: String
      }
      enum AppRoute {
        case test
      }
      let customDecoder = JSONDecoder()
      customDecoder.keyDecodingStrategy = .convertFromSnakeCase
      let sut = URLRoutingClient<AppRoute>(
        request: { _ in
          ("{\"decodableValue\":\"result\"}".data(using: .utf8)!, URLResponse())
        }, decoder: customDecoder)
      let response = try await sut.decodedResponse(for: .test, as: Response.self, decoder: .init())
      XCTAssertEqual(response.value, .init(decodableValue: "result"))
    }
  
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
    func test_middleware() async throws {
      struct AppRouter: ParserPrinter {
        var body: some Router<Void> {
          Always(())
        }
      }

      struct Middleware: URLRoutingClientMiddleware {
        let label: String
        let accumulator: _ActorIsolated<[String]>
        
        func intercept(
          _ request: URLRequestData,
          route: Void,
          next: (URLRequestData, Void) async throws -> (Data, URLResponse)
        ) async throws -> (Data, URLResponse) {
          await accumulator.withValue { $0.append("\(label) - intercept request") }
          let response = try await next(request, route)
          await accumulator.withValue { $0.append("\(label) - intercept response") }
          return response
        }
      }
      
      let accumulator = _ActorIsolated<[String]>([])
      
      let sut: URLRoutingClient = .live(
        router: AppRouter(),
        session: URLSession.noop(),
        middlewares: [
          Middleware(label: "First", accumulator: accumulator),
          Middleware(label: "Second", accumulator: accumulator),
          Middleware(label: "Third", accumulator: accumulator)
        ]
      )
      
      _ = try await sut.data(for: ())
      
      await accumulator.withValue {
        XCTAssertEqual($0, [
          "First - intercept request",
          "Second - intercept request",
          "Third - intercept request",
          
          "Third - intercept response",
          "Second - intercept response",
          "First - intercept response"
        ])
      }
    }
  #endif
}

extension URLSession {
  fileprivate static func noop() -> Self {
    final class NoopURLProtocol: URLProtocol {
      override class func canInit(with request: URLRequest) -> Bool { true }
      override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
      override func startLoading() {
        self.client?.urlProtocol(self, didReceive: URLResponse(), cacheStoragePolicy: .notAllowed)
        self.client?.urlProtocol(self, didLoad: Data())
        self.client?.urlProtocolDidFinishLoading(self)
      }
      override func stopLoading() {}
    }
    let noopConfiguration = URLSessionConfiguration.ephemeral
    noopConfiguration.protocolClasses = [NoopURLProtocol.self]
    return Self.init(configuration: noopConfiguration)
  }
}

fileprivate final actor _ActorIsolated<Value> {
  private var value: Value
  init(_ value: @autoclosure @Sendable () throws -> Value) rethrows {
    self.value = try value()
  }
  func withValue<T>(
    _ operation: @Sendable (inout Value) throws -> T
  ) rethrows -> T {
    var value = self.value
    defer { self.value = value }
    return try operation(&value)
  }
}
