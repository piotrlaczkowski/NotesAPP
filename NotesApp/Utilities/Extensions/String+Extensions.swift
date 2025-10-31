import Foundation

extension String {
    func base64EncodedData() -> Data? {
        return Data(base64Encoded: self, options: .ignoreUnknownCharacters)
    }
}

