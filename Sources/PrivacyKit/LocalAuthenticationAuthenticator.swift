#if canImport(LocalAuthentication)
    import Foundation
    import LocalAuthentication

    /// The shipped authenticator: device-owner authentication via LocalAuthentication.
    /// `.deviceOwnerAuthentication` accepts biometrics OR the device passcode, so the
    /// journal is gated but its owner is never locked out of their own words.
    ///
    /// Requires `NSFaceIDUsageDescription` in the app Info.plist (app-shell config).
    public struct LocalAuthenticationAuthenticator: BiometricAuthenticating {
        public init() {}

        public func availability() -> BiometricAvailability {
            let context = LAContext()
            var error: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
                return .unavailable(reason: error?.localizedDescription ?? "no credential available")
            }
            return .available(Self.kind(for: context.biometryType))
        }

        public func authenticate(reason: String) async -> AuthOutcome {
            let context = LAContext()
            var error: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
                return .unavailable
            }
            do {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
                return success ? .success : .failed
            } catch let laError as LAError {
                switch laError.code {
                case .userCancel, .appCancel, .systemCancel:
                    return .canceled
                case .biometryNotAvailable, .biometryNotEnrolled, .passcodeNotSet:
                    return .unavailable
                default:
                    return .failed
                }
            } catch {
                return .failed
            }
        }

        private static func kind(for type: LABiometryType) -> BiometryKind {
            switch type {
            case .faceID: .faceID
            case .touchID: .touchID
            case .opticID: .opticID
            default: .passcodeOnly
            }
        }
    }
#endif
