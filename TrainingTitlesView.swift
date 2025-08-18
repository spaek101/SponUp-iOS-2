//
//  TrainingTitlesView.swift
//  SponUp2.0
//
//  Created by Steve Paek on 8/7/25.
//


import SwiftUI

struct TrainingTitlesView: View {
    @EnvironmentObject var store: ChallengeTitleStore
    @State private var newTitle = ""
    
    var body: some View {
        Form {
            Section(header: Text("Add New Training Challenge")) {
                HStack {
                    TextField("Enter title", text: $newTitle)
                    Button("Add") {
                        guard !newTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        store.trainingTitles.append(newTitle.trimmingCharacters(in: .whitespaces))
                        store.save(store.trainingTitles, for: "training")
                        newTitle = ""
                    }
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            
            Section(header: Text("All Training Challenges")) {
                List {
                    ForEach(store.trainingTitles, id: \.self) { title in
                        Text(title)
                    }
                    .onDelete { idx in
                        store.trainingTitles.remove(atOffsets: idx)
                        store.save(store.trainingTitles, for: "training")
                    }
                }
            }
        }
        .navigationTitle("Training Challenges")
    }
}
