import AppIntents
import QuickCaptureKit
import SwiftUI
import WidgetKit

/// The widget extension is intentionally decoupled from DesignSystem (which loads
/// custom fonts); it only needs three brand colors, defined inline.
private extension Color {
    static let paper = Color(red: 0xF7 / 255, green: 0xF2 / 255, blue: 0xE9 / 255)
    static let clay = Color(red: 0xB5 / 255, green: 0x65 / 255, blue: 0x4A / 255)
    static let ink = Color(red: 0x2B / 255, green: 0x26 / 255, blue: 0x20 / 255)
}

struct QuickRecordEntry: TimelineEntry {
    let date: Date
}

/// Static — the widget never changes; it's a button. A single timeline entry,
/// never refreshed.
struct QuickRecordProvider: TimelineProvider {
    func placeholder(in _: Context) -> QuickRecordEntry {
        QuickRecordEntry(date: Date())
    }

    func getSnapshot(in _: Context, completion: @escaping (QuickRecordEntry) -> Void) {
        completion(QuickRecordEntry(date: Date()))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<QuickRecordEntry>) -> Void) {
        completion(Timeline(entries: [QuickRecordEntry(date: Date())], policy: .never))
    }
}

/// Tap-to-record on the Home Screen (systemSmall) and Lock Screen (accessoryCircular).
struct QuickRecordWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "app.inward.Inward.QuickRecord", provider: QuickRecordProvider()) { _ in
            QuickRecordWidgetView()
        }
        .configurationDisplayName("Quick entry")
        .description("Tap to start a new Inward voice entry.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct QuickRecordWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            Button(intent: StartEntryIntent()) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 22, weight: .regular))
            }
            .buttonStyle(.plain)
            .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        default:
            Button(intent: StartEntryIntent()) {
                VStack(spacing: 8) {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(Color.clay)
                    Text("New entry")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(Color.ink)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .containerBackground(Color.paper, for: .widget)
        }
    }
}
