import SwiftUI
import SwiftData

@Observable
final class EventNoteViewModel {
    var notes: [EventNote] = []
    var generalNotes: [EventNote] { notes.filter { $0.noteType == .general } }
    var prepNotes: [EventNote] { notes.filter { $0.noteType == .prep } }
    var checklistNotes: [EventNote] { notes.filter { $0.noteType == .checklist } }
    var linkNotes: [EventNote] { notes.filter { $0.noteType == .link } }

    var isGeneratingPrep = false
    var generationError: String?

    func fetchNotes(for eventId: UUID, modelContext: ModelContext) {
        let descriptor = FetchDescriptor<EventNote>(
            predicate: #Predicate { $0.eventId == eventId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        notes = (try? modelContext.fetch(descriptor)) ?? []
    }

    func createNote(
        eventId: UUID,
        body: String,
        noteType: EventNoteType,
        checklistItems: [String],
        links: [String],
        modelContext: ModelContext
    ) {
        let note = EventNote(
            eventId: eventId,
            body: body,
            noteType: noteType
        )
        if !checklistItems.isEmpty {
            note.checklistItems = checklistItems
        }
        if !links.isEmpty {
            note.links = links
        }
        modelContext.insert(note)
        try? modelContext.save()
        fetchNotes(for: eventId, modelContext: modelContext)
    }

    func updateNote(
        _ note: EventNote,
        body: String,
        noteType: EventNoteType,
        checklistItems: [String],
        links: [String],
        modelContext: ModelContext
    ) {
        note.body = body
        note.noteType = noteType
        note.updatedAt = Date()
        if !checklistItems.isEmpty {
            note.checklistItems = checklistItems
        }
        if !links.isEmpty {
            note.links = links
        }
        try? modelContext.save()
        fetchNotes(for: note.eventId, modelContext: modelContext)
    }

    func deleteNote(_ note: EventNote, modelContext: ModelContext) {
        let eventId = note.eventId
        modelContext.delete(note)
        try? modelContext.save()
        fetchNotes(for: eventId, modelContext: modelContext)
    }

    func toggleChecklistItem(in note: EventNote, at index: Int, modelContext: ModelContext) {
        var items = note.checklistItems
        guard index < items.count else { return }
        var item = items[index]
        item = item.hasPrefix("[x] ") ? String(item.dropFirst(4)) : "[x] " + item
        items[index] = item
        note.checklistItems = items
        note.updatedAt = Date()
        try? modelContext.save()
    }

    func addChecklistItem(to note: EventNote, item: String, modelContext: ModelContext) {
        var items = note.checklistItems
        items.append("[ ] " + item)
        note.checklistItems = items
        note.updatedAt = Date()
        try? modelContext.save()
    }

    func addLink(to note: EventNote, url: String, modelContext: ModelContext) {
        var links = note.links
        links.append(url)
        note.links = links
        note.updatedAt = Date()
        try? modelContext.save()
    }

    func removeLink(from note: EventNote, at index: Int, modelContext: ModelContext) {
        var links = note.links
        guard index < links.count else { return }
        links.remove(at: index)
        note.links = links
        note.updatedAt = Date()
        try? modelContext.save()
    }

    func generatePrepNote(for eventId: UUID, modelContext: ModelContext) async {
        isGeneratingPrep = true
        generationError = nil

        try? await Task.sleep(nanoseconds: 1_500_000_000)

        let existingPrep = notes.filter { $0.noteType == .prep }
        if existingPrep.count < 3 {
            createNote(
                eventId: eventId,
                body: "Consider reviewing any materials and arriving 10 minutes early.",
                noteType: .prep,
                checklistItems: [],
                links: [],
                modelContext: modelContext
            )
        }

        isGeneratingPrep = false
    }
}
