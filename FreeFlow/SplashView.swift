//
//  SplashView.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 20/05/2026.
//

import SwiftUI

struct SplashWordPlacement: Identifiable {
    let id = UUID()
    let text: String
    let size: CGFloat
    let opacity: Double
    let rotation: Double
    let offsetX: CGFloat
    let offsetY: CGFloat
}

struct SplashView: View {
    @EnvironmentObject private var settings: FlowSettings
    @Environment(\.colorScheme) private var systemColorScheme
    
    @State private var animateLogo = false
    @State private var animateBackgroundWords = false
    @State private var placedWords: [SplashWordPlacement] = []
    
    private var isDarkMode: Bool {
        if settings.appTheme == .system {
            return systemColorScheme == .dark
        }
        return settings.appTheme == .dark
    }
    
    private var backgroundColor: Color {
        isDarkMode ? Color(white: 0.08) : Color(white: 0.96)
    }
    
    private var logoColor: Color {
        isDarkMode ? .white : Color(white: 0.1)
    }
    
    private var wordCloudColor: Color {
        isDarkMode ? Color(white: 0.45) : Color(white: 0.4)
    }

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            // REBALANCED BACKGROUND WORD CLOUD MATRIX
            ZStack {
                ForEach(placedWords) { word in
                    Text(word.text)
                        .font(.system(size: word.size, weight: .bold, design: .rounded))
                        .foregroundStyle(wordCloudColor.opacity(word.opacity))
                        .rotationEffect(.degrees(word.rotation))
                        .offset(x: word.offsetX, y: word.offsetY)
                        .scaleEffect(animateBackgroundWords ? 1.01 : 0.99)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 7.0).repeatForever(autoreverses: true), value: animateBackgroundWords)

            // CENTERED LOGO
            VStack {
                Text("FreeFlow")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(logoColor)
                    .shadow(color: isDarkMode ? .black.opacity(0.3) : .black.opacity(0.05), radius: 10, x: 0, y: 6)
                    .offset(y: animateLogo ? 0 : 12)
                    .opacity(animateLogo ? 1.0 : 0.0)
                    .scaleEffect(animateLogo ? 1.0 : 0.97)
            }
        }
        .onAppear {
            generateDenseWordCloud()
            
            withAnimation(.easeOut(duration: 1.2)) {
                animateLogo = true
            }
            withAnimation(.easeInOut(duration: 7.0)) {
                animateBackgroundWords = true
            }
        }
    }
    
    private func generateDenseWordCloud() {
        guard placedWords.isEmpty else { return }
        var generatedSet: [SplashWordPlacement] = []
        
        for idx in 0..<95 {
            let targetWord = expandedSampleWords[idx % expandedSampleWords.count]
            
            let item = SplashWordPlacement(
                text: targetWord,
                size: CGFloat.random(in: 13...24),
                // FIXED: Increased baseline opacity variables to bring out word crispness safely
                opacity: isDarkMode ? Double.random(in: 0.06...0.12) : Double.random(in: 0.07...0.14),
                rotation: Double.random(in: -18...18),
                offsetX: CGFloat.random(in: -450...450),
                offsetY: CGFloat.random(in: -380...380)
            )
            generatedSet.append(item)
        }
        self.placedWords = generatedSet
    }
}

private let expandedSampleWords: [String] = [
    "appeal", "marvel", "prolong", "systemize", "slippery", "tempo",
    "faithful", "cadence", "neutralize", "interrupt", "session", "bars",
    "rhythm", "over-rap", "eminent", "involved", "lyrics", "spit",
    "flow", "rhyme", "vibe", "studio", "beat", "mic", "freestyle", "loop",
    "syllable", "anchor", "focus", "verse", "record", "playback", "bounce",
    "write", "sheet", "note", "cloud", "rhymes", "tracks", "crossfade", "audio"
]
