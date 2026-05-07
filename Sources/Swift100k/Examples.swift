import SwiftUI

private struct HugeRecord: Identifiable, Equatable, Sendable {
    public let id: Int
    public let title: String
    public let subtitle: String

    public init(id: Int, title: String, subtitle: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}

private struct HugeRecordProvider: Swift100kDataProvider {
    public typealias Item = HugeRecord
    public let items: [HugeRecord]

    public init(totalCount: Int = 100_000) {
        self.items = (0..<totalCount).map {
            HugeRecord(id: $0, title: "Record \($0)", subtitle: "Metadata \($0 % 100)")
        }
    }
}

private struct ExamplesView: View {
    @State private var selectedSize: Int = 100_000
    @State private var startDate: Date?
    @State private var firstRowDate: Date?

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            Picker("Dataset", selection: $selectedSize) {
                Text("100k").tag(100_000)
                Text("500k").tag(500_000)
                Text("1M").tag(1_000_000)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            metricsBar

            benchmarkList
                .id(selectedSize)
                .onAppear {
                    startDate = Date()
                    firstRowDate = nil
                }
        }
    }

    @ViewBuilder
    private var benchmarkList: some View {
        let provider = HugeRecordProvider(totalCount: selectedSize)

        Swift100kView(
            provider: provider,
            initialIndex: 0,
            pageSize: 100,
            maxWindowSize: 320,
            prefetchThreshold: 24,
            prefetchPagesAhead: 1,
            autoLoadMore: true,
            debugEnabled: true
        ) { item in
            HStack {
                Text(item.title)
                    .font(.body)
                Spacer(minLength: 8)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .onAppear {
                if firstRowDate == nil {
                    firstRowDate = Date()
                }
            }
        }
    }

    private var metricsBar: some View {
        HStack(spacing: 16) {
            Text("Rows: \(selectedSize.formatted())")
            if let startDate, let firstRowDate {
                Text("First paint: \(firstRowDate.timeIntervalSince(startDate), format: .number.precision(.fractionLength(3)))s")
            } else {
                Text("First paint: measuring...")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption.monospaced())
        .padding(.horizontal)
    }
}

#Preview {
    ExamplesView()
}
