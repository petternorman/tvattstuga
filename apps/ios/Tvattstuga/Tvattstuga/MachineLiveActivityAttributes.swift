import ActivityKit
import Foundation

struct MachineLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var machineName: String
        var groupName: String
        var endDate: Date
    }

    var machineID: String
}
