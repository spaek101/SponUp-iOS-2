//
//  GameTitlesView.swift
//  SponUp2.0
//
//  Created by Steve Paek on 8/7/25.
//


import SwiftUI

struct GameTitlesView: View {
    @EnvironmentObject var store: ChallengeTitleStore
    @State private var newTitle = ""
    
    var body: some View {
        Form {
            Section(header: Text("Add New Game Challenge")) {
                HStack {
                    TextField("Enter title", text: $newTitle)
                    Button("Add") {
                        guard !newTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        store.gameTitles.append(newTitle.trimmingCharacters(in: .whitespaces))
                        store.save(store.gameTitles, for: "game")
                        newTitle = ""
                    }
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            
            Section(header: Text("All Game Challenges")) {
                List {
                    ForEach(store.gameTitles, id: \.self) { title in
                        Text(title)
                    }
                    .onDelete { idx in
                        store.gameTitles.remove(atOffsets: idx)
                        store.save(store.gameTitles, for: "game")
                    }
                }
            }
        }
        .navigationTitle("Game Challenges")
    }
}
