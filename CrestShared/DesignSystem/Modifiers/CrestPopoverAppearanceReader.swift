import SwiftUI

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Reports the appearance a popover's own window is drawn in. The popover's
/// material follows that window, the way the system's menus do, rather than
/// the environment the popover inherits from the Space it opened from, so its
/// labels have to follow the window too.
struct CrestPopoverAppearanceReader {
    // MARK: - Static Variables

    /// The appearance a popover most likely opens in, used until its window reports.
    @MainActor static var expected: ColorScheme {
        #if os(macOS)
            NSApp?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
        #else
            UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
        #endif
    }

    // MARK: - Variables

    @Binding var colorScheme: ColorScheme?
}

#if os(macOS)
    extension CrestPopoverAppearanceReader: NSViewRepresentable {
        // MARK: - Actions - Representation

        func makeNSView(context: Context) -> ReportingView {
            ReportingView(report: report)
        }

        func updateNSView(_ view: ReportingView, context: Context) {
            view.report = report
        }

        private func report(_ scheme: ColorScheme) {
            guard colorScheme != scheme else { return }
            colorScheme = scheme
        }

        final class ReportingView: NSView {
            // MARK: - Variables

            var report: (ColorScheme) -> Void

            // MARK: - Initializers

            init(report: @escaping (ColorScheme) -> Void) {
                self.report = report
                super.init(frame: .zero)
            }

            @available(*, unavailable)
            required init?(coder: NSCoder) { nil }

            // MARK: - Actions - Appearance

            override func viewDidMoveToWindow() {
                super.viewDidMoveToWindow()
                publish()
            }

            override func viewDidChangeEffectiveAppearance() {
                super.viewDidChangeEffectiveAppearance()
                publish()
            }

            private func publish() {
                guard let window else { return }
                let scheme: ColorScheme =
                    window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
                // Reported after the current layout pass, which may be the one that placed this view.
                DispatchQueue.main.async { [report] in report(scheme) }
            }
        }
    }
#else
    extension CrestPopoverAppearanceReader: UIViewRepresentable {
        // MARK: - Actions - Representation

        func makeUIView(context: Context) -> ReportingView {
            ReportingView(report: report)
        }

        func updateUIView(_ view: ReportingView, context: Context) {
            view.report = report
        }

        private func report(_ scheme: ColorScheme) {
            guard colorScheme != scheme else { return }
            colorScheme = scheme
        }

        final class ReportingView: UIView {
            // MARK: - Variables

            var report: (ColorScheme) -> Void

            // MARK: - Initializers

            init(report: @escaping (ColorScheme) -> Void) {
                self.report = report
                super.init(frame: .zero)
                isUserInteractionEnabled = false
                registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: Self, _) in
                    view.publish()
                }
            }

            @available(*, unavailable)
            required init?(coder: NSCoder) { nil }

            // MARK: - Actions - Appearance

            override func didMoveToWindow() {
                super.didMoveToWindow()
                publish()
            }

            private func publish() {
                guard let window else { return }
                let scheme: ColorScheme = window.traitCollection.userInterfaceStyle == .dark ? .dark : .light
                // Reported after the current layout pass, which may be the one that placed this view.
                DispatchQueue.main.async { [report] in report(scheme) }
            }
        }
    }
#endif
