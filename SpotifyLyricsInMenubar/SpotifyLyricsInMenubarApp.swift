//
//  SpotifyLyricsInMenubarApp.swift
//  SpotifyLyricsInMenubar
//
//  Created by Avi Wadhwa on 26/07/23.
//

import SwiftUI
#if canImport(Translation)
import Translation
#endif
import LaunchAtLogin

class translationConfigObject: ObservableObject {
    @Published private var _translationConfig: Any?
    @available(macOS 15, *)
    var translationConfig: TranslationSession.Configuration? {
        get { return _translationConfig as? TranslationSession.Configuration }
        set { _translationConfig = newValue }
    }
}

enum MusicType {
    case spotify
    case appleMusic
}

//final class AppDelegate: NSObject, NSApplicationDelegate {
////    @Environment(\.openWindow) private var openWindow
//    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
////        openWindow(id: "onboarding")
//        return false
//    }
//}

@main
struct SpotifyLyricsInMenubarApp: App {
//    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var viewmodel = viewModel.shared
    // True: means Apple Music, False: Spotify
    @AppStorage("spotifyOrAppleMusic") var spotifyOrAppleMusic: Bool = false
    @AppStorage("hasOnboarded") var hasOnboarded: Bool = false
    @AppStorage("hasUpdated22") var hasUpdated22: Bool = false
    @AppStorage("hasTranslated") var hasTranslated: Bool = false
    @AppStorage("truncationLength") var truncationLength: Int = 40
    @StateObject var translationConfigObject: translationConfigObject = .init()
    @Environment(\.openWindow) var openWindow
    @Environment(\.openURL) var openURL
    var body: some Scene {
        MenuBarExtra(content: {
            if let userName = viewmodel.userName {
                Text("Hi \(userName)!")
            }
            Text(songTitle)
            Toggle("Show Song Details in Menubar", isOn: $viewmodel.showSongDetailsInMenubar)
            Divider()
            if let currentlyPlaying = viewmodel.currentlyPlaying, let currentlyPlayingName = viewmodel.currentlyPlayingName {
                Text(!viewmodel.currentlyPlayingLyrics.isEmpty ? "Lyrics Found 😃 (\(viewmodel.currentLyricSource))" : "No Lyrics Found ☹️")
                Button(viewmodel.currentlyPlayingLyrics.isEmpty ? "Check for Lyrics Again" : "Refresh Lyrics") {

                    Task {
                        if spotifyOrAppleMusic {
                            try await viewmodel.appleMusicNetworkFetch()
                        }
                        let tempLyrics = try await viewmodel.fetchNetworkLyrics(for: currentlyPlaying, currentlyPlayingName, spotifyOrAppleMusic)
                        if tempLyrics.isEmpty {
                            viewmodel.currentlyPlayingLyricsIndex = nil
                        }
                        viewmodel.currentlyPlayingLyrics = tempLyrics
                        viewmodel.fetchBackgroundColor()
                        if viewmodel.translate {
                            if #available(macOS 15, *) {
                                if translationConfigObject.translationConfig == TranslationSession.Configuration(target: viewmodel.userLocaleLanguage.language) {
                                    translationConfigObject.translationConfig?.invalidate()
                                } else {
                                    translationConfigObject.translationConfig = TranslationSession.Configuration(target: viewmodel.userLocaleLanguage.language)
                                }
                            }
                        }
                        viewmodel.lyricsIsEmptyPostLoad = viewmodel.currentlyPlayingLyrics.isEmpty
                        print("HELLOO")
                        if viewmodel.isPlaying, !viewmodel.currentlyPlayingLyrics.isEmpty, viewmodel.showLyrics {
                            viewmodel.startLyricUpdater(appleMusicOrSpotify: spotifyOrAppleMusic)
                        }
                    }
                }
                .keyboardShortcut("r")
                if viewmodel.currentlyPlayingLyrics.isEmpty {
                    Button("Upload Local LRC File") {
                        Task {
                            try await viewmodel.currentlyPlayingLyrics = viewmodel.localFetch(for: currentlyPlaying, currentlyPlayingName, spotifyOrAppleMusic)
                            viewmodel.fetchBackgroundColor()
                            if viewmodel.translate {
                                if #available(macOS 15, *) {
                                    if translationConfigObject.translationConfig == TranslationSession.Configuration(target: viewmodel.userLocaleLanguage.language) {
                                        translationConfigObject.translationConfig?.invalidate()
                                    } else {
                                        translationConfigObject.translationConfig = TranslationSession.Configuration(target: viewmodel.userLocaleLanguage.language)
                                    }
                                }
                            }
                            viewmodel.lyricsIsEmptyPostLoad = viewmodel.currentlyPlayingLyrics.isEmpty
                            if viewmodel.isPlaying, !viewmodel.currentlyPlayingLyrics.isEmpty, viewmodel.showLyrics {
                                viewmodel.startLyricUpdater(appleMusicOrSpotify: spotifyOrAppleMusic)
                            }
                        }
                    }
                } else {
                    Button("Delete Lyrics (wrong lyrics)") {
                        viewmodel.deleteLyric(trackID: currentlyPlaying)
                    }
                }
            // Special case where Apple Music -> Spotify ID matching fails (perhaps Apple Music music was not the media in foreground, network failure, genuine no match)
            // Apple Music Persistent ID exists but Spotify ID (currently playing) is nil
            } else if viewmodel.currentlyPlayingAppleMusicPersistentID != nil, viewmodel.currentlyPlaying == nil {
                Text("No Lyrics (Couldn't find Spotify ID) ☹️")
                Button("Check for Lyrics Again") {
                    Task {
                        // Fetch updates the currentlyPlaying ID which will call Lyric Updater
                        try await viewmodel.appleMusicFetch()
                    }
                }
                .keyboardShortcut("r")
            }
            Toggle("Show Lyrics", isOn: $viewmodel.showLyrics)
            .disabled(!hasOnboarded)
            .keyboardShortcut("h")
            Divider()
            if #available(macOS 15, *) {
                if viewmodel.translate {
                    Text(!viewmodel.translatedLyric.isEmpty ? "Translated Lyrics 😃" : "No Translation ☹️")
                    if viewmodel.translatedLyric.isEmpty {
                        Button("Translation Help") {
                            openURL(URL(string: "https://aviwadhwa.com/TranslationHelp")!)
                        }
                    }
                }

                Toggle("Translate To \(viewmodel.userLocaleLanguageString)", isOn: $viewmodel.translate)
            }
            else {
                Text("Update to macOS 15 to enable translation")
            }
            Divider()
            Toggle("Romanize", isOn: $viewmodel.romanize)
            Divider()
            Text("Menubar Size is \(truncationLength)")
            if truncationLength != 60 {
                Button("Increase Size to \(truncationLength+10) ") {
                    truncationLength = truncationLength + 10
                }
                .keyboardShortcut("+")
            }
            if truncationLength != 30 {
                Button("Decrease Size to \(truncationLength-10)") {
                    truncationLength = truncationLength - 10
                }
                .keyboardShortcut("-")
            }
            Divider()
            if #available(macOS 14.0, *) {
                Toggle("Fullscreen", isOn: $viewmodel.displayFullscreen)
            } else {
                Text("Update to macOS 14.0 to use fullscreen")
            }
            Toggle(viewmodel.showLyrics ? "Karaoke Mode" : "Karaoke Mode (Enable Show Lyrics)", isOn: $viewmodel.karaoke)
                .disabled(!viewmodel.showLyrics)
                .keyboardShortcut("k")
            Divider()
            if !spotifyOrAppleMusic {
                 Toggle("Spotify Connect Audio Delay", isOn: $viewmodel.spotifyConnectDelay)
                 if viewmodel.spotifyConnectDelay {
                     Text("Offset is \(viewmodel.spotifyConnectDelayCount) ms")
                     if viewmodel.spotifyConnectDelayCount != 3000 {
                         Button("Increase Offset to \(viewmodel.spotifyConnectDelayCount+100)") {
                             viewmodel.spotifyConnectDelayCount = viewmodel.spotifyConnectDelayCount + 100
                         }
                     }
                     if viewmodel.spotifyConnectDelayCount != 300 {
                         Button("Decrease Offset to \(viewmodel.spotifyConnectDelayCount-100)") {
                             viewmodel.spotifyConnectDelayCount = viewmodel.spotifyConnectDelayCount - 100
                         }
                     }
                 }
                 Divider()
                Toggle("AirPlay Audio Delay", isOn: $viewmodel.airplayDelay)
            }
            Divider()
            Button("Settings (New Karaoke Settings!)") {
                openWindow(id: "onboarding")
                NSApplication.shared.activate(ignoringOtherApps: true)
                // send notification to check auth
                NotificationCenter.default.post(name: Notification.Name("didClickSettings"), object: nil)
            }.keyboardShortcut("s")
            LaunchAtLogin.Toggle(String(localized: "Launch at Login"))
            .keyboardShortcut("l")
            Button("Check for Updates…", action: {viewmodel.updaterController.checkForUpdates(nil)})
            //    .disabled(!viewmodel.canCheckForUpdates)
                .keyboardShortcut("u")
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }.keyboardShortcut("q")
        } , label: {
            // Text(Image) Doesn't render propertly in MenubarExtra. Stupid Apple. Must resort to if/else
            Group {
                if let menuBarTitle {
                    Text(menuBarTitle)
                } else {
                    Image(systemName: "music.note.list")
                }
            }
                .onChange(of: viewmodel.showLyrics) { newShowLyricsIn in
                    print("ON CHANGE OF SHOW LYRICS")
                    if newShowLyricsIn {
                        viewmodel.startLyricUpdater(appleMusicOrSpotify: spotifyOrAppleMusic)
                    } else {
                        viewmodel.stopLyricUpdater()
                    }
                }
                .floatingPanel(isPresented: $viewmodel.displayKaraoke, content: {
                    KaraokeView()
                        .environmentObject(viewmodel)
                })
                .onAppear {
                    print("on appear running")
                    if !hasUpdated22 {

                        NSApplication.shared.activate(ignoringOtherApps: true)
                        openWindow(id: "update22")
                        hasUpdated22 = true
                        return
                    }
                    // Skip onboarding check - app is ready to use immediately
                    // hasOnboarded = true
                    guard let isRunning = spotifyOrAppleMusic ? viewmodel.appleMusicScript?.isRunning : viewmodel.spotifyScript?.isRunning, isRunning else {
                        return
                    }
                    print("Application just started. lets check whats playing")
                    if  spotifyOrAppleMusic ? viewmodel.appleMusicScript?.playerState == .playing :  viewmodel.spotifyScript?.playerState == .playing {
                        viewmodel.isPlaying = true
                    }
                    if spotifyOrAppleMusic {
                        Task {
                            let status = await viewmodel.requestMusicKitAuthorization()
                            print("APP STARTUP MusicKit auth status is \(status)")

                            if status != .authorized {
                                // Skip permission reset - allow app to function
                            }
                        }
                        let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.Music")
                        // Check Apple Music automation permission but don't block startup
                        if AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, true) != 0 {
                            print("Apple Music automation permission not granted")
                        }
                        if let currentTrackName = viewmodel.appleMusicScript?.currentTrack?.name, let currentArtistName = viewmodel.appleMusicScript?.currentTrack?.artist {
                            // Don't set currentlyPlaying here: the persistentID change triggers the appleMusicFetch which will set spotify's currentlyPlaying
                            if currentTrackName == "" {
                                viewmodel.currentlyPlayingName = nil
                                viewmodel.currentlyPlayingArtist = nil
                            } else {
                                viewmodel.currentlyPlayingName = currentTrackName
                                viewmodel.currentlyPlayingArtist = currentArtistName
                            }
                            print("ON APPEAR HAS UPDATED APPLE MUSIC SONG ID")
                            viewmodel.currentlyPlayingAppleMusicPersistentID = viewmodel.appleMusicScript?.currentTrack?.persistentID
                        }
                    } else {
                        let target = NSAppleEventDescriptor(bundleIdentifier: "com.spotify.client")
                        // Check Spotify automation permission but don't block startup
                        if AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, true) != 0 {
                            print("Spotify automation permission not granted")
                        }
                        if let currentTrack = viewmodel.spotifyScript?.currentTrack?.spotifyUrl?.spotifyProcessedUrl(), let currentTrackName = viewmodel.spotifyScript?.currentTrack?.name, let currentArtistName =  viewmodel.spotifyScript?.currentTrack?.artist, currentTrack != "", currentTrackName != "" {
                            viewmodel.currentlyPlaying = currentTrack
                            viewmodel.currentlyPlayingName = currentTrackName
                            viewmodel.currentlyPlayingArtist = currentArtistName
                            print(currentTrack)
                        }
                    }
                }
                .onReceive(DistributedNotificationCenter.default().publisher(for: Notification.Name(rawValue:  "com.apple.Music.playerInfo")), perform: { notification in
                    guard spotifyOrAppleMusic == true else {
                        print("#TODO we are still listening to apple music playback state changes even when user selected Spotify")
                        return
                    }
                    print("playback changed in apple music")
                    if notification.userInfo?["Player State"] as? String == "Playing" {
                        print("is playing")
                        viewmodel.isPlaying = true
                    } else {
                        print("paused. timer canceled")
                        viewmodel.isPlaying = false
                        // manually cancels the lyric-updater task bc media is paused
                    }
                    /*let currentlyPlaying = (notification.userInfo?["Track ID"] as? String)?.components(separatedBy: ":").last*/
                    let currentlyPlayingName = (notification.userInfo?["Name"] as? String)
                    //viewmodel.currentlyPlaying = nil
                    if currentlyPlayingName == "" {
                        viewmodel.currentlyPlayingName = nil
                        viewmodel.currentlyPlayingArtist = nil
                    } else {
                        viewmodel.currentlyPlayingName = currentlyPlayingName
                        viewmodel.currentlyPlayingArtist = (notification.userInfo?["Artist"] as? String)
                    }
                    viewmodel.currentlyPlayingAppleMusicPersistentID = viewmodel.appleMusicScript?.currentTrack?.persistentID
                })
                .onReceive(DistributedNotificationCenter.default().publisher(for: Notification.Name(rawValue:  "com.spotify.client.PlaybackStateChanged")), perform: { notification in
                    guard spotifyOrAppleMusic == false else {
                        print("#TODO we are still listening to spotify playback state changes even when user selected Apple Music")
                        return
                    }
                    print("playback changed in spotify")
                    if notification.userInfo?["Player State"] as? String == "Playing" {
                        print("is playing")
                        viewmodel.isPlaying = true
                    } else {
                        print("paused. timer canceled")
                        viewmodel.isPlaying = false
                        // manually cancels the lyric-updater task bc media is paused
                    }
                    print(notification.userInfo?["Track ID"] as? String)
                    let currentlyPlaying = (notification.userInfo?["Track ID"] as? String)?.spotifyProcessedUrl()
                    let currentlyPlayingName = (notification.userInfo?["Name"] as? String)
                    if currentlyPlaying != "", currentlyPlayingName != "" {
                        viewmodel.currentlyPlaying = currentlyPlaying
                        viewmodel.currentlyPlayingName = currentlyPlayingName
                        viewmodel.currentlyPlayingArtist = (notification.userInfo?["Artist"] as? String)
                    }
                })
                .complexModifier {
                    if #available(macOS 15.0, *) {
                        $0.translationTask(translationConfigObject.translationConfig) { session in
                            print("translation task called")
                            do {
                                print("translation task called in do")
                                let requests = viewModel.shared.currentlyPlayingLyrics.map { TranslationSession.Request(sourceText: $0.words, clientIdentifier: $0.id.uuidString) }
                                let response = try await session.translations(from: requests)
                                if response.count == viewmodel.currentlyPlayingLyrics.count {
//                                    viewmodel.translateSource = response
                                    viewmodel.translatedLyric = response.map {
                                        $0.targetText
                                    }
                                }
                                print(response)

                            } catch {
                                if let source = viewmodel.findRealLanguage() {
                                    translationConfigObject.translationConfig = TranslationSession.Configuration(source: source, target: viewmodel.userLocaleLanguage.language)
                                }
                                print(error)
                            }
                        }
//                        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willBecomeActiveNotification)) { _ in
//                            if !viewmodel.fullscreenInProgress {
//                                openWindow(id: "onboarding")
//                            }
//
//                           }
                        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                               // This code will be executed just before the app terminates
                            UserDefaults.standard.set(viewmodel.karaokeFont.fontName, forKey: "karaokeFontName")
                            UserDefaults.standard.set(Double(viewmodel.karaokeFont.pointSize), forKey: "karaokeFontSize")
                           }
                        .onChange(of: viewmodel.romanize) { newRomanize in
                            if newRomanize {
                                print("Romanized Lyrics generated from romanize value change for song \(viewmodel.currentlyPlaying)")
                                viewmodel.romanizedLyrics = viewmodel.currentlyPlayingLyrics.compactMap({
                                    viewmodel.generateRomanizedLyric($0)
                                })
                            } else {
                                viewmodel.romanizedLyrics = []
                            }
                        }
                        .onChange(of: viewmodel.translate) { newTranslate in
                            if newTranslate {
                                if translationConfigObject.translationConfig == TranslationSession.Configuration(target: viewmodel.userLocaleLanguage.language) {
                                    translationConfigObject.translationConfig?.invalidate()
                                } else {
                                    translationConfigObject.translationConfig = TranslationSession.Configuration(target: viewmodel.userLocaleLanguage.language)
                                }
                            } else {
                                viewmodel.translatedLyric = []
                            }
                        }

                    }
                    else {
                        $0
                    }
                }
