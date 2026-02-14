import SwiftUI

struct MachineRowView: View {
    let entry: GroupMachine
    var showGroupName = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let state = entry.machine.displayState(referenceDate: context.date)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.machine.name)
                        .font(.headline)

                    if showGroupName {
                        Text(entry.groupName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(entry.machine.detailLine(referenceDate: context.date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(state.title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(state.tintColor)
                    .background(state.tintColor.opacity(0.15))
                    .clipShape(Capsule())
            }
            .padding(.vertical, 4)
        }
    }
}
