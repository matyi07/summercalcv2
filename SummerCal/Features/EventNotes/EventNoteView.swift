import SwiftUI
import SwiftData

struct EventNoteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let eventId: UUID
    var existingNote: EventNote?

    @State private var noteType: EventNoteType = .general
    @State private var bodyText: String = ""
    @State private var checklistItems: [String] = []
    @State private var links: [String] = []
    @State private var newChecklistItem: String = ""
    @State private var newLink: String = ""

    private var eventNoteViewModel: EventNoteViewModel
    private var navigationTitleKey: LocalizedStringKey {
        existingNote == nil ? "New Note" : "Edit Note"
    }

    init(eventId: UUID, existingNote: EventNote? = nil, eventNoteViewModel: EventNoteViewModel = EventNoteViewModel()) {
        self.eventId = eventId
        self.existingNote = existingNote
        self.eventNoteViewModel = eventNoteViewModel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Note Type") {
                    Picker("Type", selection: $noteType) {
                        ForEach(EventNoteType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Content") {
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 120)
                }

                if noteType == .checklist {
                    Section("Checklist Items") {
                        ForEach(checklistItems.indices, id: \.self) { index in
                            HStack {
                                Text(checklistItems[index])
                                    .strikethrough(checklistItems[index].hasPrefix("[x] "))
                                Spacer()
                                Button {
                                    checklistItems.remove(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            checklistItems.remove(atOffsets: indexSet)
                        }

                        HStack {
                            TextField("New item", text: $newChecklistItem)
                            Button("Add") {
                                guard !newChecklistItem.isEmpty else { return }
                                checklistItems.append("[ ] " + newChecklistItem)
                                newChecklistItem = ""
                            }
                        }
                    }
                }

                if noteType == .link {
                    Section("Links") {
                        ForEach(links.indices, id: \.self) { index in
                            HStack {
                                Text(links[index])
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button {
                                    links.remove(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            links.remove(atOffsets: indexSet)
                        }

                        HStack {
                            TextField("https://...", text: $newLink)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                            Button("Add") {
                                guard !newLink.isEmpty else { return }
                                links.append(newLink)
                                newLink = ""
                            }
                        }
                    }
                }
            }
            .navigationTitle(navigationTitleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(bodyText.isEmpty)
                }
            }
            .onAppear {
                if let existing = existingNote {
                    noteType = existing.noteType
                    bodyText = existing.body
                    checklistItems = existing.checklistItems
                    links = existing.links
                }
            }
        }
    }

    private func save() {
        if let existing = existingNote {
            eventNoteViewModel.updateNote(
                existing,
                body: bodyText,
                noteType: noteType,
                checklistItems: checklistItems,
                links: links,
                modelContext: modelContext
            )
        } else {
            eventNoteViewModel.createNote(
                eventId: eventId,
                body: bodyText,
                noteType: noteType,
                checklistItems: checklistItems,
                links: links,
                modelContext: modelContext
            )
        }
    }
}

private extension EventNoteType {
    var displayName: LocalizedStringKey {
        switch self {
        case .general: return "General"
        case .prep: return "Prep"
        case .checklist: return "Checklist"
        case .link: return "Link"
        case .postEvent: return "Post"
        case .aiSummary: return "AI"
        }
    }
}
