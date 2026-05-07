# Swift100k

`Swift100k` is a SwiftUI list component for very large datasets (100k to 1M+ rows) using a windowed loading strategy.

It keeps only a small visible window in memory, supports loading more from top/bottom, and works with array-based data providers.

## Requirements

- Swift 6
- iOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 1+

## Install with Swift Package Manager

In Xcode:

1. Open your project.
2. Go to **File > Add Package Dependencies...**
3. Enter your repository URL.
4. Select product `Swift100k`.

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/NguyenPhongVN/swift-100k", branch: "main")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "Swift100k", package: "swift-100k")
        ]
    )
]
```

## Quick Start

### 1) Create a data provider

Conform to `Swift100kDataProvider`:

```swift
import SwiftUI
import Swift100k

struct RowItem: Identifiable, Sendable {
    let id: Int
    let title: String
}

struct RowProvider: Swift100kDataProvider {
    let items: [RowItem]
}
```

### 2) Render `Swift100kView`

```swift
import SwiftUI
import Swift100k

struct ContentView: View {
    private let provider = RowProvider(
        items: (0..<1_000_000).map { RowItem(id: $0, title: "Row \($0)") }
    )

    var body: some View {
        Swift100kView(
            provider: provider,
            initialIndex: 0,
            performanceMode: .ultraLargeData,
            debugEnabled: true
        ) { item in
            Text(item.title)
        }
    }
}
```

## Main APIs

- `Swift100kView`: windowed large-list SwiftUI component.
- `Swift100kDataProvider`: protocol for array-based providers.
- `Swift100kArrayDataProvider`: ready-made provider for in-memory arrays.
- `WindowedListPerformanceMode`: presets (`balanced`, `largeData`, `ultraLargeData`).

## Performance Tips

- Use `Swift100kArrayDataProvider` when you already have `[Item]` in memory.
- Start with `.ultraLargeData` for 500k+ datasets.
- Keep row views lightweight (avoid heavy view trees or expensive modifiers).

## Behavior Notes

- `initialIndex` controls first visible section of data.
- Use `initialIndex: 0` to open at the first rows.
- Top row shows `Reached top` when `startIndex == 0`.
- Load-more buttons handle top and bottom paging explicitly.

## Local Development

```bash
swift build
swift test
```
