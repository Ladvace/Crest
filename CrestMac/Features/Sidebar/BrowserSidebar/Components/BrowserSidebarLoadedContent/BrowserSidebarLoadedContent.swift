import AppKit
import SwiftUI

/// The windowed shell's sidebar layout: a clipped Space pager tucked under the
/// address chrome, with the Space switcher resting under it.
///
/// Everything about *what* the sidebar does comes down from `BrowserSidebar`
/// through the context. What this view owns is the arrangement, the switcher's
/// accessories, and the page body only a windowed card pool can answer for.
struct BrowserSidebarLoadedContent: View {
    let context: BrowserSidebarContext
    let pages: BrowserPagePool
    let address: Binding<String>
    let isAddressEditing: Binding<Bool>
    let addressFocusRequest: Int
    let activateAddress: () -> Void
    let submitAddress: () -> Void
    let openNewTab: () -> Void
    /// Widens the sidebar from its icon column.
    let expandSidebar: () -> Void
    let sidebarToggleAction: BrowserSidebarToggleAction
    let toggleSidebar: () -> Void
    let commandSurfaceNamespace: Namespace.ID
    let commandPaletteHandoff: BrowserCommandPaletteHandoff
    let tabPromotionNamespace: Namespace.ID

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.browserSidebarWidgetRuntime) private var widgetRuntime
    @Environment(\.spacePagerPresentation) private var inheritedPagerPresentation
    @State private var standalonePagerPresentation = SpacePagerPresentation()
    /// Whether the sidebar is narrow enough to show only icons. Kept as the
    /// answer alone: holding the width redrew the whole sidebar on every
    /// step of a resize.
    @State private var showsIconColumn = false

    private var spacePagerPresentation: SpacePagerPresentation {
        inheritedPagerPresentation ?? standalonePagerPresentation
    }

    var body: some View {
        Group {
            if showsIconColumn {
                BrowserSidebarIconColumn(
                    context: context, pages: pages, openNewTab: openNewTab,
                    search: {
                        expandSidebar()
                        activateAddress()
                    })
            } else {
                fullSidebar
            }
        }
        .onGeometryChange(for: Bool.self) {
            BrowserChromeLayout.showsIconColumn(atSidebarWidth: $0.size.width)
        } action: {
            showsIconColumn = $0
        }
    }

    private var fullSidebar: some View {
        VStack(spacing: 0) {
            SidebarChrome(
                context: context,
                pages: pages,
                address: address,
                isAddressEditing: isAddressEditing,
                addressFocusRequest: addressFocusRequest,
                activateAddress: activateAddress,
                submitAddress: submitAddress,
                commandSurfaceNamespace: commandSurfaceNamespace,
                commandPaletteHandoff: commandPaletteHandoff,
                sidebarToggleAction: sidebarToggleAction,
                toggleSidebar: toggleSidebar
            )
            .onGeometryChange(for: CGFloat.self) {
                $0.size.height
            } action: {
                // The pager already reaches the glow's outset up under the chrome.
                spacePagerPresentation.gestureTopInset = max(0, $0 - BrowserTabSelectionGlow.outset)
            }
            // Above the pager, so a selected pin's glow slides under the
            // address field.
            .zIndex(1)

            BrowserSidebarSpacePager(context: context) { space, isSelected in
                BrowserSidebarSpacePage(
                    space: space,
                    isSelected: isSelected,
                    context: context,
                    pages: pages,
                    openNewTab: openNewTab,
                    commandSurfaceNamespace: commandSurfaceNamespace,
                    tabPromotionNamespace: tabPromotionNamespace
                )
                .padding(.top, BrowserTabSelectionGlow.outset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            // The native Space pages clip at their own bounds, so the pager
            // reaches the glow's outset up under the chrome and each page
            // starts that far down: the glow draws into the band behind the
            // address field while paging still clips at the sides and bottom.
            .padding(.top, -BrowserTabSelectionGlow.outset)

            // The widget deck is a top layer over every Space of every profile.
            // It mounts unconditionally beside the pager — never keyed to the
            // selected Space — so switching Spaces cannot unmount or recreate it.
            if BrowserSidebarWidgetHost.isShown(
                sidebarIsPresented: true,
                isPrivateBrowsing: context.browser.isPrivateBrowsing
            ) {
                BrowserSidebarWidgetHost(
                    capabilities: widgetCapabilities,
                    activateMediaSession: activateMediaSession,
                    ownerFaviconData: ownerFaviconData
                )
                .background {
                    BrowserSidebarWidgetDeckScrollMonitor(cycle: cycleWidgetDeck)
                }
            }

            BrowserSpaceSwitcher(
                browser: context.browser,
                downloadCenter: context.pageAccess.downloadCenter,
                capabilities: context.capabilities,
                selectSpace: context.selectSpace,
                accessories: switcherAccessories
            )
            .environment(
                \.colorScheme,
                context.browser.shownSpace.map {
                    $0.settings.look.shown.colorScheme(over: colorScheme)
                } ?? .dark
            )
            .modifier(
                SpaceForegroundBlend(
                    spaces: context.availableSpaces, selectedSpaceID: context.browser.selectedSpaceID))
        }
        .environment(\.spacePagerPresentation, spacePagerPresentation)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(context.browser.shownSpace?.settings.name ?? "Browser") Space"
        )
    }

    private func activateMediaSession(
        _ assignment: BrowserTabRuntimeAssignment
    ) {
        Task { @MainActor in
            guard
                pages.containsResidentPage(matching: assignment),
                let space = context.browser.spaceModel(matching: assignment.spaceAssignment),
                space.tabs.model(assignment.tabID) != nil,
                await context.spaceAccess.unlock(space)
            else { return }
            context.selectSpace(assignment.spaceID)
            context.browser.selectTab(assignment.tabID)
            pages.select()
        }
    }

    private var widgetCapabilities: BrowserSidebarWidgetCapabilities {
        [.persistentSidebar, .mediaSessions, .directSoftwareUpdates]
    }

    private func ownerFaviconData(
        _ assignment: BrowserTabRuntimeAssignment
    ) -> Data? {
        guard context.browser.spaceModel(matching: assignment.spaceAssignment)?.tabs.model(assignment.tabID) != nil
        else { return nil }
        return context.browser.core.state.favicons.image(of: assignment.tabID)
    }

    /// The scroll wheel flips the widget deck, so the wheel handler owns no
    /// selection state of its own: it asks the shared cycle policy for the next
    /// card and hands it to the runtime the host already observes.
    private func cycleWidgetDeck(
        _ direction: BrowserSidebarWidgetCarouselDirection
    ) {
        guard let widgetRuntime else { return }
        let instances = widgetRuntime.instances(capabilities: widgetCapabilities)
        guard instances.count > 1,
            let nextID = direction.adjacentID(
                to: widgetRuntime.carouselSelection,
                in: instances
            )
        else { return }
        withAnimation(
            CrestMotion.spaceSwipe.unlessReducingMotion(reduceMotion)
        ) {
            widgetRuntime.selectCarouselInstance(
                nextID,
                visibleInstances: instances
            )
        }
    }

    private var switcherAccessories: BrowserSpaceSwitcherAccessories {
        BrowserSpaceSwitcherAccessories(
            commonLists: BrowserSpaceSwitcherCommonLists(
                isExpanded: context.utilityPresentation.isSwitcherExpanded,
                toggle: context.toggleUtilitySwitcher,
                recordTriggerFrame:
                    context.utilityPresentation.recordTriggerFrame
            ),
            spaceMenu: BrowserSpaceSwitcherSpaceMenu(
                edit: { id in
                    guard let space = context.availableSpaces.first(where: { $0.id == id }) else { return }
                    context.chromeActions.presentSpaceSettings(BrowserSpaceRuntimeAssignment(space: space))
                },
                create: context.chromeActions.createSpace
            ),
            newItems: BrowserSpaceSwitcherNewItems(
                newTab: openNewTab,
                newSplit: addsToShownSpace(openNewSplit),
                createFolder: addsToShownSpace(createFolder),
                createSpace: context.chromeActions.createSpace
            )
        )
    }

    /// `action`, where the Space on show takes new tabs and folders: it is
    /// there and unlocked.
    private func addsToShownSpace(_ action: @escaping () -> Void) -> (() -> Void)? {
        context.browser.showsSelectedSpaceActions(accessController: context.spaceAccess) ? action : nil
    }

    /// Opens a new tab beside the selected one, the two in a split.
    private func openNewSplit() {
        let browser = context.browser
        guard let space = browser.shownSpace, let selectedTabID = browser.selectedTabID(in: space.id),
            let newTabID = browser.openNewTab()
        else { return }
        _ = browser.addTabToSplit(
            BrowserTabDragItem(tabID: newTabID, spaceID: space.id, profileID: space.profileID),
            joining: selectedTabID,
            at: nil
        )
        pages.select()
    }

    /// Adds a folder to the Space on show and starts naming it, as the
    /// sidebar's own New Folder does.
    private func createFolder() {
        guard let space = context.browser.shownSpace else { return }
        let assignment = BrowserSpaceRuntimeAssignment(space: space)
        guard let folderID = context.browser.addFolder(matching: assignment) else { return }
        context.browser.setSavedTabsExpanded(true, matching: assignment)
        context.sidebarInteraction.editingFolderRequest = BrowserFolderRuntimeAssignment(
            folderID: folderID,
            spaceID: assignment.spaceID,
            profileID: assignment.profileID
        )
    }
}

