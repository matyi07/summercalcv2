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
        defer { isGeneratingPrep = false }
        let languageCode = UserSettings.current(in: modelContext).languageCode ?? "en"

        do {
            let settings = UserSettings.current(in: modelContext)
            let eventDescriptor = FetchDescriptor<CalendarEvent>(
                predicate: #Predicate { $0.id == eventId }
            )
            guard let event = try modelContext.fetch(eventDescriptor).first else {
                generationError = prepError("Event not found", languageCode: languageCode)
                return
            }

            fetchNotes(for: eventId, modelContext: modelContext)

            let providerKind = AIProviderKind.fromSettings(settings.aiProviderKind)
            let model = settings.aiModelName.isEmpty
                ? (providerKind?.defaultModel ?? "gpt-4o")
                : settings.aiModelName
            let config = AIRequestConfig(
                model: model,
                maxTokens: min(max(settings.aiMaxTokens, 512), 1600),
                temperature: 0.35,
                baseURL: settings.aiBaseURL
            )

            let messages = [
                AIMessage(
                    role: "system",
                    content: """
                    You write practical event-preparation notes for a personal calendar app. Be specific to the event details. Avoid generic advice unless the event context truly requires it. Return only a concise prep note with bullet points.
                    """
                ),
                AIMessage(
                    role: "user",
                    content: buildPrepPrompt(event: event, notes: notes)
                )
            ]

            let client = try AIProviderRouter().client(for: settings.aiProviderKind, settings: settings)
            let response = try await client.sendChat(messages: messages, config: config)
            let body = cleanedAIContent(response.content)

            guard !body.isEmpty else {
                generationError = prepError("AI returned an empty prep note", languageCode: languageCode)
                return
            }

            if let existingPrep = prepNotes.first {
                updateNote(
                    existingPrep,
                    body: body,
                    noteType: .prep,
                    checklistItems: [],
                    links: [],
                    modelContext: modelContext
                )
            } else {
                createNote(
                    eventId: eventId,
                    body: body,
                    noteType: .prep,
                    checklistItems: [],
                    links: [],
                    modelContext: modelContext
                )
            }
        } catch KeychainError.readError(_) {
            generationError = prepError("Add an API key in AI Settings before generating prep notes.", languageCode: languageCode)
        } catch {
            generationError = error.localizedDescription
        }
    }

    private func buildPrepPrompt(event: CalendarEvent, notes: [EventNote]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = event.isAllDay ? .none : .short

        var lines: [String] = [
            "Event title: \(event.title)",
            "Start: \(dateFormatter.string(from: event.startDate))",
            "End: \(dateFormatter.string(from: event.endDate))",
            "All day: \(event.isAllDay ? "yes" : "no")"
        ]

        if let category = event.category, !category.isEmpty {
            lines.append("Category: \(category)")
        }
        if let location = event.location, !location.isEmpty {
            lines.append("Location: \(location)")
        }
        if let eventNotes = event.notes, !eventNotes.isEmpty {
            lines.append("Event description/notes: \(eventNotes)")
        }
        if event.isOutdoor {
            lines.append("This is marked as an outdoor event.")
        }
        if event.isWorkEvent, let workTypeName = event.workTypeName {
            lines.append("Work type: \(workTypeName)")
        }

        let relevantNotes = notes
            .filter { !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .prefix(5)
        if !relevantNotes.isEmpty {
            lines.append("Existing event notes:")
            for note in relevantNotes {
                lines.append("- \(note.body)")
            }
        }

        lines.append("""

        Generate a useful preparation plan for this event. Include concrete things to bring, check, book, review, or do beforehand when relevant. Keep it under 8 bullets.
        """)

        return lines.joined(separator: "\n")
    }

    private func cleanedAIContent(_ content: String) -> String {
        content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```markdown", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func prepError(_ message: String, languageCode: String) -> String {
        guard languageCode == "hu" else { return message }
        switch message {
        case "Event not found":
            return "Az esemény nem található."
        case "AI returned an empty prep note":
            return "Az MI üres előkészületi jegyzetet adott vissza."
        case "Add an API key in AI Settings before generating prep notes.":
            return "Adj meg API-kulcsot az MI-beállításokban az előkészületi jegyzet generálása előtt."
        default:
            return message
        }
    }
}
