//
//  PlainTextDocument.swift
//  NodePass
//
//  Minimal text document for saving logs and responses through the system save panel.
//

import SwiftUI
import UniformTypeIdentifiers

struct PlainTextDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.plainText]

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
