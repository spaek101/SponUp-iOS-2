import SwiftUI
import Combine
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

    // Bottom “link” flow
    @State private var pendingAccepted: [Challenge] = []      // drives bottom banner in other screens
    @State private var showChallengeLink = false

    // 👇 Missing before
    @State private var showLinkSheet = false
    @State private var selectedChallenges: [Challenge] = []

    // Force calendar refresh when events load
    @State private var calendarRefreshID = UUID()

    // Live clock so UI flips automatically when start time passes
    @State private var now = Date()

    let calendar = Calendar.current
    let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]

    private let db = Firestore.firestore()
    private let userID = Auth.auth().currentUser?.uid

    // MARK: – Derived helpers

    /// Union of challenges assigned to an event either via `challenge.eventID`
    /// or via the event’s `challengeIDs` array. Keeps previously linked items visible.
    private func challengesForEvent(_ evt: Event) -> [Challenge] {
        let eid = evt.id
        let byEventID = acceptedChallenges.filter { $0.eventID == eid }

        let idSet = Set(evt.challengeIDs)
        let byArray = acceptedChallenges.filter { ch in
            guard let cid = ch.id else { return false }
            return idSet.contains(cid)
        }

        var map: [String: Challenge] = [:]
        for ch in byEventID { if let id = ch.id { map[id] = ch } }
        for ch in byArray   { if let id = ch.id { map[id] = ch } }
        return map.values.sorted { $0.title < $1.title }
    }

    /// How many challenges are already linked per event (from backend/local state).
    private var existingLinkedCounts: [String: Int] {
        Dictionary(grouping: acceptedChallenges.compactMap { $0.eventID }) { $0 }
            .mapValues { $0.count }
    }
    
    // MARK: – Pending strip recompute
    private func recomputePendingAccepted() {
        // Pending = accepted challenges that are not linked to any event.
        // Keep it simple (avoid heavy enum/string checks): just look at eventID.
        pendingAccepted = acceptedChallenges.filter { ch in
            let linked = ch.eventID ?? ""
            return linked.isEmpty
        }
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

    // MARK: – Body

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
            // 👇 Link sheet — keep strip closed after linking, and never reopen on dismiss
            .sheet(isPresented: $showLinkSheet, onDismiss: {
                // Just clear the sheet list and keep the strip OFF.
                selectedChallenges.removeAll()
                showChallengeLink = false
            }) {
                let futureEvents = userEvents.filter { $0.startAt > Date() }

                ChallengeLinkDetails(
                    selectedChallenges: $selectedChallenges,
                    upcomingEvents: futureEvents,
                    existingLinkedCount: { eid in
                        // live count so capacity/labels update on repeat links
                        acceptedChallenges.filter { $0.eventID == eid }.count
                    },


                    // ✅ When user hits the big "Link" in the details screen:
                    onLinkSelection: { pairs in
                        // Build a lookup of the selected models (so we can merge them locally after linking)
                        let byId: [String: Challenge] = Dictionary(
                            uniqueKeysWithValues: selectedChallenges.compactMap { ch in
                                guard let id = ch.id else { return nil }
                                return (id, ch)
                            }
                        )

                        linkPairsToFirestore(pairs, sourceModels: byId) {
                            recomputePendingAccepted()      // keeps the strip in sync
                            selectedChallenges.removeAll()
                            showChallengeLink = false
                            showLinkSheet = false
                        }
                    },


                    // (safety) if the child calls this without pairs, still close everything
                    onConfirmLink: {
                        pendingAccepted.removeAll()
                        selectedChallenges.removeAll()
                        showChallengeLink = false
                        showLinkSheet = false
                    },

                    // "Clear Picks" in the details view only clears that temporary list
                    onClear: {
                        selectedChallenges.removeAll()
                    },

                    // IMPORTANT: do NOT mutate Events here. Only flip local accepted state
                    // when user explicitly unaccepts from the details view.
                    onUnaccept: { challengeId, previousEventId in
                        // Only revert the *accepted* copy; do NOT remove anything from Events unless you intend to.
                        if let idx = acceptedChallenges.firstIndex(where: { $0.id == challengeId }) {
                            acceptedChallenges[idx].eventID = nil
                        }
                        // If you truly want to detach from the event when unaccepting, you can,
                        // but per your request, we leave Events alone here.
                    }
                )
            }

            .onAppear {
                let group = DispatchGroup()
                group.enter()
                loadUserEvents { group.leave() }
                group.enter()
                loadAcceptedChallenges { group.leave() }
                group.notify(queue: .main) {
                    sweepExpiredUnsubmitted() // 🔁 rule (3)
                    recomputePendingAccepted()
                }
            }
            .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { tick in
                now = tick
            }
            .navigationTitle("Events")
            .navigationBarTitleDisplayMode(.inline)
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
                        let hasStarted = now >= evt.startAt

                        VStack(alignment: .leading, spacing: 8) {
                            Text("[\(timeFormatter.string(from: evt.startAt))] \(evt.title)")
                                .font(.headline)
                                .foregroundColor(.black)

                            let chs = challengesForEvent(evt)
                            if !chs.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Challenges:")
                                        .font(.subheadline).bold()
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(Array(chs.enumerated()), id: \.offset) { index, c in
                                            HStack(spacing: 8) {
                                                HStack(spacing: 6) {
                                                    Text("• \(c.title)")
                                                    if let cash = c.rewardCash, cash > 0 { Text(String(format: "$%.2f", cash)) }
                                                    if let pts = c.rewardPoints, pts > 0 { Text("+\(pts) pts") }
                                                }
                                                .lineLimit(1)
                                                .truncationMode(.tail)

                                                Spacer(minLength: 8)

                                                if !hasStarted {
                                                    Button {
                                                        removeChallenge(c, from: evt)
                                                    } label: {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .font(.system(size: 16, weight: .bold))
                                                            .foregroundColor(.gray)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .padding(.vertical, 6)

                                            if index < chs.count - 1 {
                                                Divider().padding(.vertical, 4)
                                            }
                                        }
                                    }
                                }
                            }

                            // Upload button ONLY after event start
                            if hasStarted {
                                PhotosPicker(
                                    selection: $pickedItems,
                                    matching: .images,
                                    photoLibrary: .shared()
                                ) {
                                    Label("Upload Results for this Event", systemImage: "square.and.arrow.up")
                                        .font(.subheadline.bold())
                                        .frame(maxWidth: .infinity)
                                        .padding(8)
                                        .background(Color.blue.opacity(0.7))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .onChange(of: pickedItems) { _, _ in
                                    uploadForEvent = evt
                                    // TODO: Upload & write submission doc
                                }
                                .padding(.top, 8)
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
                DispatchQueue.main.async {
                    userEvents.append(newEvent)
                    calendarRefreshID = UUID()
                }
            }
        }
    }

    private func linkPairsToFirestore(
        _ pairs: [(challengeId: String, eventId: String)],
        sourceModels: [String: Challenge] = [:],
        completion: (() -> Void)? = nil
    ) {
        guard !pairs.isEmpty else { completion?(); return }
        guard let uid = userID else { return }

        let batch = db.batch()

        // 1) Persist links
        for (cid, eid) in pairs {
            let accRef = db.collection("users").document(uid)
                .collection("acceptedChallenges").document(cid)
            batch.setData(["eventID": eid], forDocument: accRef, merge: true)

            let evtRef = db.collection("events").document(eid)
            batch.updateData(["challengeIDs": FieldValue.arrayUnion([cid])], forDocument: evtRef)
        }

        batch.commit { err in
            if let err = err {
                print("Batch link failed: \(err)")
                return
            }

            // 2) Local UI merge so the EventsView cards show the new links immediately
            DispatchQueue.main.async {
                // Fast index for existing accepted challenges
                var indexById: [String: Int] = [:]
                for (i, ch) in acceptedChallenges.enumerated() {
                    if let id = ch.id { indexById[id] = i }
                }

                for (cid, eid) in pairs {
                    if let idx = indexById[cid] {
                        // Update an existing accepted item
                        acceptedChallenges[idx].eventID = eid
                    } else if var src = sourceModels[cid] {
                        // Merge a new accepted item from the sheet models
                        src.eventID = eid
                        acceptedChallenges.append(src)
                        indexById[cid] = acceptedChallenges.count - 1
                    }

                    // Ensure the local event has the challenge id
                    if let eidx = userEvents.firstIndex(where: { $0.id == eid }) {
                        if !userEvents[eidx].challengeIDs.contains(cid) {
                            userEvents[eidx].challengeIDs.append(cid)
                        }
                    }
                }

                completion?()
            }
        }
    }


    private func removeChallenge(_ challenge: Challenge, from event: Event) {
        if Date() >= event.startAt { return }
        guard let cid = challenge.id else { return }
        let eid = event.id ?? challenge.eventID

        // Optimistic UI
        DispatchQueue.main.async {
            acceptedChallenges.removeAll { $0.id == cid }
            if let eid = eid, let eidx = userEvents.firstIndex(where: { $0.id == eid }) {
                userEvents[eidx].challengeIDs.removeAll { $0 == cid }
            }
        }

        // Remove from user's accepted list
        if let uid = userID {
            db.collection("users").document(uid)
              .collection("acceptedChallenges").document(cid)
              .delete { err in
                  if let err = err { print("Remove (user) failed: \(err)") }
              }

            // Flip back to available in feed
            db.collection("users").document(uid)
              .collection("challenges")
              .document(cid)
              .setData([
                  "state": "available",
                  "eventID": FieldValue.delete()
              ], merge: true)
        }

        // Detach from event doc
        if let eid = eid {
            db.collection("events").document(eid)
              .updateData(["challengeIDs": FieldValue.arrayRemove([cid])]) { err in
                  if let err = err { print("Remove (event) failed: \(err)") }
              }
        }
    }

    // MARK: – Loaders (with completion)

    private func loadUserEvents(completion: (() -> Void)? = nil) {
        db.collection("events").getDocuments { snap, err in
            defer { completion?() }
            if let e = err { print("Error: \(e)") ; return }
            let events = snap?.documents.compactMap { parseEventData($0.data()) } ?? []
            DispatchQueue.main.async {
                userEvents = events
                calendarRefreshID = UUID()
            }
        }
    }

    private func loadAcceptedChallenges(completion: (() -> Void)? = nil) {
        guard let uid = userID else { completion?(); return }
        db.collection("users").document(uid)
          .collection("acceptedChallenges")
          .getDocuments { snap, err in
              defer { completion?() }
              if let e = err { print("Error: \(e)"); return }
              let challenges = snap?.documents.compactMap { parseChallengeData($0.data()) } ?? []
              DispatchQueue.main.async {
                  acceptedChallenges = challenges
                  recomputePendingAccepted()

              }
          }
    }

    // MARK: – Rule (3): recycle after 5 days if no accepted/pending submission

    private func sweepExpiredUnsubmitted() {
        guard let uid = userID else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date()

        let eventsById: [String: Event] = Dictionary(uniqueKeysWithValues:
            userEvents.compactMap { e in
                guard let id = e.id else { return nil }
                return (id, e)
            }
        )

        let linked = acceptedChallenges.filter { $0.eventID != nil }

        for ch in linked {
            guard
                let cid = ch.id,
                let eid = ch.eventID,
                let evt = eventsById[eid],
                evt.endDate < cutoff
            else { continue }

            let subRef = db.collection("users").document(uid)
                .collection("submissions")
                .document(cid)

            subRef.getDocument { snap, _ in
                let status = (snap?.data()?["status"] as? String) ?? "missing"
                let accepted = status == "accepted"
                let pending  = status == "pending"

                if !accepted && !pending {
                    db.collection("users").document(uid)
                      .collection("challenges")
                      .document(cid)
                      .setData([
                          "state": "available",
                          "eventID": FieldValue.delete()
                      ], merge: true)

                    db.collection("users").document(uid)
                      .collection("acceptedChallenges")
                      .document(cid)
                      .delete()

                    db.collection("events").document(eid)
                      .updateData(["challengeIDs": FieldValue.arrayRemove([cid])]) { err in
                          if let err = err { print("Detach from event failed: \(err)") }
                      }

                    DispatchQueue.main.async {
                        acceptedChallenges.removeAll { $0.id == cid }
                        if let eidx = userEvents.firstIndex(where: { $0.id == eid }) {
                            userEvents[eidx].challengeIDs.removeAll { $0 == cid }
                        }
                    }
                }
            }
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


