//
//  ChatMessage.swift
//  SponUp2.0
//
//  Created by Steve Paek on 8/4/25.
//

import Foundation
import Combine
import FirebaseFirestore
import AVFoundation   // for text-to-speech
import UIKit

struct ChatMessage: Identifiable {
    let id = UUID()
    let sender: Sender
    let text: String

    enum Sender { case user, chai }
}

final class ChaiAgent: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    var userName: String = ""

    /// Populate this after loading your sponsor’s roster:
    var knownAthletes: [String] = []

    private var hasGreeted = false
    private let speaker = AVSpeechSynthesizer()

    /// Call once when the chat panel appears
    func greet() {
        guard !hasGreeted else { return }
        hasGreeted = true
        let welcome = """
        Hi, \(userName)! I can help you **create and fund challenges**.  
        For example: “Create a challenge for (Athlete’s Name) to get two base hits for $20.”
        """
        reply(welcome)
    }

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        append(.user, trimmed)

        // Normalize apostrophes (“RBI’s” → “RBIs”)
        let input = trimmed.replacingOccurrences(of: "'", with: "")

        if let (athlete, count, stat, reward) = parseCreateCommand(from: input) {
            // Save to Firestore
            let data: [String: Any] = [
                "athleteName": athlete,
                "requirement": "\(count) \(stat)",
                "reward": reward,
                "createdBy": userName,
                "createdAt": Timestamp()
            ]
            Firestore.firestore()
                .collection("challenges")
                .addDocument(data: data)

            // Format dollars
            let rewardString: String = {
                if reward.truncatingRemainder(dividingBy: 1) == 0 {
                    return String(format: "$%.0f", reward)
                } else {
                    return String(format: "$%.2f", reward)
                }
            }()

            reply("✅ Created a challenge for \(athlete): make \(count) \(stat) to earn \(rewardString).")
        } else {
            reply("""
                Sorry, I didn’t understand. Try commands like:
                “Create a challenge for Bryce Harper to get two hits for $10.”
                “Create a challenge for Mike Trout to get 3 RBIs for $20.”
                Supported stats include hits, singles, doubles, triples, home runs, at-bats, AVG, OBP, SLG, OPS, runs scored, RBIs, BB, K, SB, CS, PO, A, E, C, PB, WP, W, L, SV, QS, ERA, WHIP, holds.
                """)
        }
    }

    // MARK: – Parsing

    private func parseCreateCommand(from input: String) -> (String, Int, String, Double)? {
        let pattern = """
        (?ix)
        create\\s+(?:a\\s+)?challenge.*?for\\s+
        ([^\\.\\-–]+?)\\s+
        (?:to\\s+)?(?:have(?:\\s+them)?\\s+)?
        (?:get|make|do)\\s+
        (\\w+)\\s+
        ([\\w\\s]+?)\\s+
        (?:(?:to\\s+earn)|for)\\s+
        \\$(\\d+(?:\\.\\d{1,2})?)
        """
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns   = input as NSString
        let full = NSRange(location: 0, length: ns.length)
        guard let m = regex.firstMatch(in: input, range: full),
              m.numberOfRanges == 5
        else { return nil }

        // 1) Raw athlete name
        let rawName = ns
            .substring(with: m.range(at: 1))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 1a) Fuzzy-match to your knownAthletes list
        let athlete: String
        if !knownAthletes.isEmpty {
            athlete = knownAthletes.min { lhs, rhs in
                lhs.levenshteinDistance(to: rawName)
                 < rhs.levenshteinDistance(to: rawName)
            } ?? rawName
        } else {
            athlete = rawName
        }

        // 2) Count
        let rawCount = ns.substring(with: m.range(at: 2)).lowercased()
        guard let count = parseNumber(rawCount) else { return nil }

        // 3) Stat phrase
        let rawStat = ns
            .substring(with: m.range(at: 3))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard let stat = normalizeStat(rawStat) else { return nil }

        // 4) Reward
        let rawReward = ns.substring(with: m.range(at: 4))
        guard let reward = Double(rawReward) else { return nil }

        return (athlete, count, stat, reward)
    }

    /// Map spelled-out and digit numbers to Int, plus homophones
    private func parseNumber(_ s: String) -> Int? {
        let word = s.lowercased()
        if word == "to" || word == "too" { return 2 }
        if word == "for"                 { return 4 }
        if let n = Int(word)            { return n }
        return wordToNumber[word]
    }

    private let wordToNumber: [String:Int] = [
        "a":1, "an":1,
        "zero":0, "one":1, "two":2, "three":3, "four":4,
        "five":5, "six":6, "seven":7, "eight":8, "nine":9,
        "ten":10, "eleven":11, "twelve":12, "thirteen":13,
        "fourteen":14, "fifteen":15, "sixteen":16,
        "seventeen":17, "eighteen":18, "nineteen":19, "twenty":20
    ]

    private func normalizeStat(_ raw: String) -> String? {
        for (pattern, normalized) in statPatterns {
            if raw.range(of: pattern, options: .regularExpression) != nil {
                return normalized
            }
        }
        return nil
    }

    private let statPatterns: [(pattern: String, normalized: String)] = [
        ("^hit(?:s)?$",                    "hit(s)"),
        ("^single(?:s)?$",                 "single(s)"),
        ("^double(?:s)?$",                 "double(s)"),
        ("^triple(?:s)?$",                 "triple(s)"),
        ("^home\\s*runs?$|^hrs?$",         "home run(s)"),
        ("^at[-]?bat(?:s)?$|^abs?$",       "at-bat(s)"),
        ("^batting\\s*average$|^avg$",     "batting average"),
        ("^on[-]?base\\s*percentage$|^obp$", "on-base percentage"),
        ("^slugging\\s*percentage$|^slg$", "slugging percentage"),
        ("^ops$",                          "OPS"),
        ("^runs?\\s*scored$|^runs?$",       "run(s) scored"),
        ("^rbi(?:s)?$|^runs\\s*batted\\s*in$", "RBI(s)"),
        ("^walk(?:s)?$|^bb(?:s)?$",        "walk(s)"),
        ("^strikeout(?:s)?$|^k(?:s)?$",    "strikeout(s)"),
        ("^stolen\\s*base(?:s)?$|^sb(?:s)?$", "stolen base(s)"),
        ("^caught\\s*stealing$|^cs(?:s)?$",  "caught stealing"),
        ("^putout(?:s)?$|^po(?:s)?$",      "putout(s)"),
        ("^assist(?:s)?$|^a(?:s)?$",       "assist(s)"),
        ("^error(?:s)?$|^e(?:s)?$",        "error(s)"),
        ("^catch(?:es)?$|^c(?:s)?$",       "catch(es)"),
        ("^passed\\s*ball(?:s)?$|^pb(?:s)?$", "passed ball(s)"),
        ("^wild\\s*pitch(?:s)?$|^wp(?:s)?$", "wild pitch(s)"),
        ("^win(?:s)?$|^w(?:s)?$",          "win(s)"),
        ("^loss(?:es)?$|^l(?:s)?$",        "loss(es)"),
        ("^save(?:s)?$|^sv(?:s)?$",        "save(s)"),
        ("^quality\\s*start(?:s)?$|^qs(?:s)?$", "quality start(s)"),
        ("^earned\\s*run\\s*average$|^era$", "ERA"),
        ("^whip$",                         "WHIP"),
        ("^holds?$|^hdls?$",               "hold(s)")
    ]

    // MARK: – Messaging Helpers

    private func append(_ sender: ChatMessage.Sender, _ text: String) {
        DispatchQueue.main.async {
            self.messages.append(.init(sender: sender, text: text))
        }
    }

    /// Appends a `.chai` message and speaks it
    private func reply(_ text: String) {
        append(.chai, text)
        speak(text)
    }

    private func speak(_ text: String) {
        let utt = AVSpeechUtterance(string: text)
        utt.voice = AVSpeechSynthesisVoice(language: "en-US")
        speaker.speak(utt)
    }
}

// MARK: — Levenshtein String Distance

// MARK: — Levenshtein String Distance

private extension String {
    func levenshteinDistance(to other: String) -> Int {
        let a = Array(self.lowercased())
        let b = Array(other.lowercased())
        var dist = [[Int]](
            repeating: [Int](repeating: 0, count: b.count + 1),
            count: a.count + 1
        )

        for i in 0...a.count { dist[i][0] = i }
        for j in 0...b.count { dist[0][j] = j }

        for i in 1...a.count {
            for j in 1...b.count {
                if a[i-1] == b[j-1] {
                    dist[i][j] = dist[i-1][j-1]
                } else {
                    // explicitly call the global min(_:_:)
                    dist[i][j] = Swift.min(
                        dist[i-1][j]   + 1,
                        dist[i][j-1]   + 1,
                        dist[i-1][j-1] + 1
                    )
                }
            }
        }
        return dist[a.count][b.count]
    }
}
