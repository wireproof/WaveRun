# Wave Run for iOS

Wave Run is a work-in-progress native iOS reconstruction of Soft Kiwi's WaveRun, an arcade game about switching between moving waves while avoiding hazards. It targets iPhone and iPad in landscape orientation.

The current prototype uses SwiftUI, recovered game artwork and audio, and procedural wave paths. Tap Play or the open menu background to start; during play, tap to switch lanes, avoid red hazards, and collect green bonuses. It includes normal and hard settings, a colorblind option, a locally stored best score, original star artwork, a distance and star counter, and a player trail with jump particles.

## Status

This is an early reconstruction, not a verified reproduction of the original. Wave motion, scoring, menus, sound timing and effects are approximations. Arcade and Random mode parity, multiplayer, achievements and leaderboards are not implemented. The recovered original executable remains encrypted and has not supplied gameplay source code.

Version 0.1.0 build 6 was installed on the intended iPhone and iPad. That build has not been launched or visually tested on either device; an earlier build was reported to open on iPhone. Audio playback and gameplay fidelity remain unverified.

## Build

Open `WaveRun.xcodeproj` in Xcode, or regenerate it from `project.yml` with XcodeGen. The app targets iOS 16 or later and uses the bundle identifier `com.wireproof.waverun`. Device builds require a suitable development signing configuration.

Project media is in `WaveRun/OriginalAssets` and the app icon is in `WaveRun/Assets.xcassets`.


The prerelease IPA is unsigned and must be signed with a suitable provisioning profile before installation.
