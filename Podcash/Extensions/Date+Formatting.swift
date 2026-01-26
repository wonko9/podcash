import Foundation

extension Date {
    /// Returns a human-readable relative date string
    /// e.g., "Today", "Yesterday", "3 days ago", "Dec 15", "Dec 15, 2023"
    var relativeFormatted: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(self) {
            return "Today"
        }

        if calendar.isDateInYesterday(self) {
            return "Yesterday"
        }

        let components = calendar.dateComponents([.day], from: self, to: now)
        if let days = components.day, days < 7 {
            return "\(days) days ago"
        }

        // Check if same year
        let thisYear = calendar.component(.year, from: now)
        let dateYear = calendar.component(.year, from: self)

        if thisYear == dateYear {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: self)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: self)
        }
    }

    /// Returns a short date string
    /// e.g., "Dec 15" or "Dec 15, 2023"
    var shortFormatted: String {
        let calendar = Calendar.current
        let now = Date()
        let thisYear = calendar.component(.year, from: now)
        let dateYear = calendar.component(.year, from: self)

        let formatter = DateFormatter()
        if thisYear == dateYear {
            formatter.dateFormat = "MMM d"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: self)
    }
}
