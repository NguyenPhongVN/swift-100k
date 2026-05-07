import SwiftUI
import Observation
import Foundation

@MainActor
@Observable
public final class Swift100kViewModel<P: Swift100kDataProvider> {
    public private(set) var visibleItems: [P.Item] = []
    public private(set) var startIndex: Int = 0
    public private(set) var isLoadingTop = false
    public private(set) var isLoadingBottom = false
    public private(set) var scrollTargetID: P.Item.ID?
    public private(set) var scrollTargetAnimated: Bool = true
    public private(set) var scrollTargetAnchorIsTop: Bool = true
    public private(set) var logicalTotalCount: Int
    public private(set) var debugLastEvent: String = ""

    private let provider: P
    private let pageSize: Int
    private let maxWindowSize: Int
    private let prefetchThreshold: Int
    private let prefetchPagesAhead: Int
    private var indexByID: [P.Item.ID: Int] = [:]
    private var wasNearTop = false
    private var wasNearBottom = false
    private var lastAppearedGlobalIndex: Int?
    private var lastDirection: ScrollDirection = .none
    private var lastTopLoadTime: Date?
    private var lastBottomLoadTime: Date?
    private var lastTopLoadStartSnapshot: Int?
    private var lastBottomLoadEndSnapshot: Int?
    private var isTrimScheduled = false
    private var isMutatingWindow = false
    private let loadCooldown: TimeInterval = 0.25
    private let debugEnabled: Bool
    private var trimTriggerSize: Int { maxWindowSize + pageSize }

    public init(
        provider: P,
        pageSize: Int = 50,
        maxWindowSize: Int = 180,
        prefetchThreshold: Int = 20,
        prefetchPagesAhead: Int = 2,
        debugEnabled: Bool = false
    ) {
        self.provider = provider
        self.pageSize = pageSize
        self.maxWindowSize = maxWindowSize
        self.prefetchThreshold = prefetchThreshold
        self.prefetchPagesAhead = max(1, prefetchPagesAhead)
        self.logicalTotalCount = provider.items.count
        self.debugEnabled = debugEnabled
        log("init totalCount=\(provider.items.count)")
    }

    public func initialLoad(around initialIndex: Int = 0) async {
        guard visibleItems.isEmpty else { return }
        log("initialLoad around=\(initialIndex)")
        await jumpToIndex(initialIndex)
    }

    public func onItemAppear(_ item: P.Item) async {
        guard let localIndex = indexByID[item.id] else { return }
        let globalIndex = startIndex + localIndex
        updateScrollDirection(with: globalIndex)

        let distanceToTop = localIndex
        let distanceToBottom = (visibleItems.count - 1) - localIndex
        let nearTop = distanceToTop <= prefetchThreshold
        let nearBottom = distanceToBottom <= prefetchThreshold
        log("onItemAppear global=\(globalIndex) local=\(localIndex) nearTop=\(nearTop) nearBottom=\(nearBottom)")

        if !nearTop { wasNearTop = false }
        if !nearBottom { wasNearBottom = false }

        if nearTop && nearBottom {
            switch lastDirection {
            case .up:
                if !wasNearTop { wasNearTop = true; await loadTop(pages: prefetchPagesAhead) }
            case .down, .none:
                if !wasNearBottom { wasNearBottom = true; await loadBottom(pages: prefetchPagesAhead) }
            }
            return
        }

        if nearBottom {
            if !wasNearBottom { wasNearBottom = true; await loadBottom(pages: prefetchPagesAhead) }
            return
        }

        if nearTop, !wasNearTop {
            wasNearTop = true
            await loadTop(pages: prefetchPagesAhead)
        }
    }

    public func loadBottom() async {
        await loadBottom(pages: 1)
    }

    public func loadBottom(pages: Int) async {
        let safePages = max(1, pages)
        for _ in 0..<safePages {
            let loaded = await loadBottomPage()
            if !loaded { break }
        }
    }

    public func autoPrefetchBottom() async {
        await loadBottom(pages: prefetchPagesAhead)
    }

