//
//  QRCodeReader.swift
//  NodePass
//
//  Finds master links in still images, for Macs without a scanning camera or a QR code that
//  arrived as a screenshot.
//

import Foundation
import Vision

enum QRCodeReader {
    enum Failure: LocalizedError {
        case unreadableImage
        case noMasterLink

        var errorDescription: String? {
            switch self {
            case .unreadableImage: "The file could not be read as an image."
            case .noMasterLink: "No NodePass master code was found in this image."
            }
        }
    }

    /// The first `np://master?…` link encoded in a QR code of the image.
    static func masterImport(fromImageAt url: URL) async throws -> MasterImport {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { throw Failure.unreadableImage }
        return try await masterImport(fromImageData: data)
    }

    static func masterImport(fromImageData data: Data) async throws -> MasterImport {
        var request = DetectBarcodesRequest()
        request.symbologies = [.qr]
        let observations: [BarcodeObservation]
        do {
            observations = try await request.perform(on: data)
        } catch {
            throw Failure.unreadableImage
        }
        for payload in observations.compactMap(\.payloadString) {
            if let link = URL(string: payload), let master = MasterImport(deepLink: link) {
                return master
            }
        }
        throw Failure.noMasterLink
    }
}
