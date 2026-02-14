import Foundation

struct Credentials: Codable, Equatable {
    var username: String
    var password: String
}

struct ResourceGroup: Decodable, Identifiable, Hashable {
    let name: String
    let machines: [Machine]

    var id: String { name }
}

struct Machine: Decodable, Identifiable, Hashable {
    let name: String
    let status: String
    let state: String

    var id: String { name }
}

struct GroupMachine: Identifiable, Hashable {
    let groupName: String
    let machine: Machine

    var id: String { "\(groupName)::\(machine.id)" }
}

enum RefreshInterval: Int, CaseIterable, Identifiable {
    case off = 0
    case seconds30 = 30
    case minute1 = 60
    case minutes5 = 300
    case minutes10 = 600

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .off:
            return "Off"
        case .seconds30:
            return "30 seconds"
        case .minute1:
            return "1 minute"
        case .minutes5:
            return "5 minutes"
        case .minutes10:
            return "10 minutes"
        }
    }

    static func fromStoredSeconds(_ value: Int) -> RefreshInterval {
        RefreshInterval(rawValue: value) ?? .minute1
    }
}
