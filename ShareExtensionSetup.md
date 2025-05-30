# Share Extension Setup Guide

This guide explains how to integrate the Share Extension into your Duet iOS app so it appears in share sheets when sharing videos from social media apps.

## Files Created

The following files have been created for the Share Extension:

```
DuetShareExtension/
├── Info.plist
├── ShareViewController.swift (SwiftUI-based)
└── DuetShareExtension.entitlements
```

## Xcode Project Setup

Follow these steps to add the Share Extension to your Xcode project:

### 1. Add Share Extension Target

1. Open `Duet.xcodeproj` in Xcode
2. Click on your project name in the Project Navigator
3. In the project editor, click the "+" button at the bottom of the Targets list
4. Choose "iOS" → "Application Extension" → "Share Extension"
5. Set the following:
   - Product Name: `DuetShareExtension`
   - Bundle Identifier: `com.Duet.Duet.DuetShareExtension`
   - Language: Swift
   - Click "Finish"
6. When prompted about activating the scheme, click "Activate"

### 2. Replace Generated Files

Replace the auto-generated files with the ones provided:

1. Replace `DuetShareExtension/Info.plist` with the one created above
2. Replace `DuetShareExtension/ShareViewController.swift` with the SwiftUI-based one created above
3. **Delete** the auto-generated `MainInterface.storyboard` file (we're using SwiftUI instead)
4. Add `DuetShareExtension.entitlements` to the extension target

### 3. Configure App Groups

1. **Main App Target:**
   - Select your main "Duet" target
   - Go to "Signing & Capabilities"
   - Click "+" and add "App Groups"
   - Create a new App Group: `group.com.Duet.Duet`

2. **Share Extension Target:**
   - Select the "DuetShareExtension" target
   - Go to "Signing & Capabilities"
   - Click "+" and add "App Groups"
   - Add the same App Group: `group.com.Duet.Duet`

### 4. Update Build Settings

1. **Share Extension Target:**
   - Select "DuetShareExtension" target
   - Go to "Build Settings"
   - Set "Code Signing Entitlements" to `DuetShareExtension/DuetShareExtension.entitlements`

### 5. Add Required Frameworks

Add these frameworks to the Share Extension target:

1. Select "DuetShareExtension" target
2. Go to "Build Phases" → "Link Binary With Libraries"
3. Add the following frameworks:
   - `SwiftUI.framework`
   - `AVFoundation.framework`
   - `UniformTypeIdentifiers.framework`
   - `MobileCoreServices.framework`

## How It Works

### 1. Share Sheet Integration

When users share a video from social media apps:
- The Share Extension appears as "Share to Duet" option
- Users can tap it to share the video to your app
- The extension now uses SwiftUI for a modern, native look that matches your app

### 2. Video Processing Flow

1. **Video Reception**: Share Extension receives the video file/URL
2. **Storage**: Video is copied to shared App Group container
3. **App Launch**: Main Duet app opens via URL scheme (`duet://share`)
4. **Processing**: Main app processes the shared video

### 3. Data Sharing

- Videos are stored in shared App Group container: `group.com.Duet.Duet`
- Video paths and metadata are shared via `UserDefaults(suiteName:)`
- URL schemes trigger the main app with video information

## Supported Video Sources

The extension supports videos from:
- TikTok
- Instagram Reels
- YouTube Shorts
- Twitter/X videos
- Any app that shares video files
- Direct video file sharing

## Customization

### 1. Modify Video Processing

Update the `processSharedVideo()` method in `DuetApp.swift` to integrate with your existing video processing pipeline:

```swift
private func processSharedVideo(_ videoURL: URL) {
    // Add your actual video processing logic here
    // For example:
    // - Create DateIdeaViewModel instance
    // - Call your video summarization API
    // - Navigate to specific processing view
    // - Add to processing queue
}
```

### 2. Update UI Text

Modify these strings in `ShareViewController.swift`:
- `placeholder`: Change the placeholder text shown in share extension
- `showError()`: Customize error messages
- Display name in `Info.plist` → `CFBundleDisplayName`

### 3. Supported File Types

To support additional file types, modify the `NSExtensionActivationRule` in `DuetShareExtension/Info.plist`:

```xml
<key>NSExtensionActivationRule</key>
<dict>
    <key>NSExtensionActivationSupportsMovieWithMaxCount</key>
    <integer>1</integer>
    <key>NSExtensionActivationSupportsVideoWithMaxCount</key>
    <integer>1</integer>
    <key>NSExtensionActivationSupportsFileWithMaxCount</key>
    <integer>1</integer>
    <!-- Add more types as needed -->
</dict>
```

## Testing

### 1. Test in Simulator

1. Build and run your app in the iOS Simulator
2. Open Safari and go to a video sharing website
3. Try to share a video - your "Share to Duet" option should appear
4. Tap it to test the flow

### 2. Test on Device

1. Install the app on a physical device
2. Open TikTok, Instagram, or another social media app
3. Find a video and tap the share button
4. Look for "Share to Duet" in the share sheet
5. Test the complete flow from sharing to processing

## Troubleshooting

### Share Extension Not Appearing

1. Verify App Groups are configured correctly for both targets
2. Check that the extension's `Info.plist` has correct activation rules
3. Ensure both main app and extension are properly signed
4. Try restarting the device/simulator

### App Not Opening

1. Verify URL scheme `duet://` is registered in main app's `Info.plist`
2. Check that `handleInviteURL` method is called with `onOpenURL`
3. Ensure shared container permissions are set correctly

### Video File Not Found

1. Check App Group container permissions
2. Verify file copying logic in `copyVideoToSharedLocation`
3. Ensure shared `UserDefaults` suite name matches

## Security Considerations

- Videos are temporarily stored in shared container
- Cleanup old videos periodically to save storage
- Validate video files before processing
- Handle permissions properly for accessing shared content

## Next Steps

1. Integrate with your existing video processing pipeline
2. Add proper error handling and user feedback
3. Implement video cleanup strategies
4. Test with various social media platforms
5. Consider adding preview functionality in the share extension 