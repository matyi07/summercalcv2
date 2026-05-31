import Foundation
import SwiftData

struct WorkTimeVariant: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int

    init(
        id: UUID = UUID(),
        name: String,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int
    ) {
        self.id = id
        self.name = name
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
    }

    init?(name: String, start: Date, end: Date, calendar: Calendar = .current) {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return nil }

        let startComponents = calendar.dateComponents([.hour, .minute], from: start)
        let endComponents = calendar.dateComponents([.hour, .minute], from: end)
        guard let startHour = startComponents.hour,
              let startMinute = startComponents.minute,
              let endHour = endComponents.hour,
              let endMinute = endComponents.minute else {
            return nil
        }

        self.init(
            name: cleanedName,
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute
        )
    }

    func startDate(on date: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: date)
    }

    func endDate(on date: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: date)
    }

    func timeRangeText() -> String {
        "\(Self.timeText(hour: startHour, minute: startMinute)) - \(Self.timeText(hour: endHour, minute: endMinute))"
    }

    private static func timeText(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }
}

@Model
final class WorkType {
    @Attribute(.unique) var id: UUID
    var name: String
    var rateAmount: Double
    var pricingMode: String
    var currencyCode: String?
    var defaultStartDate: Date?
    var defaultEndDate: Date?
    var defaultStartHour: Int?
    var defaultStartMinute: Int?
    var defaultEndHour: Int?
    var defaultEndMinute: Int?
    var locationName: String?
    var variantsJSON: String?
    var defaultVariantId: UUID?
    var note: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        rateAmount: Double,
        pricingMode: String = "hourly",
        currencyCode: String? = nil,
        defaultStartDate: Date? = nil,
        defaultEndDate: Date? = nil,
        defaultStartHour: Int? = nil,
        defaultStartMinute: Int? = nil,
        defaultEndHour: Int? = nil,
        defaultEndMinute: Int? = nil,
        locationName: String? = nil,
        variantsJSON: String? = nil,
        defaultVariantId: UUID? = nil,
        note: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.rateAmount = rateAmount
        self.pricingMode = pricingMode
        self.currencyCode = currencyCode
        self.defaultStartDate = defaultStartDate
        self.defaultEndDate = defaultEndDate
        self.defaultStartHour = defaultStartHour
        self.defaultStartMinute = defaultStartMinute
        self.defaultEndHour = defaultEndHour
        self.defaultEndMinute = defaultEndMinute
        self.locationName = locationName
        self.variantsJSON = variantsJSON
        self.defaultVariantId = defaultVariantId
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var usesDailyPricing: Bool {
        pricingMode == "daily"
    }

    func workVariants() -> [WorkTimeVariant] {
        guard let variantsJSON,
              let data = variantsJSON.data(using: .utf8),
              let variants = try? JSONDecoder().decode([WorkTimeVariant].self, from: data) else {
            return []
        }
        return variants
    }

    func setWorkVariants(_ variants: [WorkTimeVariant]) {
        let cleaned = variants.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if cleaned.isEmpty {
            variantsJSON = nil
            defaultVariantId = nil
            return
        }

        if let data = try? JSONEncoder().encode(cleaned),
           let json = String(data: data, encoding: .utf8) {
            variantsJSON = json
        }

        if let defaultVariantId,
           !cleaned.contains(where: { $0.id == defaultVariantId }) {
            self.defaultVariantId = cleaned.first?.id
        }
    }
}