//                .translationTask(translationConfig) { session in
//                    print("translation task called")
//                    do {
//                        print("translation task called in do")
//                        let requests = viewModel.shared.currentlyPlayingLyrics.map { TranslationSession.Request(sourceText: $0.words, clientIdentifier: $0.id.uuidString) }
//                        let response = try await session.translations(from: requests)
//                        if response.count == viewmodel.currentlyPlayingLyrics.count {
//                            viewmodel.translatedLyric = response.map {
//                                $0.targetText
//                            }
//                        }
//                        print(response)
//
//                    } catch {
//                        print(error)
//                    }
//                }
//                .onChange(of: viewmodel.translate) { newTranslate in
//                    if newTranslate {
//                        if translationConfig == nil {
//                            translationConfig = TranslationSession.Configuration()
//                            return
//                        }
//                        translationConfig?.invalidate()
//                    } else {
//                        translationConfig = nil
//                    }
//                }
                .onChange(of: spotifyOrAppleMusic) { newSpotifyorAppleMusic in
                    // Music app changed, no need to reset onboarding
                }
                .onChange(of: viewmodel.fullscreen) { newFullscreen in
                    if newFullscreen {
                        openWindow(id: "fullscreen")
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    }
                }
                .onChange(of: viewmodel.translate) { newTranslate in
                    if !hasTranslated {
                        openURL(URL(string: "https://aviwadhwa.com/TranslationHelp")!)
                    }
                    hasTranslated = true
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("onboardingCompleted"))) { _ in
                    // Trigger music detection after onboarding is completed
                    // Ensure lyrics are shown by default
                    viewmodel.showLyrics = true
                    if spotifyOrAppleMusic {
                        // Apple Music
                        Task {
                            let status = await viewmodel.requestMusicKitAuthorization()
                            print("Onboarding completed - MusicKit auth status is \(status)")
                        }

                        if let currentTrackName = viewmodel.appleMusicScript?.currentTrack?.name,
                           let currentArtistName = viewmodel.appleMusicScript?.currentTrack?.artist {
                            if currentTrackName == "" {
                                viewmodel.currentlyPlayingName = nil
                                viewmodel.currentlyPlayingArtist = nil
                            } else {
                                viewmodel.currentlyPlayingName = currentTrackName
                                viewmodel.currentlyPlayingArtist = currentArtistName
                            }
                            viewmodel.currentlyPlayingAppleMusicPersistentID = viewmodel.appleMusicScript?.currentTrack?.persistentID
                        }

                        // Check if Apple Music is playing
                        if viewmodel.appleMusicScript?.playerState == .playing {
                            viewmodel.isPlaying = true
                        }
                    } else {
                        // Spotify
                        if let currentTrack = viewmodel.spotifyScript?.currentTrack?.spotifyUrl?.spotifyProcessedUrl(),
                           let currentTrackName = viewmodel.spotifyScript?.currentTrack?.name,
                           let currentArtistName = viewmodel.spotifyScript?.currentTrack?.artist,
                           currentTrack != "", currentTrackName != "" {
                            viewmodel.currentlyPlaying = currentTrack
                            viewmodel.currentlyPlayingName = currentTrackName
                            viewmodel.currentlyPlayingArtist = currentArtistName
                        }

                        // Check if Spotify is playing
                        if viewmodel.spotifyScript?.playerState == .playing {
                            viewmodel.isPlaying = true
                        }
                    }

                    // Start lyric updater if playing and also fetch lyrics
                    if viewmodel.isPlaying {
                        // First fetch lyrics for the current song
                        Task {
                            do {
                                if spotifyOrAppleMusic {
                                    // Apple Music
                                    if let trackID = viewmodel.currentlyPlayingAppleMusicPersistentID {
                                        let lyrics = try await viewmodel.fetchLyrics(for: trackID, viewmodel.currentlyPlayingName ?? "", spotifyOrAppleMusic)
                                        await MainActor.run {
                                            viewmodel.currentlyPlayingLyrics = lyrics
                                            if !lyrics.isEmpty {
                                                viewmodel.lyricsIsEmptyPostLoad = false
                                                viewmodel.startLyricUpdater(appleMusicOrSpotify: spotifyOrAppleMusic)
                                            }
                                        }
                                    }
                                } else {
                                    // Spotify
                                    if let trackID = viewmodel.currentlyPlaying {
                                        let lyrics = try await viewmodel.fetchLyrics(for: trackID, viewmodel.currentlyPlayingName ?? "", spotifyOrAppleMusic)
                                        await MainActor.run {
                                            viewmodel.currentlyPlayingLyrics = lyrics
                                            if !lyrics.isEmpty {
                                                viewmodel.lyricsIsEmptyPostLoad = false
                                                viewmodel.startLyricUpdater(appleMusicOrSpotify: spotifyOrAppleMusic)
                                            }
                                        }
                                    }
                                }
                            } catch {
                                print("Failed to fetch lyrics on onboarding completion: \(error)")
                            }
                        }
                    }
                }
                .onChange(of: viewmodel.cookie) { newCookie in
                    viewmodel.accessToken = nil
                }
                .onChange(of: viewmodel.isPlaying) { nowPlaying in
                    if nowPlaying, viewmodel.showLyrics {
                        if !viewmodel.currentlyPlayingLyrics.isEmpty  {
                            print("timer started for spotify change, lyrics not nil")
                            viewmodel.startLyricUpdater(appleMusicOrSpotify: spotifyOrAppleMusic)
                        }
                    } else {
                        viewmodel.stopLyricUpdater()
                    }
                }
                .task(id: viewmodel.currentlyPlayingAppleMusicPersistentID) {
                    if viewmodel.currentlyPlayingAppleMusicPersistentID != nil {
                        // reset the store playback id so that the nil check actually works later
                        viewmodel.appleMusicStorePlaybackID = nil
                        await viewmodel.appleMusicStarter()
                    }
                }
                .onChange(of: viewmodel.currentlyPlaying) { nowPlaying in
                    print("song change")
                    withAnimation {
                        viewmodel.currentlyPlayingLyricsIndex = nil
                    }
                    viewmodel.currentlyPlayingLyrics = []
                    viewmodel.translatedLyric = []
                    viewmodel.romanizedLyrics = []
                    Task {
                        if let nowPlaying, let currentlyPlayingName = viewmodel.currentlyPlayingName, let lyrics = await viewmodel.fetch(for: nowPlaying, currentlyPlayingName, spotifyOrAppleMusic) {
                            viewmodel.currentlyPlayingLyrics = lyrics
                            viewmodel.fetchBackgroundColor()
                            if viewmodel.translate {
                                if #available(macOS 15, *) {
                                    if translationConfigObject.translationConfig == TranslationSession.Configuration(target: viewmodel.userLocaleLanguage.language) {
                                        translationConfigObject.translationConfig?.invalidate()
                                    } else {
                                        translationConfigObject.translationConfig = TranslationSession.Configuration(target: viewmodel.userLocaleLanguage.language)
                                    }
                                }
                            }
                            if viewmodel.romanize {
                                print("Romanized Lyrics generated from song change for \(viewmodel.currentlyPlaying)")
                                viewmodel.romanizedLyrics = viewmodel.currentlyPlayingLyrics.compactMap({
                                    viewmodel.generateRomanizedLyric($0)
                                })
                            }
                            viewmodel.lyricsIsEmptyPostLoad = lyrics.isEmpty
                            if viewmodel.isPlaying, !viewmodel.currentlyPlayingLyrics.isEmpty, viewmodel.showLyrics {
                                print("STARTING UPDATER")
                                viewmodel.startLyricUpdater(appleMusicOrSpotify: spotifyOrAppleMusic)
                            }
                        }
                    }
                }
        })
        if #available(macOS 14.0, *) {
            Window("Lyric Fever: Fullscreen", id: "fullscreen") {
                FullscreenView(spotifyOrAppleMusic: $spotifyOrAppleMusic)
                    .preferredColorScheme(.dark)
                    .environmentObject(viewmodel)
                    .onAppear {
                        // Block "Esc" button
                        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { (aEvent) -> NSEvent? in
                                if aEvent.keyCode == 53 { // if esc pressed
                                    return nil
                                }

                                return aEvent
                            }
                        Task { @MainActor in
                            let window = NSApp.windows.first {$0.identifier?.rawValue == "fullscreen"}
                            window?.collectionBehavior = .fullScreenPrimary
                            if window?.styleMask.rawValue != 49167 {
                                window?.toggleFullScreen(true)
                                withAnimation() {
                                    viewmodel.fullscreenInProgress = false
                                }
                            }
                        }
                    }
                    .onDisappear {
                        NSApp.setActivationPolicy(.accessory)
                        viewmodel.fullscreen = false
                        viewmodel.fullscreenInProgress = true
                    }
            }
        }
        Window("Lyric Fever: Onboarding", id: "onboarding") { // << here !!
            OnboardingWindow().frame(minWidth: 700, maxWidth: 700, minHeight: 600, maxHeight: 600, alignment: .center)
                .environmentObject(viewmodel)
                .preferredColorScheme(.dark)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    // Force window to front when it appears
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let window = NSApp.windows.first(where: { $0.title == "Lyric Fever: Onboarding" }) {
                            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                            window.makeKeyAndOrderFront(nil)
                            window.orderFrontRegardless()
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    }
                }
                .onDisappear {
                    if !viewmodel.fullscreen {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
        }.windowResizability(.contentSize)
            .windowStyle(.hiddenTitleBar)
        Window("Lyric Fever: Update 3.0", id: "update22") { // << here !!
            Update22Window().frame(minWidth: 700, maxWidth: 700, minHeight: 500, maxHeight: 500, alignment: .center)
                .environmentObject(viewmodel)
                .preferredColorScheme(.dark)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    Task { @MainActor in
                        let window = NSApp.windows.first {$0.identifier?.rawValue == "update22"}
                        window?.level = .floating
                    }
                }
                .onDisappear {
                    if !viewmodel.fullscreen {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
        }
            .windowResizability(.contentSize)
            .windowStyle(.hiddenTitleBar)
    }

    var songTitle: LocalizedStringKey {
        if let currentlyPlayingName = viewmodel.currentlyPlayingName, let currentlyPlayingArtist = viewmodel.currentlyPlayingArtist {
            if viewmodel.isPlaying {
                return "Now Playing: \(currentlyPlayingName) - \(currentlyPlayingArtist)"//.trunc(length: truncationLength)
            } else {
                return "Now Paused: \(currentlyPlayingName) - \(currentlyPlayingArtist)"//.trunc(length: truncationLength)
            }
        }
        return "Open \(spotifyOrAppleMusic ? "Apple Music" : "Spotify" )!"
    }

    var menuBarTitle: String? {
        // Update message takes priority
        if viewmodel.mustUpdateUrgent {
            return String(localized: "⚠️ Please Update (Click Check Updates)").trunc(length: truncationLength)
        } else if !hasOnboarded {
            // Show setup warning only if not onboarded
            return String(localized: "⚠️ Complete Setup (Click Settings)").trunc(length: truncationLength)
        }

        // Try to work through lyric logic
        // NEW: Revert to song name if fullscreen / karaoke activated
        if !viewmodel.fullscreen, !viewmodel.karaoke, viewmodel.isPlaying, viewmodel.showLyrics, let currentlyPlayingLyricsIndex = viewmodel.currentlyPlayingLyricsIndex {
            // Attempt to display translations
            // Implicit assumption: translatedLyric.count == currentlyPlayingLyrics.count
            if viewmodel.translationExists {
                // I don't localize, because I deliver the lyric verbatim
                return viewmodel.translatedLyric[currentlyPlayingLyricsIndex].trunc(length: truncationLength)
            } else {
                // Attempt to display Romanization
                if viewmodel.romanize, let toLatin = viewmodel.currentlyPlayingLyrics[currentlyPlayingLyricsIndex].words.applyingTransform(.toLatin, reverse: false) {
                    // I don't localize, because I deliver the lyric verbatim
                    return toLatin.trunc(length: truncationLength)
                } else {
                    // I don't localize, because I deliver the lyric verbatim
                    return viewmodel.currentlyPlayingLyrics[currentlyPlayingLyricsIndex].words.trunc(length: truncationLength)
                }
            }
        // Backup: Display name and artist
        } else if viewmodel.showSongDetailsInMenubar, let currentlyPlayingName = viewmodel.currentlyPlayingName, let currentlyPlayingArtist = viewmodel.currentlyPlayingArtist {
            if viewmodel.isPlaying {
                return String(localized: "Now Playing: \(currentlyPlayingName) - \(currentlyPlayingArtist)").trunc(length: truncationLength)
            } else {
                return String(localized: "Now Paused: \(currentlyPlayingName) - \(currentlyPlayingArtist)").trunc(length: truncationLength)
            }
        }

        // Default: no title
        return nil
    }
}

