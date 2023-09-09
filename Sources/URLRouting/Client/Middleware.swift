import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A type that intercepts server requests and responses.
///
/// It allows you to read and modify the request before it is received by the client, and the
/// response after it is returned by the client.
///
/// Appropriate for handling authentication, logging, metrics, tracing, injecting custom headers
/// such as "user-agent", and more.
///
/// ### Implement a custom client middleware
///
/// Define a type that implements the middleware protocol. Here is an example implementation of a middleware that
/// injects the "Authorization" header to every outgoing request:
///
/// ```swift
/// /// Injects an authorization header to every request.
/// struct AuthenticationMiddleware: ClientMiddleware {
///   /// The token value.
///   var bearerToken: String
///
///   func intercept(
///     _ request: URLRequestData,
///     route: APIRoute,
///     next: (URLRequestData, APIRoute) async throws -> (Data, URLRequest)
///   ) async throws -> (Data, URLRequest) {
///     var request = request
///     request.headers["Authorization"] = ["Bearer \(token)"[...]]
///     return try await next(request, route)
///   }
/// }
/// ```
///
/// Similarly to the process of using an existing ``URLRoutingClient``, provide the middleware to the `live`
/// static method for creating an API client from a parser-printer:
///
/// ```swift
/// let client: URLRoutingClient = .live(
///	  router: MyRouter()
///   middleware: [
///     AuthenticationMiddleware()
///   ]
/// )
/// ```
///
/// ### AnyURLRoutingClientMiddleware (for Swift 5.6 and earlier runtimes)
///
/// Create a type-erased ``URLRoutingClientMiddleware`` as a convenience:
///
/// ```swift
/// extension URLRoutingClientMiddleware where Self == AnyURLRoutingClientMiddleware<MyRoute> {
///   static var authentication: Self {
///  	  .init(AuthenticationMiddleware())
///   }
/// }
/// ```
///
/// Similarly to the process of using an existing ``URLRoutingClient``, provide the middleware to the `live`
/// static method for creating an API client from a parser-printer:
///
/// ```swift
/// let client: URLRoutingClient = .live(
///	  router: MyRouter()
///   middleware: [
///     .authentication
///   ]
/// )
/// ```
///
/// ### Make a Request
///
/// ```swift
/// let (user, response) = try await client.decodedResponse(for: .currentUser, as: User.self)
/// ```
///
/// As part of the invocation of `currentUser`, the client first invokes the middleware in the order you
/// provided them, and then passes the request to the client. When a response is received, the last
/// middleware handles it first, in the reverse order of the `middleware` array.
/// ```
@rethrows 
public protocol URLRoutingClientMiddleware<Route> {
  associatedtype Route
  
  func intercept(
    _ request: URLRequestData,
    route: Route,
    next: (URLRequestData, Route) async throws -> (Data, URLResponse)
  ) async throws -> (Data, URLResponse)
}

/// A type-erased ``URLRoutingClientMiddleware``.
///
/// This middleware forwards its ``intercept(_:route:next:)`` method to an arbitrary underlying conversion
/// having the same `Route` type, hiding the specifics of the underlying ``URLRoutingClientMiddleware``.
public struct AnyURLRoutingClientMiddleware<Route>: URLRoutingClientMiddleware {
	
	@usableFromInline
	typealias Next = (URLRequestData, Route) async throws -> (Data, URLResponse)

	@usableFromInline
	let _intercept: (URLRequestData, Route, Next) async throws -> (Data, URLResponse)

	@inlinable
	public init<M: URLRoutingClientMiddleware>(_ middleware: M) where M.Route == Route {
		self._intercept = middleware.intercept(_:route:next:)
	}

	@inlinable
	public func intercept(
		_ request: URLRequestData,
		route: Route,
		next: (URLRequestData, Route) async throws -> (Data, URLResponse)
	) async throws -> (Data, URLResponse) {
		try await _intercept(request, route, next)
	}
	
}
