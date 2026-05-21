//
//  ExploreView.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 20/05/2026.
//

import SwiftUI

struct ExploreView: View {
    @State private var searchText: String = "fame"
    @State private var words: [DatamuseWord] = []
    @State private var isLoading: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var mainTextColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Integrated Top Search Field Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Explore syntax concepts...", text: $searchText, onCommit: executeExploreSearch)
                    .textFieldStyle(.plain)
                    .foregroundColor(mainTextColor)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(8)
            .background(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.05))
            .cornerRadius(10)
            .padding()
            
            if words.isEmpty && !isLoading {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Press enter to search concept meanings")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    Section(header: Text("Linguistic Semantic Connections").font(.system(size: 11, weight: .bold))) {
                        ForEach(words) { item in
                            HStack {
                                Text(item.word)
                                    .foregroundColor(mainTextColor)
                                Spacer()
                                if let syllables = item.numSyllables {
                                    Text("\(syllables) syl")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listRowBackground(cardBackground)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
        .task {
            // Initial payload load on view appear
            executeExploreSearch()
        }
    }
    
    private func executeExploreSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoading = true
        
        Task {
            let results = await DatamuseAPI.shared.fetchRelatedWords(phrase: searchText, type: .synonyms)
            await MainActor.run {
                self.words = results
                self.isLoading = false
            }
        }
    }
}

#Preview {
    ExploreView()
        .background(Color(white: 0.12))
}
