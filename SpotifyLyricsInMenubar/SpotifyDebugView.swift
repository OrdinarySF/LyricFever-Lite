import SwiftUI

struct SpotifyDebugView: View {
    @ObservedObject var viewModel = LyricFever.viewModel.shared
    @State private var testCookie: String = ""
    @State private var debugOutput: String = ""
    @State private var isTesting: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Spotify Authentication Debug")
                .font(.title2)
                .bold()
            
            Text("This tool helps diagnose sp_dc cookie issues")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Current Cookie Status:")
                    .font(.headline)
                
                if viewModel.cookie.isEmpty {
                    Label("No cookie stored", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                } else {
                    Label("Cookie stored (length: \(viewModel.cookie.count))", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                
                if let accessToken = viewModel.accessToken {
                    let expirationDate = Date(timeIntervalSince1970: accessToken.accessTokenExpirationTimestampMs / 1000)
                    let isExpired = expirationDate < Date()
                    
                    Label(
                        "Access token \(isExpired ? "expired" : "valid until \(expirationDate.formatted())")",
                        systemImage: isExpired ? "xmark.circle.fill" : "checkmark.circle.fill"
                    )
                    .foregroundColor(isExpired ? .red : .green)
                } else {
                    Label("No access token", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Test sp_dc Cookie:")
                    .font(.headline)
                
                TextField("Paste sp_dc cookie here", text: $testCookie)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    Button("Test Cookie") {
                        Task {
                            await testSpotifyCookie()
                        }
                    }
                    .disabled(testCookie.isEmpty || isTesting)
                    
                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    
                    Spacer()
                    
                    Button("Use This Cookie") {
                        viewModel.cookie = testCookie
                        viewModel.accessToken = nil
                        debugOutput += "\n✅ Cookie saved. Please restart the app."
                    }
                    .disabled(testCookie.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Debug Output:")
                    .font(.headline)
                
                ScrollView {
                    Text(debugOutput)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .frame(height: 200)
                
                Button("Clear Output") {
                    debugOutput = ""
                }
                .font(.caption)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 500, height: 600)
    }
    
    private func testSpotifyCookie() async {
        isTesting = true
        debugOutput = "🔄 Starting cookie test...\n"
        
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["User-Agent": viewModel.fakeSpotifyUserAgentconfig.httpAdditionalHeaders?["User-Agent"] as? String ?? ""]
        let session = URLSession(configuration: config)
        
        do {
            // Step 1: Get server time
            debugOutput += "\n📡 Getting server time..."
            let serverTimeRequest = URLRequest(url: URL(string: "https://open.spotify.com/server-time")!)
            let (serverTimeData, _) = try await session.data(for: serverTimeRequest)
            
            guard let serverTimeJSON = try? JSONSerialization.jsonObject(with: serverTimeData) as? [String: Any],
                  let serverTime = serverTimeJSON["serverTime"] as? Int else {
                debugOutput += "\n❌ Failed to get server time"
                isTesting = false
                return
            }
            
            debugOutput += "\n✅ Server time: \(serverTime)"
            
            // Step 2: Generate TOTP
            guard let totp = viewModel.TOTPGenerator.generate(serverTimeSeconds: serverTime) else {
                debugOutput += "\n❌ Failed to generate TOTP"
                isTesting = false
                return
            }
            
            debugOutput += "\n✅ Generated TOTP: \(totp)"
            
            // Step 3: Request access token
            let tokenURL = "https://open.spotify.com/get_access_token?reason=transport&productType=web-player&totp=\(totp)&totpServer=\(Int(Date().timeIntervalSince1970))&totpVer=5&sTime=\(serverTime)&cTime=\(serverTime)"
            
            var tokenRequest = URLRequest(url: URL(string: tokenURL)!)
            tokenRequest.setValue("sp_dc=\(testCookie)", forHTTPHeaderField: "Cookie")
            tokenRequest.setValue("https://open.spotify.com", forHTTPHeaderField: "Origin")
            tokenRequest.setValue("https://open.spotify.com/", forHTTPHeaderField: "Referer")
            
            debugOutput += "\n📡 Requesting access token..."
            
            let (tokenData, tokenResponse) = try await session.data(for: tokenRequest)
            
            if let httpResponse = tokenResponse as? HTTPURLResponse {
                debugOutput += "\n📊 HTTP Status: \(httpResponse.statusCode)"
                
                if httpResponse.statusCode == 401 {
                    debugOutput += "\n❌ Cookie is invalid or expired"
                    isTesting = false
                    return
                }
            }
            
            let responseString = String(data: tokenData, encoding: .utf8) ?? "No response"
            
            if responseString.lowercased().contains("invalid") || responseString.lowercased().contains("expired") {
                debugOutput += "\n❌ Response indicates invalid cookie:"
                debugOutput += "\n\(responseString)"
            } else if let tokenJSON = try? JSONSerialization.jsonObject(with: tokenData) as? [String: Any],
                      let accessToken = tokenJSON["accessToken"] as? String {
                debugOutput += "\n✅ Successfully got access token!"
                
                // Step 4: Test the token
                debugOutput += "\n📡 Testing access token..."
                
                var meRequest = URLRequest(url: URL(string: "https://api.spotify.com/v1/me")!)
                meRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                
                let (meData, meResponse) = try await session.data(for: meRequest)
                
                if let httpResponse = meResponse as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        if let userJSON = try? JSONSerialization.jsonObject(with: meData) as? [String: Any],
                           let displayName = userJSON["display_name"] as? String {
                            debugOutput += "\n✅ Token valid! User: \(displayName)"
                            debugOutput += "\n\n🎉 Cookie is working! You can use it."
                        } else {
                            debugOutput += "\n✅ Token valid!"
                        }
                    } else {
                        debugOutput += "\n❌ Token test failed (HTTP \(httpResponse.statusCode))"
                    }
                }
            } else {
                debugOutput += "\n❌ Failed to parse access token response:"
                debugOutput += "\n\(responseString.prefix(200))..."
            }
            
        } catch {
            debugOutput += "\n❌ Error: \(error.localizedDescription)"
        }
        
        isTesting = false
    }
}

// Add this to your settings or debug menu
struct SpotifyDebugMenuItem: View {
    @State private var showDebugWindow = false
    
    var body: some View {
        Button("Debug Spotify Auth...") {
            showDebugWindow = true
        }
        .sheet(isPresented: $showDebugWindow) {
            SpotifyDebugView()
        }
    }
}