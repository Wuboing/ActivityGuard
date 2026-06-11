import SwiftUI

// MARK: - Sparkline

struct SparklineView: View {
    let values: [Double]
    var color: Color = Color(hex: 0x0A84FF)
    var height: CGFloat = 32
    var showGradient: Bool = true

    var body: some View {
        GeometryReader { geo in
            if values.count >= 2 {
                let maxVal = max(values.max() ?? 1, 1)
                let step = geo.size.width / CGFloat(values.count - 1)
                let points: [CGPoint] = values.enumerated().map { i, v in
                    let x = CGFloat(i) * step
                    let y = geo.size.height - CGFloat(v / maxVal) * geo.size.height
                    return CGPoint(x: x, y: y)
                }

                let linePath = Path { path in
                    for (i, p) in points.enumerated() {
                        if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                    }
                }

                let areaPath = Path { path in
                    guard let first = points.first, let last = points.last else { return }
                    path.move(to: CGPoint(x: first.x, y: geo.size.height))
                    path.addLine(to: first)
                    for p in points.dropFirst() { path.addLine(to: p) }
                    path.addLine(to: CGPoint(x: last.x, y: geo.size.height))
                    path.closeSubpath()
                }

                ZStack {
                    if showGradient {
                        areaPath.fill(
                            LinearGradient(
                                colors: [color.opacity(0.22), color.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    linePath.stroke(
                        color,
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                    )
                }
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.12))
                    .frame(height: 2)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Ring Progress

struct RingProgressView: View {
    let progress: Double
    let theme: MonitorTheme
    var lineWidth: CGFloat? = nil
    var size: CGFloat = 72

    private var resolvedLineWidth: CGFloat { lineWidth ?? (size > 80 ? 4 : 3) }

    private var ringColor: Color { theme.cpuColor(for: progress * 100) }

    var body: some View {
        let clamped = min(max(progress, 0), 1)
        ZStack {
            Circle()
                .stroke(theme.textTertiary.opacity(0.18), lineWidth: resolvedLineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(clamped))
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: resolvedLineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text(String(format: "%.0f%%", clamped * 100))
                .font(.system(size: size * 0.22, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Stacked CPU Bar

struct StackedCPUBar: View {
    let user: Double
    let system: Double
    let idle: Double
    let theme: MonitorTheme

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                segment(width: geo.size.width * CGFloat(user / 100), color: theme.primary)
                segment(width: geo.size.width * CGFloat(system / 100), color: theme.cyan)
                segment(width: geo.size.width * CGFloat(idle / 100), color: theme.textTertiary.opacity(0.22))
            }
        }
        .frame(height: 4)
        .clipShape(Capsule())
    }

    private func segment(width: CGFloat, color: Color) -> some View {
        Capsule()
            .fill(color)
            .frame(width: max(width, 0))
    }
}

// MARK: - Mini Progress

struct MiniProgressBar: View {
    let value: Double
    let maxValue: Double
    let color: Color
    var trackColor: Color? = nil
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(trackColor ?? Color.primary.opacity(0.08))
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(min(value / max(maxValue, 0.01), 1)))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Compact Process Row (Popover)

struct MonitorCompactProcessRow: View {
    let process: ProcessWithCPU
    let theme: MonitorTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(process.name)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(String(format: "%.1f%%", process.cpuPercent))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.cpuColor(for: process.cpuPercent))
                    .monospacedDigit()
            }
            MiniProgressBar(
                value: process.cpuPercent,
                maxValue: 100,
                color: theme.cpuColor(for: process.cpuPercent),
                trackColor: theme.progressTrack
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - KPI Card Header

struct MonitorCardHeader: View {
    let icon: String
    let title: String
    let theme: MonitorTheme
    var tint: Color? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint ?? theme.primary)
                .frame(width: 22, height: 22)
                .background(
                    (tint ?? theme.primary).opacity(0.14),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textSecondary)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Status Badge

struct MonitorStatusBadge: View {
    let active: Bool
    let theme: MonitorTheme
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(active ? theme.success : theme.warning)
                .frame(width: 8, height: 8)
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }
}

// MARK: - Process Row (Dashboard + List)

struct MonitorProcessRow: View {
    let process: ProcessWithCPU
    let theme: MonitorTheme
    var anomaly: Anomaly? = nil
    var showKill: Bool = false
    var onKill: (() -> Void)? = nil
    var striped: Bool = false

    @State private var hovered = false

    var body: some View {
        HStack(spacing: 12) {
            if let anomaly {
                Image(systemName: anomaly.kind.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(anomalyColor(anomaly.kind))
                    .frame(width: 16)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Text(process.name)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(format: "%.1f%%", process.cpuPercent))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.cpuColor(for: process.cpuPercent))
                        .monospacedDigit()
                        .frame(width: 52, alignment: .trailing)
                    Text(process.cpuTimeFormatted)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 64, alignment: .trailing)
                        .lineLimit(1)
                    Text(String(process.threadCount))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                    Text(process.rssFormatted)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 72, alignment: .trailing)
                }
                MiniProgressBar(
                    value: process.cpuPercent,
                    maxValue: 100,
                    color: theme.cpuColor(for: process.cpuPercent),
                    trackColor: theme.progressTrack
                )
            }

            if showKill, process.pid > 100 {
                Button(action: { onKill?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.danger)
                }
                .buttonStyle(.plain)
                .opacity(hovered ? 1 : 0.4)
                .help("Kill")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(
            hovered ? theme.rowHover : Color.clear,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .padding(.horizontal, 4)
        .onHover { hovered = $0 }
    }

    private func anomalyColor(_ kind: AnomalyKind) -> Color {
        switch kind {
        case .highCPU: return theme.danger
        case .memoryLeak: return theme.warning
        case .zombie: return theme.textTertiary
        case .highEnergy: return theme.warning
        }
    }
}
