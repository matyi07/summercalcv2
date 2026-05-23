import Foundation

struct AIPlannerRequest {
    var date: Date
    var freeWindows: [DateInterval]
    var eventsSummary: String
    var weatherSummary: String
    var locationSummary: String
    var nearbyPlaces: [PlaceCandidate]
    var userPreferences: [String]
    var budgetPreference: String?
    var energyLevel: String?
}

enum PromptBuilder {
    static func buildDayPlannerPrompt(request: AIPlannerRequest) -> String {
        var prompt = "You are a helpful day planner. Based on the following context, suggest realistic and optional plans for today.\n\n"
        prompt += "Date: \(DateUtils.formattedDayAndDate(request.date))\n"
        
        if !request.eventsSummary.isEmpty {
            prompt += "Events: \(request.eventsSummary)\n"
        }
        
        if request.freeWindows.isEmpty {
            prompt += "No significant free time today.\n"
        } else {
            let totalFree = request.freeWindows.reduce(0.0) { $0 + $1.duration } / 3600.0
            prompt += "Free time: \(String(format: "%.1f", totalFree)) hours\n"
            for window in request.freeWindows {
                prompt += "  Free: \(DateUtils.formattedTime(window.start)) - \(DateUtils.formattedTime(window.end))\n"
            }
        }
        
        if !request.weatherSummary.isEmpty {
            prompt += "Weather: \(request.weatherSummary)\n"
        }
        if !request.locationSummary.isEmpty {
            prompt += "Location: \(request.locationSummary)\n"
        }
        if !request.nearbyPlaces.isEmpty {
            prompt += "Nearby places:\n"
            for place in request.nearbyPlaces.prefix(5) {
                var line = "  - \(place.name) (\(place.category))"
                if let openNow = place.openNow { line += openNow ? " [OPEN]" : " [CLOSED]" }
                prompt += line + "\n"
            }
        }
        if !request.userPreferences.isEmpty {
            prompt += "Preferences: \(request.userPreferences.joined(separator: ", "))\n"
        }
        if let budget = request.budgetPreference { prompt += "Budget: \(budget)\n" }
        if let energy = request.energyLevel { prompt += "Energy level: \(energy)\n" }
        
        prompt += "\nPlease provide: day summary, 3-5 activity suggestions with title/category/duration/cost, a recommended plan, and a short notification suggestion."
        return prompt
    }
    
    static func buildEventPrepPrompt(event: CalendarEvent, notes: [EventNote], weatherSummary: String?) -> String {
        var prompt = "I have an event: \"\(event.title)\" at \(DateUtils.formattedTime(event.startDate)).\n"
        if let location = event.location { prompt += "Location: \(location)\n" }
        if let weather = weatherSummary { prompt += "Weather during event: \(weather)\n" }
        
        let prepNotes = notes.filter { $0.noteType == .prep || $0.noteType == .checklist }
        if !prepNotes.isEmpty {
            prompt += "Current notes:\n"
            for note in prepNotes {
                prompt += "- \(note.body)\n"
            }
        }
        
        prompt += "\nSuggest 3-5 preparation items I should do before this event. Keep it brief."
        return prompt
    }
    
    static func buildFreeDaySuggestionsPrompt(freeWindows: [DateInterval], weather: String, places: [PlaceCandidate], preferences: UserSettings) -> String {
        let totalFree = freeWindows.reduce(0.0) { $0 + $1.duration } / 3600.0
        var prompt = "Today is mostly free (about \(String(format: "%.0f", totalFree)) hours). Weather: \(weather).\n"
        
        if !places.isEmpty {
            prompt += "Nearby options:\n"
            for place in places.prefix(5) {
                prompt += "- \(place.name) (\(place.category))\n"
            }
        }
        
        prompt += "\nSuggest 3-5 activity ideas for today. Be specific and realistic."
        return prompt
    }
    
    static func buildNoteSummaryPrompt(notes: [EventNote]) -> String {
        var prompt = "Summarize these event notes into 1-3 short bullet points suitable for a notification preview:\n\n"
        for note in notes.prefix(5) {
            prompt += "- \(note.body)\n"
        }
        return prompt
    }
}
