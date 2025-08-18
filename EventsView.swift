import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import PhotosUI

struct EventsView: View {
    @State private var selectedDate: Date? = Calendar.current.startOfDay(for: Date())
    @State private var showAddEventSheet = false
    @State private var displayedMonth: Date = Calendar.current.startOfDay(for: Date())
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var uploadForEvent: Event? = nil

    // Firestore-loaded data
    @State private var userEvents: [Event] = []
    @State private var acceptedChallenges: [Challenge] = []

    // Force calendar refresh when events load
    @State private var calendarRefreshID = UUID()

    let calendar = Calendar.current
    let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]

    private let db = Firestore.firestore()
    private let userID = Auth.auth().currentUser?.uid

    private var challengesByEventID: [String: [Challenge]] {
        Dictionary(grouping: acceptedChallenges, by: { $0.eventID ?? "" })
    }
    private var eventsByDate: [Date: [Event]] {
        Dictionary(grouping: userEvents, by: { calendar.startOfDay(for: $0.startAt) })
    }
    private func dotCount(for date: Date) -> Int {
        let dayStart = calendar.startOfDay(for: date)
        let eventsCount = eventsByDate[dayStart]?.count ?? 0
        return min(eventsCount, 3)
    }
    private var currentMonthName: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }
    private let rowHeight: CGFloat = 60
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    // Month nav (black chevrons + label)
                    HStack {
                        Button { previousMonth() } label: {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.black)
                        }
                        Spacer()
                        Text(currentMonthName)
                            .font(.title2.bold())
                            .foregroundColor(.black)
                        Spacer()
                        Button { nextMonth() } label: {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // Weekday headers (black)
                    HStack {
                        ForEach(Array(daysOfWeek.enumerated()), id: \.offset) { _, d in
                            Text(d)
                                .font(.caption.bold())
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Calendar grid
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .shadow(radius: 4)

                        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 7), spacing: 10) {
                            let days = generateDaysInMonth()
                            ForEach(Array(days.enumerated()), id: \.offset) { _, dateOpt in
                                if let date = dateOpt {
                                    CalendarDayView(
                                        date: date,
                                        isToday: calendar.isDateInToday(date),
                                        selectedDate: $selectedDate,
                                        eventCount: dotCount(for: date)
                                    )
                                    .frame(height: rowHeight)
                                } else {
                                    Rectangle().fill(Color.clear).frame(height: rowHeight)
                                }
                            }
                        }
                        .id(calendarRefreshID)
                    }
                    .frame(height: CGFloat(numberOfWeeksInMonth()) * (rowHeight + 10))
                    .padding(.horizontal, 16)

                    // Details below
                    selectedDayCard
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    Spacer(minLength: 40)
                }
            }
            .sheet(isPresented: $showAddEventSheet) {
                if let date = selectedDate {
                    AddEventView(date: date) { title, time in
                        addUserEvent(title: title, time: time)
                        showAddEventSheet = false
                    }
                }
            }
            .onAppear {
                loadUserEvents()
                loadAcceptedChallenges()
            }
            .navigationTitle("Events")
            .navigationBarTitleDisplayMode(.inline)
            // Same subtle background as Leaderboard/MyChallenges
            .background(
                Image("leaderboard_bg")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.15)
                    .ignoresSafeArea()
            )
        }
    }

    // MARK: – Selected day card
    private var selectedDayCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let date = selectedDate {
                let dayStart = calendar.startOfDay(for: date)
                let eventsForDay = (eventsByDate[dayStart] ?? []).sorted { $0.startAt < $1.startAt }

                if !eventsForDay.isEmpty {
                    ForEach(eventsForDay, id: \.id) { evt in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("[\(timeFormatter.string(from: evt.startAt))] \(evt.title)")
                                .font(.headline)
                                .foregroundColor(.black)

                            let chs = challengesByEventID[evt.id ?? ""] ?? []
                            if !chs.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Challenges:")
                                        .font(.subheadline).bold()
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(Array(chs.prefix(3).enumerated()), id: \.1.id) { index, c in
                                            HStack(spacing: 8) {
                                                HStack(spacing: 6) {
                                                    Text("• \(c.title)")
                                                    if let cash = c.rewardCash { Text(String(format: "$%.2f", cash)) }
                                                    if let pts = c.rewardPoints { Text("+\(pts) pts") }
                                                }
                                                .lineLimit(1)
                                                .truncationMode(.tail)

                                                Spacer(minLength: 8)

                                                Button {
                                                    removeChallenge(c, from: evt)
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundColor(.gray)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .padding(.vertical, 6)

                                            if index < chs.prefix(3).count - 1 {
                                                Divider().padding(.vertical, 4)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .padding(.vertical, 4)
                    }

                    Button("+ Add Event") { showAddEventSheet = true }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.top, 12)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No events scheduled for this day.")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Button("+ Add Event") { showAddEventSheet = true }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .padding(.top, 12)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("Select a day to see events and challenges.")
                    .font(.headline)
                    .foregroundColor(.black.opacity(0.7))
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }

    // MARK: – Firestore ops

    private func addUserEvent(title: String, time: Date) {
        guard let sel = selectedDate else { return }
        var comps = calendar.dateComponents([.year, .month, .day], from: sel)
        let tcomps = calendar.dateComponents([.hour, .minute], from: time)
        comps.hour = tcomps.hour; comps.minute = tcomps.minute
        guard let combined = calendar.date(from: comps) else { return }

        let endDate = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: combined) ?? combined

        let eid = UUID().uuidString
        let newEvent = Event(
            id: eid,
            title: title,
            homeTeam: "User Team",
            awayTeam: "Opponent Team",
            startAt: combined,
            endDate: endDate,
            challengeIDs: []
        )

        let data: [String:Any] = [
            "id": eid,
            "title": title,
            "homeTeam": "User Team",
            "awayTeam": "Opponent Team",
            "startAt": Timestamp(date: combined),
            "endDate": Timestamp(date: endDate),
            "challengeIDs": []
        ]

        db.collection("events").document(eid).setData(data) { err in
            if let e = err { print("Error: \(e)") }
            else {
                userEvents.append(newEvent)
                calendarRefreshID = UUID()
            }
        }
    }

    private func removeChallenge(_ challenge: Challenge, from event: Event) {
        guard let cid = challenge.id else { return }
        let eid = event.id ?? challenge.eventID

        // Optimistic UI
        acceptedChallenges.removeAll { $0.id == cid }
        if let eid = eid, let eidx = userEvents.firstIndex(where: { $0.id == eid }) {
            userEvents[eidx].challengeIDs.removeAll { $0 == cid }
        }

        // Firestore removes
        if let uid = userID {
            db.collection("users").document(uid)
                .collection("acceptedChallenges").document(cid)
                .delete { err in
                    if let err = err { print("Remove (user) failed: \(err)") }
                }
        }
        if let eid = eid {
            db.collection("events").document(eid)
                .updateData(["challengeIDs": FieldValue.arrayRemove([cid])]) { err in
                    if let err = err { print("Remove (event) failed: \(err)") }
                }
        }
    }

    private func loadUserEvents() {
        db.collection("events").getDocuments { snap, err in
            if let e = err { print("Error: \(e)") ; return }
            userEvents = snap?.documents.compactMap { parseEventData($0.data()) } ?? []
            calendarRefreshID = UUID()
        }
    }

    private func loadAcceptedChallenges() {
        guard let uid = userID else { return }
        db.collection("users").document(uid)
          .collection("acceptedChallenges")
          .getDocuments { snap, err in
            if let e = err { print("Error: \(e)"); return }
            acceptedChallenges = snap?.documents.compactMap { parseChallengeData($0.data()) } ?? []
        }
    }

    // MARK: – Parsing

    private func parseEventData(_ d: [String:Any]) -> Event? {
        guard
            let id   = d["id"] as? String,
            let t    = d["title"] as? String,
            let ht   = d["homeTeam"] as? String,
            let at   = d["awayTeam"] as? String,
            let ts   = d["startAt"] as? Timestamp,
            let ids  = d["challengeIDs"] as? [String]
        else { return nil }

        let start = ts.dateValue()
        let endDate = (d["endDate"] as? Timestamp)?.dateValue()
            ?? (Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: start) ?? start)

        return Event(
            id: id,
            title: t,
            homeTeam: ht,
            awayTeam: at,
            startAt: start,
            endDate: endDate,
            challengeIDs: ids
        )
    }

    private func parseChallengeData(_ d: [String:Any]) -> Challenge? {
        guard
            let id         = d["id"] as? String,
            let catRaw     = d["category"] as? String,
            let cat        = ChallengeCategory(rawValue: catRaw),
            let title      = d["title"] as? String,
            let typeRaw    = d["type"] as? String,
            let type       = ChallengeType(rawValue: typeRaw),
            let diffRaw    = d["difficulty"] as? String,
            let diff       = Difficulty(rawValue: diffRaw),
            let stateRaw   = d["state"] as? String,
            let state      = ChallengeState(rawValue: stateRaw)
        else { return nil }

        return Challenge(
            id:           id,
            category:     cat,
            title:        title,
            type:         type,
            difficulty:   diff,
            rewardCash:   d["rewardCash"] as? Double,
            rewardPoints: d["rewardPoints"] as? Int,
            timeRemaining:d["timeRemaining"] as? TimeInterval,
            state:        state,
            acceptedDate: (d["acceptedDate"] as? Timestamp)?.dateValue(),
            startAt:      (d["startAt"] as? Timestamp)?.dateValue(),
            eventID:      d["eventID"] as? String
        )
    }

    // MARK: – Date helpers

    private func generateDaysInMonth() -> [Date?] {
        guard let monthInt = calendar.dateInterval(of: .month, for: displayedMonth),
              let firstWeekday = calendar.dateComponents([.weekday], from: monthInt.start).weekday
        else { return [] }

        let firstIndex = (firstWeekday - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: firstIndex)
        let count = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 0
        for d in 0..<count {
            if let dt = calendar.date(byAdding: .day, value: d, to: monthInt.start) {
                days.append(dt)
            }
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private func numberOfWeeksInMonth() -> Int {
        generateDaysInMonth().count / 7
    }

    private func previousMonth() {
        if let p = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = p
        }
    }

    private func nextMonth() {
        if let n = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = n
        }
    }
}

// MARK: – CalendarDayView

struct CalendarDayView: View {
    let date: Date
    let isToday: Bool
    @Binding var selectedDate: Date?
    let eventCount: Int

    let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 6) {
            Text("\(calendar.component(.day, from: date))")
                .font(.subheadline)
                .foregroundColor(
                    calendar.isDate(selectedDate ?? Date.distantPast, inSameDayAs: date) ? .white :
                        (isToday ? .red : .black)
                )
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(
                    calendar.isDate(selectedDate ?? Date.distantPast, inSameDayAs: date)
                        ? Color.blue : Color.clear
                )
                .cornerRadius(6)

            // Dots
            if eventCount > 0 {
                HStack(spacing: 3) {
                    ForEach(0..<eventCount, id: \.self) { _ in
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 6, height: 6)
                    }
                }
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(4)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDate = date
        }
    }
}

// MARK: – AddEventView

struct AddEventView: View {
    let date: Date
    @Environment(\.dismiss) var dismiss

    @State private var title: String = ""
    @State private var time: Date = Date()

    var onSave: ((String, Date) -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Event Title")) {
                    TextField("Enter event title", text: $title)
                }
                Section(header: Text("Event Time")) {
                    DatePicker(
                        "",
                        selection: $time,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add Event")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !title.isEmpty {
                            onSave?(title, time)
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .ignoresSafeArea(.keyboard)
    }
}
