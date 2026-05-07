import SwiftUI

public struct Swift100kView<P: Swift100kDataProvider, Row: View>: View {
    @State private var viewModel: Swift100kViewModel<P>
    @State private var isInitialAnchorReady = false
    private let rowBuilder: (P.Item) -> Row
    private let initialIndex: Int
    private let autoLoadMore: Bool
    private let debugEnabled: Bool

    public init(
        provider: P,
        initialIndex: Int = 0,
        pageSize: Int = 50,
        maxWindowSize: Int = 180,
        prefetchThreshold: Int = 20,
        prefetchPagesAhead: Int = 2,
        autoLoadMore: Bool = true,
        debugEnabled: Bool = false,
        @ViewBuilder row: @escaping (P.Item) -> Row
    ) {
        _viewModel = State(
            initialValue: Swift100kViewModel(
            provider: provider,
            pageSize: pageSize,
            maxWindowSize: maxWindowSize,
            prefetchThreshold: prefetchThreshold,
            prefetchPagesAhead: prefetchPagesAhead,
            debugEnabled: debugEnabled
        )
        )
        self.initialIndex = initialIndex
        self.autoLoadMore = autoLoadMore
        self.debugEnabled = debugEnabled
        self.rowBuilder = row
    }

    public init(
        provider: P,
        initialIndex: Int = 0,
        performanceMode: WindowedListPerformanceMode,
        autoLoadMore: Bool = true,
        debugEnabled: Bool = false,
        @ViewBuilder row: @escaping (P.Item) -> Row
    ) {
        _viewModel = State(
            initialValue: Swift100kViewModel(
            provider: provider,
            pageSize: performanceMode.pageSize,
            maxWindowSize: performanceMode.maxWindowSize,
            prefetchThreshold: performanceMode.prefetchThreshold,
            prefetchPagesAhead: performanceMode.prefetchPagesAhead,
            debugEnabled: debugEnabled
        )
        )
        self.initialIndex = initialIndex
        self.autoLoadMore = autoLoadMore
        self.debugEnabled = debugEnabled
        self.rowBuilder = row
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if autoLoadMore && viewModel.canLoadTop {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                guard isInitialAnchorReady else { return }
                                Task { await viewModel.autoPrefetchTop() }
                            }
                    }

                    if viewModel.startIndex == 0 {
                        Color.clear
                            .frame(height: 1)
                            .id("top-state-\(viewModel.startIndex)")
                    }

                    ForEach(viewModel.visibleItems) { item in
                        rowBuilder(item)
                            .id(item.id)
                    }

                    if autoLoadMore && viewModel.canLoadBottom {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                guard isInitialAnchorReady else { return }
                                Task { await viewModel.autoPrefetchBottom() }
                            }
                            .id("bottom-trigger-\(viewModel.startIndex + viewModel.visibleItems.count)")
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .onChange(of: viewModel.scrollTargetID) { _, targetID in
                guard let targetID else { return }
                Task { @MainActor in
                    await Task.yield()
                    if viewModel.scrollTargetAnimated {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(targetID, anchor: viewModel.scrollTargetAnchorIsTop ? .top : .bottom)
                        }
                    } else {
                        proxy.scrollTo(targetID, anchor: viewModel.scrollTargetAnchorIsTop ? .top : .bottom)
                    }
                    viewModel.clearScrollTarget()
                }
            }
            .task {
                await viewModel.initialLoad(around: initialIndex)
                guard initialIndex == 0 else {
                    isInitialAnchorReady = true
                    return
                }
                await Task.yield()
                proxy.scrollTo("top-state-0", anchor: .top)
                isInitialAnchorReady = true
            }
        }
        .overlay(alignment: .top) {
            if viewModel.isLoadingTop {
                ProgressView().padding(.top, 8)
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.isLoadingBottom {
                ProgressView().padding(.bottom, 8)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if debugEnabled {
                DebugOverlay(summary: viewModel.debugVisibleSummary, lastEvent: viewModel.debugLastEvent)
            }
        }
    }
}

private struct DebugOverlay: View {
    let summary: String
    let lastEvent: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary)
                .font(.caption2.monospaced())
                .foregroundStyle(.primary)
            if !lastEvent.isEmpty {
                Text(lastEvent)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(8)
    }
}
