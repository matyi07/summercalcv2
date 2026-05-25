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
    
    static func buildSmartSuggestionPrompt(
        date: String,
        freeWindows: [DateInterval],
        todaysEvents: [CalendarEvent],
        weatherSummary: String,
        nearbyPlaces: [PlaceCandidate],
        preferences: [String]
    ) -> String {
        var prompt = "You are a helpful personal assistant. Based on the following context, suggest exactly 3 specific, realistic activities for the user's free time today.\n\n"
        prompt += "Date: \(date)\n"
        
        if todaysEvents.isEmpty {
            prompt += "Events: None scheduled.\n"
        } else {
            prompt += "Scheduled events:\n"
            for event in todaysEvents {
                prompt += "  - \"\(event.title)\" from \(DateUtils.formattedTime(event.startDate)) to \(DateUtils.formattedTime(event.endDate))"
                if let location = event.location { prompt += " at \(location)" }
                prompt += "\n"
            }
        }
        
        if freeWindows.isEmpty {
            prompt += "Free time: No significant free windows available.\n"
        } else {
            let totalFree = freeWindows.reduce(0.0) { $0 + $1.duration } / 3600.0
            prompt += "Free time windows (\(String(format: "%.1f", totalFree)) hours total):\n"
            for window in freeWindows {
                prompt += "  - \(DateUtils.formattedTime(window.start)) to \(DateUtils.formattedTime(window.end))\n"
            }
        }
        
        if !weatherSummary.isEmpty {
            prompt += "Weather: \(weatherSummary)\n"
        }
        
        if !nearbyPlaces.isEmpty {
            prompt += "Nearby places:\n"
            for place in nearbyPlaces.prefix(5) {
                var line = "  - \(place.name) (\(place.category ?? "place"))"
                if let rating = place.rating { line += " [\(String(format: "%.1f", rating)) stars]" }
                if let openNow = place.openNow { line += openNow ? " [OPEN]" : " [CLOSED]" }
                prompt += line + "\n"
            }
        }
        
        if !preferences.isEmpty {
            prompt += "User preferences: \(preferences.joined(separator: ", "))\n"
        }
        
        prompt += "\nReturn your response as a JSON array of exactly 3 activity suggestions. Each suggestion must have these fields:\n"
        prompt += "- title: string (short, catchy activity name)\n"
        prompt += "- summary: string (1-2 sentence description)\n"
        prompt += "- category: string (one of: outdoor, indoor, fitness, social, food, culture, errand, leisure)\n"
        prompt += "- estimatedDurationMinutes: number (realistic duration in minutes)\n"
        prompt += "- estimatedCostLevel: number (0=free, 1=cheap, 2=moderate, 3=expensive)\n"
        prompt += "- placeName: string or null (name of a nearby place if applicable)\n"
        prompt += "- weatherReason: string or null (brief explanation of why this activity suits today's weather)\n"
        prompt += "\nRespond ONLY with the JSON array, no other text. Example: [{\"title\": \"Morning Park Walk\", ...}]"
        
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
