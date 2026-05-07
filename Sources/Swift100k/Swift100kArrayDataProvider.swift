import Foundation

public struct Swift100kArrayDataProvider<Item: Identifiable & Sendable>: Swift100kDataProvider {
    public let items: [Item]

    public init(items: [Item]) {
        self.items = items
    }
}
