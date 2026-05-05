import SwiftUI

struct CountdownRow: View {
    let item: CountdownItem
    /// Tap callback for the trailing ring. The ring doubles as the
    /// completion toggle (replacing the previous left-side checkbox), so
    /// the parent row supplies what to do when the user taps it. Optional
    /// for previews / static contexts that don't need the action.
    var onToggleCompletion: (() -> Void)? = nil

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(alignment: .center, spacing: 12) {
                // Leading ring doubles as the completion toggle — sits where
                // users instinctively look for a checkbox in a todo-style
                // list. Active state: depleting urgency ring (green/orange/
                // red). Completed state: solid green disc + white check,
                // mirroring Apple Watch Activity-ring goal closure.
                let diff = item.targetDate.timeIntervalSince(context.date)
                Button {
                    onToggleCompletion?()
                } label: {
                    CountdownProgressRing(
                        progress: ringProgress(at: context.date),
                        tint: ringColor(for: diff),
                        isCompleted: item.isCompleted
                    )
                    .frame(width: 34, height: 34)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.isCompleted
                    ? "Reopen \(item.title)"
                    : "Mark \(item.title) as done")

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

                countdownView(at: context.date)
            }
            .padding(.vertical, 4)
            .opacity(item.isCompleted ? 0.6 : 1.0)
        }
    }

    /// Smallest fraction of the ring we'll ever render colored, so overdue
    /// items keep a tiny red dot at the top of the ring instead of
    /// looking like an unchecked checkbox. With the 3pt rounded line
    /// caps, ~1% of arc renders as essentially just the cap geometry —
    /// a small dot, no visible "arc" length.
    private static let minVisibleProgress: Double = 0.01

    /// Progress of the urgency ring, 0...1. 1 = freshly created, 0 = deadline
    /// reached or passed (clamped to a small sliver so overdue items stay
    /// visually distinct from a vanilla checkbox). For items predating the
    /// `createdAt` field (default `.distantPast`) we fall back to a 30-day
    /// rolling window so the ring still depletes meaningfully.
    private func ringProgress(at now: Date) -> Double {
        let remaining = item.targetDate.timeIntervalSince(now)
        guard remaining > 0 else { return Self.minVisibleProgress }

        // Anything older than ~10 years is a sentinel `.distantPast` from
        // a legacy row. Use a 30-day rolling window in that case.
        let legacyCutoff = now.addingTimeInterval(-10 * 365 * 86400)
        let total: TimeInterval
        if item.createdAt < legacyCutoff {
            total = 30 * 86400
        } else {
            total = item.targetDate.timeIntervalSince(item.createdAt)
        }
        guard total > 0 else { return Self.minVisibleProgress }
        let raw = remaining / total
        return min(1, max(Self.minVisibleProgress, raw))
    }

    /// Mirrors the day-count text color exactly: red overdue / red < 1d /
    /// orange < 7d / green ≥ 7d. Kept here rather than reusing
    /// `countdownDisplay(diff:).color` to avoid recomputing the entire
    /// CountdownDisplay struct just for the ring tint.
    private func ringColor(for diff: TimeInterval) -> Color {
        if diff <= 0 { return .red }
        if diff < 86400 { return .red }
        if diff < 7 * 86400 { return .orange }
        return .green
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
    /// Fraction of the ring filled, clamped to 0...1.
    /// 1 = full (just created), 0 = deadline reached / past.
    let progress: Double
    /// Stroke + glow color for the active state. Caller passes the same
    /// urgency color used by the day-count text so the two visual
    /// elements stay in sync.
    let tint: Color
    /// When true, the ring renders as a "closed" goal: solid green disc
    /// with a white checkmark, mirroring the Apple Watch Activity-ring
    /// completion state. When false, the ring shows the active depleting
    /// trim over a gray track.
    let isCompleted: Bool

    var body: some View {
        ZStack {
            if isCompleted {
                // Closed-goal look: solid green fill + white check. The
                // outline preserves the ring silhouette so the row's
                // visual mass doesn't shift between active and done.
                Circle()
                    .fill(Color.green)
                    .shadow(color: Color.green.opacity(0.55), radius: 2.5)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.white)
            } else {
                // Gray track underneath — the "empty" portion of the ring.
                Circle()
                    .stroke(
                        Color.gray.opacity(0.25),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )

                // Glowing trim — the "remaining" portion. Rotated -90° so
                // 0% trim starts at the top and grows clockwise, matching
                // the visual language of a depleting timer.
                Circle()
                    .trim(from: 0, to: max(0, min(1, progress)))
                    .stroke(
                        tint,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: tint.opacity(0.7), radius: 2.5)
                    .animation(.easeInOut(duration: 0.4), value: progress)

                // Faint "ghost" checkmark inside the ring — a discoverability
                // cue that hints at tap-to-complete without competing with
                // the urgency colors. On completion the ring transitions to
                // the bright white check above; this is its low-opacity
                // preview.
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.secondary.opacity(0.45))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isCompleted)
    }
}
