import SwiftUI

/// Whether content blocking blocks on the page's site, in every Space. Shown
/// for a page whose engine blocks with Crest's rules and whose Space blocks.
struct BrowserSiteContentBlockingToggle: View {
    let configuration: BrowserSiteControlConfiguration

    var body: some View {
        if let host, offersBlocking {
            Toggle(isOn: blocks(on: host)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Block Ads and Trackers")
                    Text(host).font(.caption).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .accessibilityIdentifier("site-content-blocking")
        }
    }

    private var host: String? {
        configuration.page.live.displayURL?.host()
    }

    private var offersBlocking: Bool {
        configuration.page.pageEngine.registration.supports(.contentBlocking)
            && configuration.space.settings.browsingPreferences.contentBlocking.blocksContent
    }

    private func blocks(on host: String) -> Binding<Bool> {
        Binding {
            !configuration.browser.exemptsFromContentBlocking(host)
        } set: { blocks in
            configuration.browser.setContentBlocking(blocks, onSite: host)
        }
    }
}
