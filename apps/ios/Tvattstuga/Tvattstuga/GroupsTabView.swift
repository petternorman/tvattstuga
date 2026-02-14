import SwiftUI

struct GroupsTabView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            Group {
                if model.isInitialLoading && model.groups.isEmpty {
                    ProgressView("Loading groups...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if model.groups.isEmpty {
                    ContentUnavailableView(
                        "No Groups",
                        systemImage: "square.grid.3x1.folder.badge.plus",
                        description: Text("Pull to refresh after you have added credentials.")
                    )
                } else {
                    List {
                        if let errorMessage = model.errorMessage {
                            Section {
                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundStyle(.red)
                            }
                        }

                        ForEach(model.groups) { group in
                            Section {
                                ForEach(group.machines) { machine in
                                    MachineRowView(
                                        entry: GroupMachine(groupName: group.name, machine: machine),
                                        showGroupName: false
                                    )
                                }
                            } header: {
                                GroupHeaderView(group: group)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Groups")
            .refreshable {
                await model.refresh()
            }
        }
    }
}

private struct GroupHeaderView: View {
    let group: ResourceGroup

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            HStack {
                Text(group.name)
                    .font(.headline)
                Spacer()
                Text("\(group.availableCount(referenceDate: context.date))/\(group.machines.count) available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
