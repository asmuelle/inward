import DesignSystem
import JournalStore
import SwiftUI

/// The privacy controls: the optional lock and the encrypted export, plus the
/// quiet restatement of what Inward never does.
struct SettingsView: View {
    let store: any JournalStoring

    @AppStorage(Prefs.lockEnabled) private var lockEnabled = false
    @Environment(\.dismiss) private var dismiss
    @State private var showingExport = false
    @State private var showingImport = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Lamplight.Spacing.section) {
                    lockSection
                    exportSection
                    importSection
                    Text(Copy.settingsPrivacyFooter)
                        .font(.lamplight(.caption))
                        .foregroundStyle(Color.inwardSage)
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
