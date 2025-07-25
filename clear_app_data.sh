#!/bin/bash

# Script to clear all LyricFever persistent data for testing first-time experience

echo "Clearing LyricFever persistent data..."

# Multiple possible bundle identifiers
BUNDLE_IDS=(
    "com.aviwad.Lyric-Fever"
    "com.aviwadhwa.SpotifyLyricsInMenubar"
    "com.aviwad.SpotifyLyricsInMenubar"
)

# Clear UserDefaults for all possible bundle IDs
echo "Clearing UserDefaults..."
for BUNDLE_ID in "${BUNDLE_IDS[@]}"; do
    if defaults read "$BUNDLE_ID" &>/dev/null; then
        defaults delete "$BUNDLE_ID"
        echo "Deleted UserDefaults for $BUNDLE_ID"
    fi
done

# Clear Core Data from all possible locations
echo "Clearing Core Data..."

# Container paths
for BUNDLE_ID in "${BUNDLE_IDS[@]}"; do
    CONTAINER_PATH=~/Library/Containers/"$BUNDLE_ID"
    if [ -d "$CONTAINER_PATH" ]; then
        # Remove all app data in container
        rm -rf "$CONTAINER_PATH"/Data/Library/Application\ Support/* 2>/dev/null
        rm -rf "$CONTAINER_PATH"/Data/Library/Caches/* 2>/dev/null
        rm -rf "$CONTAINER_PATH"/Data/Documents/* 2>/dev/null
        rm -f "$CONTAINER_PATH"/Data/Library/Preferences/"$BUNDLE_ID".plist 2>/dev/null
        echo "Cleared container data for $BUNDLE_ID"
    fi
done

# Non-sandboxed locations
APP_SUPPORT_PATHS=(
    ~/Library/Application\ Support/Lyric\ Fever
    ~/Library/Application\ Support/SpotifyLyricsInMenubar
)

for APP_SUPPORT in "${APP_SUPPORT_PATHS[@]}"; do
    if [ -d "$APP_SUPPORT" ]; then
        rm -rf "$APP_SUPPORT"/*
        echo "Cleared $APP_SUPPORT"
    fi
done

# Clear preferences plist files
echo "Clearing preference files..."
PREF_PATH=~/Library/Preferences
for BUNDLE_ID in "${BUNDLE_IDS[@]}"; do
    rm -f "$PREF_PATH"/"$BUNDLE_ID".plist 2>/dev/null
    rm -f "$PREF_PATH"/"$BUNDLE_ID".plist.lockfile 2>/dev/null
done

# Clear LaunchAgents if any
echo "Checking LaunchAgents..."
for BUNDLE_ID in "${BUNDLE_IDS[@]}"; do
    LAUNCH_AGENT=~/Library/LaunchAgents/"$BUNDLE_ID".plist
    if [ -f "$LAUNCH_AGENT" ]; then
        launchctl unload "$LAUNCH_AGENT" 2>/dev/null
        rm -f "$LAUNCH_AGENT"
        echo "Removed LaunchAgent for $BUNDLE_ID"
    fi
done

# Clear Sparkle update cache
echo "Clearing Sparkle update cache..."
rm -rf ~/Library/Caches/com.aviwad.Lyric-Fever 2>/dev/null
rm -rf ~/Library/Caches/com.aviwadhwa.SpotifyLyricsInMenubar 2>/dev/null
rm -rf ~/Library/Application\ Support/com.aviwad.Lyric-Fever 2>/dev/null
rm -rf ~/Library/Application\ Support/com.aviwadhwa.SpotifyLyricsInMenubar 2>/dev/null

# Clear any group containers
echo "Clearing group containers..."
rm -rf ~/Library/Group\ Containers/*lyric* 2>/dev/null
rm -rf ~/Library/Group\ Containers/*aviwad* 2>/dev/null

# Kill the app if running
echo "Terminating app if running..."
killall "Lyric Fever" 2>/dev/null || true
killall "SpotifyLyricsInMenubar" 2>/dev/null || true

# Clear any cached preferences
echo "Clearing preference cache..."
killall cfprefsd 2>/dev/null || echo "Preference daemon not running"

echo "✅ All persistent data cleared!"
echo "You can now launch LyricFever to test the first-time experience."