import SwiftUI

/// The app's real tab rows and actions, bound only to the in-memory practice
/// store, laid out as the browser's own sidebar is: the address field, pinned
/// tabs, the Space's name, its tabs, and the bar at the foot with the Space and
/// a menu that makes new tabs and folders.
struct BrowserGettingStartedPracticeSidebar: View {
    let practice: BrowserGettingStartedPractice
    let capabilities: BrowserInteractionCapabilities

    var body: some View {
        let space = practice.space
        return VStack(spacing: 0) {
            BrowserGettingStartedPracticeAddressField()
                .padding(.horizontal, 10)
                .padding(.top, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let context = practice.listContext(capabilities: capabilities) {
                        BrowserPinnedTabsDropSection(context: context)
                        HStack(spacing: 9) {
                            BrowserSpaceIdentityIcon(space: space, size: 18)
                            Text("Practice").font(CrestTypography.sans(14, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        BrowserSidebarTabList(
                            context: context, alwaysShowsSavedTabs: true, showsClearAction: true,
                            openNewTab: practice.openExampleTab)
                    }
                }.padding(8)
            }
            .browserNativeScrollState(practice.sidebarScroll)
            .scrollIndicators(.automatic)
            BrowserGettingStartedPracticeBottomBar(practice: practice)
        }
        .environment(practice.sidebarInteraction)
        .background(CrestBrandTheme.surface)
    }
}

/// The address field at the top of the sidebar, shown as it rests: the
/// practice has no pages to load.
private struct BrowserGettingStartedPracticeAddressField: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
            Text("Search or enter website")
            Spacer(minLength: 0)
        }
        .font(CrestTypography.sans(12))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 32)
        .crestInteractiveSurface(isSelected: false, isHovering: false, showsRestingSurface: true)
        .accessibilityHidden(true)
    }
}

/// The bar at the foot of the sidebar: the archive, the practice Space, and
/// the menu that makes a new tab or folder in it.
private struct BrowserGettingStartedPracticeBottomBar: View {
    let practice: BrowserGettingStartedPractice

    var body: some View {
        HStack {
            Image(systemName: "archivebox")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Spacer()
            BrowserSpaceIdentityIcon(space: practice.space, size: 16)
                .accessibilityHidden(true)
            Spacer()
            Menu {
                Button("New Tab", systemImage: "plus", action: practice.openExampleTab)
                Button("New Folder", systemImage: "folder.badge.plus") { practice.addFolder(nested: false) }
            } label: {
                Image(systemName: "plus")
            }
            .menuStyle(.button)
            .buttonStyle(CrestChromeButtonStyle())
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("New")
        }
        .font(.system(size: 14, weight: .medium))
        .padding(.horizontal, 14)
        .frame(height: 40)
    }
}
