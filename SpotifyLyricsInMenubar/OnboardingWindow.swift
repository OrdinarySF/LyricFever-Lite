//
//  OnboardingWindow.swift
//  SpotifyLyricsInMenubar
//
//  Created by Avi Wadhwa on 01/09/23.
//

import SwiftUI
import SDWebImageSwiftUI
import ScriptingBridge
import MusicKit
import WebKit

struct OnboardingWindow: View {
    @State var spotifyPermission: Bool = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.controlActiveState) var controlActiveState
    @State var appleMusicPermission: Bool = false
    @State var appleMusicLibraryPermission: Bool = false
    @State var permissionMissing: Bool = false
    @State var isAnimating = true
//    @State private var selection: Int? = nil
    @AppStorage("spotifyOrAppleMusic") var spotifyOrAppleMusic: Bool = false
    @AppStorage("hasOnboarded") var hasOnboarded: Bool = false
    @State var errorMessage: String = "Please download the [official Spotify desktop client](https://www.spotify.com/in-en/download/mac/)"
    var body: some View {
        TabView {

            NavigationStack() {
                VStack(alignment: .center, spacing: 20) {
                    Group {
                        if permissionMissing {
                            Group {
                                AnimatedImage(name: "newPermissionMac.gif", isAnimating: $isAnimating)
                                    .resizable()
                                    .frame(width: 397, height: 340)
                                HStack {
                                    Button("Open Automation Panel", action: {
                                        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
                                        NSWorkspace.shared.open(url)
                                    })
                                    if spotifyOrAppleMusic {
                                        Button("Open Music Panel", action: {
                                            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Media")!
                                            NSWorkspace.shared.open(url)
                                        })
                                    }
                                }
                            }
                        } else {
                            Group {
                                Image("hi")
                                    .resizable()
                                    .frame(width: 150, height: 150, alignment: .center)

                                Text("Welcome to Lyric Fever! 🎉")
                                    .font(.largeTitle)
                                    .onAppear() {

                                    }

                                Text("Please pick between Spotify and Apple Music")
                                    .font(.title)
                            }
                        }
                    }
                    .transition(.fade)

                    Group {
                        Picker("", selection: $spotifyOrAppleMusic) {
                            VStack {
                                Image("spotify")
                                    .resizable()
                                    .frame(width: 70.0, height: 70.0)
                                Text("Spotify")
                            }.tag(false)
                            VStack {
                                Image("music")
                                    .resizable()
                                    .frame(width: 70.0, height: 70.0)
                                Text("Apple Music")
                            }.tag(true)
                        }
                        .font(.title2)
                        .frame(width: 500)
                        .pickerStyle(.radioGroup)
                        .horizontalRadioGroupLayout()



                        Text(LocalizedStringKey(errorMessage))
                            .transition(.opacity)
                            .id(errorMessage)

                        if spotifyPermission && appleMusicPermission && appleMusicLibraryPermission {
                            NavigationLink("Next", destination: ApiView())
                                .font(.headline)
                                .controlSize(.large)
                                .buttonStyle(.borderedProminent)
                        } else {
                            HStack {
                                Button("Give Spotify Permissions") {

                                    let target = NSAppleEventDescriptor(bundleIdentifier: "com.spotify.client")
                                    // Can cause a freeze if app we're querying for isn't open
                                    // See: https://forums.developer.apple.com/forums/thread/666528
                                    guard let spotify = NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").first else {
                                        withAnimation {
                                            errorMessage = "Please open Spotify!"
                                        }
                                        return
                                    }
                                    let status = AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, true)
                                    switch status {
                                        case -600:
                                            errorMessage = "Please open Spotify!"
                                        case -0:
                                        withAnimation {
                                            permissionMissing = false
                                                spotifyPermission = true
                                            errorMessage = ""
                                        }
                                        default:
                                        withAnimation {
                                            errorMessage = "Please give required permissions!"
                                            permissionMissing = true
                                            isAnimating = true
                                        }
                                    }

                                    }

                                .disabled(spotifyPermission)
                                Button("Give Apple Music Permissions") {
                                    let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.Music")
                                    guard let music = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").first else {
                                        withAnimation {
                                            errorMessage = "Please open Apple Music!"
                                        }
                                        return
                                    }
                                    let status = AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, true)
                                    switch status {
                                        case -600:
                                        errorMessage = "Please open Apple Music!"
                                        case -0:
                                        withAnimation {
                                            appleMusicPermission = true
                                            permissionMissing = false
                                        }
                                        isAnimating = false
                                        if appleMusicLibraryPermission {
                                            errorMessage = ""
                                        } else {
                                            errorMessage = "Please give us Apple Music Library permissions!"
                                        }
                                        default:
                                        withAnimation {
                                            permissionMissing = true
                                        }
                                        errorMessage = "Please give us required permissions!"
                                        permissionMissing = true
                                        isAnimating = true
                                            // OPEN AUTOMATION PANEL
                                    }

                                }
                                .disabled(appleMusicPermission)
                                Button("Give Apple Music Library Permissions") {
                                    Task {
                                        let status = await MusicKit.MusicAuthorization.request()

                                        if status == .authorized {
                                            withAnimation {
                                                appleMusicLibraryPermission = true
                                                permissionMissing = false
                                            }
                                            isAnimating = false
                                            if appleMusicPermission {
                                                errorMessage = ""
                                            } else {
                                                errorMessage = "Please give us Apple Music permissions!"
                                            }
                                        }
                                        else {
                                            errorMessage = "Please give us required permissions!"
                                            withAnimation {
                                                permissionMissing = true
                                            }
                                            isAnimating = true
                                        }
                                    }
                                }
                                .disabled(appleMusicLibraryPermission)
                            }
                        }


                        Text("Email me at [aviwad@gmail.com](mailto:aviwad@gmail.com) for any support\n⚠️ Disclaimer: I do not own the rights to Spotify or the lyric content presented.\nMusixmatch and Spotify own all rights to the lyrics.\n [Lyric Fever GitHub]()\nVersion 3.0")
                            .multilineTextAlignment(.center)
                            .font(.callout)
                            .padding(.top, 10)
                            .frame(alignment: .bottom)
                    }
                    .transition(.fade)

                }
                .onAppear {
                    if spotifyOrAppleMusic {
                        errorMessage = "Please open Apple Music!"
                        spotifyPermission = true
                        appleMusicPermission = false
                        appleMusicLibraryPermission = false
                    } else {
                        errorMessage = "Please download the [official Spotify desktop client](https://www.spotify.com/in-en/download/mac/)"
                        appleMusicPermission = true
                        appleMusicLibraryPermission = true
                        spotifyPermission = false
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("didClickSettings"))) { newValue in
                    if spotifyOrAppleMusic {
                        // first set spotify button to true, because we dont run the spotify or apple music boolean check on window open anymore
                        errorMessage = "Please open Apple Music!"
                        spotifyPermission = true
                        appleMusicPermission = false
                        appleMusicLibraryPermission = false


                        // Check Apple Music Automation permission
                        guard let music = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").first else {
                            withAnimation {
                                errorMessage = "Please open Apple Music!"
                            }
                            return
                        }
                        let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.Music")
                        let status = AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, true)
                        switch status {
                            case -600:
                            errorMessage = "Please open Apple Music!"
                            case -0:
                            appleMusicPermission = true
                            permissionMissing = false
                            isAnimating = false
                            if appleMusicLibraryPermission {
                                errorMessage = ""
                            } else {
                                errorMessage = "Please give us Apple Music Library permissions!"
                            }
    //                                case -1744:
    //                                Alert(title: Text("Please give permission by going to the Automation panel"))
                            default:
                            withAnimation {
                                permissionMissing = true
                            }
                            errorMessage = "Please give us required permissions!"
                            permissionMissing = true
                            isAnimating = true
                                // OPEN AUTOMATION PANEL
                        }

                        // Check Media Library Permission
                        Task {
                            let status = await MusicKit.MusicAuthorization.request()

                            if status == .authorized {
                                withAnimation {
                                    appleMusicLibraryPermission = true
                                    permissionMissing = false
                                }
                                isAnimating = false
                                if appleMusicPermission {
                                    errorMessage = ""
                                } else {
                                    errorMessage = "Please give us Apple Music permissions!"
                                }
                            }
                            else {
                                errorMessage = "Please give us required permissions!"
                                withAnimation {
                                    permissionMissing = true
                                }
                                isAnimating = true
                            }
                        }

                    } else {
                        errorMessage = "Please download the [official Spotify desktop client](https://www.spotify.com/in-en/download/mac/)"
                        appleMusicPermission = true
                        appleMusicLibraryPermission = true
                        spotifyPermission = false
                        // Check Spotify
                        guard let spotify = NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").first else {
                            withAnimation {
                                errorMessage = "Please open Spotify!"
                            }
                            return
                        }
                        let target = NSAppleEventDescriptor(bundleIdentifier: "com.spotify.client")
                        let status = AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, true)
                        switch status {
                            case -600:
                                errorMessage = "Please open Spotify!"
                            case -0:
                            withAnimation {
                                permissionMissing = false
                                    spotifyPermission = true
                                errorMessage = ""
                            }
    //                                case -1744:
    //                                Alert(title: Text("Please give permission by going to the Automation panel"))
                            default:
                            withAnimation {
                                errorMessage = "Please give required permissions!"
                                permissionMissing = true
                                isAnimating = true
                            }
                                // OPEN AUTOMATION PANEL
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { newValue in
                    isAnimating = false
                    permissionMissing = false
                }
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.willMiniaturizeNotification)) { newValue in
                    isAnimating = false
                    permissionMissing = false
                }
                .onChange(of: spotifyOrAppleMusic) { newSpotifyOrAppleMusic in
                    print("Updating permission booleans based on media player change")
                    if spotifyOrAppleMusic {
                        errorMessage = "Please open Apple Music!"
                        spotifyPermission = true
                        appleMusicPermission = false
                        appleMusicLibraryPermission = false
                    } else {
                        errorMessage = "Please download the [official Spotify desktop client](https://www.spotify.com/in-en/download/mac/)"
                        appleMusicPermission = true
                        appleMusicLibraryPermission = true
                        spotifyPermission = false
                    }
                }
                .onChange(of: controlActiveState) { newState in
                    if newState == .inactive {
                        isAnimating = false
                    } else {
                        isAnimating = true
                    }
                }
            }
            .tabItem {
                Label("Main Settings", systemImage: "person.crop.circle")
            }
            KaraokeSettingsView()
                .padding(.horizontal, 100)
                 .tabItem {
                     Label("Karaoke Window", systemImage: "person.crop.circle")
                 }
        }
    }
}

