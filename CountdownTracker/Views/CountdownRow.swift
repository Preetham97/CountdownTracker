import SwiftUI

struct CountdownRow: View {
    let item: CountdownItem

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body)
                        .fontWeight(.medium)
                    Text(item.targetDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                countdownView(at: context.date)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func countdownView(at now: Date) -> some View {
        let diff = item.targetDate.timeIntervalSince(now)
        let display = countdownDisplay(diff: diff)

        VStack(alignment: .trailing, spacing: 2) {
            Text(display.primary)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(display.color)
                .monospacedDigit()
            Text(display.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private struct CountdownDisplay {
        let primary: String
        let label: String
        let color: Color
    }

    private func countdownDisplay(diff: TimeInterval) -> CountdownDisplay {
        if diff <= 0 {
            let absDiff = abs(diff)
            let days = Int(absDiff / 86400)
            if days == 0 {
                return CountdownDisplay(primary: "Today", label: "passed", color: .secondary)
            }
            return CountdownDisplay(primary: "\(days)d", label: "ago", color: .secondary)
        }

        let days = Int(diff / 86400)
        let hours = Int(diff.truncatingRemainder(dividingBy: 86400) / 3600)
        let minutes = Int(diff.truncatingRemainder(dividingBy: 3600) / 60)
        let seconds = Int(diff.truncatingRemainder(dividingBy: 60))

        let color: Color
        if diff < 86400 { color = .red }
        else if diff < 7 * 86400 { color = .orange }
        else { color = .blue }

        if days > 0 {
            return CountdownDisplay(primary: "\(days)d \(hours)h", label: "\(minutes)m left", color: color)
        } else if hours > 0 {
            return CountdownDisplay(primary: "\(hours)h \(minutes)m", label: "\(seconds)s left", color: color)
        } else if minutes > 0 {
            return CountdownDisplay(primary: "\(minutes)m \(seconds)s", label: "left", color: color)
        } else {
            return CountdownDisplay(primary: "\(seconds)s", label: "left", color: .red)
        }
    }
}
