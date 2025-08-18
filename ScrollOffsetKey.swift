import SwiftUI

/// Publishes the vertical scroll offset (0 at rest → negative while scrolling up)
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