/// Bridges the widget deck's scroll-wheel handling into SwiftUI. AppKit stays on
/// the macOS side of the app; the shared deck knows only about a cycle direction.
struct BrowserSidebarWidgetDeckScrollMonitor: NSViewRepresentable {
    let cycle: @MainActor (BrowserSidebarWidgetCarouselDirection) -> Void

    func makeNSView(context: Context) -> BrowserSidebarWidgetDeckScrollObserverView {
        BrowserSidebarWidgetDeckScrollObserverView(cycle: cycle)
    }

    func updateNSView(
        _ nsView: BrowserSidebarWidgetDeckScrollObserverView,
        context: Context
    ) {
        nsView.cycle = cycle
    }

    static func dismantleNSView(
        _ nsView: BrowserSidebarWidgetDeckScrollObserverView,
        coordinator: ()
    ) {
        nsView.stopMonitoring()
    }
}

/// One scroll event, reduced to what the deck's segmentation actually reads.
///
/// `beginsGesture`, `endsGesture`, and `isMomentum` are *hints*. A Magic Mouse and
/// some forwarded trackpad streams deliver precise deltas with an empty `phase`,
/// so nothing here may depend on a phase ever arriving.
struct BrowserSidebarWidgetDeckScrollInput: Equatable {
    let deltaY: CGFloat
    let timestamp: TimeInterval
    let isPrecise: Bool
    var beginsGesture = false
    var endsGesture = false
    var isMomentum = false
}

