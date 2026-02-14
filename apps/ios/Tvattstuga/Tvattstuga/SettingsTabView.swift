import SwiftUI

struct SettingsTabView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showClearCredentialsAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if let username = model.signedInUsername {
                        LabeledContent("Signed in as") {
                            Text(username)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Not signed in")
                            .foregroundStyle(.secondary)
                    }

                    Button(model.signedInUsername == nil ? "Add credentials" : "Update credentials") {
                        model.presentLoginSheet()
                    }

                    if model.signedInUsername != nil {
                        Button("Clear credentials", role: .destructive) {
                            showClearCredentialsAlert = true
                        }
                    }
                }

                Section("Refresh") {
                    Picker(
                        "Auto refresh",
                        selection: Binding(
                            get: { model.refreshInterval },
                            set: { model.setRefreshInterval($0) }
                        )
                    ) {
                        ForEach(RefreshInterval.allCases) { interval in
                            Text(interval.title).tag(interval)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Button("Refresh now") {
                        Task {
                            await model.refresh()
                        }
                    }
                    .disabled(model.isRefreshing || model.isInitialLoading)
                }

                Section("Status View") {
                    Text(model.statusFilterSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if model.sortedGroupNames.isEmpty {
                        Text("Load data to choose preferred groups.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.sortedGroupNames, id: \.self) { groupName in
                            Toggle(
                                groupName,
                                isOn: Binding(
                                    get: { model.isPreferredStatusGroup(groupName) },
                                    set: { model.setPreferredStatusGroup(groupName, enabled: $0) }
                                )
                            )
                        }
                    }

                    if model.isStatusFiltered {
                        Button("Show all groups") {
                            model.clearPreferredStatusGroups()
                        }
                    }
                }

                Section("API") {
                    LabeledContent("Base URL") {
                        Text(model.apiBaseURLDisplay)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Source") {
                        Text(model.apiBaseURLSourceDisplay)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }

                    Text("Priority: Run Arguments env var -> build configuration -> Settings override.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("API Override (Debug)") {
                    TextField("https://tvattstuga-api.vercel.app", text: $model.apiBaseURLOverrideInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    Button("Save override") {
                        model.saveAPIBaseURLOverride()
                    }

                    Button("Clear override", role: .destructive) {
                        model.clearAPIBaseURLOverride()
                    }

                    Text("Used only when env var and build configuration are both missing.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
        .alert("Clear saved credentials?", isPresented: $showClearCredentialsAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                model.clearCredentials()
            }
        } message: {
            Text("You will need to sign in again before data can be loaded.")
        }
    }
}
