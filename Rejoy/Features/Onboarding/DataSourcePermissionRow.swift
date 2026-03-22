import SwiftUI

struct DataSourcePermissionRow: View {
    let title: String
    let icon: String
    let status: PermissionStatus
    let onRequest: () async -> Void

    enum PermissionStatus {
        case notDetermined
        case granted
        case denied
        case unavailable
    }

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(AppFont.title2)
                .foregroundStyle(AppColors.dotsSecondaryText)
                .frame(width: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.headline)
                Text(statusText)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColors.dotsSecondaryText)
            }

            Spacer()

            if status == .notDetermined {
                Button("Request Access") {
                    Task { await onRequest() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
        switch status {
        case .notDetermined:
            return "Tap to request"
        case .granted:
            return "Access granted"
        case .denied:
            return "Access denied"
        case .unavailable:
            return "Not available"
        }
    }
}
