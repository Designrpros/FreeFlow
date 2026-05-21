//
//  AdverbVocabulary.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 20/05/2026.
//

import Foundation

struct AdverbVocabulary {
    static let source: [WordMetadata] = [
        // --- ORIGINAL SET ---
        WordMetadata(text: "behind", type: .adverb, rhymes: ["mind", "find", "kind", "blind", "grind", "remind", "aligned"]),
        WordMetadata(text: "anytime", type: .adverb, rhymes: ["time", "rhyme", "chime", "climb", "crime", "prime", "slime", "dime"]),
        WordMetadata(text: "alike", type: .adverb, rhymes: ["mic", "like", "bike", "hike", "spike", "strike", "psych", "dislike"]),
        
        // --- EXPANDED SET (TEMPORAL & DIRECTIONAL CADENCES) ---
        WordMetadata(text: "tonight", type: .adverb, rhymes: ["bright", "light", "night", "flight", "sight", "might", "tight", "height", "white", "ignite"]),
        WordMetadata(text: "away", type: .adverb, rhymes: ["day", "way", "say", "play", "gray", "stay", "stray", "display", "decay", "delay"]),
        WordMetadata(text: "alone", type: .adverb, rhymes: ["bone", "stone", "zone", "clone", "grown", "thrown", "unknown", "postpone", "throne"]),
        WordMetadata(text: "instead", type: .adverb, rhymes: ["bed", "red", "head", "dead", "led", "fed", "spread", "misled", "thread", "widespread"]),
        WordMetadata(text: "abroad", type: .adverb, rhymes: ["lord", "board", "cord", "sword", "award", "applaud", "fraud", "ignored", "record"]),
        WordMetadata(text: "aground", type: .adverb, rhymes: ["sound", "bound", "found", "ground", "round", "around", "profound", "astound", "surround"]),
        WordMetadata(text: "around", type: .adverb, rhymes: ["sound", "bound", "found", "ground", "round", "aground", "profound", "astound", "surround"]),
        WordMetadata(text: "aloud", type: .adverb, rhymes: ["proud", "loud", "crowd", "cloud", "shroud", "allowed", "bowed"]),
        WordMetadata(text: "afresh", type: .adverb, rhymes: ["flesh", "mesh", "refresh", "refreshing"]),
        WordMetadata(text: "inside", type: .adverb, rhymes: ["side", "ride", "tide", "wide", "hide", "glide", "guide", "stride", "divide", "provide", "outside"]),
        WordMetadata(text: "outside", type: .adverb, rhymes: ["side", "ride", "tide", "wide", "hide", "glide", "guide", "stride", "divide", "provide", "inside"]),
        WordMetadata(text: "nowhere", type: .adverb, rhymes: ["bare", "care", "dare", "fare", "hare", "share", "stare", "ware", "aware", "somewhere", "anywhere"]),
        WordMetadata(text: "somewhere", type: .adverb, rhymes: ["bare", "care", "dare", "fare", "hare", "share", "stare", "ware", "aware", "nowhere", "anywhere"]),
        WordMetadata(text: "anywhere", type: .adverb, rhymes: ["bare", "care", "dare", "fare", "hare", "share", "stare", "ware", "aware", "nowhere", "somewhere"]),
        WordMetadata(text: "fast", type: .adverb, rhymes: ["vast", "past", "last", "cast", "blast", "contrast", "forecast", "outcast"]),
        WordMetadata(text: "late", type: .adverb, rhymes: ["date", "fate", "gate", "hate", "rate", "state", "weight", "create", "debate", "relate", "elate"]),
        WordMetadata(text: "hard", type: .adverb, rhymes: ["card", "guard", "yard", "board", "regard", "discard", "bombard", "avatar"]),
        WordMetadata(text: "deep", type: .adverb, rhymes: ["keep", "sleep", "leap", "cheap", "weep", "steep", "creep", "sheep", "heap", "asleep"]),
        WordMetadata(text: "back", type: .adverb, rhymes: ["pack", "track", "black", "jack", "smack", "stack", "attack", "unpack", "abstract", "impact"]),
        WordMetadata(text: "forth", type: .adverb, rhymes: ["north", "worth", "birth", "earth"]),
        WordMetadata(text: "out", type: .adverb, rhymes: ["shout", "doubt", "about", "scout", "route", "sprout", "without", "throughout"]),
        WordMetadata(text: "without", type: .adverb, rhymes: ["shout", "doubt", "about", "scout", "route", "sprout", "out", "throughout"]),
        WordMetadata(text: "throughout", type: .adverb, rhymes: ["shout", "doubt", "about", "scout", "route", "sprout", "out", "without"]),
        WordMetadata(text: "soon", type: .adverb, rhymes: ["moon", "tune", "noon", "spoon", "cartoon", "monsoon", "immune", "commune"]),
        WordMetadata(text: "now", type: .adverb, rhymes: ["how", "cow", "vow", "bow", "allow", "avow", "somehow"]),
        WordMetadata(text: "somehow", type: .adverb, rhymes: ["how", "cow", "vow", "bow", "allow", "avow", "now"]),
        WordMetadata(text: "forever", type: .adverb, rhymes: ["clever", "never", "ever", "sever", "however", "endeavor"]),
        WordMetadata(text: "however", type: .adverb, rhymes: ["clever", "never", "ever", "sever", "forever", "endeavor"]),
        WordMetadata(text: "never", type: .adverb, rhymes: ["clever", "forever", "ever", "sever", "however", "endeavor"]),
        WordMetadata(text: "apart", type: .adverb, rhymes: ["art", "heart", "part", "start", "smart", "chart", "depart", "restart"]),
        WordMetadata(text: "straight", type: .adverb, rhymes: ["late", "date", "fate", "gate", "hate", "rate", "state", "weight", "create", "debate"]),
        WordMetadata(text: "overhead", type: .adverb, rhymes: ["bed", "red", "head", "dead", "led", "fed", "spread", "misled", "instead"]),
        WordMetadata(text: "upstream", type: .adverb, rhymes: ["dream", "scheme", "team", "stream", "gleam", "cream", "scream", "beam", "theme", "supreme"]),
        WordMetadata(text: "downstream", type: .adverb, rhymes: ["dream", "scheme", "team", "stream", "gleam", "cream", "scream", "beam", "theme", "supreme"])
    ]
}
