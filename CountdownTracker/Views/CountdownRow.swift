import SwiftUI

struct CountdownRow: View {
    let item: CountdownItem

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.body)
                            .fontWeight(.medium)
                            .strikethrough(item.isCompleted, color: .secondary)
                            .foregroundStyle(item.isCompleted ? Color.secondary : .primary)
                        if !item.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            // Visual hint that this row has notes — tap to
                            // open the edit sheet to read them.
                            Image(systemName: "note.text")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Has notes")
                        }
                    }
                    Text(item.targetDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !item.isCompleted {
                    // Visual urgency cue mirroring the app icon — a glowing
                    // red ring that depletes from full (at creation) to
                    // empty (at the deadline).
                    CountdownProgressRing(progress: ringProgress(at: context.date))
                        .frame(width: 26, height: 26)
                        .padding(.trailing, 2)
                }

                countdownView(at: context.date)
            }
            .padding(.vertical, 4)
            .opacity(item.isCompleted ? 0.6 : 1.0)
        }
    }

    /// Progress of the urgency ring, 0...1. 1 = freshly created, 0 = deadline
    /// reached or passed. For items predating the `createdAt` field (default
    /// `.distantPast`) we fall back to a 30-day rolling window so the ring
    /// still depletes meaningfully instead of looking permanently empty.
    private func ringProgress(at now: Date) -> Double {
        let remaining = item.targetDate.timeIntervalSince(now)
        guard remaining > 0 else { return 0 }

        // Anything older than ~10 years is a sentinel `.distantPast` from
        // a legacy row. Use a 30-day rolling window in that case.
        let legacyCutoff = now.addingTimeInterval(-10 * 365 * 86400)
        let total: TimeInterval
        if item.createdAt < legacyCutoff {
            total = 30 * 86400
        } else {
            total = item.targetDate.timeIntervalSince(item.createdAt)
        }
        guard total > 0 else { return 0 }
        return max(0, min(1, remaining / total))
    }

    @ViewBuilder
    private func countdownView(at now: Date) -> some View {
        let diff = item.targetDate.timeIntervalSince(now)
        let display = countdownDisplay(diff: diff)

        VStack(alignment: .trailing, spacing: 2) {
            Text(display.primary)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(item.isCompleted ? Color.secondary : display.color)
                .strikethrough(item.isCompleted, color: .secondary)
                .monospacedDigit()
            Text(item.isCompleted ? "done" : display.label)
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
            // Past-deadline, still-unchecked items stay in the active list and
            // render in red — they need the user to either check them off or
            // extend the deadline. Grey would read as "done" and hide the cue.
            let absDiff = abs(diff)
            let days = Int(absDiff / 86400)
            if days == 0 {
                return CountdownDisplay(primary: "Today", label: "passed", color: .red)
            }
            return CountdownDisplay(primary: "\(days)d", label: "ago", color: .red)
        }

        let days = Int(diff / 86400)
        let hours = Int(diff.truncatingRemainder(dividingBy: 86400) / 3600)
        let minutes = Int(diff.truncatingRemainder(dividingBy: 3600) / 60)
        let seconds = Int(diff.truncatingRemainder(dividingBy: 60))

        let color: Color
        if diff < 86400 { color = .red }
        else if diff < 7 * 86400 { color = .orange }
        else { color = .green }

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

/// Miniature of the app icon: a circular ring with a gray track and a
/// glowing red trim that depletes as a deadline approaches. Starts from
/// the top and unwinds clockwise, like a clock running down.
private struct CountdownProgressRing: View {
    /// Fraction of the ring filled in red, clamped to 0...1.
    /// 1 = full (just created), 0 = deadline reached / past.
    let progress: Double

    var body: some View {
        ZStack {
            // Gray track underneath — the "empty" portion of the ring.
            Circle()
                .stroke(
                    Color.gray.opacity(0.25),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )

            // Red glowing trim — the "remaining" portion. Rotated -90°
            // so 0% trim starts at the top and grows clockwise, matching
            // the visual language of a depleting timer.
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(
                    Color.red,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.red.opacity(0.7), radius: 2.5)
                .animation(.easeInOut(duration: 0.4), value: progress)
        }
    }
}
