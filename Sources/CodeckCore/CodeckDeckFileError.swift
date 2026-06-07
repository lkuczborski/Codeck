import Foundation

public enum CodeckDeckFileError: LocalizedError, Equatable {
  case fileAlreadyExists(String)
  case fileNotFound(String)
  case invalidUTF8

  public var errorDescription: String? {
    switch self {
    case let .fileAlreadyExists(path):
      "A deck already exists at \(path). Pass overwrite=true to replace it."
    case let .fileNotFound(path):
      "No deck exists at \(path)."
    case .invalidUTF8:
      "Could not encode the deck as UTF-8."
    }
  }
}
