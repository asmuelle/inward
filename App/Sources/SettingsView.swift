import DesignSystem
import JournalStore
import QuickCaptureKit
import SwiftUI

/// The privacy controls: the optional lock and the encrypted export, plus the
/// quiet restatement of what Inward never does.
struct SettingsView: View {
    let store: any JournalStoring

    @AppStorage(Prefs.lockEnabled) private var lockEnabled = false
    @AppStorage(Prefs.spokenSummaryEnabled) private var spokenSummaryEnabled = false
    @AppStorage(Prefs.weeklyReminderEnabled) private var weeklyReminderEnabled = false
    /// Calendar weekday, Sunday = 1; default Sunday evening at 8 (in minutes).
    @AppStorage(Prefs.weeklyReminderWeekday) private var weeklyReminderWeekday = 1
    @AppStorage(Prefs.weeklyReminderMinutes) private var weeklyReminderMinutes = 20 * 60
    @Environment(\.dismiss) private var dismiss
    @State private var showingExport = false
    @State private var showingImport = false
    @State private var reminderDenied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Lamplight.Spacing.section) {
                    lockSection
                    spokenSummarySection
                    weeklyReminderSection
                    proofSection
                    exportSection
                    importSection
                    Text(Copy.settingsPrivacyFooter)
                        .font(.lamplight(.caption))
                        .foregroundStyle(Color.inwardSage)
                        .frame(maxWidth: .infinity, alignment: .center)
                    HStack(spacing: Lamplight.Spacing.element) {
                        Link(Copy.legalPrivacyLink, destination: LegalLinks.privacyPolicy)
                        Link(Copy.legalTermsLink, destination: LegalLinks.termsOfUse)
                    }
                    .font(.lamplight(.caption))
                    .foregroundStyle(Color.inwardClay)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(Lamplight.Spacing.block)
            }
            .background(Color.inwardPaper.ignoresSafeArea())
            .navigationTitle(Copy.settingsTitle)
            .inwardInlineTitle()
            .toolbar {
                ToolbarItem(placement: .inwardTrailing) {
                    Button(Copy.settingsDone) { dismiss() }
                        .font(.lamplight(.chrome))
                }
            }
            .sheet(isPresented: $showingExport) {
                ExportView(store: store)
            }
            .sheet(isPresented: $showingImport) {
                ImportView(store: store)
            }
        }
    }

    private var lockSection: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: Lamplight.Spacing.tight) {
                Toggle(isOn: $lockEnabled) {
                    Text(Copy.settingsLockToggle)
                        .font(.lamplight(.entryProse))
                        .foregroundStyle(Color.inwardInk)
                }
                .tint(.inwardClay)
                Text(Copy.settingsLockFooter)
                    .font(.lamplight(.caption))
                    .foregroundStyle(Color.inwardSage)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var spokenSummarySection: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: Lamplight.Spacing.tight) {
                Toggle(isOn: $spokenSummaryEnabled) {
                    Text(Copy.settingsSpokenSummaryToggle)
                        .font(.lamplight(.entryProse))
                        .foregroundStyle(Color.inwardInk)
                }
                .tint(.inwardClay)
                Text(Copy.settingsSpokenSummaryFooter)
                    .font(.lamplight(.caption))
                    .foregroundStyle(Color.inwardSage)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var weeklyReminderSection: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: Lamplight.Spacing.tight) {
                Toggle(isOn: $weeklyReminderEnabled) {
                    Text(Copy.settingsWeeklyReminderToggle)
                        .font(.lamplight(.entryProse))
                        .foregroundStyle(Color.inwardInk)
                }
                .tint(.inwardClay)
                if weeklyReminderEnabled {
                    Picker(selection: $weeklyReminderWeekday) {
                        ForEach(1 ... 7, id: \.self) { day in
                            Text(Calendar.current.weekdaySymbols[day - 1]).tag(day)
                        }
                    } label: {
                        Text(Copy.weeklyReminderDayLabel)
                            .font(.lamplight(.entryProse))
                            .foregroundStyle(Color.inwardInk)
                    }
                    .tint(.inwardClay)
                    DatePicker(selection: reminderTimeBinding, displayedComponents: .hourAndMinute) {
                        Text(Copy.weeklyReminderTimeLabel)
                            .font(.lamplight(.entryProse))
                            .foregroundStyle(Color.inwardInk)
                    }
                    .tint(.inwardClay)
                }
                Text(reminderDenied ? Copy.settingsWeeklyReminderDenied : Copy.settingsWeeklyReminderFooter)
                    .font(.lamplight(.caption))
                    .foregroundStyle(Color.inwardSage)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: weeklyReminderEnabled) { _, _ in Task { await applyWeeklyReminder() } }
        .onChange(of: weeklyReminderWeekday) { _, _ in Task { await applyWeeklyReminder() } }
        .onChange(of: weeklyReminderMinutes) { _, _ in Task { await applyWeeklyReminder() } }
    }

    /// Bridges the minutes-since-midnight preference to the time picker.
    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                let components = DateComponents(hour: weeklyReminderMinutes / 60, minute: weeklyReminderMinutes % 60)
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                weeklyReminderMinutes = (parts.hour ?? 20) * 60 + (parts.minute ?? 0)
            }
        )
    }

    private func applyWeeklyReminder() async {
        let granted = await WeeklyReviewReminder.apply(
            enabled: weeklyReminderEnabled,
            weekday: weeklyReminderWeekday,
            minutesOfDay: weeklyReminderMinutes
        )
        // Only judge denial while switched on; the disable pass must not clear
        // the hint that explains why the toggle just fell back.
        if weeklyReminderEnabled {
            reminderDenied = !granted
            if !granted { weeklyReminderEnabled = false }
        }
    }

    /// The standing airplane-mode proof — the brand promise as a screen.
    private var proofSection: some View {
        PaperCard {
            NavigationLink {
                ProofView(onTryCapture: tryProofCapture)
            } label: {
                HStack {
                    Text(Copy.settingsProofLink)
                        .font(.lamplight(.entryProse))
                        .foregroundStyle(Color.inwardInk)
                    Spacer()
                    Image(systemName: "airplane")
                        .foregroundStyle(Color.inwardClay)
                }
            }
            .buttonStyle(.plain)
        }
    }

    /// Closes Settings, then rides the existing quick-capture signal into a
    /// recording. The short pause lets the sheet finish dismissing so the
    /// capture sheet can present.
    private func tryProofCapture() {
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            QuickCaptureSignal.shared.requestStart()
        }
    }

    private var exportSection: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: Lamplight.Spacing.tight) {
                Button {
                    showingExport = true
                } label: {
                    HStack {
                        Text(Copy.settingsExport)
                            .font(.lamplight(.entryProse))
                            .foregroundStyle(Color.inwardInk)
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Color.inwardClay)
                    }
                }
                .buttonStyle(.plain)
                Text(Copy.settingsExportFooter)
                    .font(.lamplight(.caption))
                    .foregroundStyle(Color.inwardSage)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var importSection: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: Lamplight.Spacing.tight) {
                Button {
                    showingImport = true
                } label: {
                    HStack {
                        Text(Copy.settingsImport)
                            .font(.lamplight(.entryProse))
                            .foregroundStyle(Color.inwardInk)
                        Spacer()
                        Image(systemName: "square.and.arrow.down")
                            .foregroundStyle(Color.inwardClay)
                    }
                }
                .buttonStyle(.plain)
                Text(Copy.settingsImportFooter)
                    .font(.lamplight(.caption))
                    .foregroundStyle(Color.inwardSage)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
