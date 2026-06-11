import SwiftUI

/// Fixed-width numeric display to prevent card layout shift when values change.
struct StableMetric: View {
    let text: String
    var fontSize: CGFloat = 40
    var width: CGFloat = 72
    var alignment: Alignment = .leading
    var weight: Font.Weight = .bold

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: weight, design: .monospaced))
            .monospacedDigit()
            .frame(width: width, alignment: alignment)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

struct StablePercent: View {
    let value: Double
    var fontSize: CGFloat = 22
    var width: CGFloat = 56

    var body: some View {
        Text(String(format: "%.1f", value))
            .font(.system(size: fontSize, weight: .bold, design: .monospaced))
            .monospacedDigit()
            .frame(width: width, alignment: .center)
            .lineLimit(1)
    }
}

struct StablePercentLabel: View {
    let value: Double
    var width: CGFloat = 52

    var body: some View {
        Text(String(format: "%.1f%%", value))
            .font(.caption.monospacedDigit())
            .frame(width: width, alignment: .trailing)
            .lineLimit(1)
    }
}

struct StableProcessCPU: View {
    let value: Double
    var width: CGFloat = 48

    var body: some View {
        Text(String(format: "%.1f%%", value))
            .font(.caption.monospacedDigit())
            .frame(width: width, alignment: .trailing)
            .lineLimit(1)
    }
}
