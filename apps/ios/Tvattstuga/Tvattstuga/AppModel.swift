import Foundation
import Combine
import UserNotifications
import ActivityKit

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var groups: [ResourceGroup] = []
    @Published private(set) var isInitialLoading = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastUpdatedAt: Date?
    @Published private(set) var errorMessage: String?
    @Published private(set) var signedInUsername: String?
    @Published private(set) var refreshInterval: RefreshInterval
    @Published private(set) var preferredStatusGroupNames: Set<String>
    @Published private(set) var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var trackedNotificationMachineIDs: Set<String>
    @Published private(set) var notificationInfoMessage: String?
    @Published private(set) var trackedLiveActivityMachineID: String?
    @Published private(set) var liveActivityInfoMessage: String?

    @Published var isLoginSheetPresented = false
    @Published var loginUsername = ""
    @Published var loginPassword = ""
    @Published var loginError: String?
    @Published var apiBaseURLOverrideInput = ""

    private let apiClient: APIClient
    private let credentialsStore: CredentialsStoring
    private let notificationManager: NotificationManager
    private let refreshIntervalKey = "tvattstuga.refresh.interval.seconds"
    private let preferredStatusGroupsKey = "tvattstuga.status.preferred.groups"
    private let trackedNotificationMachineIDsKey = "tvattstuga.notifications.tracked.machine.ids"
    private let trackedLiveActivityMachineIDKey = "tvattstuga.live-activity.machine.id"
    private let trackedMachineAlertEndDateKey = "tvattstuga.tracking.end.date"

    private var credentials: Credentials?
    private var hasBootstrapped = false
    private var autoRefreshTask: Task<Void, Never>?
    private var liveActivityEndTask: Task<Void, Never>?
    private var trackedMachineAlertEndDate: Date?

    init(
        apiClient: APIClient = APIClient(),
        credentialsStore: CredentialsStoring = KeychainCredentialsStore(),
        notificationManager: NotificationManager = NotificationManager()
    ) {
        self.apiClient = apiClient
        self.credentialsStore = credentialsStore
        self.notificationManager = notificationManager

        let storedValue = UserDefaults.standard.object(forKey: refreshIntervalKey) as? Int
        refreshInterval = RefreshInterval.fromStoredSeconds(storedValue ?? RefreshInterval.minute1.rawValue)
        let storedPreferredGroups = UserDefaults.standard.stringArray(forKey: preferredStatusGroupsKey) ?? []
        preferredStatusGroupNames = Set(storedPreferredGroups)
        let storedTrackedMachineIDs = UserDefaults.standard.stringArray(forKey: trackedNotificationMachineIDsKey) ?? []
        trackedNotificationMachineIDs = Set(storedTrackedMachineIDs)
        trackedLiveActivityMachineID = UserDefaults.standard.string(forKey: trackedLiveActivityMachineIDKey)
        trackedMachineAlertEndDate = UserDefaults.standard.object(forKey: trackedMachineAlertEndDateKey) as? Date
        apiBaseURLOverrideInput = AppConfig.apiBaseURLOverrideString
    }

    deinit {
        autoRefreshTask?.cancel()
        liveActivityEndTask?.cancel()
    }

    var summaryGroupsCount: Int {
        statusRelevantGroups.count
    }

    var summaryMachinesCount: Int {
        statusRelevantGroups.reduce(0) { $0 + $1.machines.count }
    }

    var summaryAvailableCount: Int {
        statusRelevantGroups.reduce(0) { $0 + $1.availableCount() }
    }

    var isStatusFiltered: Bool {
        !preferredStatusGroupNames.isEmpty
    }

    var allGroupsCount: Int {
        groups.count
    }

    var statusFilterSummary: String {
        if preferredStatusGroupNames.isEmpty {
            return "Showing all groups in Status."
        }
        return "Showing \(summaryGroupsCount) of \(allGroupsCount) groups in Status."
    }

    var sortedGroupNames: [String] {
        groups.map(\.name).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var apiBaseURLDisplay: String {
        let resolved = AppConfig.apiBaseURLString
        return resolved.isEmpty ? "Not set" : resolved
    }

    var apiBaseURLSourceDisplay: String {
        AppConfig.apiBaseURLSourceDescription
    }

    var notificationPermissionDescription: String {
        switch notificationAuthorizationStatus {
        case .notDetermined:
            return "Not requested"
        case .denied:
            return "Denied"
        case .authorized:
            return "Allowed"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }

    var notificationPermissionAllowsTracking: Bool {
        authorizationAllowsNotifications(notificationAuthorizationStatus)
    }

    var trackedNotificationCount: Int {
        trackedNotificationMachineIDs.count
    }

    var liveActivitySupported: Bool {
        if #available(iOS 16.1, *) {
            return LiveActivityManager.areEnabled()
        }
        return false
    }

    var liveActivitySupportDescription: String {
        if #available(iOS 16.1, *) {
            return liveActivitySupported ? "Enabled" : "Disabled in system settings"
        }
        return "Requires iOS 16.1+"
    }

    var liveActivityTrackedMachineLabel: String {
        trackedMachineAlertLabel
    }

    var trackedMachineAlertID: String? {
        trackedLiveActivityMachineID ?? trackedNotificationMachineIDs.first
    }

    var trackedMachineAlertLabel: String {
        guard let trackedID = trackedMachineAlertID else {
            return "None"
        }
        return allMachineEntries.first(where: { $0.id == trackedID })?.machine.name ?? "Unknown machine"
    }

    var machineEntries: [GroupMachine] {
        statusRelevantGroups.flatMap { group in
            group.machines.map { GroupMachine(groupName: group.name, machine: $0) }
        }
    }

    var availableEntries: [GroupMachine] {
        machineEntries
            .filter {
                let state = $0.machine.displayState()
                return state == .available || state == .recentlyUsed
            }
            .sorted { $0.machine.name.localizedCaseInsensitiveCompare($1.machine.name) == .orderedAscending }
    }

    var activeEntries: [GroupMachine] {
        machineEntries
            .filter { $0.machine.completionDate() != nil || $0.machine.displayState() == .taken }
            .sorted { lhs, rhs in
                let leftDate = lhs.machine.completionDate() ?? .distantFuture
                let rightDate = rhs.machine.completionDate() ?? .distantFuture
                if leftDate == rightDate {
                    return lhs.machine.name.localizedCaseInsensitiveCompare(rhs.machine.name) == .orderedAscending
                }
                return leftDate < rightDate
            }
    }

    func bootstrapIfNeeded() async {
        guard !hasBootstrapped else {
            return
        }
        hasBootstrapped = true
        await refreshNotificationAuthorizationStatus()
        await expireTrackedMachineAlertIfNeeded()

        if let stored = credentialsStore.loadCredentials() {
            credentials = stored
            signedInUsername = stored.username
            loginUsername = stored.username
            restartAutoRefresh()
            await refresh(initialLoad: true)
            return
        }

        presentLoginSheet()
    }

    func handleAppBecameActive() async {
        await expireTrackedMachineAlertIfNeeded()
    }

    func presentLoginSheet() {
        loginError = nil
        if let existingUsername = signedInUsername {
            loginUsername = existingUsername
        }
        loginPassword = ""
        isLoginSheetPresented = true
    }

    func dismissLoginSheet() {
        guard signedInUsername != nil else {
            return
        }
        loginError = nil
        loginPassword = ""
        isLoginSheetPresented = false
    }

    func saveLogin() async {
        loginError = nil

        let username = loginUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = loginPassword

        guard !username.isEmpty, !password.isEmpty else {
            loginError = "Username and password are required."
            return
        }

        let newCredentials = Credentials(username: username, password: password)
        do {
            try credentialsStore.saveCredentials(newCredentials)
            credentials = newCredentials
            signedInUsername = username
            loginPassword = ""
            isLoginSheetPresented = false
            restartAutoRefresh()
            await refresh(initialLoad: true)
        } catch {
            loginError = error.localizedDescription
        }
    }

    func clearCredentials() {
        do {
            try credentialsStore.clearCredentials()
        } catch {
            errorMessage = error.localizedDescription
        }

        credentials = nil
        signedInUsername = nil
        loginPassword = ""
        groups = []
        lastUpdatedAt = nil
        errorMessage = nil

        autoRefreshTask?.cancel()
        autoRefreshTask = nil
        Task {
            await stopTrackedMachineAlert(clearMessage: false)
        }

        isLoginSheetPresented = true
    }

    func setRefreshInterval(_ interval: RefreshInterval) {
        refreshInterval = interval
        UserDefaults.standard.set(interval.rawValue, forKey: refreshIntervalKey)
        restartAutoRefresh()
    }

    func isPreferredStatusGroup(_ groupName: String) -> Bool {
        preferredStatusGroupNames.contains(groupName)
    }

    func setPreferredStatusGroup(_ groupName: String, enabled: Bool) {
        if enabled {
            preferredStatusGroupNames.insert(groupName)
        } else {
            preferredStatusGroupNames.remove(groupName)
        }
        persistPreferredStatusGroups()
    }

    func clearPreferredStatusGroups() {
        preferredStatusGroupNames.removeAll()
        persistPreferredStatusGroups()
    }

    func isMachineNotificationEnabled(_ entry: GroupMachine) -> Bool {
        trackedNotificationMachineIDs.contains(entry.id)
    }

    func isMachineAlertEnabled(for entry: GroupMachine) -> Bool {
        trackedMachineAlertID == entry.id
    }

    func canTrackNotification(for entry: GroupMachine) -> Bool {
        guard let completion = entry.machine.completionDate() else {
            return false
        }
        return completion > Date()
    }

    func canTrackMachineAlert(for entry: GroupMachine) -> Bool {
        canTrackLiveActivity(for: entry)
    }

    func requestNotificationPermission() async {
        _ = await notificationManager.requestAuthorization()
        await refreshNotificationAuthorizationStatus()
    }

    func clearTrackedMachineNotifications() {
        for id in trackedNotificationMachineIDs {
            notificationManager.removeNotification(identifier: notificationIdentifier(forMachineID: id))
        }
        trackedNotificationMachineIDs.removeAll()
        persistTrackedMachineNotifications()
        setTrackingInfoMessage("Cleared all tracked machine notifications.")
    }

    func toggleMachineNotification(for entry: GroupMachine) async {
        await toggleMachineAlert(for: entry)
    }

    func toggleMachineAlert(for entry: GroupMachine) async {
        if isMachineAlertEnabled(for: entry) {
            await stopTrackedMachineAlert(clearMessage: true)
            return
        }

        guard let completion = entry.machine.completionDate(), completion > Date() else {
            setTrackingInfoMessage("No valid completion time found for \(entry.machine.name).")
            return
        }

        guard #available(iOS 16.1, *) else {
            setTrackingInfoMessage("Live Activities require iOS 16.1 or later.")
            return
        }

        guard liveActivitySupported else {
            setTrackingInfoMessage("Live Activities are disabled. Enable them in iOS Settings for this app.")
            return
        }

        if !notificationPermissionAllowsTracking {
            _ = await notificationManager.requestAuthorization()
            await refreshNotificationAuthorizationStatus()
        }

        guard notificationPermissionAllowsTracking else {
            setTrackingInfoMessage("Notifications are disabled. Enable them in iOS Settings.")
            return
        }

        let machineID = entry.id
        let notificationID = notificationIdentifier(forMachineID: machineID)

        await stopTrackedMachineAlert(clearMessage: false)

        do {
            try await notificationManager.scheduleMachineReadyNotification(
                identifier: notificationID,
                title: "Laundry ready",
                body: "\(entry.machine.name) in \(entry.groupName) should be ready now.",
                at: completion
            )
        } catch {
            setTrackingInfoMessage("Could not schedule notification: \(error.localizedDescription)")
            return
        }

        do {
            try await LiveActivityManager.startOrUpdate(
                machineID: machineID,
                machineName: entry.machine.name,
                groupName: entry.groupName,
                endDate: completion
            )
        } catch {
            notificationManager.removeNotification(identifier: notificationID)
            setTrackingInfoMessage("Could not start Live Activity: \(error.localizedDescription)")
            return
        }

        trackedNotificationMachineIDs = [machineID]
        persistTrackedMachineNotifications()
        trackedLiveActivityMachineID = machineID
        persistTrackedLiveActivityMachineID()
        scheduleLiveActivityAutoStop(for: machineID, at: completion)
        setTrackingInfoMessage("Tracking \(entry.machine.name). You'll get notified when it's ready.")
    }

    func isLiveActivityEnabled(for entry: GroupMachine) -> Bool {
        trackedLiveActivityMachineID == entry.id
    }

    func canTrackLiveActivity(for entry: GroupMachine) -> Bool {
        guard let completion = entry.machine.completionDate() else {
            return false
        }
        return completion > Date()
    }

    func toggleLiveActivity(for entry: GroupMachine) async {
        await toggleMachineAlert(for: entry)
    }

    func stopTrackedMachineAlert(clearMessage: Bool) async {
        cancelLiveActivityAutoStop()

        for machineID in trackedNotificationMachineIDs {
            notificationManager.removeNotification(identifier: notificationIdentifier(forMachineID: machineID))
        }
        trackedNotificationMachineIDs.removeAll()
        persistTrackedMachineNotifications()

        if #available(iOS 16.1, *), let machineID = trackedLiveActivityMachineID {
            await LiveActivityManager.end(machineID: machineID)
        }

        trackedLiveActivityMachineID = nil
        persistTrackedLiveActivityMachineID()
        trackedMachineAlertEndDate = nil
        persistTrackedMachineAlertEndDate()

        if clearMessage {
            setTrackingInfoMessage("Tracking stopped.")
        }
    }

    func stopLiveActivity(clearMessage: Bool) async {
        cancelLiveActivityAutoStop()

        if #available(iOS 16.1, *), let machineID = trackedLiveActivityMachineID {
            await LiveActivityManager.end(machineID: machineID)
        }

        trackedLiveActivityMachineID = nil
        persistTrackedLiveActivityMachineID()
        trackedMachineAlertEndDate = nil
        persistTrackedMachineAlertEndDate()
        if clearMessage {
            setTrackingInfoMessage("Live Activity stopped.")
        }
    }

    func saveAPIBaseURLOverride() {
        AppConfig.setAPIBaseURLOverride(apiBaseURLOverrideInput)
        apiBaseURLOverrideInput = AppConfig.apiBaseURLOverrideString
        objectWillChange.send()
    }

    func clearAPIBaseURLOverride() {
        AppConfig.setAPIBaseURLOverride("")
        apiBaseURLOverrideInput = ""
        objectWillChange.send()
    }

    func refresh(initialLoad: Bool = false) async {
        guard !isInitialLoading, !isRefreshing else {
            return
        }

        guard let credentials else {
            presentLoginSheet()
            return
        }

        guard let baseURL = AppConfig.apiBaseURL else {
            errorMessage = APIClientError.missingBaseURL.localizedDescription
            return
        }

        if initialLoad {
            isInitialLoading = true
        } else {
            isRefreshing = true
        }

        defer {
            isInitialLoading = false
            isRefreshing = false
        }

        do {
            let fetchedGroups = try await apiClient.fetchGroups(baseURL: baseURL, credentials: credentials)
            groups = fetchedGroups
            lastUpdatedAt = Date()
            errorMessage = nil
            await reconcileTrackedMachineNotifications()
            await reconcileLiveActivity()
        } catch let apiError as APIClientError {
            if case .server(let status, _) = apiError, status == 401 {
                loginError = "Login failed. Check your credentials."
                isLoginSheetPresented = true
            }
            errorMessage = apiError.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restartAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil

        guard refreshInterval != .off, credentials != nil else {
            return
        }

        let intervalSeconds = refreshInterval.rawValue
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(intervalSeconds))
                guard let self else {
                    return
                }
                await self.refresh()
            }
        }
    }

    private var statusRelevantGroups: [ResourceGroup] {
        if preferredStatusGroupNames.isEmpty {
            return groups
        }

        return groups.filter { preferredStatusGroupNames.contains($0.name) }
    }

    private var allMachineEntries: [GroupMachine] {
        groups.flatMap { group in
            group.machines.map { GroupMachine(groupName: group.name, machine: $0) }
        }
    }

    private func refreshNotificationAuthorizationStatus() async {
        notificationAuthorizationStatus = await notificationManager.authorizationStatus()
    }

    private func authorizationAllowsNotifications(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    private func notificationIdentifier(forMachineID machineID: String) -> String {
        "tvattstuga.machine-ready.\(machineID)"
    }

    private func reconcileTrackedMachineNotifications() async {
        guard !trackedNotificationMachineIDs.isEmpty else {
            return
        }

        await refreshNotificationAuthorizationStatus()

        var changed = false
        let now = Date()

        if let trackedMachineAlertEndDate, trackedMachineAlertEndDate <= now {
            let machineName = trackedMachineAlertLabel == "None" ? "Laundry machine" : trackedMachineAlertLabel
            await stopTrackedMachineAlert(clearMessage: false)
            setTrackingInfoMessage("\(machineName) should be ready now.")
            return
        }

        if trackedNotificationMachineIDs.count > 1 {
            let preferredMachineID = trackedLiveActivityMachineID
                ?? trackedNotificationMachineIDs.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.first

            for machineID in trackedNotificationMachineIDs where machineID != preferredMachineID {
                notificationManager.removeNotification(identifier: notificationIdentifier(forMachineID: machineID))
                trackedNotificationMachineIDs.remove(machineID)
                changed = true
            }
        }

        for machineID in Array(trackedNotificationMachineIDs) {
            guard let entry = allMachineEntries.first(where: { $0.id == machineID }) else {
                notificationManager.removeNotification(identifier: notificationIdentifier(forMachineID: machineID))
                trackedNotificationMachineIDs.remove(machineID)
                changed = true
                continue
            }

            guard let completion = entry.machine.completionDate(), completion > now else {
                notificationManager.removeNotification(identifier: notificationIdentifier(forMachineID: machineID))
                trackedNotificationMachineIDs.remove(machineID)
                changed = true
                continue
            }

            guard notificationPermissionAllowsTracking else {
                continue
            }

            do {
                try await notificationManager.scheduleMachineReadyNotification(
                    identifier: notificationIdentifier(forMachineID: machineID),
                    title: "Laundry ready",
                    body: "\(entry.machine.name) in \(entry.groupName) should be ready now.",
                    at: completion
                )
            } catch {
                setTrackingInfoMessage("Could not refresh some notifications: \(error.localizedDescription)")
            }
        }

        if changed {
            persistTrackedMachineNotifications()
        }
    }

    private func persistPreferredStatusGroups() {
        let sorted = Array(preferredStatusGroupNames).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        UserDefaults.standard.set(sorted, forKey: preferredStatusGroupsKey)
    }

    private func persistTrackedMachineNotifications() {
        let sorted = Array(trackedNotificationMachineIDs).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        UserDefaults.standard.set(sorted, forKey: trackedNotificationMachineIDsKey)
    }

    private func persistTrackedLiveActivityMachineID() {
        UserDefaults.standard.set(trackedLiveActivityMachineID, forKey: trackedLiveActivityMachineIDKey)
    }

    private func persistTrackedMachineAlertEndDate() {
        if let trackedMachineAlertEndDate {
            UserDefaults.standard.set(trackedMachineAlertEndDate, forKey: trackedMachineAlertEndDateKey)
        } else {
            UserDefaults.standard.removeObject(forKey: trackedMachineAlertEndDateKey)
        }
    }

    private func reconcileLiveActivity() async {
        guard #available(iOS 16.1, *) else {
            return
        }

        if let activeMachineID = LiveActivityManager.trackedMachineID(), trackedLiveActivityMachineID != activeMachineID {
            trackedLiveActivityMachineID = activeMachineID
            persistTrackedLiveActivityMachineID()
        }

        guard let machineID = trackedLiveActivityMachineID else {
            cancelLiveActivityAutoStop()
            return
        }

        guard let entry = allMachineEntries.first(where: { $0.id == machineID }) else {
            trackedNotificationMachineIDs.remove(machineID)
            persistTrackedMachineNotifications()
            await stopLiveActivity(clearMessage: false)
            return
        }

        guard let completion = entry.machine.completionDate(), completion > Date() else {
            trackedNotificationMachineIDs.remove(machineID)
            persistTrackedMachineNotifications()
            await stopLiveActivity(clearMessage: false)
            return
        }

        do {
            try await LiveActivityManager.startOrUpdate(
                machineID: machineID,
                machineName: entry.machine.name,
                groupName: entry.groupName,
                endDate: completion
            )
            scheduleLiveActivityAutoStop(for: machineID, at: completion)

            if trackedNotificationMachineIDs != [machineID] {
                for trackedMachineID in trackedNotificationMachineIDs where trackedMachineID != machineID {
                    notificationManager.removeNotification(identifier: notificationIdentifier(forMachineID: trackedMachineID))
                }
                trackedNotificationMachineIDs = [machineID]
                persistTrackedMachineNotifications()
            }

            if notificationPermissionAllowsTracking {
                do {
                    try await notificationManager.scheduleMachineReadyNotification(
                        identifier: notificationIdentifier(forMachineID: machineID),
                        title: "Laundry ready",
                        body: "\(entry.machine.name) in \(entry.groupName) should be ready now.",
                        at: completion
                    )
                } catch {
                    setTrackingInfoMessage("Could not refresh machine tracking: \(error.localizedDescription)")
                }
            }
        } catch {
            setTrackingInfoMessage("Could not refresh Live Activity: \(error.localizedDescription)")
        }
    }

    private func setTrackingInfoMessage(_ message: String?) {
        notificationInfoMessage = message
        liveActivityInfoMessage = message
    }

    private func scheduleLiveActivityAutoStop(for machineID: String, at completion: Date) {
        cancelLiveActivityAutoStop()
        trackedMachineAlertEndDate = completion
        persistTrackedMachineAlertEndDate()

        let delay = max(1, completion.timeIntervalSinceNow + 1)
        liveActivityEndTask = Task { [weak self] in
            let nanoseconds = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else {
                return
            }
            await self?.completeTrackedMachineIfNeeded(machineID: machineID)
        }
    }

    private func cancelLiveActivityAutoStop() {
        liveActivityEndTask?.cancel()
        liveActivityEndTask = nil
    }

    private func completeTrackedMachineIfNeeded(machineID: String) async {
        guard trackedLiveActivityMachineID == machineID else {
            return
        }

        let machineName = allMachineEntries.first(where: { $0.id == machineID })?.machine.name ?? "Laundry machine"
        trackedNotificationMachineIDs.remove(machineID)
        persistTrackedMachineNotifications()
        await stopLiveActivity(clearMessage: false)
        setTrackingInfoMessage("\(machineName) should be ready now.")
    }

    private func expireTrackedMachineAlertIfNeeded() async {
        guard let trackedMachineAlertEndDate else {
            return
        }

        let now = Date()
        if trackedMachineAlertEndDate <= now {
            let machineName = trackedMachineAlertLabel == "None" ? "Laundry machine" : trackedMachineAlertLabel
            await stopTrackedMachineAlert(clearMessage: false)
            setTrackingInfoMessage("\(machineName) should be ready now.")
            return
        }

        if let machineID = trackedLiveActivityMachineID {
            scheduleLiveActivityAutoStop(for: machineID, at: trackedMachineAlertEndDate)
        }
    }
}
