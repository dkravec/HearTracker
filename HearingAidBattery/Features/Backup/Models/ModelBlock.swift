import Foundation

struct ModelBlock<T: Codable>: Codable {
    let version: Int
    let items: [T]
}
