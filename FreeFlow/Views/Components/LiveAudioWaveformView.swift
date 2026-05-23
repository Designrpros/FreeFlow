//
//   LiveAudioWaveformView.swift
//   FreeFlow
//
//   Created by Vegar Berentsen on 21/05/2026.
//

import SwiftUI

struct LiveAudioWaveformView: View {
    // Passed explicitly from FlowView to establish a strict reactive dependency graph
    let isPlaying: Bool
    let isSeeking: Bool
    
    private let barCount = 8
    private let idleAmplitudes: [CGFloat] = [15, 25, 18, 30, 22, 28, 16, 20]
    
    @State private var barAmplitudes: [CGFloat] = [15, 25, 18, 30, 22, 28, 16, 20]
    @State private var animationTask: Task<Void, Never>? = nil
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(.foreground)
                    .frame(width: 8, height: barAmplitudes[index])
            }
        }
        .frame(width: 120, height: 60)
        .onAppear {
            startAnimationLoop()
        }
        .onDisappear {
            animationTask?.cancel()
        }
        .onChange(of: isPlaying) { _, _ in handleStateUpdate() }
        .onChange(of: isSeeking) { _, _ in handleStateUpdate() }
    }
    
    private func handleStateUpdate() {
        if isPlaying && !isSeeking {
            startAnimationLoop()
        } else {
            animationTask?.cancel()
            withAnimation(.easeInOut(duration: 0.2)) {
                barAmplitudes = idleAmplitudes
            }
        }
    }
    
    private func startAnimationLoop() {
        animationTask?.cancel()
        
        guard isPlaying && !isSeeking else {
            barAmplitudes = idleAmplitudes
            return
        }
        
        animationTask = Task { @MainActor in
            while !Task.isCancelled {
                guard isPlaying && !isSeeking else { break }
                
                // 🚀 SLOWED DOWN: Interpolation transition duration increased from 0.12 to 0.22
                withAnimation(.easeInOut(duration: 0.22)) {
                    var dynamicAmplitudes: [CGFloat] = []
                    for _ in 0..<barCount {
                        dynamicAmplitudes.append(CGFloat.random(in: 12...58))
                    }
                    self.barAmplitudes = dynamicAmplitudes
                }
                
                // 🚀 SLOWED DOWN: Loop sleep interval increased from 120ms to 250ms (Quarter of a second)
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        LiveAudioWaveformView(isPlaying: true, isSeeking: false)
            .foregroundColor(.orange)
    }
}
