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
        // Fast lookup for accepted IDs so button text updates instantly
        let acceptedIDs: Set<String> = Set(acceptedChallenges.compactMap { $0.id })

        SuggestedChallengesSection(
            challenges: $challenges,
            selectedFilter: $selectedFilter,
            headerType: "sponsored",
            onClaim: onClaim,
            onShowMore: nil
        ) { challenge, onClaim in
            AnyView(
                ChallengeCardView(
                    challenge: challenge,
                    onClaim: onClaim,
                    fundButton: false,                              // athlete view → Accept/Remove
                    isFunded: {
                        guard let id = challenge.id else { return false }
                        return acceptedIDs.contains(id)             // true → "Remove", false → "Accept"
                    }(),
                    isSelected: false                               // not a cart context here
                )
            )
        }
        .padding(.horizontal, 0) // keep consistent with other tabs
    }
}