// LyricsX
extension CharacterSet {

    static let hiragana = CharacterSet(charactersIn: "\u{3040}"..<"\u{30a0}")
    static let katakana = CharacterSet(charactersIn: "\u{30a0}"..<"\u{3100}")
    static let kana = CharacterSet(charactersIn: "\u{3040}"..<"\u{3100}")
    static let kanji = CharacterSet(charactersIn: "\u{4e00}"..<"\u{9fc0}")
}


extension String {
  // https://gist.github.com/budidino/8585eecd55fd4284afaaef762450f98e
  func trunc(length: Int, trailing: String = "…") -> String {
    return (self.count > length) ? self.prefix(length) + trailing : self
  }
}

extension View {
    func complexModifier<V: View>(@ViewBuilder _ closure: (Self) -> V) -> some View {
        closure(self)
    }
}
// https://stackoverflow.com/questions/48136456/locale-current-reporting-wrong-language-on-device
extension Locale {
    static func preferredLocaleString() -> String? {
        guard let preferredIdentifier = Locale.preferredLanguages.first else {
            return Locale.current.localizedString(for: Calendar.autoupdatingCurrent.identifier)
        }
        return Locale.current.localizedString(forIdentifier: preferredIdentifier)
    }
    static func preferredLocale() -> Locale {
        guard let preferredIdentifier = Locale.preferredLanguages.first else {
            return Locale.current
        }
        return Locale.init(identifier: preferredIdentifier)
    }
}

extension String {
    func spotifyProcessedUrl() -> String? {
        let components = self.components(separatedBy: ":")
        guard components.count > 2 else { return nil }
        if components[1] == "episode" {
            return nil
        }
        if components[1] == "local" {
            var localTrackId = components.dropFirst(2).dropLast().joined(separator: ":")
            // Ensures only Spotify tracks have a length of 22
            if localTrackId.count == 22 {
                localTrackId.append("_")
            }
            return localTrackId
        } else {
            return components.dropFirst(2).joined(separator: ":")
        }
    }
}
