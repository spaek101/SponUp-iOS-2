//
//  SponsoredTab.swift
//  SponUp2.0
//
//  Created by Steve Paek on 8/17/25.
//

import SwiftUI

struct SponsoredTab: View {
    // Parent owns the VM and binds this to `$sponsoredVM.sponsored`
    @Binding var challenges: [Challenge]
    @Binding var selectedFilter: SuggestedFilter

    // Athlete-side state
    let acceptedChallenges: [Challenge]
    let onClaim: (Challenge) -> Void

    var body: some View {
        // Build a typed key set: "type|id"
        let acceptedKeys: Set<String> = Set(
            acceptedChallenges.compactMap { ch in
                guard let id = ch.id else { return nil }
                return "\(ch.type.rawValue)|\(id)"
            }
        )

        SuggestedChallengesSection(
            challenges: $challenges,
            selectedFilter: $selectedFilter,
            headerType: "sponsored",
            onClaim: onClaim,
            onShowMore: nil
        ) { challenge, onClaim in
            let isFunded: Bool = {
                guard let id = challenge.id else { return false }
                let key = "\(challenge.type.rawValue)|\(id)"
                return acceptedKeys.contains(key)
            }()

            return AnyView(
                ChallengeCardView(
                    challenge: challenge,
                    onClaim: onClaim,
                    fundButton: false,        // athlete view → Accept/Remove
                    isFunded: isFunded,       // uses typed key, no cross-tab bleed
                    isSelected: false
                )
            )
        }
        .padding(.horizontal, 0)
    }
}

