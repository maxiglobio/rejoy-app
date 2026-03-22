import SwiftUI

struct OnboardingView: View {
    var onContinue: (() -> Void)?

    @StateObject private var healthKit = HealthKitService()
    @StateObject private var calendar = CalendarService()
    @StateObject private var motion = MotionService()
    @StateObject private var location = LocationService()
    @StateObject private var screenTime = ScreenTimeService()

    var body: some View {
        NavigationStack {
            List {
                Section("Data Sources") {
                    DataSourcePermissionRow(
                        title: "Health",
                        icon: "heart.fill",
                        status: healthKit.isAvailable ? .notDetermined : .unavailable
                    ) {
                        _ = await healthKit.requestAuthorization()
                    }

                    DataSourcePermissionRow(
                        title: "Motion (Steps)",
                        icon: "figure.walk",
                        status: motion.isAvailable ? .notDetermined : .unavailable
                    ) {
                        _ = await motion.requestAuthorization()
                    }

                    DataSourcePermissionRow(
                        title: "Location",
                        icon: "location.fill",
                        status: location.authorizationStatus == .authorizedWhenInUse || location.authorizationStatus == .authorizedAlways ? .granted : .notDetermined
                    ) {
                        _ = await location.requestAuthorization()
                    }

                    DataSourcePermissionRow(
                        title: "Calendar",
                        icon: "calendar",
                        status: .notDetermined
                    ) {
                        _ = await calendar.requestAuthorization()
                    }

                    DataSourcePermissionRow(
                        title: "Manual Entry",
                        icon: "hand.tap",
                        status: .granted
                    ) { }
                }

                if onContinue != nil {
                    Section {
                        Button {
                            onContinue?()
                        } label: {
                            Text("Continue")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle(onContinue != nil ? "Welcome" : "Permissions")
        }
    }
}
