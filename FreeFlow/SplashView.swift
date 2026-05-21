//
//  SplashView.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 20/05/2026.
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.gray.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    // Ambient word cloud placeholder
                    ForEach(0..<30, id: \.self) { idx in
                        Text(sampleWords[idx % sampleWords.count])
                            .font(.system(size: CGFloat.random(in: 14...28), weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.08))
                            .rotationEffect(.degrees(Double.random(in: -8...8)))
                            .offset(x: CGFloat.random(in: -180...180), y: CGFloat.random(in: -120...120))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text("Free Flow")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(radius: 10)
                    .padding(.bottom, 80)
            }
            .padding()
        }
    }
}

private let sampleWords: [String] = [
    "appeal", "jealous", "marvel", "prolong", "systemize", "slippery", "dice",
    "faithful", "pretty", "neutralize", "interrupt", "nude", "busy", "hijack",
    "over-rap", "eminent", "involved", "annihilated"
]

#Preview {
    SplashView()
}
