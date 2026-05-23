import Foundation
import SwiftData

final class EventNoteService {
    func fetchNotes(for eventId: UUID, context: ModelContext) -> [EventNote] {
        let predicate = #Predicate<EventNote> { $0.eventId == eventId }
        let descriptor = FetchDescriptor<EventNote>(predicate: predicate, sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func addNote(eventId: UUID, body: String, type: EventNoteType = .general, checklistItems: [String] = [], links: [String] = [], context: ModelContext) {
        let note = EventNote(
            eventId: eventId,
            body: body,
            noteType: type,
            checklistItemsJSON: checklistItems.isEmpty ? nil : (try? String(data: JSONEncoder().encode(checklistItems), encoding: .utf8)),
            linksJSON: links.isEmpty ? nil : (try? String(data: JSONEncoder().encode(links), encoding: .utf8))
        )
        context.insert(note)
        try? context.save()
    }
    
    func deleteNote(_ note: EventNote, context: ModelContext) {
        context.delete(note)
        try? context.save()
    }
    
    func updateNote(_ note: EventNote, body: String, context: ModelContext) {
        note.body = body
        note.updatedAt = Date()
        try? context.save()
    }
    
    func addChecklistItem(to note: EventNote, item: String, context: ModelContext) {
        var items = note.checklistItems
        items.append(item)
        note.checklistItemsJSON = (try? String(data: JSONEncoder().encode(items), encoding: .utf8))
        note.updatedAt = Date()
        try? context.save()
    }
    
    func toggleChecklistItem(in note: EventNote, at index: Int, context: ModelContext) {
        var items = note.checklistItems
        guard index < items.count else { return }
        let item = items[index]
        let isChecked = item.hasPrefix("[x] ")
        if isChecked {
            items[index] = String(item.dropFirst(4))
        } else {
            items[index] = "[x] \(item)"
        }
        note.checklistItemsJSON = (try? String(data: JSONEncoder().encode(items), encoding: .utf8))
        note.updatedAt = Date()
        try? context.save()
    }
    
    func addLink(to note: EventNote, link: String, context: ModelContext) {
        var links = note.links
        links.append(link)
        note.linksJSON = (try? String(data: JSONEncoder().encode(links), encoding: .utf8))
        note.updatedAt = Date()
        try? context.save()
    }
    
    func removeLink(from note: EventNote, at index: Int, context: ModelContext) {
        var links = note.links
        guard index < links.count else { return }
        links.remove(at: index)
        note.linksJSON = links.isEmpty ? nil : (try? String(data: JSONEncoder().encode(links), encoding: .utf8))
        note.updatedAt = Date()
        try? context.save()
    }
    
    func notesForNotificationPreview(eventId: UUID, context: ModelContext) -> String {
        let notes = fetchNotes(for: eventId, context: context)
        return notes.prefix(2).map { $0.body }.joined(separator: ". ")
    }
}
