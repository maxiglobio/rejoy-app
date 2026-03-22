import Foundation

/// Data source types for time tracking
enum DataSourceType: String, Codable, CaseIterable, Identifiable {
    case healthKitWorkout
    case healthKitSteps
    case healthKitExercise
    case healthKitMindful
    case healthKitSleep
    case motionPedometer
    case locationPlace
    case calendarEvents
    case screenTime
    case manualEntry

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .healthKitWorkout: return "Workouts"
        case .healthKitSteps: return "Steps"
        case .healthKitExercise: return "Exercise Time"
        case .healthKitMindful: return "Mindful Sessions"
        case .healthKitSleep: return "Sleep"
        case .motionPedometer: return "Walking/Running"
        case .locationPlace: return "Time in Places"
        case .calendarEvents: return "Calendar Events"
        case .screenTime: return "Screen Time"
        case .manualEntry: return "Manual Entry"
        }
    }

    var icon: String {
        switch self {
        case .healthKitWorkout: return "figure.run"
        case .healthKitSteps: return "figure.walk"
        case .healthKitExercise: return "flame"
        case .healthKitMindful: return "brain.head.profile"
        case .healthKitSleep: return "bed.double"
        case .motionPedometer: return "pedometer"
        case .locationPlace: return "location"
        case .calendarEvents: return "calendar"
        case .screenTime: return "iphone"
        case .manualEntry: return "hand.tap"
        }
    }

    var requiresPermission: Bool {
        switch self {
        case .healthKitWorkout, .healthKitSteps, .healthKitExercise, .healthKitMindful, .healthKitSleep:
            return true
        case .motionPedometer, .locationPlace, .calendarEvents:
            return true
        case .screenTime:
            return true // Stub - entitlement required
        case .manualEntry:
            return false
        }
    }
}
