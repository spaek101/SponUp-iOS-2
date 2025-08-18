import Foundation
import FirebaseFirestore

// MARK: - Challenge Types and Enums

enum ChallengeType: String, Codable {
    case sponsored, reward, training, eventFocus
}

enum Difficulty: String, CaseIterable, Codable {
    case easy, medium, hard
}

enum ChallengeState: String, Codable {
    case available, selected, inProgress, completed
}

enum SuggestedFilter {
    case eventFocus, training, sponsored
}

// MARK: - Challenge Category

/// Specific sport category used for selecting the correct image
enum ChallengeCategory: String, Codable {
    case batting
    case pitching
    case catching
    case fielding
    case baseRunning
}

// MARK: - Challenge Model

struct Challenge: Identifiable, Codable, Equatable, Hashable {
    var id: String?

    let category: ChallengeCategory
    let title: String
    let type: ChallengeType
    let difficulty: Difficulty
    let rewardCash: Double?
    let rewardPoints: Int?
    let timeRemaining: TimeInterval?
    var state: ChallengeState
    let acceptedDate: Date?
    let startAt: Date?
    var eventID: String?
    var athleteID: String?
    let imageURL: String?
    let createdAt: Date?   // used for ordering

    enum CodingKeys: String, CodingKey {
        case id, category, title, type, difficulty, rewardCash, rewardPoints
        case timeRemaining, state, acceptedDate, startAt
        case eventID, athleteID, imageURL, createdAt
    }

    init(
        id: String? = nil,
        category: ChallengeCategory,
        title: String,
        type: ChallengeType,
        difficulty: Difficulty,
        rewardCash: Double? = nil,
        rewardPoints: Int? = nil,
        timeRemaining: TimeInterval? = nil,
        state: ChallengeState,
        acceptedDate: Date? = nil,
        startAt: Date? = nil,
        eventID: String? = nil,
        athleteID: String? = nil,
        imageURL: String? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.type = type
        self.difficulty = difficulty
        self.rewardCash = rewardCash
        self.rewardPoints = rewardPoints
        self.timeRemaining = timeRemaining
        self.state = state
        self.acceptedDate = acceptedDate
        self.startAt = startAt
        self.eventID = eventID
        self.athleteID = athleteID
        self.imageURL = imageURL
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decodeIfPresent(String.self,          forKey: .id)
        category      = try c.decode(ChallengeCategory.self,        forKey: .category)
        title         = try c.decode(String.self,                   forKey: .title)
        type          = try c.decode(ChallengeType.self,            forKey: .type)
        difficulty    = try c.decode(Difficulty.self,               forKey: .difficulty)
        rewardCash    = try c.decodeIfPresent(Double.self,          forKey: .rewardCash)
        rewardPoints  = try c.decodeIfPresent(Int.self,             forKey: .rewardPoints)
        timeRemaining = try c.decodeIfPresent(TimeInterval.self,    forKey: .timeRemaining)
        state         = try c.decode(ChallengeState.self,           forKey: .state)

        // Dates can arrive as Firestore Timestamp or Date
        if let ts = try? c.decodeIfPresent(Timestamp.self, forKey: .acceptedDate) {
            acceptedDate = ts.dateValue()
        } else {
            acceptedDate = try c.decodeIfPresent(Date.self, forKey: .acceptedDate)
        }
        if let ts = try? c.decodeIfPresent(Timestamp.self, forKey: .startAt) {
            startAt = ts.dateValue()
        } else {
            startAt = try c.decodeIfPresent(Date.self, forKey: .startAt)
        }
        if let ts = try? c.decodeIfPresent(Timestamp.self, forKey: .createdAt) {
            createdAt = ts.dateValue()
        } else {
            createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        }

        eventID   = try c.decodeIfPresent(String.self,  forKey: .eventID)
        athleteID = try c.decodeIfPresent(String.self,  forKey: .athleteID)
        imageURL  = try c.decodeIfPresent(String.self,  forKey: .imageURL)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(id,                  forKey: .id)
        try c.encode(category,                     forKey: .category)
        try c.encode(title,                        forKey: .title)
        try c.encode(type,                         forKey: .type)
        try c.encode(difficulty,                   forKey: .difficulty)
        try c.encodeIfPresent(rewardCash,          forKey: .rewardCash)
        try c.encodeIfPresent(rewardPoints,        forKey: .rewardPoints)
        try c.encodeIfPresent(timeRemaining,       forKey: .timeRemaining)
        try c.encode(state,                        forKey: .state)
        if let d = acceptedDate { try c.encode(Timestamp(date: d), forKey: .acceptedDate) }
        if let d = startAt      { try c.encode(Timestamp(date: d), forKey: .startAt) }
        if let d = createdAt    { try c.encode(Timestamp(date: d), forKey: .createdAt) }
        try c.encodeIfPresent(eventID,             forKey: .eventID)
        try c.encodeIfPresent(athleteID,           forKey: .athleteID)
        try c.encodeIfPresent(imageURL,            forKey: .imageURL)
    }
}

// MARK: - Challenge Image Mapping

