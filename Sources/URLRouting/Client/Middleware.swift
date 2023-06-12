import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// A type that intercepts server requests and responses.
///
/// It allows you to read and modify the request before it is received by the client and the
/// response after it is returned by the client.
///
/// Appropriate for handling authentication, logging, metrics, tracing, injecting custom headers
/// such as "user-agent", and more.
///
/// ### Use an existing client middleware
///
/// Instantiate the middleware using the parameters required by the specific implementation.
/// For example, using a hypothetical existing middleware that logs every request and response:
///
///	```swift
/// let loggingMiddleware = LoggingMiddleware()
/// ```
///
/// Similarly to the process of using an existing ``URLRoutingClient``, provide the middleware
/// to the `live` static method for creating an API client from a parser-printer.
///
/// ```swift
/// let client: URLRoutingClient = .live(
///	  router: APIRouter()
///   middlewares: [
///     LoggingMiddleWare()
///   ]
/// )
/// ```
///
/// Then make a request:
///
/// ```swift
/// let (user, response) = try await client.decodedResponse(for: .currentUser, as: User.self)
/// ```
///
/// As part of the invocation of `currentUser`, the client first invokes the middlewares in the order you
/// provided them, and then passes the request to the client. When a response is received, the last
/// middleware handles it first, in the reverse order of the `middlewares` array.
///
/// ### Implement a custom client middleware
///
/// Here is an example implementation of a middleware that injects the "Authorization" header to every
/// outgoing request:
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
@rethrows public protocol URLRoutingClientMiddleware<Route> {
  associatedtype Route
  
  func intercept(
    _ request: URLRequestData,
    route: Route,
    next: (URLRequestData, Route) async throws -> (Data, URLResponse)
  ) async throws -> (Data, URLResponse)
}