    @discardableResult
    private func loadBottomPage() async -> Bool {
        guard !isLoadingBottom, !isMutatingWindow else { return false }
        let endExclusive = startIndex + visibleItems.count
        guard canTriggerBottomLoad(endExclusive: endExclusive) else { return false }
        guard endExclusive < logicalTotalCount else {
            log("loadBottom skipped: reached end endExclusive=\(endExclusive), logicalTotal=\(logicalTotalCount)")
            return false
        }

        let nextStart = endExclusive
        let nextEnd = min(nextStart + pageSize, logicalTotalCount)
        guard nextStart < nextEnd else { return false }

        var didLoad = false
        isMutatingWindow = true
        defer { isMutatingWindow = false }
        await withLoading(.bottom) {
            log("loadBottom fetch range=\(nextStart)..<\(nextEnd)")
            let preserveBottomID = visibleItems.last?.id
            let chunk = fetch(range: nextStart..<nextEnd)
            guard !chunk.isEmpty else { return }

            visibleItems.append(contentsOf: chunk)
            rebuildIndexMap()
            await scheduleTrimIfNeeded(preferredDirection: .down)
            preserveViewport(targetID: preserveBottomID, fallback: visibleItems.last?.id, anchor: .bottom)
            markBottomLoaded(endExclusive: endExclusive)
            log("loadBottom appended=\(chunk.count), visible=\(visibleItems.count), start=\(startIndex), logicalTotal=\(logicalTotalCount)")
            didLoad = true
        }
        return didLoad
    }

    public func loadTop() async {
        await loadTop(pages: 1)
    }

    public func loadTop(pages: Int) async {
        let safePages = max(1, pages)
        for _ in 0..<safePages {
            let loaded = await loadTopPage()
            if !loaded { break }
        }
    }

    public func autoPrefetchTop() async {
        await loadTop(pages: prefetchPagesAhead)
    }

    @discardableResult
    private func loadTopPage() async -> Bool {
        guard !isLoadingTop, !isMutatingWindow else { return false }
        guard canTriggerTopLoad(start: startIndex) else { return false }
        guard startIndex > 0 else { return false }

        let newStart = max(0, startIndex - pageSize)
        guard newStart < startIndex else { return false }

        var didLoad = false
        isMutatingWindow = true
        defer { isMutatingWindow = false }
        await withLoading(.top) {
            log("loadTop fetch range=\(newStart)..<\(startIndex)")
            let preserveTopID = visibleItems.first?.id
            let chunk = fetch(range: newStart..<startIndex)
            guard !chunk.isEmpty else { return }

            visibleItems.insert(contentsOf: chunk, at: 0)
            startIndex = newStart
            rebuildIndexMap()
            await scheduleTrimIfNeeded(preferredDirection: .up)
            preserveViewport(targetID: preserveTopID, fallback: visibleItems.first?.id, anchor: .top)
            markTopLoaded(start: startIndex)
            log("loadTop prepended=\(chunk.count), visible=\(visibleItems.count), start=\(startIndex)")
            didLoad = true
        }
        return didLoad
    }

    public func jumpToIndex(_ index: Int) async {
        guard logicalTotalCount > 0 else {
            visibleItems = []
            startIndex = 0
            rebuildIndexMap()
            return
        }

        let clamped = min(max(0, index), logicalTotalCount - 1)
        let half = maxWindowSize / 2
        var newStart = max(0, clamped - half)
        let maxStart = max(0, logicalTotalCount - maxWindowSize)
        newStart = min(newStart, maxStart)
        let newEnd = min(newStart + maxWindowSize, logicalTotalCount)
        guard newStart < newEnd else { return }

        isLoadingTop = true
        isLoadingBottom = true
        defer {
            isLoadingTop = false
            isLoadingBottom = false
        }

        let window = fetch(range: newStart..<newEnd)
        visibleItems = window
        startIndex = newStart
        rebuildIndexMap()
        let localTarget = clamped - newStart
        if visibleItems.indices.contains(localTarget) {
            scrollTargetID = visibleItems[localTarget].id
        }
        wasNearTop = false
        wasNearBottom = false
        lastAppearedGlobalIndex = nil
        lastDirection = .none
        log("jumpToIndex loaded range=\(newStart)..<\(newEnd), visible=\(visibleItems.count), target=\(clamped)")
    }

    public func clearScrollTarget() {
        scrollTargetID = nil
        scrollTargetAnimated = true
        scrollTargetAnchorIsTop = true
    }

    public var debugVisibleSummary: String {
        let count = visibleItems.count
        guard count > 0 else {
            return "Visible: 0 | Range: - | Total: \(logicalTotalCount)"
        }
        let end = startIndex + count - 1
        return "Visible: \(count) | Range: \(startIndex)-\(end) | Total: \(logicalTotalCount)"
    }

    public var canLoadTop: Bool {
        startIndex > 0 && !isLoadingTop
    }

    public var canLoadBottom: Bool {
        (startIndex + visibleItems.count) < logicalTotalCount && !isLoadingBottom
    }

    public func refresh() async {
        await jumpToIndex(startIndex)
    }

