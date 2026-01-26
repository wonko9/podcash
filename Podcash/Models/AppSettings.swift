import Foundation
import SwiftData

@Model
final class AppSettings {
    var globalPlaybackSpeed: Double = 1.0
    var sleepTimerMinutes: Int?   // nil = off
    var sleepTimerEndTime: Date?  // when timer should fire

    init() {}

    /// Singleton accessor - creates settings if none exist
    static func getOrCreate(context: ModelContext) -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        return settings
    }
}
