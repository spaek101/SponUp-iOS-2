# SponUp Assets.xcassets

This is a comprehensive asset catalog for the SponUp iOS app, designed with modern design principles and accessibility in mind.

## Color System

### Brand Colors
- **BrandPrimary**: Main brand color (vibrant blue) - used for primary actions and branding
- **Colors**: Accent color (bright green) - used for highlights and secondary actions

### Surface Colors
- **SurfacePrimary**: Main surface color for cards and content areas
- **TextPrimary**: Primary text color for main content
- **TextSecondary**: Secondary text color for supporting content

### Semantic Colors
- **SuccessGreen**: Success states, easy challenges, positive actions
- **WarningOrange**: Warning states, medium challenges, caution
- **ErrorRed**: Error states, hard challenges, destructive actions

### Challenge Difficulty Colors
- **ChallengeEasy**: Green for beginner-level challenges
- **ChallengeMedium**: Orange for intermediate-level challenges  
- **ChallengeHard**: Red for expert-level challenges

### Utility Colors
- **GradientStart/GradientEnd**: For beautiful gradient backgrounds
- **BorderColor**: Subtle borders for UI elements
- **ShadowColor**: Shadows for depth and elevation
- **OverlayColor**: For modals and overlays

## Image Assets

### Challenge Sport Images
- **ChallengeBatting**: Baseball batting challenges
- **ChallengePitching**: Baseball pitching challenges
- **ChallengeCatching**: Baseball catching challenges

### UI Elements
- **LeaderboardBackground**: Background for leaderboard sections
- **ProfilePlaceholder**: Default profile image placeholder
- **ChaiLogo**: Chai AI integration logo

### App Icon
- **AppIcon**: Complete app icon set with all required sizes for iOS devices

## Design Principles

1. **Accessibility**: All colors support both light and dark modes
2. **Consistency**: Unified color palette across the entire app
3. **Semantic**: Colors have clear meaning and purpose
4. **Modern**: Following Apple's latest design guidelines
5. **Scalable**: Easy to extend with new colors and assets

## Usage

### In SwiftUI
```swift
import SwiftUI

// Use colors
Color("BrandPrimary")
Color("SuccessGreen")
Color("SurfacePrimary")

// Use images
Image("ChallengeBatting")
Image("ChaiLogo")
```

### In UIKit
```swift
import UIKit

// Use colors
UIColor(named: "BrandPrimary")
UIColor(named: "SuccessGreen")
UIColor(named: "SurfacePrimary")

// Use images
UIImage(named: "ChallengeBatting")
UIImage(named: "ChaiLogo")
```

## File Structure

```
NewAssets.xcassets/
├── Contents.json
├── README.md
├── AppIcon.appiconset/
│   └── Contents.json
├── BrandPrimary.colorset/
│   └── Contents.json
├── Colors.colorset/
│   └── Contents.json
├── SurfacePrimary.colorset/
│   └── Contents.json
├── TextPrimary.colorset/
│   └── Contents.json
├── TextSecondary.colorset/
│   └── Contents.json
├── SuccessGreen.colorset/
│   └── Contents.json
├── WarningOrange.colorset/
│   └── Contents.json
├── ErrorRed.colorset/
│   └── Contents.json
├── ChallengeEasy.colorset/
│   └── Contents.json
├── ChallengeMedium.colorset/
│   └── Contents.json
├── ChallengeHard.colorset/
│   └── Contents.json
├── GradientStart.colorset/
│   └── Contents.json
├── GradientEnd.colorset/
│   └── Contents.json
├── BorderColor.colorset/
│   └── Contents.json
├── ShadowColor.colorset/
│   └── Contents.json
├── OverlayColor.colorset/
│   └── Contents.json
├── ChallengeBatting.imageset/
│   └── Contents.json
├── ChallengePitching.imageset/
│   └── Contents.json
├── ChallengeCatching.imageset/
│   └── Contents.json
├── LeaderboardBackground.imageset/
│   └── Contents.json
├── ProfilePlaceholder.imageset/
│   └── Contents.json
└── ChaiLogo.imageset/
    └── Contents.json
```

## Migration Notes

This new asset catalog is designed to replace the existing one while maintaining backward compatibility. The color names are semantic and follow a clear naming convention that makes it easy to understand their purpose.

## Future Enhancements

- Add more sport-specific challenge images
- Include animation assets for micro-interactions
- Add custom SF Symbols configurations
- Include high-resolution marketing assets
