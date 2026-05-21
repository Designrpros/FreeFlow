//
//  VerbVocabulary.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 20/05/2026.
//

import Foundation

struct VerbVocabulary {
    static let source: [WordMetadata] = [
        // --- ORIGINAL SET ---
        WordMetadata(text: "walking", type: .verb, rhymes: ["talking", "stalking", "rocking", "shocking", "blocking", "knocking", "mocking", "flocking"]),
        WordMetadata(text: "walked", type: .verb, rhymes: ["talked", "stalked", "rocked", "shocked", "blocked", "knocked", "mocked", "flocked"]),
        WordMetadata(text: "grind", type: .verb, rhymes: ["mind", "find", "kind", "blind", "behind", "wind", "remind", "aligned"]),
        WordMetadata(text: "beat", type: .verb, rhymes: ["heat", "street", "feet", "meet", "sweet", "treat", "cheat", "sheet", "repeat"]),
        WordMetadata(text: "move", type: .verb, rhymes: ["groove", "prove", "improve", "disprove", "approve", "smooth", "soothe"]),
        
        // --- PRESENT PARTICIPLE (-ING GERUNDS) ---
        WordMetadata(text: "flowing", type: .verb, rhymes: ["growing", "knowing", "showing", "blowing", "glowing", "throwing", "going", "slowing", "overflowing"]),
        WordMetadata(text: "growing", type: .verb, rhymes: ["flowing", "knowing", "showing", "blowing", "glowing", "throwing", "going", "slowing", "outgrowing"]),
        WordMetadata(text: "rhyming", type: .verb, rhymes: ["timing", "climbing", "priming", "chiming", "subliming", "aligning", "designing"]),
        WordMetadata(text: "shining", type: .verb, rhymes: ["lining", "pining", "dining", "signing", "designing", "aligning", "combining", "defining", "refining"]),
        WordMetadata(text: "running", type: .verb, rhymes: ["stunning", "cunning", "shunning", "gunning", "sunning"]),
        WordMetadata(text: "striking", type: .verb, rhymes: ["liking", "biking", "hiking", "spiking", "disliking"]),
        WordMetadata(text: "chasing", type: .verb, rhymes: ["pacing", "racing", "facing", "bracing", "tracing", "placing", "erasing", "replacing"]),
        WordMetadata(text: "blazing", type: .verb, rhymes: ["gazing", "grazing", "phasing", "amazing", "raising", "praising"]),
        WordMetadata(text: "shouting", type: .verb, rhymes: ["doubting", "scouting", "routing", "sprouting", "outing", "flouting"]),
        WordMetadata(text: "shaking", type: .verb, rhymes: ["making", "taking", "breaking", "waking", "baking", "faking", "mistaking", "awaking"]),
        WordMetadata(text: "breaking", type: .verb, rhymes: ["making", "taking", "shaking", "waking", "baking", "faking", "mistaking", "heartbreaking"]),
        WordMetadata(text: "ruling", type: .verb, rhymes: ["schooling", "fooling", "cooling", "pooling", "fueling"]),
        WordMetadata(text: "fearing", type: .verb, rhymes: ["hearing", "clearing", "steering", "nearing", "peering", "appearing", "disappearing", "engineering"]),
        WordMetadata(text: "burning", type: .verb, rhymes: ["learning", "turning", "earning", "yearning", "churning", "returning", "discerning"]),
        WordMetadata(text: "healing", type: .verb, rhymes: ["feeling", "dealing", "stealing", "sealing", "peeling", "revealing", "appealing"]),
        WordMetadata(text: "living", type: .verb, rhymes: ["giving", "forgiving", "driven", "misgiving"]),
        WordMetadata(text: "fading", type: .verb, rhymes: ["trading", "wading", "shading", "evading", "parading", "degrading", "persuading"]),
        
        // --- PAST TENSE (-ED / IRREGULAR TERMINATIONS) ---
        WordMetadata(text: "learned", type: .verb, rhymes: ["turned", "burned", "earned", "yearned", "churned", "returned", "discerned", "unconcerned"]),
        WordMetadata(text: "turned", type: .verb, rhymes: ["learned", "burned", "earned", "yearned", "churned", "returned", "overturned"]),
        WordMetadata(text: "found", type: .verb, rhymes: ["bound", "ground", "round", "sound", "around", "profound", "astound", "surround", "unbound"]),
        WordMetadata(text: "spoke", type: .verb, rhymes: ["broke", "smoke", "woke", "choke", "joke", "stroke", "cloak", "provoke", "evoke"]),
        WordMetadata(text: "made", type: .verb, rhymes: ["fade", "trade", "wade", "shade", "blade", "grade", "parade", "evade", "persuade", "afraid"]),
        WordMetadata(text: "saved", type: .verb, rhymes: ["brave", "wave", "cave", "grave", "slave", "crave", "behave", "engrave"]),
        WordMetadata(text: "lost", type: .verb, rhymes: ["cost", "frost", "crossed", "exhaust"]),
        WordMetadata(text: "caught", type: .verb, rhymes: ["bought", "brought", "thought", "taught", "fought", "sought", "distraught"]),
        WordMetadata(text: "brought", type: .verb, rhymes: ["caught", "bought", "thought", "taught", "fought", "sought", "overwrought"]),
        WordMetadata(text: "shined", type: .verb, rhymes: ["blind", "mind", "find", "kind", "grind", "behind", "remind", "aligned", "designed"]),
        WordMetadata(text: "placed", type: .verb, rhymes: ["chased", "paced", "raced", "faced", "braced", "traced", "erased", "disgraced"]),
        WordMetadata(text: "raised", type: .verb, rhymes: ["blazed", "gazed", "grazing", "phased", "dazed", "amazed", "praised"]),
        WordMetadata(text: "stood", type: .verb, rhymes: ["wood", "good", "hood", "understood", "neighborhood", "likelihood"]),
        WordMetadata(text: "came", type: .verb, rhymes: ["fame", "blame", "claim", "flame", "game", "name", "shame", "tame", "aim", "frame"]),
        
        // --- BASE / INFINITIVE ACTIONS ---
        WordMetadata(text: "climb", type: .verb, rhymes: ["time", "rhyme", "chime", "crime", "prime", "slime", "dime", "grime", "sublime"]),
        WordMetadata(text: "shine", type: .verb, rhymes: ["vine", "line", "nine", "pine", "fine", "wine", "sign", "design", "align", "combine"]),
        WordMetadata(text: "write", type: .verb, rhymes: ["bright", "light", "night", "flight", "sight", "might", "tight", "height", "white", "ignite"]),
        WordMetadata(text: "speak", type: .verb, rhymes: ["bleak", "seek", "weak", "peak", "leak", "meek", "unique", "antique", "mystique", "critique"]),
        WordMetadata(text: "seek", type: .verb, rhymes: ["bleak", "speak", "weak", "peak", "leak", "meek", "unique", "antique", "mystique", "critique"]),
        WordMetadata(text: "make", type: .verb, rhymes: ["fake", "take", "break", "wake", "shake", "quake", "snake", "mistake", "awake", "forsake"]),
        WordMetadata(text: "take", type: .verb, rhymes: ["fake", "make", "break", "wake", "shake", "quake", "snake", "mistake", "awake", "overtake"]),
        WordMetadata(text: "prove", type: .verb, rhymes: ["move", "groove", "improve", "disprove", "approve", "smooth", "soothe"]),
        WordMetadata(text: "save", type: .verb, rhymes: ["brave", "wave", "cave", "grave", "slave", "crave", "behave", "engrave"]),
        WordMetadata(text: "fight", type: .verb, rhymes: ["bright", "light", "night", "flight", "sight", "might", "tight", "height", "white", "ignite"]),
        WordMetadata(text: "hide", type: .verb, rhymes: ["side", "ride", "tide", "wide", "glide", "guide", "stride", "divide", "provide", "inside"]),
        WordMetadata(text: "ride", type: .verb, rhymes: ["side", "hide", "tide", "wide", "glide", "guide", "stride", "divide", "provide", "outside"]),
        WordMetadata(text: "show", type: .verb, rhymes: ["flow", "glow", "grow", "know", "blow", "row", "throw", "pro", "tempo"]),
        WordMetadata(text: "know", type: .verb, rhymes: ["flow", "glow", "show", "grow", "blow", "row", "throw", "pro", "although"]),
        WordMetadata(text: "grow", type: .verb, rhymes: ["flow", "glow", "show", "know", "blow", "row", "throw", "pro", "outgrow"]),
        WordMetadata(text: "throw", type: .verb, rhymes: ["flow", "glow", "show", "grow", "know", "blow", "row", "pro", "overthrow"]),
        WordMetadata(text: "change", type: .verb, rhymes: ["strange", "range", "arrange", "exchange", "derange", "estrange"]),
        WordMetadata(text: "stand", type: .verb, rhymes: ["band", "land", "hand", "grand", "brand", "demand", "expand", "command", "understand"]),
        WordMetadata(text: "start", type: .verb, rhymes: ["art", "heart", "part", "smart", "chart", "apart", "depart", "restart"]),
        WordMetadata(text: "create", type: .verb, rhymes: ["late", "date", "fate", "gate", "hate", "rate", "state", "weight", "debate", "relate"]),
        WordMetadata(text: "debate", type: .verb, rhymes: ["late", "date", "fate", "gate", "hate", "rate", "state", "weight", "create", "relate"]),
        WordMetadata(text: "escape", type: .verb, rhymes: ["cape", "tape", "shape", "drape", "scrape", "landscape"])
    ]
}
