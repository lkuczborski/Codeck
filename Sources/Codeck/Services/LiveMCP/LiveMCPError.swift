import CodeckCore
import Foundation

enum LiveMCPError: LocalizedError {
    case invalidParams(String)
    case operationFailed(String)

    var jsonRPCCode: Int {
        switch self {
        case .invalidParams:
            -32602
        case .operationFailed:
            -32000
        }
    }

    var errorDescription: String? {
        switch self {
        case let .invalidParams(message), let .operationFailed(message):
            message
        }
    }
}