extension Challenge {
    /// Returns the asset name in Assets.xcassets for this challenge’s category
    var imageName: String {
        switch category {
        case .batting:     return "Challenge_Batting"
        case .pitching:    return "Challenge_Pitching"
        case .catching:    return "Challenge_Catching"
        case .fielding:    return "Challenge_Fielding"
        case .baseRunning: return "Challenge_BaseRunning"
        }
    }

    /// Dollar fallback for the card
    var defaultCashFromDifficulty: Int {
        switch difficulty {
        case .easy:   return 5
        case .medium: return 10
        case .hard:   return 20
        }
    }

    /// What to show in "$x + y pts"
    var cashDisplay: Int {
        if let rewardCash { return Int(rewardCash) }
        return defaultCashFromDifficulty
    }
}

// MARK: - Firestore Mappers (for listeners / manual reads)

extension Challenge {
    /// Build a Challenge from a QueryDocumentSnapshot (snapshot listener / getDocuments).
    init(from doc: QueryDocumentSnapshot) {
        let d = doc.data()

        let id            = doc.documentID
        let title         = d["title"] as? String ?? ""
        let categoryStr   = d["category"] as? String ?? "fielding"
        let typeStr       = d["type"] as? String ?? "sponsored"
        let diffStr       = d["difficulty"] as? String ?? "easy"
        let stateStr      = d["state"] as? String ?? "available"

        let rewardCash    = (d["rewardCash"] as? Double) ?? (d["rewardCash"] as? NSNumber)?.doubleValue
        let rewardPoints  = (d["rewardPoints"] as? Int) ?? (d["rewardPoints"] as? NSNumber)?.intValue
        let timeRemaining = (d["timeRemaining"] as? Double) ?? (d["timeRemaining"] as? NSNumber)?.doubleValue
        let createdAt     = (d["createdAt"] as? Timestamp)?.dateValue()

        // acceptedDate key fallback: acceptedDate (preferred) or acceptedAt (legacy)
        let acceptedTs = (d["acceptedDate"] as? Timestamp) ?? (d["acceptedAt"] as? Timestamp)

        self.init(
            id: id,
            category: ChallengeCategory(rawValue: categoryStr) ?? .fielding,
            title: title,
            type: ChallengeType(rawValue: typeStr) ?? .sponsored,
            difficulty: Difficulty(rawValue: diffStr) ?? .easy,
            rewardCash: rewardCash,
            rewardPoints: rewardPoints,
            timeRemaining: timeRemaining,
            state: ChallengeState(rawValue: stateStr) ?? .available,
            acceptedDate: acceptedTs?.dateValue(),
            startAt: (d["startAt"] as? Timestamp)?.dateValue(),
            eventID: d["eventID"] as? String,
            athleteID: d["athleteID"] as? String,
            imageURL: d["imageURL"] as? String,
            createdAt: createdAt
        )
    }

    /// Build a Challenge from a DocumentSnapshot (single doc reads).
    init(from doc: DocumentSnapshot) {
        let d = doc.data() ?? [:]

        let id            = doc.documentID
        let title         = d["title"] as? String ?? ""
        let categoryStr   = d["category"] as? String ?? "fielding"
        let typeStr       = d["type"] as? String ?? "sponsored"
        let diffStr       = d["difficulty"] as? String ?? "easy"
        let stateStr      = d["state"] as? String ?? "available"

        let rewardCash    = (d["rewardCash"] as? Double) ?? (d["rewardCash"] as? NSNumber)?.doubleValue
        let rewardPoints  = (d["rewardPoints"] as? Int) ?? (d["rewardPoints"] as? NSNumber)?.intValue
        let timeRemaining = (d["timeRemaining"] as? Double) ?? (d["timeRemaining"] as? NSNumber)?.doubleValue
        let createdAt     = (d["createdAt"] as? Timestamp)?.dateValue()

        let acceptedTs = (d["acceptedDate"] as? Timestamp) ?? (d["acceptedAt"] as? Timestamp)

        self.init(
            id: id,
            category: ChallengeCategory(rawValue: categoryStr) ?? .fielding,
            title: title,
            type: ChallengeType(rawValue: typeStr) ?? .sponsored,
            difficulty: Difficulty(rawValue: diffStr) ?? .easy,
            rewardCash: rewardCash,
            rewardPoints: rewardPoints,
            timeRemaining: timeRemaining,
            state: ChallengeState(rawValue: stateStr) ?? .available,
            acceptedDate: acceptedTs?.dateValue(),
            startAt: (d["startAt"] as? Timestamp)?.dateValue(),
            eventID: d["eventID"] as? String,
            athleteID: d["athleteID"] as? String,
            imageURL: d["imageURL"] as? String,
            createdAt: createdAt
        )
    }
}

// MARK: - Leaderboard Entry (rank computed in the view)

struct LeaderboardEntry: Identifiable, Codable {
    var id: String
    var name: String
    var points: Int
    var rank: Int?
    var avatarURL: String?
    var isYou: Bool = false
}

// MARK: - Tier

struct Tier: Codable {
    let name: String
    var points: Int
    var nextSkinTarget: Int
}

// MARK: - Event

struct Event: Identifiable, Codable {
    var id: String?
    let title: String
    let homeTeam: String
    let awayTeam: String
    let startAt: Date
    var endDate: Date
    var challengeIDs: [String]
}

// MARK: - Formatter Helper

extension Int {
    var formattedWithSeparator: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
