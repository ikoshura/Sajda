// Salin dan tempel SELURUH kode ini ke dalam file AboutView.swift

import SwiftUI

struct AboutView: View {
    @EnvironmentObject var vm: PrayerTimeViewModel
    @Binding var activePage: ActivePage
    
    @State private var isHeaderHovering = false
    @State private var isDoneHovering = false

    private var viewWidth: CGFloat {
        return vm.useCompactLayout ? 220 : 260
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { activePage = .main }) {
                HStack {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold))
                    Text("About Sajda").font(.body).fontWeight(.bold)
                    Spacer()
                }
                .padding(.vertical, 5).padding(.horizontal, 8)
                .background(Color.secondary.opacity(isHeaderHovering ? 0.25 : 0)).cornerRadius(5)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 5)
            .onHover { hovering in isHeaderHovering = hovering }
            
            Divider().padding(.horizontal, 12)
            
            VStack(spacing: 12) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(spacing: 2) {
                    Text("Sajda").font(.title2).fontWeight(.bold)
                    Text("Version 1.0.0").font(.caption).foregroundColor(.secondary)
                    Text("by abrarzha").font(.caption).foregroundColor(.secondary)
                }
                Text("A simple and beautiful prayer times app for your menu bar.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            HStack {
                Spacer()
                Button(action: { activePage = .main }) {
                    Text("Done")
                        .padding(.vertical, 3).padding(.horizontal, 8)
                        .background(Color.secondary.opacity(isDoneHovering ? 0.25 : 0))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isDoneHovering = hovering
                }
                Spacer()
            }
            .padding(.bottom, 8)
        }
        .padding(.vertical, 8)
        .frame(width: viewWidth)
    }
}
