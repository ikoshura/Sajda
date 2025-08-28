// Ganti seluruh kode di AboutView.swift dengan ini

import SwiftUI

struct AboutView: View {
    @Binding var activePage: ActivePage
    @State private var isDoneHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { activePage = .main }) {
                HStack {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold))
                    Text("About Sajda").font(.body).fontWeight(.bold)
                    Spacer()
                }
                .padding(.vertical, 5).padding(.horizontal, 8)
                .background(Color.secondary.opacity(isDoneHovering ? 0.25 : 0)).cornerRadius(5)
            }.buttonStyle(.plain).padding(.horizontal, 5).onHover { hovering in isDoneHovering = hovering }
            
            Divider().padding(.horizontal, 12)
            
            VStack(spacing: 12) {
                Image("sajda-logo").resizable().scaledToFit().frame(width: 50, height: 50)
                VStack(spacing: 2) {
                    Text("Sajda").font(.title2).fontWeight(.bold)
                    Text("Version 1.0.0").font(.caption).foregroundColor(.secondary)
                    Text("by abrarzha").font(.caption).foregroundColor(.secondary)
                }
                Text("A simple and beautiful prayer times app for your menu bar.")
                    .font(.subheadline).multilineTextAlignment(.center).padding(.horizontal)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}
