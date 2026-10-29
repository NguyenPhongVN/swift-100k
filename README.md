# Swift100k

`Swift100k` is a binary Swift Package (`.xcframework`) for iOS that renders very large message lists (100k–1M+ items) using a windowed, cell-recycling `UICollectionView` core exposed to SwiftUI.

## Requirements

- iOS 17+
- Xcode 26.4+ (Swift 6.3.1+). Built and verified with Xcode 26.6 (Swift 6.3.3). The artifact has library evolution enabled, but older Xcode versions (15/16) are not supported.
- Swift tools 5.9+

## Installation (Swift Package Manager)

### Xcode

1. Open your project in Xcode.
2. Go to **File > Add Package Dependencies...**
3. Enter repository URL: `https://github.com/NguyenPhongVN/swift-100k`
4. Select product: `Swift100k`

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/NguyenPhongVN/swift-100k", from: "1.1.0")
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

Import with the product name — the `Swift100k` target re-exports everything from the binary module:

```swift
import Swift100k
```

### 1) Model

```swift
struct ChatMessage: Identifiable, Hashable, Equatable, Sendable {
    let id: Int
    var text: String
}
```

### 2) Data source

`ListDataSource` tracks incremental changes for efficient updates. Always mutate an existing instance (`.apply(...)`, `prepend(...)`, `append(...)`) — replacing it with a new instance triggers a full reload and loses scroll position.

```swift
@State private var dataSource = ListDataSource<ChatMessage>()

// Efficient diff-based update:
dataSource.apply(newMessages)
```

### 3) Render the list

```swift
struct ChatView: View {
    @State private var dataSource = ListDataSource<ChatMessage>(items: messages)
    @State private var scrollPosition = TiledScrollPosition(scrollsToBottomOnReplace: false)

    var body: some View {
        Swift100kView(
            dataSource: dataSource,
            scrollPosition: $scrollPosition
        ) { item in
            MessageCell(item: item)
        }
    }
}
```

### 4) Cell content

Cells conform to `TiledCellContent`. Use `CellContext` for per-cell state that survives cell reuse (`@State` is lost when `UICollectionView` recycles a cell):

```swift
struct MessageCell: TiledCellContent {
    typealias StateValue = Void

    let item: ChatMessage

    func body(context: CellContext<Void>) -> some View {
        Text(item.text)
    }
}
```

### 5) Loading older/newer pages

Windowed paging is built in via `.prependLoader` / `.appendLoader`:

```swift
Swift100kView(
    dataSource: dataSource,
    scrollPosition: $scrollPosition
) { item in
    MessageCell(item: item)
}
.prependLoader(hasOlder ? .loader(perform: {
    await loadOlder()
}) {
    ProgressView()
    .padding(.vertical, 8)
} : nil)
.appendLoader(hasNewer ? .loader(perform: {
    await loadNewer()
}) {
    ProgressView()
    .padding(.vertical, 8)
} : nil)
```

### Supplementary views

```swift
.typingIndicator(.indicator(isVisible: isTyping) { TypingBubbleView() })
.headerContent(.header { Text("Start of conversation") })
```

## Main APIs

- `Swift100kView`: the list view (renamed from `MessageUI100k` in 1.1.0 so the module supports library evolution).
- `ListDataSource<Item>`: change-tracking data source (diff-based `apply`, `prepend`, `append`).
- `TiledCellContent`: protocol for cell content, with `CellContext` for reveal offset and per-cell state (`CellStateStorage`).
- `TiledScrollPosition` / `TiledScrollGeometry` / `ScrollViewGeometry`: scroll position binding and geometry observation.
- `Loader`, `TypingIndicator`, `HeaderContent`: supplementary views added via modifiers.
- `RevealConfiguration`: swipe-to-reveal configuration (`CellReveal`, `rubberBand`).
- `withPrerender`: prerendering helper.

## Verify binary checksum (maintainers)

When replacing or publishing a new binary artifact, compute checksum from the exact zip file you upload:

```bash
swift package compute-checksum MessageUI100k.xcframework.zip
```

Then update `checksum` in `Package.swift`.

## Building the artifact (maintainers)

The framework source lives in a separate project (`MessageUI100k.xcodeproj`). Build with **library evolution enabled** so consumers on compatible toolchains can import the module:

```bash
BUILD_LIBRARY_FOR_DISTRIBUTION=YES ./scripts/build_xcframework.sh
cd build
zip -r MessageUI100k.xcframework.zip MessageUI100k.xcframework
swift package compute-checksum MessageUI100k.xcframework.zip
```

**Important:** do not declare a public type with the same name as the module (`MessageUI100k`). Library-evolution `.swiftinterface` files resolve `MessageUI100k.X` against the type instead of the module, and interface verification fails. In 1.1.0 the view was renamed `MessageUI100k` → `Swift100kView` for this reason.

Release flow: commit + push the updated `Package.swift` (version + checksum), then `gh release create <version> MessageUI100k.xcframework.zip`.

## Common issues

**"compiled module was created by a different version of the compiler"**

The imported artifact was built without library evolution and is locked to the exact compiler that built it. Fixed in 1.1.0; use a rebuilt artifact (built with `BUILD_LIBRARY_FOR_DISTRIBUTION=YES`) or match the Xcode version used to build it.

**Checksum mismatch on resolve**

1. Ensure `Package.swift` checksum matches the uploaded zip file.
2. Do not reuse the same release asset URL after replacing file content — publish a new release instead.
3. Clear SwiftPM/Xcode cache and resolve again.

Useful cleanup commands:

```bash
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf .build
```

In Xcode, also run:

- `File > Packages > Reset Package Caches`
- `File > Packages > Resolve Package Versions`