struct ApiView: View {
    @Environment(\.dismiss) var dismiss
    @State private var isShowingDetailView = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepView(title: LocalizedStringKey("Lyric Sources"), description: LocalizedStringKey("Lyric Fever uses LRCLIB, QQ Music, and NetEase to fetch lyrics automatically"))

            Text(LocalizedStringKey("No configuration needed!"))
                .font(.title3)
                .padding(.vertical, 20)

            Text(LocalizedStringKey("Lyrics will be fetched automatically from available sources when you play music."))
                .foregroundColor(.secondary)

            Spacer()

            HStack {
                Button(LocalizedStringKey("Back")) {
                    dismiss()
                }
                Spacer()
                NavigationLink(destination: FinalTruncationView(), isActive: $isShowingDetailView) {EmptyView()}
                    .hidden()
                Button(LocalizedStringKey("Next")) {
                    UserDefaults.standard.set(true, forKey: "hasOnboarded")
                    isShowingDetailView = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 15)
        }
        .padding(.horizontal, 20)
        .navigationBarBackButtonHidden(true)
    }
}

struct FinalTruncationView: View {
    @Environment(\.dismiss) var dismiss
    //@AppStorage("truncationLength") var truncationLength: Int = 40
    @State var truncationLength: Int = UserDefaults.standard.integer(forKey: "truncationLength")
    @Environment(\.controlActiveState) var controlActiveState
    let allTruncations = [30,40,50,60]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepView(title: "Set the Lyric Size", description: "This depends on how much free space you have in your menu bar!")

