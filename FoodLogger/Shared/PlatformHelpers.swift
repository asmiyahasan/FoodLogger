import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Image {
    /// Makes a SwiftUI image from stored photo data on any platform.
    init?(imageData: Data) {
        #if canImport(UIKit)
        guard let image = UIImage(data: imageData) else { return nil }
        self.init(uiImage: image)
        #elseif canImport(AppKit)
        guard let image = NSImage(data: imageData) else { return nil }
        self.init(nsImage: image)
        #else
        return nil
        #endif
    }
}

extension View {
    /// Number keyboard on iPhone/iPad; no-op on Mac.
    @ViewBuilder
    func decimalKeyboard() -> some View {
        #if os(iOS) || os(visionOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    /// Small navigation title on iPhone/iPad; no-op on Mac.
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS) || os(visionOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
