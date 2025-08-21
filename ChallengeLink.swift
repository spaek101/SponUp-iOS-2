//
//  ChallengeLink.swift
//  SponUp2.0
//
//  Created by Steve Paek on 8/19/25.
//

import SwiftUI

// MARK: - Lightweight view model the banner needs
public struct ChallengeLink: Identifiable, Hashable {
    public let id: String

    // Keep for flexibility, but not used in AvatarBubble anymore
    public var imageURL: URL?
    public var imageName: String?
    public var initials: String
    public var accentSymbolName: String? = "bolt.fill"

    // NEW: whether this challenge has cash
    public var isCash: Bool = false

    public init(id: String,
                imageURL: URL? = nil,
                imageName: String? = nil,
                initials: String,
                accentSymbolName: String? = "bolt.fill",
                isCash: Bool = false) {
        self.id = id
        self.imageURL = imageURL
        self.imageName = imageName
        self.initials = initials
        self.accentSymbolName = accentSymbolName
        self.isCash = isCash
    }
}

// MARK: - Banner
public struct ChallengeLinkBanner: View {
    public var avatars: [ChallengeLink]
    public var headline: String = "Win 50x"
    public var subheadline: String = "Or More!"
    public var maxVisibleAvatars: Int = 6
    public var onPrimaryTap: (() -> Void)?
    public var onDismiss: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    private let bannerHeight: CGFloat = 86
    private let corner: CGFloat = 24

    public init(
        avatars: [ChallengeLink],
        headline: String = "Win 50x",
        subheadline: String = "Or More!",
        maxVisibleAvatars: Int = 6,
        onPrimaryTap: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.avatars = avatars
        self.headline = headline
        self.subheadline = subheadline
        self.maxVisibleAvatars = max(1, maxVisibleAvatars)
        self.onPrimaryTap = onPrimaryTap
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            LinearGradient(colors: [Color.orange.opacity(0.95), .orange],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: -2)

            HStack(spacing: 16) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: -6) {
                        ForEach(visibleAvatars) { a in
                            AvatarBubble(avatar: a)
                        }
                        if remainingCount > 0 {
                            MoreBubble(count: remainingCount)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: 60)

                Spacer(minLength: 8)

                Button(action: { onPrimaryTap?() }) {
                    VStack(spacing: 2) {
                        Text(headline)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text(subheadline)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .opacity(0.9)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(colorScheme == .dark ? 0.15 : 0.2))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
        }
        .frame(height: bannerHeight)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(avatars.count) challenges selected. \(headline) \(subheadline)")
    }

    private var visibleAvatars: [ChallengeLink] { Array(avatars.prefix(maxVisibleAvatars)) }
    private var remainingCount: Int { max(0, avatars.count - maxVisibleAvatars) }
}

// MARK: - Avatar bubble (orange circle with $ or ⭐)
private struct AvatarBubble: View {
    var avatar: ChallengeLink

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.orange)
                .frame(width: 48, height: 48)

            Image(systemName: avatar.isCash ? "dollarsign" : "star.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
        }
        .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 2))
        .padding(.vertical, 8)
        .padding(.trailing, 6)
    }
}

// MARK: - More bubble
private struct MoreBubble: View {
    var count: Int
    var body: some View {
        Text("+\(count)")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(width: 48, height: 48)
            .background(
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .fill(Color.white.opacity(0.9))
            )
            .padding(.vertical, 8)
            .padding(.trailing, 6)
            .accessibilityLabel("plus \(count) more")
    }
}
