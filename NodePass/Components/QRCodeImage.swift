//
//  QRCodeImage.swift
//  NodePass
//
//  Renders a QR code for sharing master credentials between devices.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeImage: View {
    var content: String
    var size: CGFloat = 220

    var body: some View {
        Group {
            if let image = Self.render(content, scale: size) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            } else {
                ContentUnavailableView("Could not render code", systemImage: "qrcode")
            }
        }
        .frame(width: size, height: size)
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityLabel("QR code")
    }

    static func render(_ content: String, scale: CGFloat) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(content.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let factor = max(1, scale / output.extent.width)
        let transformed = output.transformed(by: CGAffineTransform(scaleX: factor, y: factor))
        return CIContext().createCGImage(transformed, from: transformed.extent)
    }
}
