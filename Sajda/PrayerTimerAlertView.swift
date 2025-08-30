// MARK: - FILE BARU: Sajda/PrayerTimerAlertView.swift
// Salin dan tempel SELURUH kode ini ke dalam file baru.

import SwiftUI

struct PrayerTimerAlertView: View {
    var dismissAction: () -> Void
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Latar belakang tembus pandang dengan efek blur
            // Ini adalah helper view yang sama yang digunakan di OnboardingView
            VisualEffectView().ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "timer")
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(.accentColor)

                VStack {
                    Text("Break Time is Over")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Time to begin your next activity.")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                Button(action: dismissAction) {
                    Text("Dismiss")
                        .font(.headline)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction) // Bisa ditutup dengan tombol Enter
            }
            .padding(40)
        }
        .frame(width: 450, height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 20)
        .scaleEffect(isAnimating ? 1.0 : 0.9)
        .opacity(isAnimating ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isAnimating = true
            }
        }
    }
}
