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
    
    private let barCount = 8
    private let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()
    
    private let idleAmplitudes: [CGFloat] = [15, 25, 18, 30, 22, 28, 16, 20]
    
    @State private var barAmplitudes: [CGFloat] = [15, 25, 18, 30, 22, 28, 16, 20]
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    // FIXED: Using .foregroundStyle(.foreground) lets this view natively adapt
                    // to the exact .foregroundColor color values supplied by the parent parent stack layout!
                    .fill(.foreground)
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
            .foregroundColor(.orange) // Preview check to confirm accent injection flows natively
    }
}
