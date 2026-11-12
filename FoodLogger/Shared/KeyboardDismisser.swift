import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
/// Tap anywhere outside a text field to close the keyboard, on every screen and sheet.
/// Works by adding one tap recogniser to the app's window (sheets live in the same window).
final class KeyboardDismisser: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismisser()
    private var installedWindows = Set<ObjectIdentifier>()

    func install() {
        for case let windowScene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in windowScene.windows where !installedWindows.contains(ObjectIdentifier(window)) {
                let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
                tap.cancelsTouchesInView = false   // buttons and rows still get the tap
                tap.delegate = self
                window.addGestureRecognizer(tap)
                installedWindows.insert(ObjectIdentifier(window))
            }
        }
    }

    @objc private func handleTap(_ tap: UITapGestureRecognizer) {
        tap.view?.endEditing(true)
    }

    /// Ignore taps on a text field itself, so moving between fields doesn't close the keyboard.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView { return false }
            view = current.superview
        }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
#endif

extension View {
    /// Lets the user close the keyboard by tapping outside a field or dragging a list down.
    func keyboardDismissable() -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                #if canImport(UIKit)
                KeyboardDismisser.shared.install()
                #endif
            }
    }
}
