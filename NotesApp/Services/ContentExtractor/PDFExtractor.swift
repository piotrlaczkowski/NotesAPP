import Foundation
import UniformTypeIdentifiers
import PDFKit

struct PDFExtractor {
    static func extractText(from data: Data) -> String? {
        // Extract text using PDFKit (iOS 11+, macOS 10.4+)
        guard let pdfDocument = PDFDocument(data: data) else {
            return nil
        }
        
        var fullText = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex),
               let pageText = page.string {
                fullText += pageText + "\n\n"
            }
        }
        
        return fullText.isEmpty ? nil : fullText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    static func extractText(from url: URL) async throws -> String? {
        let (data, _) = try await URLSession.shared.data(from: url)
        return extractText(from: data)
    }
}

