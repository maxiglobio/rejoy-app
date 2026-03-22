import WidgetKit
import SwiftUI

@main
struct RejoyWidgetBundle: WidgetBundle {
    var body: some Widget {
        RejoyWidget()
        RejoyTrackingLiveActivity()
    }
}
