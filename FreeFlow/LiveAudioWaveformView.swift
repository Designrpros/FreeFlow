//
//  LiveAudioWaveformView.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 21/05/2026.
//

import SwiftUI
import Combine

struct LiveAudioWaveformView: View {
    @ObservedObject private var audioManager = AudioManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    private let barCount = 8
    private let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()
    
    private let idleAmplitudes: [CGFloat] = [15, 25, 18, 30, 22, 28, 16, 20]
    
    @State private var barAmplitudes: [CGFloat] = [15, 25, 18, 30, 22, 28, 16, 20]
    
    // Theme-driven dynamic content color mapping
    private var contentColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    // FIXED: Waveform dynamically shifts color matrix context to match navigation controls
    private var activeWaveformColor: Color {
        audioManager.isPlaying ? .blue : contentColor.opacity(0.6)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    // FIXED: Replaced static white fill with our matched reactive color token
                    .fill(activeWaveformColor)
                    .frame(width: 8, height: barAmplitudes[index])
                    .animation(.easeInOut(duration: 0.2), value: barAmplitudes[index])
            }
        }
        .frame(width: 120, height: 60)
        .onReceive(timer) { _ in
            updateWaveformAmplitudes()
        }
    }
    
    private func updateWaveformAmplitudes() {
        guard audioManager.isPlaying else {
            if barAmplitudes != idleAmplitudes {
                withAnimation(.easeOut(duration: 0.3)) {
                    barAmplitudes = idleAmplitudes
                }
            }
            return
        }
        
        var dynamicAmplitudes: [CGFloat] = []
        for _ in 0..<barCount {
            let randomHeight = CGFloat.random(in: 12...58)
            dynamicAmplitudes.append(randomHeight)
        }
        
        self.barAmplitudes = dynamicAmplitudes
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        LiveAudioWaveformView()
    }
}
