//
//  Update22Window.swift
//  Lyric Fever
//
//  Created by Avi Wadhwa on 2025-03-19.
//

import SwiftUI

struct Update22Window: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openWindow) var openWindow
    var body: some View {
        VStack(spacing: 25) {
            HStack {
                Image("hi")
                    .resizable()
                    .frame(width: 70, height: 70, alignment: .center)

                Text(verbatim:"Thanks for updating to Lyric Fever 3.0! 🎉")
                    .font(.title)
            }

            Text(verbatim:"3.0 Changes")
                .font(.title2)
                .foregroundStyle(.green)
            ScrollView {
                VStack(spacing: 8) {
                    Text(verbatim:"🎵 Enhanced Lyric Engine")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .padding(.bottom, 5)

                    Text(verbatim:"• Integrated QQ Music API as a new high-quality lyric source")
                    Text(verbatim:"• Implemented intelligent multi-source fallback system: LRCLIB → QQ Music → NetEase")
                    Text(verbatim:"• Refactored Core Data model to support new lyric source architecture")
                    Text(verbatim:"• Enhanced lyric fetching with improved error handling and retry logic")

                    Text(verbatim:"🔧 Developer Tools & Debugging")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .padding(.top, 10)
                        .padding(.bottom, 5)

                    Text(verbatim:"• Added Spotify Debug View for authentication testing")
                    Text(verbatim:"• Implemented Spotify Auth Error View with detailed error reporting")
                    Text(verbatim:"• Created app data clearing script for easier debugging")
                    Text(verbatim:"• Improved cookie-based authentication with automatic retry mechanisms")

                    Text(verbatim:"🚀 User Experience Improvements")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .padding(.top, 10)
                        .padding(.bottom, 5)

                    Text(verbatim:"• Completely redesigned onboarding flow - 200+ lines simplified")
                    Text(verbatim:"• Removed complex Spotify authentication requirement")
                    Text(verbatim:"• Enhanced fullscreen view with better error states")
                    Text(verbatim:"• Updated translations for better international support")

                    Text(verbatim:"🏗️ Infrastructure & CI/CD")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .padding(.top, 10)
                        .padding(.bottom, 5)

                    Text(verbatim:"• Added GitHub Actions workflow for automated DMG building")
                    Text(verbatim:"• Improved build configuration and project structure")
                    Text(verbatim:"• Enhanced error handling throughout the application")

                    Text(verbatim:"💡 Note: Spotify playback control remains fully supported with enhanced stability")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 10)
                }
                .multilineTextAlignment(.leading)
                .padding(.horizontal,10)
                .padding(.vertical,5)
                .background(Color(nsColor: NSColor.darkGray).cornerRadius(7))
            }
            Button("Close") {
                dismiss()
                // Open settings window after closing update window
                openWindow(id: "onboarding")
                
                // Use multiple methods to ensure window is focused
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    // Method 1: Activate app with all windows
                    NSApp.activate(ignoringOtherApps: true)
                    
                    // Method 2: Find and focus the window
                    if let window = NSApp.windows.first(where: { $0.title == "Lyric Fever: Onboarding" }) {
                        window.makeKeyAndOrderFront(nil)
                        window.orderFrontRegardless()
                        window.center()
                        
                        // Method 3: Set window level temporarily
                        let originalLevel = window.level
                        window.level = .floating
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            window.level = originalLevel
                        }
                    }
                    
                    // Send notification to navigate to settings
                    NotificationCenter.default.post(name: Notification.Name("didClickSettings"), object: nil)
                }
            }
            .font(.headline)
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 10)
        }
    }
}
