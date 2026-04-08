import ActivityKit
import SwiftUI
import WidgetKit

struct TvattstugaLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MachineLiveActivityAttributes.self) { context in
            HStack(alignment: .top, spacing: 12) {
                WasherActivityIcon(size: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.machineName)
                        .font(.headline)
                        .lineLimit(1)

                    Text(context.state.groupName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text("Ready \(context.state.endDate, style: .time)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                CountdownText(endDate: context.state.endDate)
                    .font(.title2.monospacedDigit().weight(.bold))
                    .foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .activityBackgroundTint(Color(.systemBackground))
            .activitySystemActionForegroundColor(.blue)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    WasherActivityIcon(size: 24)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(endDate: context.state.endDate)
                        .font(.title3.monospacedDigit().weight(.bold))
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.machineName)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(context.state.groupName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Text(context.state.endDate, style: .time)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                WasherActivityIcon(size: 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } compactTrailing: {
                CountdownText(endDate: context.state.endDate)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } minimal: {
                WasherActivityIcon(size: 14)
            }
            .keylineTint(.blue)
        }
    }
}

private struct WasherActivityIcon: View {
    var size: CGFloat

    var body: some View {
        Image("WasherGlyph")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

private struct CountdownText: View {
    let endDate: Date

    var body: some View {
        Text(timerInterval: Date()...max(Date(), endDate), countsDown: true)
            .contentTransition(.numericText())
    }
}
