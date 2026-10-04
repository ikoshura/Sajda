// MARK: - Sajda/CustomTimetableView.swift
//
// The timetable library: imported timetables (PDF, ZIP, or CSV), one active.
// The app never contacts a timetable server: files are picked from disk via
// an Open panel and stored locally.
//
// Every imported timetable becomes a favorite, so mosques switch with one tap
// from the panel's favorites list. The active row shows its summary; every
// row carries its heart and its delete. Deleting the active timetable hands
// over to the newest survivor, or to calculation when none remain.

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct CustomTimetableView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel

    @State private var errorText: String?
    @State private var isHovering = false
    @State private var hoveringID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if vm.customTimetables.isEmpty {
                importView
            } else {
                ForEach(vm.customTimetables) { timetable in
                    timetableRow(timetable)
                }
                addRow
            }
        }
        .onAppear {
            // An import can orphan favorites whose row disappears behind a
            // stale cache: retire them when the page opens so the panel and
            // the Settings list agree.
            vm.pruneMissingTimetableFavorites()
        }
    }

    // MARK: - Timetable rows

    private func timetableRow(_ timetable: CustomTimetable) -> some View {
        let isActive = vm.useCustomTimetable && vm.activeTimetableId == timetable.id
        return Button(action: { vm.switchToTimetable(id: timetable.id) }) {
            HStack(spacing: 6) {
                Image(systemName: "building.columns")
                    .scaledFont(.caption)
                    .foregroundColor(isActive ? vm.legibleInteractiveAccent : .secondary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(timetable.name)
                        .scaledFont(.subheadline, weight: isActive ? .semibold : .regular)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(Self.summary(timetable))
                        .scaledFont(.caption2)
                        .foregroundColor(Color("SecondaryTextColor"))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 4)
                HStack(spacing: 0) {
                    if isActive {
                        Image(systemName: "checkmark")
                            .scaledFont(.caption, weight: .semibold)
                            .foregroundColor(vm.legibleInteractiveAccent)
                            .frame(width: 20)
                    } else {
                        Color.clear.frame(width: 20)
                    }
                    Color.clear.frame(width: 20)
                }
            }
            .padding(.vertical, 5).padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .liquidHover(hoveringID == timetable.id)
        .onHover { hovering in hoveringID = hovering ? timetable.id : nil }
        .overlay(alignment: .trailing) {
            HStack(spacing: 2) {
                Button(action: { vm.toggleTimetableFavorite(timetable) }) {
                    Image(systemName: vm.isTimetableFavorite(id: timetable.id) ? "heart.fill" : "heart")
                        .scaledFont(.caption)
                        .foregroundColor(vm.isTimetableFavorite(id: timetable.id) ? vm.favoriteColor : .secondary)
                        .frame(width: 20, height: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help(Text(NSLocalizedString(
                    vm.isTimetableFavorite(id: timetable.id) ? "Remove from Favorites" : "Add to Favorites",
                    comment: "")))
                Button(action: { vm.deleteTimetable(id: timetable.id) }) {
                    Image(systemName: "trash")
                        .scaledFont(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help(Text(NSLocalizedString("Delete timetable", comment: "")))
            }
            .padding(.trailing, 8)
        }
    }

    // MARK: - Add row

    /// The plus row. Sits after the rows, never in a header, because an import
    /// changes the list length and a header overlay would shift under it.
    private var addRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { importFile() }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                        .scaledFont(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                    Text(NSLocalizedString("Add timetable", comment: ""))
                        .scaledFont(.subheadline)
                    Spacer(minLength: 4)
                }
                .padding(.vertical, 5).padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .liquidHover(isHovering)
            .onHover { hovering in isHovering = hovering }

            if let errorText {
                Text(errorText)
                    .scaledFont(.caption2)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(NSLocalizedString("timetable_import_hint", comment: ""))
                    .scaledFont(.caption2)
                    .foregroundColor(Color("SecondaryTextColor"))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private static func summary(_ timetable: CustomTimetable) -> String {
        let days = timetable.calendar.reduce(0) { $0 + $1.count }
        var parts = ["\(days) days"]
        if timetable.iqamaCalendar != nil { parts.append("iqama") }
        if let jumuah = timetable.jumuahSessions, !jumuah.isEmpty {
            parts.append("jumua " + jumuah.joined(separator: ", "))
        }
        return parts.joined(separator: " · ")
    }

    private func importFile() {
        errorText = nil
        let panel = NSOpenPanel()
        // One picker for every timetable format: a PDF is a self-contained
        // import, the ZIP is the monthly CSVs glued together, and CSV
        // still lets a hand-picked monthly set through.
        panel.allowedContentTypes = [.pdf, .zip, .commaSeparatedText, .plainText, .text]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.prompt = NSLocalizedString("Choose", comment: "")
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        do {
            let picked = panel.urls
            let imported: CustomTimetable
            if picked.count == 1, picked[0].pathExtension.lowercased() == "pdf" {
                imported = try CustomTimetableStore.parsePDF(url: picked[0])
            } else if picked.count == 1, picked[0].pathExtension.lowercased() == "zip" {
                let calendar = try CustomTimetableStore.parseAdhanZip(url: picked[0])
                imported = CustomTimetable(
                    name: picked[0].deletingPathExtension().lastPathComponent,
                    calendar: calendar)
            } else {
                let calendar = try CustomTimetableStore.parseAdhanFiles(picked)
                let name = picked.first?.deletingPathExtension().lastPathComponent ?? "CSV"
                imported = CustomTimetable(name: name, calendar: calendar)
            }
            let stored = try CustomTimetableStore.add(imported)
            vm.customTimetables = CustomTimetableStore.loadAll()
            vm.toggleTimetableFavorite(stored)
            vm.switchToTimetable(id: stored.id)
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Empty state

    private var importView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Button(action: { importFile() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .scaledFont(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 16)
                        Text(NSLocalizedString("Import timetable", comment: ""))
                            .scaledFont(.subheadline)
                        Spacer(minLength: 4)
                    }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .liquidHover(isHovering)
                .onHover { hovering in isHovering = hovering }
            }

            if let errorText {
                Text(errorText)
                    .scaledFont(.caption2)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(NSLocalizedString("timetable_import_hint", comment: ""))
                    .scaledFont(.caption2)
                    .foregroundColor(Color("SecondaryTextColor"))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

