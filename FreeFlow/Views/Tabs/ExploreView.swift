//
//  ExploreView.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 20/05/2026.
//

import SwiftUI

struct ExploreView: View {
    @EnvironmentObject private var settings: FlowSettings
    @State private var searchText: String = "fame"
    @State private var words: [DatamuseWord] = []
    @State private var isLoading: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    // FIXED: Evaluates light/dark canvas states cleanly from your decoupled settings property wrapper
    private var isDarkMode: Bool {
        if settings.appTheme == .system {
            return colorScheme == .dark
        }
        return settings.appTheme == .dark
    }
    
    // FIXED: Pulls background colors dynamically matching other studio workspace tabs
    private var workspaceBackground: Color {
        settings.canvasColor.backgroundColor(isDark: isDarkMode)
    }
    
    private var mainTextColor: Color {
        isDarkMode ? .white : .black
    }
    
    private var cardBackground: Color {
        isDarkMode ? Color.white.opacity(0.04) : Color.black.opacity(0.03)
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
            .background(isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.05))
            .cornerRadius(10)
            .padding()
            
            if words.isEmpty && !isLoading {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundColor(mainTextColor.opacity(0.3))
                    Text("Press enter to search concept meanings")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(mainTextColor.opacity(0.4))
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
                                        // FIXED: Re-tinted syllable counter labels to match your active Accent Theme selection perfectly
                                        .foregroundColor(settings.appAccent.color)
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
        // FIXED: Sets explicit background layer tracking matching chosen layout presets natively
        .background(workspaceBackground.ignoresSafeArea())
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
        .environmentObject(FlowSettings())
}
