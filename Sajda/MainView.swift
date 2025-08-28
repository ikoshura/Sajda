// Ganti seluruh kode di MainView.swift dengan ini

import SwiftUI
import Adhan

struct MainView: View {
    @ObservedObject var vm: PrayerTimeViewModel
    @Binding var activePage: ActivePage

    @State private var isSettingsHovering = false
    @State private var isAboutHovering = false
    @State private var isQuitHovering = false

    private let prayerOrder = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            HStack {
                Text("Sajda").font(.body).fontWeight(.bold)
                Spacer()
                if !vm.nextPrayerName.isEmpty && vm.nextPrayerName != "Done" {
                    Text("\(vm.nextPrayerName) in \(vm.countdown)").font(.body).foregroundColor(.secondary)
                }
            }.padding(.horizontal, 12).padding(.top, 4)

            Divider().padding(.horizontal, 12)

            VStack(spacing: 0) {
                ForEach(prayerOrder, id: \.self) { prayerName in
                    if let prayerTime = vm.todayTimes[prayerName] {
                        let isNextPrayer = prayerName == vm.nextPrayerName
                        let highlightColor = vm.isMonochrome ? Color.secondary.opacity(0.25) : Color.accentColor
                        let textColor = isNextPrayer ? (vm.isMonochrome ? Color.primary : Color.white) : Color.primary
                        HStack {
                            Text(prayerName)
                            Spacer()
                            Text(vm.dateFormatter.string(from: prayerTime)).font(.system(.body, design: .monospaced))
                        }
                        .foregroundColor(textColor).fontWeight(isNextPrayer ? .bold : .regular)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(isNextPrayer ? highlightColor : Color.clear))
                    }
                }
            }.padding(.horizontal, 5)
            
            Spacer(minLength: 0)
            
            Divider().padding(.horizontal, 12)
            
            VStack(alignment: .leading, spacing: 0) {
                Button(action: { activePage = .settings }) {
                    HStack {
                        Text("Settings"); Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .background(Color.secondary.opacity(isSettingsHovering ? 0.25 : 0)).cornerRadius(5)
                }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isSettingsHovering = hovering }
                
                Button(action: { activePage = .about }) {
                    HStack { Text("About"); Spacer() }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .background(Color.secondary.opacity(isAboutHovering ? 0.25 : 0)).cornerRadius(5)
                }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isAboutHovering = hovering }

                Divider().padding(.horizontal, 12)
                
                Button(action: { NSApp.terminate(nil) }) {
                    HStack { Text("Quit"); Spacer() }
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .background(Color.secondary.opacity(isQuitHovering ? 0.25 : 0)).cornerRadius(5)
                }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isQuitHovering = hovering }
            }
        }
        .padding(.vertical, 8)
    }
}