            HStack {
                Spacer()
                Image("\(truncationLength)")
                    .resizable()
                    .scaledToFit()
                    .onAppear() {
                        if truncationLength == 0 {
                            truncationLength = 40
                        }
                    }
                Spacer()
            }

            HStack {
                Spacer()
                Picker("Truncation Length", selection: $truncationLength) {
                    ForEach(allTruncations, id:\.self) { oneThing in
                        Text("\(oneThing) Characters")
                    }
                }
                .pickerStyle(.radioGroup)
                Spacer()
            }

            HStack {
                Button("Back") {
                    dismiss()
                }
                Spacer()
                Button("Done") {
                    NSApplication.shared.keyWindow?.close()
                    // Post notification to trigger music detection
                    NotificationCenter.default.post(name: Notification.Name("onboardingCompleted"), object: nil)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 15)

        }
        .onChange(of: truncationLength) { newLength in
            UserDefaults.standard.set(newLength, forKey: "truncationLength")
        }
        .padding(.horizontal, 20)
        .navigationBarBackButtonHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { newValue in
            dismiss()
            dismiss()
            dismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willMiniaturizeNotification)) { newValue in
            dismiss()
            dismiss()
            dismiss()
        }
    }
}


struct StepView: View {
    var title: LocalizedStringKey
    var description: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2)
                .bold()

            Text(description)
                .font(.title3)
        }
    }
}
