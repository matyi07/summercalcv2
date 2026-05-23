import SwiftUI

struct AddExpenseView: View {
    var body: some View {
        Text("Add Expense")
            .font(.largeTitle)
    }
}

struct SavePlaceView: View {
    let placeId: UUID?

    var body: some View {
        Text("Save Place")
            .font(.largeTitle)
    }
}

struct ShareEventView: View {
    let eventId: UUID

    var body: some View {
        Text("Share Event")
            .font(.largeTitle)
    }
}

struct AIPlanDetailView: View {
    let planId: UUID

    var body: some View {
        Text("AI Plan Detail")
            .font(.largeTitle)
    }
}

struct QuickNoteView: View {
    let eventId: UUID

    var body: some View {
        Text("Quick Note")
            .font(.largeTitle)
    }
}
