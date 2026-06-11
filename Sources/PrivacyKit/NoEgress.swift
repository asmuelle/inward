import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public enum NoEgressError: Error {
    case blocked(URL?)
}

/// Thread-safe record of every network request attempted while the harness is
/// installed. `@unchecked Sendable` is justified: all state is behind one lock.
public final class NoEgressRecorder: @unchecked Sendable {
    public static let shared = NoEgressRecorder()

    private let lock = NSLock()
    private var recorded: [URLRequest] = []

    public func record(_ request: URLRequest) {
        lock.lock()
        defer { lock.unlock() }
        recorded.append(request)
    }

    public func snapshot() -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        recorded.removeAll()
    }
}

/// URLProtocol that records and then refuses every request. Registered by the
/// test harness so any network attempt in the journaling path fails the test —
/// product invariant #2 as executable code.
public final class NoEgressURLProtocol: URLProtocol {
    override public class func canInit(with request: URLRequest) -> Bool {
        NoEgressRecorder.shared.record(request)
        return true
    }

    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override public func startLoading() {
        client?.urlProtocol(self, didFailWithError: NoEgressError.blocked(request.url))
    }

    override public func stopLoading() {}
}

public enum NoEgress {
    /// A URLSession configuration that routes everything through the blocker.
    /// Inject into any component that owns a session (none should exist in the
    /// journaling path — that is the point).
    public static func monitoredConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NoEgressURLProtocol.self]
        return configuration
    }

    /// Runs `body` with the global interceptor installed and returns every request
    /// attempted during it. Tests assert the list is empty.
    public static func observe<T: Sendable>(
        _ body: () async throws -> T
    ) async rethrows -> (value: T, attempted: [URLRequest]) {
        URLProtocol.registerClass(NoEgressURLProtocol.self)
        NoEgressRecorder.shared.reset()
        defer { URLProtocol.unregisterClass(NoEgressURLProtocol.self) }
        let value = try await body()
        return (value, NoEgressRecorder.shared.snapshot())
    }
}
