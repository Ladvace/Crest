import SwiftUI

/// How the Space blocks ads and trackers, how current its filter lists are,
/// and the sites the person lets through in every Space. Where the engine
/// blocks with uBlock Origin Lite instead, the choice turns it on or off.
struct BrowserContentBlockingSettingsSection: View {
    @Binding var policy: ContentBlockingPolicy
    let errorDescription: String?
    let browser: BrowserStore
    /// The downloaded filter lists, where Crest downloads any.
    let filterLists: FilterListLibrary?
    /// Whether the Space's engine blocks with uBlock Origin Lite rather than
    /// Crest's own rules.
    var blocksWithExtension = false

    /// The choices, from blocking nothing to blocking the most.
    private static let choices: [ContentBlockingPolicy] = [.off, .balanced, .strict]

    var body: some View {
        Section {
            Picker("Block ads and trackers", selection: $policy) {
                ForEach(blocksWithExtension ? [.off, .balanced] : Self.choices, id: \.self) { choice in
                    Text(choice.title).tag(choice)
                }
            }
            .accessibilityIdentifier("content-blocking-policy")

            if policy.blocksContent, !blocksWithExtension {
                filterListStatus
                if let errorDescription {
                    Label(errorDescription, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
            if !exemptHosts.isEmpty {
                ForEach(exemptHosts, id: \.self) { host in
                    LabeledContent(host) {
                        Button("Block Again") { browser.setContentBlocking(true, onSite: host) }
                            .buttonStyle(.borderless)
                    }
                }
            }
        } header: {
            Text("Content blocking")
        } footer: {
            Text(summary).font(.footnote).foregroundStyle(.secondary)
        }
    }

    // MARK: - Sections

    /// Which lists block, when they were last checked, and a way to check now.
    @ViewBuilder private var filterListStatus: some View {
        LabeledContent {
            if let filterLists {
                Button("Update Now") {
                    Task { await filterLists.refreshIfDue(policies: [policy], force: true) }
                }
                .disabled(filterLists.isUpdating)
            }
        } label: {
            Text(listTitles)
            Text(updateDescription)
        }
        if let failure = filterLists?.failureDescription {
            Label(failure, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(.orange)
        }
    }

    // MARK: - Content

    private var exemptHosts: [String] {
        browser.workspaceModel?.appPreferences?.contentBlockingExemptions ?? []
    }

    private var listTitles: String {
        policy.filterListNames.compactMap(FilterList.named).map(\.title).formatted(.list(type: .and))
    }

    private var updateDescription: LocalizedStringKey {
        guard let filterLists else { return "Blocking well-known ad and analytics sites" }
        if filterLists.isUpdating { return "Updating…" }
        guard let checked = filterLists.lastChecked else { return "Not downloaded yet" }
        return "Checked \(checked.formatted(.relative(presentation: .named)))"
    }

    private var summary: LocalizedStringKey {
        if blocksWithExtension {
            return policy.blocksContent
                ? "Chromium blocks ads and trackers with uBlock Origin Lite, which Crest installs in this Space. Let a site through from the extension's own controls."
                : "Pages in this Space load everything they ask for, and uBlock Origin Lite is turned off."
        }
        return switch policy {
        case .off: "Pages in this Space load everything they ask for."
        case .strict:
            "Blocks ads, trackers and cookie notices with the community lists uBlock Origin uses. A few sites may break; let one through from its site controls."
        default:
            "Blocks ads and trackers with EasyList and EasyPrivacy, updated daily. Let a site through from its site controls."
        }
    }
}
