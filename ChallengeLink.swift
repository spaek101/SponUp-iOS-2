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

    // Provide the same background you use on the challenge card:
    public var imageURL: URL?       // e.g. https://.../challenge-bg.jpg
    public var imageName: String?   // e.g. local asset name "bg_homeruns"
    public var initials: String     // fallback text if no image
    public var accentSymbolName: String? = "bolt.fill"

    public init(id: String,
                imageURL: URL? = nil,
                imageName: String? = nil,
                initials: String,
                accentSymbolName: String? = "bolt.fill") {
        self.id = id
        self.imageURL = imageURL
        self.imageName = imageName
        self.initials = initials
        self.accentSymbolName = accentSymbolName
    }
}

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
                        Text(headline).font(.system(size: 18, weight: .bold, design: .rounded))
                        Text(subheadline).font(.system(size: 12, weight: .semibold, design: .rounded)).opacity(0.9)
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
        .overlay(alignment: .topTrailing) {
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white.opacity(0.95))
                        .shadow(radius: 2)
                }
                .padding(.trailing, 18)
                .padding(.top, 6)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(avatars.count) challenges selected. \(headline) \(subheadline)")
    }

    private var visibleAvatars: [ChallengeLink] { Array(avatars.prefix(maxVisibleAvatars)) }
    private var remainingCount: Int { max(0, avatars.count - maxVisibleAvatars) }
}

// MARK: - Avatar bubble uses the challenge background image
private struct AvatarBubble: View {
    var avatar: ChallengeLink

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            avatarImage
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 2))

            if let sym = avatar.accentSymbolName {
                Image(systemName: sym)
                    .font(.system(size: 11, weight: .bold))
                    .padding(6)
                    .background(Circle().fill(Color.white))
                    .foregroundColor(.orange)
                    .offset(x: 2, y: 2)
            }
        }
        .padding(.vertical, 8)
        .padding(.trailing, 6)
    }

    // Shows URL image -> asset image -> initials fallback
    @ViewBuilder
    private var avatarImage: some View {
        if let url = avatar.imageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                case .failure(_): InitialsView(text: avatar.initials)
                case .empty: ProgressView().scaleEffect(0.8)
                @unknown default: InitialsView(text: avatar.initials)
                }
            }
        } else if let name = avatar.imageName {
            Image(name).resizable().scaledToFill()
        } else {
            InitialsView(text: avatar.initials)
        }
    }
}

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

private struct InitialsView: View {
    var text: String
    var body: some View {
        ZStack {
            LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(text)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}
