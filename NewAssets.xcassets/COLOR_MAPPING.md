# AppColors to Asset Mapping

This document shows how the `AppColors` struct references map to the actual color assets in the `NewAssets.xcassets` file.

## Color Mapping Reference

### Core App Colors (Referenced in MainTabView.swift)
```swift
// AppColors.accent → AppAccent.colorset
// Used for: tab bar selected state, accent colors, primary actions
Color("AppAccent")

// AppColors.surface → AppSurface.colorset  
// Used for: tab bar background, card backgrounds, surface elements
Color("AppSurface")

// AppColors.textSecondary → textSecondary.colorset
// Used for: tab bar normal state, secondary text, muted elements
Color("textSecondary")

// AppColors.primary → AppTheme.colorset
// Used for: brand colors, primary elements, main branding
Color("AppTheme")
```

### Semantic Colors (Used throughout the app)
```swift
// AppColors.success → Success.colorset
// Used for: easy challenges, success states, positive actions
Color("Success")

// AppColors.warning → Warning.colorset
// Used for: medium challenges, warning states, caution
Color("Warning")

// AppColors.error → Error.colorset
// Used for: hard challenges, error states, destructive actions
Color("Error")

// AppColors.textPrimary → textPrimary.colorset
// Used for: primary text, main content, headings
Color("textPrimary")
```

### Additional Utility Colors
```swift
// AppColors.background → systemBackground (built-in)
// Used for: main app background

// AppColors.secondaryBackground → secondarySystemBackground (built-in)
// Used for: secondary backgrounds, grouped content

// Challenge difficulty colors
Color("ChallengeEasy")    // Green for easy challenges
Color("ChallengeMedium")  // Orange for medium challenges
Color("ChallengeHard")    // Red for hard challenges

// Gradient colors
Color("GradientStart")    // Start of gradients
Color("GradientEnd")      // End of gradients

// Utility colors
Color("BorderColor")      // Subtle borders
Color("ShadowColor")      // Shadows and depth
Color("OverlayColor")     // Modals and overlays
```

## Usage in MainTabView.swift

```swift
// Tab bar accent color
.accentColor(AppColors.accent)  // → Color("AppAccent")

// Tab bar background
appearance.backgroundColor = UIColor(AppColors.surface)  // → UIColor(named: "AppSurface")

// Selected tab styling
appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppColors.accent)  // → UIColor(named: "AppAccent")
appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
    .foregroundColor: UIColor(AppColors.accent)  // → UIColor(named: "AppAccent")
]

// Normal tab styling  
appearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppColors.textSecondary)  // → UIColor(named: "textSecondary")
appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
    .foregroundColor: UIColor(AppColors.textSecondary)  // → UIColor(named: "textSecondary")
]
```

## Implementation Notes

1. **Case Sensitivity**: Color asset names are case-sensitive
2. **Dark Mode**: All colors support both light and dark appearances
3. **System Colors**: Some colors like `background` and `secondaryBackground` use system colors
4. **Semantic Meaning**: Colors are named for their purpose, not their appearance
5. **Accessibility**: All colors meet accessibility contrast requirements

## Migration from Old Assets

When migrating from the existing `Assets.xcassets`:
1. Replace old color references with new semantic names
2. Update any hardcoded color values to use the new system
3. Test both light and dark mode appearances
4. Verify accessibility compliance
