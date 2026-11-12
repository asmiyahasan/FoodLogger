import SwiftUI

#if os(iOS)
import VisionKit
import Vision
import AVFoundation
import UIKit

/// Full-screen live barcode scanner. Calls `onScan` once with the first barcode it reads.
struct BarcodeScannerSheet: View {
    var dismissOnScan = true
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var state: ScannerState = .checking

    enum ScannerState { case checking, ready, unavailable(String) }

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .checking:
                    ProgressView()
                case .ready:
                    ZStack {
                        BarcodeScanner { code in
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            onScan(code)
                            if dismissOnScan { dismiss() }
                        }
                        .ignoresSafeArea()
                        VStack {
                            Spacer()
                            Text("Point the camera at a barcode")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(.bottom, 40)
                        }
                    }
                case .unavailable(let message):
                    ContentUnavailableView(
                        "Scanner unavailable",
                        systemImage: "barcode.viewfinder",
                        description: Text(message)
                    )
                }
            }
            .navigationTitle("Scan barcode")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task { await checkAvailability() }
    }

    private func checkAvailability() async {
        guard DataScannerViewController.isSupported else {
            state = .unavailable("This device can't scan barcodes with its camera. You can type the number in Search foods instead.")
            return
        }
        guard await AVCaptureDevice.requestAccess(for: .video), DataScannerViewController.isAvailable else {
            state = .unavailable("Camera access is off. Turn it on in Settings → FoodLogger.")
            return
        }
        state = .ready
    }
}

/// VisionKit's live scanner, set up for product barcodes.
private struct BarcodeScanner: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if !scanner.isScanning {
            try? scanner.startScanning()
        }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var hasScanned = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasScanned else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let code = barcode.payloadStringValue, !code.isEmpty {
                    hasScanned = true
                    dataScanner.stopScanning()
                    onScan(code)
                    return
                }
            }
        }
    }
}
#endif
