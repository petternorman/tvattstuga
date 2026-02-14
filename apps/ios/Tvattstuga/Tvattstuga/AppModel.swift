import Foundation
import Combine

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

    @Published var isLoginSheetPresented = false
    @Published var loginUsername = ""
    @Published var loginPassword = ""
    @Published var loginError: String?
    @Published var apiBaseURLOverrideInput = ""

    private let apiClient: APIClient
    private let credentialsStore: CredentialsStoring
    private let refreshIntervalKey = "tvattstuga.refresh.interval.seconds"
    private let preferredStatusGroupsKey = "tvattstuga.status.preferred.groups"

    private var credentials: Credentials?
    private var hasBootstrapped = false
    private var autoRefreshTask: Task<Void, Never>?

    init(
        apiClient: APIClient = APIClient(),
        credentialsStore: CredentialsStoring = KeychainCredentialsStore()
    ) {
        self.apiClient = apiClient
        self.credentialsStore = credentialsStore

        let storedValue = UserDefaults.standard.object(forKey: refreshIntervalKey) as? Int
        refreshInterval = RefreshInterval.fromStoredSeconds(storedValue ?? RefreshInterval.minute1.rawValue)
        let storedPreferredGroups = UserDefaults.standard.stringArray(forKey: preferredStatusGroupsKey) ?? []
        preferredStatusGroupNames = Set(storedPreferredGroups)
        apiBaseURLOverrideInput = AppConfig.apiBaseURLOverrideString
    }

    deinit {
        autoRefreshTask?.cancel()
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

    private func persistPreferredStatusGroups() {
        let sorted = Array(preferredStatusGroupNames).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        UserDefaults.standard.set(sorted, forKey: preferredStatusGroupsKey)
    }
}