/// Turns wheel and trackpad scrolling into single card flips.
///
/// Precise (trackpad, Magic Mouse) deltas accumulate until they clear
/// `continuousThreshold`, then latch so one flick advances exactly one card and
/// the momentum tail advances none. Because a phase-less device never sends the
/// `.ended` that would clear that latch, two independent boundaries reset it: a
/// quiet gap longer than `gestureGap` starts a new gesture, and the latch itself
/// expires `gestureGap` after the flip it armed. The latch can therefore degrade
/// into a rate limiter but can never become a permanent block.
///
/// A wheel produces discrete notches with no phase at all, so those are rate
/// limited by `discreteInterval` instead and never latch.
struct BrowserSidebarWidgetDeckScrollAccumulator {
    static let continuousThreshold: CGFloat = 30
    static let gestureGap: TimeInterval = 0.3
    static let discreteInterval: TimeInterval = 0.12

    private var accumulated: CGFloat = 0
    private var isLatched = false
    private var lastContinuousTimestamp: TimeInterval?
    private var lastFlipTimestamp: TimeInterval?
    private var lastDiscreteTimestamp: TimeInterval?

    mutating func reset() {
        self = Self()
    }

    mutating func consume(
        _ input: BrowserSidebarWidgetDeckScrollInput
    ) -> BrowserSidebarWidgetCarouselDirection? {
        input.isPrecise ? consumeContinuous(input) : consumeDiscrete(input)
    }

    private mutating func consumeContinuous(
        _ input: BrowserSidebarWidgetDeckScrollInput
    ) -> BrowserSidebarWidgetCarouselDirection? {
        let hasGap =
            lastContinuousTimestamp.map {
                input.timestamp - $0 > Self.gestureGap
            } ?? true
        if input.beginsGesture || hasGap {
            accumulated = 0
            isLatched = false
        }
        lastContinuousTimestamp = input.timestamp

        if input.endsGesture {
            accumulated = 0
            isLatched = false
            return nil
        }
        guard !input.isMomentum else { return nil }
        if isLatched {
            guard let lastFlipTimestamp,
                input.timestamp - lastFlipTimestamp > Self.gestureGap
            else { return nil }
            isLatched = false
            accumulated = 0
        }
        accumulated += input.deltaY
        guard abs(accumulated) >= Self.continuousThreshold else { return nil }
        let direction = Self.direction(forDeltaY: accumulated)
        accumulated = 0
        isLatched = true
        lastFlipTimestamp = input.timestamp
        return direction
    }

