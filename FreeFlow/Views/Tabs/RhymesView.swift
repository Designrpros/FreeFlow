//
//  RhymesView.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 20/05/2026.
//

import SwiftUI

struct RhymesView: View {
    @EnvironmentObject private var settings: FlowSettings
    @State private var searchText: String = "fame"
    @State private var rhymes: [DatamuseWord] = []
    @State private var isLoading: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    // FIXED: Evaluates interface light/dark states through your decoupled theme variables
    private var isDarkMode: Bool {
        if settings.appTheme == .system {
            return colorScheme == .dark
        }
        return settings.appTheme == .dark
    }
    
    // FIXED: Pulls backend layout color arrays matching your global background configurations
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
            // Native Glass Search field bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search Rhymes...", text: $searchText, onCommit: executeRhymeSearch)
                    .textFieldStyle(.plain)
                    .foregroundColor(mainTextColor)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        rhymes = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.05))
            .cornerRadius(10)
            .padding()
            
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        // Focus Target Title
                        Text(searchText.lowercased())
                            .font(.system(size: 54, weight: .bold, design: .rounded))
                            .foregroundColor(mainTextColor)
                        
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.9)
                        } else {
                            Text("Rhyme Stream Matches Found: \(rhymes.count)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(mainTextColor.opacity(0.4))
                        }
                    }
                    .padding(.top)
                    
                    // Structural Grid Layout View
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Rhyming Companion Index")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(mainTextColor.opacity(0.4))
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110, maximum: 150), spacing: 12)], spacing: 12) {
                            ForEach(rhymes) { item in
                                VStack(spacing: 4) {
                                    Text(item.word)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(mainTextColor)
                                        .lineLimit(1)
                                    
                                    if let syllables = item.numSyllables {
                                        Text("\(syllables) syllable\(syllables == 1 ? "" : "s")")
                                            .font(.system(size: 9, design: .monospaced))
                                            // FIXED: Tints grid subheaders to follow your active Accent Theme smoothly
                                            .foregroundColor(settings.appAccent.color.opacity(0.9))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(cardBackground)
                                .cornerRadius(6)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        // FIXED: Implements full layout backplate background tracking from settings choices
        .background(workspaceBackground.ignoresSafeArea())
        .task {
            // Initial network payload evaluation on screen launch
            executeRhymeSearch()
        }
    }
    
    private func executeRhymeSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoading = true
        
        Task {
            let results = await DatamuseAPI.shared.fetchRhymes(for: searchText)
            await MainActor.run {
                self.rhymes = results
                self.isLoading = false
            }
        }
    }
}

#Preview {
    RhymesView()
        .environmentObject(FlowSettings())
}
