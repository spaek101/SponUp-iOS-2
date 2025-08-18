
/*

import Foundation

struct MockData {
    // Fixed UUIDs for eventChallenges so we can reference them reliably
    static let eventChallenge1ID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let eventChallenge2ID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let eventChallenge3ID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

    static let eventChallenges: [Challenge] = [
        Challenge(
            id: eventChallenge1ID,
            title: "Steal 2 Bases",
            type: .sponsored,
            difficulty: .easy,
            rewardCash: 10,
            rewardPoints: 150,
            timeRemaining: 3600 * 3,
            state: .available,
            acceptedDate: Date().addingTimeInterval(-86400 * 1)
        ),
        Challenge(
            id: eventChallenge2ID,
            title: "Hit a Homer",
            type: .reward,
            difficulty: .medium,
            rewardCash: nil,
            rewardPoints: 100,
            timeRemaining: 3600 * 5,
            state: .available,
            acceptedDate: Date().addingTimeInterval(-86400 * 2)
        ),
        Challenge(
            id: eventChallenge3ID,
            title: "Score 3 Runs",
            type: .sponsored,
            difficulty: .medium,
            rewardCash: 5,
            rewardPoints: 120,
            timeRemaining: 3600 * 2 + 1800,
            state: .available,
            acceptedDate: Date().addingTimeInterval(-86400 * 3)
        )
    ]

    static let baseChallenges: [Challenge] = [
        Challenge(
            id: UUID(),
            title: "Steal 2 Bases",
            type: .sponsored,
            difficulty: .easy,
            rewardCash: 10,
            rewardPoints: 150,
            timeRemaining: 3600 * 3 + 720,
            state: .available,
            acceptedDate: Date().addingTimeInterval(-86400 * 3)
        ),
        Challenge(
            id: UUID(),
            title: "Score 3 Runs",
            type: .sponsored,
            difficulty: .medium,
            rewardCash: 5,
            rewardPoints: 120,
            timeRemaining: 3600 * 2 + 1800,
            state: .available,
            acceptedDate: Date().addingTimeInterval(-86400 * 5)
        ),
        Challenge(
            id: UUID(),
            title: "Golden Arm",
            type: .sponsored,
            difficulty: .medium,
            rewardCash: 8,
            rewardPoints: 140,
            timeRemaining: 3600 * 2,
            state: .available,
            acceptedDate: Date().addingTimeInterval(-86400 * 1)
        ),
        Challenge(
            id: UUID(),
            title: "Top 3 Hits",
            type: .sponsored,
            difficulty: .hard,
            rewardCash: 12,
            rewardPoints: 180,
            timeRemaining: 3600 * 4,
            state: .available,
            acceptedDate: Date().addingTimeInterval(-86400 * 7)
        ),
        Challenge(
            id: UUID(),
            title: "Hit a Homer",
            type: .reward,
            difficulty: .medium,
            rewardCash: nil,
            rewardPoints: 100,
            timeRemaining: 3600 * 5,
            state: .available,
            acceptedDate: Date().addingTimeInterval(-86400 * 2)
        ),
        Challenge(
            id: UUID(),
            title: "Throw 10 Ks",
            type: .reward,
            difficulty: .hard,
            rewardCash: nil,
            rewardPoints: 150,
            timeRemaining: 3600 * 6,
            state: .available,
            acceptedDate: Date().addingTimeInterval(-86400 * 4)
        ),
        Challenge(
            id: UUID(),
            title: "5 Clean Catches",
            type: .reward,
            difficulty: .easy,
            rewardCash: nil,
            rewardPoints: 80,
            timeRemaining: 3600 * 4 + 600,
            state: .available,
            acceptedDate: Date().addingTimeInterval(-86400 * 6)
        ),
        Challenge(
            id: UUID(),
            title: "Clutch Moment",
            type: .reward,
            difficulty: .medium,
            rewardCash: nil,
            rewardPoints: 130,
            timeRemaining: 3600 * 2 + 600,
            state: .available,
            acceptedDate: Date().addingTimeInterval(-86400 * 3)
        ),
        Challenge(
            id: UUID(),
            title: "50 Pitches",
            type: .training,
            difficulty: .hard,
            rewardCash: nil,
            rewardPoints: 50,
            timeRemaining: nil,
            state: .available,
            acceptedDate: nil
        ),
        Challenge(
            id: UUID(),
            title: "3 Double Plays",
            type: .training,
            difficulty: .medium,
            rewardCash: nil,
            rewardPoints: 70,
            timeRemaining: nil,
            state: .available,
            acceptedDate: nil
        ),
        Challenge(
            id: UUID(),
            title: "Attend Meeting",
            type: .training,
            difficulty: .easy,
            rewardCash: nil,
            rewardPoints: 30,
            timeRemaining: nil,
            state: .available,
            acceptedDate: nil
        ),
        Challenge(
            id: UUID(),
            title: "Run 5 Sprints",
            type: .training,
            difficulty: .easy,
            rewardCash: nil,
            rewardPoints: 40,
            timeRemaining: nil,
            state: .available,
            acceptedDate: nil
        ),
        Challenge(
            id: UUID(),
            title: "Cone Drills",
            type: .training,
            difficulty: .medium,
            rewardCash: nil,
            rewardPoints: 60,
            timeRemaining: nil,
            state: .available,
            acceptedDate: nil
        ),
        Challenge(
            id: UUID(),
            title: "100 Swings",
            type: .training,
            difficulty: .hard,
            rewardCash: nil,
            rewardPoints: 90,
            timeRemaining: nil,
            state: .available,
            acceptedDate: nil
        ),
        Challenge(
            id: UUID(),
            title: "Stretch 10 Min",
            type: .training,
            difficulty: .easy,
            rewardCash: nil,
            rewardPoints: 20,
            timeRemaining: nil,
            state: .available,
            acceptedDate: nil
        ),
        Challenge(
            id: UUID(),
            title: "Watch Replays",
            type: .training,
            difficulty: .medium,
            rewardCash: nil,
            rewardPoints: 55,
            timeRemaining: nil,
            state: .available,
            acceptedDate: nil
        ),
        Challenge(
            id: UUID(),
            title: "Agility Ladder",
            type: .training,
            difficulty: .medium,
            rewardCash: nil,
            rewardPoints: 45,
            timeRemaining: nil,
            state: .available,
            acceptedDate: nil
        ),
        Challenge(
            id: UUID(),
            title: "Wall Ball Drill",
            type: .training,
            difficulty: .easy,
            rewardCash: nil,
            rewardPoints: 35,
            timeRemaining: nil,
            state: .available,
            acceptedDate: nil
        ),
        Challenge(
            id: UUID(),
            title: "Tee Work Session",
            type: .training,
            difficulty: .medium,
            rewardCash: nil,
            rewardPoints: 50,
            timeRemaining: nil,
            state: .available,
            acceptedDate: nil
        ),
        Challenge(
            id: UUID(),
            title: "Baserunning Circuit",
            type: .training,
            difficulty: .hard,
            rewardCash: nil,
            rewardPoints: 75,
            timeRemaining: nil,
            state: .available,
            acceptedDate: nil
        ),
        Challenge(
            id: UUID(),
            title: "Glove Work Reps",
            type: .training,
            difficulty: .medium,
            rewardCash: nil,
            rewardPoints: 60,
            timeRemaining: nil,
            state: .available,
            acceptedDate: nil
        ),
        Challenge(
            id: UUID(),
            title: "Hit & Run Drill",
            type: .training,
            difficulty: .hard,
            rewardCash: nil,
            rewardPoints: 85,
            timeRemaining: nil,
            state: .available,
            acceptedDate: nil
        )
    ]

    static let challenges: [Challenge] = baseChallenges + eventChallenges

    static let leaderboard: [LeaderboardEntry] = [
        LeaderboardEntry(id: UUID(), rank: 1, name: "Bryce Harper", avatarName: "avatar1", points: 27_540, isYou: false),
        LeaderboardEntry(id: UUID(), rank: 2, name: "Shohei Ohtani", avatarName: "avatar2", points: 26_760, isYou: false),
        LeaderboardEntry(id: UUID(), rank: 3, name: "Aaron Judge", avatarName: "avatar3", points: 25_420, isYou: false),
        LeaderboardEntry(id: UUID(), rank: 4, name: "Steven Kwan", avatarName: "avatar4", points: 24_000, isYou: false),
        LeaderboardEntry(id: UUID(), rank: 5, name: "Nick Kurz", avatarName: "avatar5", points: 23_480, isYou: false),
        LeaderboardEntry(id: UUID(), rank: 6, name: "Brent Rooker", avatarName: "avatar6", points: 22_310, isYou: false),
        LeaderboardEntry(id: UUID(), rank: 7, name: "Jacob Wilson", avatarName: "avatar7", points: 21_050, isYou: false)
    ]

    static let tier: Tier = Tier(name: "Profile", points: 950, nextSkinTarget: 1200)
}

extension MockData {
    static let events: [Event] = [
        Event(
            id: UUID(),
            title: "Game vs Warriors",
            homeTeam: "SponUp Hooligans",
            awayTeam: "Rival Tigers",
            startAt: Calendar.current.date(from: DateComponents(year: 2025, month: 7, day: 28, hour: 19, minute: 30))!,
            challengeIDs: [
                eventChallenge1ID,
                eventChallenge2ID,
                eventChallenge3ID
            ]
        ),
        Event(
            id: UUID(),
            title: "Tournament Finals",
            homeTeam: "Rival Tigers",
            awayTeam: "Mighty Eagles",
            startAt: Calendar.current.date(from: DateComponents(year: 2025, month: 7, day: 31, hour: 18, minute: 45))!,
            challengeIDs: [
                eventChallenge2ID,
                eventChallenge3ID
            ]
        ),
        Event(
            id: UUID(),
            title: "Charity Match",
            homeTeam: "SponUp Hooligans",
            awayTeam: "City Hawks",
            startAt: Calendar.current.date(from: DateComponents(year: 2025, month: 7, day: 29, hour: 14))!,
            challengeIDs: [
                eventChallenge1ID
            ]
        ),
        Event(
            id: UUID(),
            title: "Summer League Game",
            homeTeam: "Mighty Eagles",
            awayTeam: "Rival Tigers",
            startAt: Calendar.current.date(from: DateComponents(year: 2025, month: 7, day: 29, hour: 18))!,
            challengeIDs: [
                eventChallenge2ID,
                eventChallenge3ID
            ]
        )
    ]
 }*/