    private mutating func consumeDiscrete(
        _ input: BrowserSidebarWidgetDeckScrollInput
    ) -> BrowserSidebarWidgetCarouselDirection? {
        guard input.deltaY != 0 else { return nil }
        if let lastDiscreteTimestamp,
            input.timestamp - lastDiscreteTimestamp < Self.discreteInterval
        {
            return nil
        }
        lastDiscreteTimestamp = input.timestamp
        return Self.direction(forDeltaY: input.deltaY)
    }

    /// Scrolling the content up brings the next card forward, matching how a
    /// scroll advances any other vertical list.
    static func direction(
        forDeltaY deltaY: CGFloat
    ) -> BrowserSidebarWidgetCarouselDirection {
        deltaY < 0 ? .next : .previous
    }
}

/// Watches scroll events over the widget area and hands the qualifying ones to
/// the accumulator. Every consumed event is swallowed so nothing behind scrolls.
@MainActor
final class BrowserSidebarWidgetDeckScrollObserverView: NSView {
    var cycle: @MainActor (BrowserSidebarWidgetCarouselDirection) -> Void
    private var eventMonitor: Any?
    private var accumulator = BrowserSidebarWidgetDeckScrollAccumulator()

    init(cycle: @escaping @MainActor (BrowserSidebarWidgetCarouselDirection) -> Void) {
        self.cycle = cycle
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateEventMonitor()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func stopMonitoring() {
        guard let eventMonitor else { return }
        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
        accumulator.reset()
    }

    private func updateEventMonitor() {
        stopMonitoring()
        guard window != nil else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .scrollWheel
        ) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard event.window === window,
            containsWindowLocation(event.locationInWindow),
            abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX)
        else { return event }

        let input = BrowserSidebarWidgetDeckScrollInput(
            deltaY: event.scrollingDeltaY,
            timestamp: event.timestamp,
            isPrecise: event.hasPreciseScrollingDeltas,
            beginsGesture: event.phase.contains(.began),
            endsGesture: event.phase.contains(.ended)
                || event.phase.contains(.cancelled),
            isMomentum: !event.momentumPhase.isEmpty
        )
        if let direction = accumulator.consume(input) {
            cycle(direction)
        }
        return nil
    }

    private func containsWindowLocation(_ locationInWindow: NSPoint) -> Bool {
        guard bounds.width > 0, bounds.height > 0 else { return false }
        return bounds.contains(convert(locationInWindow, from: nil))
    }
}

#Preview("Browser Sidebar — Tabs") {
    @Previewable @State var address = "https://developer.apple.com"
    @Previewable @State var isAddressEditing = false
    @Previewable @Namespace var commandSurfaceNamespace
    @Previewable @Namespace var tabPromotionNamespace
    let browser = BrowserSidebarPreviewFixture.makeBrowser()
    let pages = BrowserSidebarPreviewFixture.makePages(for: browser)
    let spaceAccess = BrowserSidebarPreviewFixture.makeSpaceAccess()
    BrowserSidebar(
        browser: browser,
        pageAccess: BrowserSidebarPageAccess(pages: pages, browser: browser, spaceAccess: spaceAccess),
        spaceAccess: spaceAccess,
        capabilities: BrowserInteractionCapabilities(),
        utilityCoordinator: BrowserSidebarUtilityCoordinator(
            browser: browser,
            pages: pages,
            spaceAccess: spaceAccess
        ),
        utilityPresentation:
            BrowserSidebarPreviewFixture.makeUtilityPresentation(),
        chromeActions: BrowserSidebarPreviewFixture.makeChromeActions()
    ) { context in
        BrowserSidebarLoadedContent(
            context: context,
            pages: pages,
            address: $address,
            isAddressEditing: $isAddressEditing,
            addressFocusRequest: 0,
            activateAddress: { isAddressEditing = true },
            submitAddress: {},
            openNewTab: {},
            expandSidebar: {},
            sidebarToggleAction: .hide,
            toggleSidebar: {},
            commandSurfaceNamespace: commandSurfaceNamespace,
            commandPaletteHandoff: .neither,
            tabPromotionNamespace: tabPromotionNamespace
        )
    }
    .environment(BrowserSidebarInteractionState.connected(to: browser))
    .frame(width: BrowserChromeLayout.sidebarIdealWidth, height: 680)
}