    public func insert(_ item: P.Item, at globalIndex: Int) {
        logicalTotalCount += 1
        let local = globalIndex - startIndex
        if local >= 0 && local <= visibleItems.count {
            visibleItems.insert(item, at: local)
            rebuildIndexMap()
            trimIfNeeded(preferredDirection: .none)
        } else if globalIndex < startIndex {
            startIndex += 1
        }
    }

    public func remove(id: P.Item.ID, globalIndex: Int?) {
        logicalTotalCount = max(0, logicalTotalCount - 1)
        if let idx = visibleItems.firstIndex(where: { $0.id == id }) {
            visibleItems.remove(at: idx)
            rebuildIndexMap()
            return
        }
        if let g = globalIndex, g < startIndex {
            startIndex = max(0, startIndex - 1)
        }
    }

    public func update(_ item: P.Item) {
        if let idx = indexByID[item.id] {
            visibleItems[idx] = item
        }
    }

    private func updateScrollDirection(with newGlobalIndex: Int) {
        defer { lastAppearedGlobalIndex = newGlobalIndex }
        guard let old = lastAppearedGlobalIndex else {
            lastDirection = .none
            return
        }
        if newGlobalIndex > old {
            lastDirection = .down
        } else if newGlobalIndex < old {
            lastDirection = .up
        } else {
            lastDirection = .none
        }
    }

    private func trimIfNeeded(preferredDirection: ScrollDirection) {
        guard visibleItems.count > trimTriggerSize else { return }
        let overflow = visibleItems.count - maxWindowSize
        guard overflow > 0 else { return }
        let trimCount = max(pageSize, overflow)

        switch preferredDirection {
        case .down:
            visibleItems.removeFirst(trimCount)
            startIndex += trimCount
        case .up:
            visibleItems.removeLast(trimCount)
        case .none:
            if lastDirection == .down {
                visibleItems.removeFirst(trimCount)
                startIndex += trimCount
            } else {
                visibleItems.removeLast(trimCount)
            }
        }
        rebuildIndexMap()
    }

    private func scheduleTrimIfNeeded(preferredDirection: ScrollDirection) async {
        guard !isTrimScheduled else {
            trimIfNeeded(preferredDirection: preferredDirection)
            return
        }
        isTrimScheduled = true
        await Task.yield()
        trimIfNeeded(preferredDirection: preferredDirection)
        isTrimScheduled = false
    }

    private func rebuildIndexMap() {
        indexByID.removeAll(keepingCapacity: true)
        indexByID.reserveCapacity(visibleItems.count)
        for (index, item) in visibleItems.enumerated() {
            indexByID[item.id] = index
        }
    }

    private func log(_ message: String) {
        guard debugEnabled else { return }
        debugLastEvent = message
        print("[BiDirectionalWindowedList] \(message)")
    }

    private enum LoadingSide {
        case top
        case bottom
    }

    private func withLoading(_ side: LoadingSide, operation: () async -> Void) async {
        switch side {
        case .top:
            isLoadingTop = true
            await operation()
            isLoadingTop = false
        case .bottom:
            isLoadingBottom = true
            await operation()
            isLoadingBottom = false
        }
    }

    private func preserveViewport(targetID: P.Item.ID?, fallback: P.Item.ID?, anchor: ScrollAnchor) {
        if let targetID, indexByID[targetID] != nil {
            setScrollTarget(targetID, animated: false, anchor: anchor)
            return
        }
        if let fallback {
            setScrollTarget(fallback, animated: false, anchor: anchor)
        }
    }

    private func setScrollTarget(_ id: P.Item.ID, animated: Bool, anchor: ScrollAnchor) {
        scrollTargetAnimated = animated
        scrollTargetAnchorIsTop = (anchor == .top)
        scrollTargetID = id
    }

    private func canTriggerTopLoad(start: Int) -> Bool {
        if lastTopLoadStartSnapshot == start, let lastTopLoadTime,
           Date().timeIntervalSince(lastTopLoadTime) < loadCooldown {
            return false
        }
        return true
    }

    private func canTriggerBottomLoad(endExclusive: Int) -> Bool {
        if lastBottomLoadEndSnapshot == endExclusive, let lastBottomLoadTime,
           Date().timeIntervalSince(lastBottomLoadTime) < loadCooldown {
            return false
        }
        return true
    }

    private func markTopLoaded(start: Int) {
        lastTopLoadStartSnapshot = start
        lastTopLoadTime = Date()
    }

    private func markBottomLoaded(endExclusive: Int) {
        lastBottomLoadEndSnapshot = endExclusive
        lastBottomLoadTime = Date()
    }

    private func fetch(range: Range<Int>) -> [P.Item] {
        guard let safeRange = range.clamped(to: provider.items.count) else { return [] }
        return Array(provider.items[safeRange])
    }
}
