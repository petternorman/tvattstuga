import SwiftUI

struct StatusTabView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            Group {
                if model.isInitialLoading && model.groups.isEmpty {
                    ProgressView("Loading status...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if model.allGroupsCount == 0 {
                    ContentUnavailableView(
                        "No Data Yet",
                        systemImage: "tray",
                        description: Text("Save credentials in Settings to start loading laundry status.")
                    )
                } else if model.summaryGroupsCount == 0 {
                    ContentUnavailableView(
                        "No Preferred Groups",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Choose at least one group in Settings, or clear your filter.")
                    )
                } else {
                    List {
                        summarySection

                        if let errorMessage = model.errorMessage {
                            Section {
                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundStyle(.red)
                            }
                        }

                        if !model.availableEntries.isEmpty {
                            Section("Available Now") {
                                ForEach(model.availableEntries) { entry in
                                    MachineRowView(entry: entry, showGroupName: true)
                                }
                            }
                        }

                        if !model.activeEntries.isEmpty {
                            Section("Active Cycles") {
                                ForEach(model.activeEntries) { entry in
                                    MachineRowView(
                                        entry: entry,
                                        showGroupName: true,
                                        showsTrackingControl: model.canTrackMachineAlert(for: entry),
                                        isTrackingEnabled: model.isMachineAlertEnabled(for: entry),
                                        onTrackingToggle: {
                                            Task {
                                                await model.toggleMachineAlert(for: entry)
                                            }
                                        }
                                    )
                                }
                            }
                        }

                        if let lastUpdated = model.lastUpdatedAt {
                            Section {
                                Text("Last updated \(lastUpdated.formatted(date: .omitted, time: .standard))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Status")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await model.refresh()
                        }
                    } label: {
                        if model.isRefreshing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(model.isRefreshing || model.isInitialLoading)
                }
            }
            .refreshable {
                await model.refresh()
            }
        }
    }

    private var summarySection: some View {
        Section("Overview") {
            LabeledContent("Available") {
                Text("\(model.summaryAvailableCount)")
            }
        }
    }
}
