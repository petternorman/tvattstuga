import ActivityKit
import Foundation

enum LiveActivityManager {
    @available(iOS 16.1, *)
    static func areEnabled() -> Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    @available(iOS 16.1, *)
    static func startOrUpdate(
        machineID: String,
        machineName: String,
        groupName: String,
        endDate: Date
    ) async throws {
        let state = MachineLiveActivityAttributes.ContentState(
            machineName: machineName,
            groupName: groupName,
            endDate: endDate
        )
        let content = ActivityContent(state: state, staleDate: endDate)

        for activity in Activity<MachineLiveActivityAttributes>.activities where activity.attributes.machineID != machineID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        if let existing = Activity<MachineLiveActivityAttributes>.activities.first(where: { $0.attributes.machineID == machineID }) {
            await existing.update(content)
            return
        }

        _ = try Activity.request(
            attributes: MachineLiveActivityAttributes(machineID: machineID),
            content: content,
            pushType: nil
        )
    }

    @available(iOS 16.1, *)
    static func end(machineID: String? = nil) async {
        for activity in Activity<MachineLiveActivityAttributes>.activities where machineID == nil || activity.attributes.machineID == machineID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    @available(iOS 16.1, *)
    static func trackedMachineID() -> String? {
        Activity<MachineLiveActivityAttributes>.activities.first?.attributes.machineID
    }
}
