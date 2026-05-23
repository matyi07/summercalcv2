import Foundation
import SwiftData

enum EventNoteType: String, Codable, CaseIterable {
    case general
    case prep
    case checklist
    case link
    case postEvent
    case aiSummary
}

@Model
final class EventNote {
    @Attribute(.unique) var id: UUID
    var eventId: UUID
    var body: String
    var noteType: EventNoteType
    var checklistItemsJSON: String?
    var linksJSON: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        eventId: UUID,
        body: String,
        noteType: EventNoteType = .general,
        checklistItemsJSON: String? = nil,
        linksJSON: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.eventId = eventId
        self.body = body
        self.noteType = noteType
        self.checklistItemsJSON = checklistItemsJSON
        self.linksJSON = linksJSON
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var checklistItems: [String] {
        get {
            guard let json = checklistItemsJSON,
                  let data = json.data(using: .utf8),
                  let items = try? JSONDecoder().decode([String].self, from: data)
            else { return [] }
            return items
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8)
            else { return }
            checklistItemsJSON = json
        }
    }

    var links: [String] {
        get {
            guard let json = linksJSON,
                  let data = json.data(using: .utf8),
                  let items = try? JSONDecoder().decode([String].self, from: data)
            else { return [] }
            return items
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8)
            else { return }
            linksJSON = json
        }
    }
}
