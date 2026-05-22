//
//  FreeFlowWidgets.swift
//  FreeFlowWidgetsExtension
//
//  Created by Vegar Berentsen on 22/05/2026.
//

import WidgetKit
import SwiftUI

// --- 1. DATA LAYOUT MODELS ---
struct WordTimelineEntry: TimelineEntry {
    let date: Date
    let data: WidgetWordData
}

// --- 2. TIMELINE PROVIDER ---
struct WordFlowProvider: TimelineProvider {
    func placeholder(in context: Context) -> WordTimelineEntry {
        WordTimelineEntry(date: Date(), data: WidgetDataManager.shared.readWordFromSharedContainer())
    }

    func getSnapshot(in context: Context, completion: @escaping (WordTimelineEntry) -> Void) {
        let entry = WordTimelineEntry(date: Date(), data: WidgetDataManager.shared.readWordFromSharedContainer())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordTimelineEntry>) -> Void) {
        let currentDate = Date()
        
        // Refresh calculation frame scheduled for 1 hour out to keep resource cycles lightweight
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate) ?? currentDate
        
        // Fetch current live session state tracking values natively via shared memory suite bridges
        let liveData = WidgetDataManager.shared.readWordFromSharedContainer()
        let entry = WordTimelineEntry(date: currentDate, data: liveData)
        
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// --- 3. DISPLAY LAYOUT VIEWS ---
struct FreeFlowWidgetEntryView : View {
    var entry: WordFlowProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if family == .systemSmall {
                // --- 📱 OPTIMIZED SMALL WIDGET LAYOUT ---
                HStack {
                    Text(entry.data.category.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                }
                .padding([.top, .horizontal])
                
                Spacer(minLength: 4)
                
                Text(entry.data.word)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                
                Spacer(minLength: 8) // Pushes the rhyme schemes down to anchor them at the bottom
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("RHYMES")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.8))
                        .tracking(0.5)
                    
                    // FIXED: Setting lineLimit(nil) gives the comma-separated strings
                    // full permission to break and wrap across multiple vertical text lines safely
                    Text(entry.data.rhymes.prefix(4).joined(separator: ", "))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.85))
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding([.bottom, .horizontal])
                .frame(maxWidth: .infinity, alignment: .leading)
                
            } else {
                // --- 💻 STANDARD MEDIUM WIDGET LAYOUT ---
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.orange)
                    Text("TODAY'S ANCHOR")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(entry.data.category.uppercased())
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(.orange.opacity(0.8))
                }
                .padding([.top, .horizontal])
                
                Spacer(minLength: 4)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.data.word)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(entry.data.definition)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
                .padding(.horizontal)
                
                Spacer(minLength: 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("RHYME SCHEMES")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.7))
                        .tracking(0.5)
                    
                    HStack(spacing: 6) {
                        ForEach(entry.data.rhymes.prefix(4), id: \.self) { rhyme in
                            Text(rhyme)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding([.bottom, .horizontal])
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.02))
            }
        }
        .containerBackground(for: .widget) {
            #if os(macOS)
            Color(NSColor.windowBackgroundColor)
            #else
            Color(UIColor.systemBackground)
            #endif
        }
    }
}

// --- 4. ENGINE LAUNCH INTERFACE BLOCK ---
// REMOVED: @main has been removed from this file scope level
struct FreeFlowWidgets: Widget {
    let kind: String = "FreeFlowWidgets"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WordFlowProvider()) { entry in
            FreeFlowWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today's Word Flow")
        .description("Streams current anchor words and rhyme matrix schemes straight down to your device dashboards.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
