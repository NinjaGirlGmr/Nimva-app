import Foundation
import SwiftData

@Model
final class Intention {
    var id: UUID = UUID()
    var text: String = ""
    var weekOf: Date = Date()     // normalized to the Monday of the week it was created
    var createdAt: Date = Date()

    init(text: String, weekOf: Date) {
        self.id = UUID()
        self.text = text
        self.weekOf = weekOf
        self.createdAt = Date()
    }
}
