import SwiftUI

public enum WindowedListPerformanceMode: Sendable {
    case balanced
    case largeData
    case ultraLargeData

    var pageSize: Int {
        switch self {
        case .balanced: return 60
        case .largeData: return 100
        case .ultraLargeData: return 220
        }
    }

    var maxWindowSize: Int {
        switch self {
        case .balanced: return 180
        case .largeData: return 180
        case .ultraLargeData: return 520
        }
    }

    var prefetchThreshold: Int {
        switch self {
        case .balanced: return 20
        case .largeData: return 24
        case .ultraLargeData: return 60
        }
    }

    var prefetchPagesAhead: Int {
        switch self {
        case .balanced: return 1
        case .largeData: return 1
        case .ultraLargeData: return 2
        }
    }

    var cachePageSize: Int {
        switch self {
        case .balanced: return 80
        case .largeData: return 100
        case .ultraLargeData: return 240
        }
    }

    var maxCachedPages: Int {
        switch self {
        case .balanced: return 24
        case .largeData: return 48
        case .ultraLargeData: return 64
        }
    }
}

public protocol Swift100kDataProvider: Sendable {
    associatedtype Item: Identifiable & Sendable
    var items: [Item] { get }
}

enum ScrollDirection {
    case up
    case down
    case none
}

enum ScrollAnchor {
    case top
    case bottom
}

extension Range where Bound == Int {
    func clamped(to count: Int) -> Range<Int>? {
        guard !isEmpty else { return nil }
        let lower = Swift.max(0, lowerBound)
        let upper = Swift.min(count, upperBound)
        guard lower < upper else { return nil }
        return lower..<upper
    }
}
