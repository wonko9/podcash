import Foundation
import os

/// Centralized logging for the app
enum AppLogger {
    static let audio = Logger(subsystem: "com.personal.podpeace", category: "Audio")
    static let download = Logger(subsystem: "com.personal.podpeace", category: "Download")
    static let sync = Logger(subsystem: "com.personal.podpeace", category: "Sync")
    static let data = Logger(subsystem: "com.personal.podpeace", category: "Data")
    static let feed = Logger(subsystem: "com.personal.podpeace", category: "Feed")
    static let stats = Logger(subsystem: "com.personal.podpeace", category: "Stats")
}
