import SwiftUI

struct SpotifyAuthErrorView: View {
    @ObservedObject var viewModel = LyricFever.viewModel.shared
    @AppStorage("hasOnboarded") var hasOnboarded: Bool = false
    @State private var showingDebugView = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.yellow)
            
            Text("Spotify Authentication Issue")
                .font(.title2)
                .bold()
            
            Text("Your sp_dc cookie has expired or is invalid. This is needed to fetch lyrics from Spotify.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 15) {
                Text("To fix this issue:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 10) {
                    Label("Log in to Spotify Web Player again", systemImage: "1.circle.fill")
                    Label("Or manually enter a new sp_dc cookie", systemImage: "2.circle.fill")
                    Label("The cookie expires periodically and needs renewal", systemImage: "info.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            HStack(spacing: 15) {
                Button("Re-login to Spotify") {
                    // Clear current cookie and trigger re-onboarding
                    viewModel.cookie = ""
                    viewModel.accessToken = nil
                    hasOnboarded = false
                }
                .buttonStyle(.borderedProminent)
                
                Button("Debug Tools") {
                    showingDebugView = true
                }
                
                Button("Use LRCLIB Only") {
                    // Option to skip Spotify and use only LRCLIB
                    viewModel.cookie = "skip"
                    hasOnboarded = true
                }
            }
            
            Text("Note: LRCLIB provides lyrics but may have less content than Spotify")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(30)
        .frame(width: 450)
        .sheet(isPresented: $showingDebugView) {
            SpotifyDebugView()
        }
    }
}

// Extension to show error in menu bar
extension viewModel {
    func handleSpotifyAuthError() {
        // Show user-friendly error message in menu bar
        Task { @MainActor in
            if mustUpdateUrgent {
                return // Don't show auth errors if update is urgent
            }
            
            // You could set a flag to show auth error in menu bar
            // For example:
            // showAuthError = true
            
            // Or show a notification
            let notification = NSUserNotification()
            notification.title = "Lyric Fever"
            notification.informativeText = "Spotify authentication failed. Please log in again."
            notification.soundName = NSUserNotificationDefaultSoundName
            
            NSUserNotificationCenter.default.deliver(notification)
        }
    }
}