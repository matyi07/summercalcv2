import Foundation
import SwiftData

final class ActivitySuggestionService {
    private let indoorActivities = [
        ("Cafe work session", "Get coffee and be productive", "indoor_cafe", 120, 2),
        ("Visit a museum", "Explore local exhibits", "museum", 180, 2),
        ("Gym workout", "Get your exercise in", "gym", 60, 1),
        ("Watch a movie", "Catch a film at the cinema", "cinema", 150, 2),
        ("Library reading", "Peaceful reading session", "library", 120, 0),
        ("Shopping trip", "Browse local shops", "shopping", 90, 2),
        ("Home cooking", "Try a new recipe", "home", 90, 1),
        ("Indoor climbing", "Climbing gym session", "indoor_sport", 120, 3)
    ]

    private let outdoorActivities = [
        ("Park walk", "Enjoy a relaxing walk", "park", 45, 0),
        ("Outdoor cafe", "Coffee with a view", "cafe", 60, 1),
        ("Hiking trail", "Explore nature", "hiking", 180, 0),
        ("Beach day", "Relax by the water", "beach", 240, 0),
        ("Botanical garden", "Visit the gardens", "park", 120, 1),
        ("Outdoor yoga", "Yoga in the park", "fitness", 60, 0),
        ("Cycling route", "Bike ride through town", "cycling", 120, 0),
        ("Farmers market", "Fresh produce shopping", "errand", 60, 1)
    ]

    func generateFreeDaySuggestions(
        date: Date,
        freeWindows: [DateInterval],
        weather: WeatherSnapshot?,
        places: [PlaceCandidate],
        settings: UserSettings
    ) async -> [ActivitySuggestion] {
        var suggestions: [ActivitySuggestion] = []
        let isGoodWeather = (weather?.precipitationChance ?? 0) < 0.3

        if isGoodWeather {
            let outdoor = outdoorActivities.shuffled().prefix(3)
            suggestions = outdoor.map { act in
                ActivitySuggestion(
                    date: date,
                    title: act.0,
                    summary: act.1,
                    category: act.2,
                    estimatedDurationMinutes: act.3,
                    estimatedCostLevel: act.4,
                    weatherReason: "Good weather for outdoors"
                )
            }
        } else {
            let indoor = indoorActivities.shuffled().prefix(3)
            suggestions = indoor.map { act in
                ActivitySuggestion(
                    date: date,
                    title: act.0,
                    summary: act.1,
                    category: act.2,
                    estimatedDurationMinutes: act.3,
                    estimatedCostLevel: act.4,
                    weatherReason: "Indoor activity for today's weather"
                )
            }
        }

        if let place = places.first {
            suggestions.append(
                ActivitySuggestion(
                    date: date,
                    title: "Visit \(place.name)",
                    summary: "Nearby: \(place.address ?? "")",
                    category: place.category,
                    estimatedDurationMinutes: 60,
                    estimatedCostLevel: 2,
                    placeName: place.name,
                    placeId: place.placeId
                )
            )
        }

        if settings.nextDayFreePreviewEnabled {
            suggestions.append(
                ActivitySuggestion(
                    date: date,
                    title: "Plan for tomorrow",
                    summary: "Check tomorrow's schedule and weather",
                    category: "planning",
                    estimatedDurationMinutes: 15,
                    estimatedCostLevel: 0
                )
            )
        }

        return Array(suggestions.prefix(5))
    }

    func generateQuickIdeas(weather: WeatherSnapshot?, preferences: [String]) -> [ActivitySuggestion] {
        let isOutdoorFriendly = (weather?.precipitationChance ?? 0) < 0.3
        let pool = isOutdoorFriendly ? outdoorActivities : indoorActivities
        return pool.shuffled().prefix(3).map { act in
            ActivitySuggestion(
                date: Date(),
                title: act.0,
                summary: act.1,
                category: act.2,
                estimatedDurationMinutes: act.3,
                estimatedCostLevel: act.4
            )
        }
    }
}
