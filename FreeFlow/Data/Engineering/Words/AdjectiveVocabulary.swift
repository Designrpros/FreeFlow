//
//  AdjectiveVocabulary.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 20/05/2026.
//

import Foundation

struct AdjectiveVocabulary {
    static let source: [WordMetadata] = [
        // --- ORIGINAL SET ---
        WordMetadata(text: "blind", type: .adjective, rhymes: ["mind", "find", "kind", "grind", "behind", "remind", "aligned"]),
        WordMetadata(text: "prime", type: .adjective, rhymes: ["time", "rhyme", "chime", "climb", "crime", "slime", "dime", "grime"]),
        WordMetadata(text: "dark", type: .adjective, rhymes: ["spark", "bark", "mark", "park", "lark", "shark", "embark", "remark"]),
        WordMetadata(text: "elite", type: .adjective, rhymes: ["beat", "heat", "street", "feet", "meet", "sweet", "treat", "cheat"]),
        
        // --- EXPANDED SET (A-Z CADENCES) ---
        WordMetadata(text: "bright", type: .adjective, rhymes: ["light", "night", "flight", "sight", "might", "tight", "height", "fright", "white", "write", "delight", "ignite"]),
        WordMetadata(text: "cold", type: .adjective, rhymes: ["bold", "gold", "old", "told", "hold", "sold", "fold", "unfold", "behold", "controlled"]),
        WordMetadata(text: "deep", type: .adjective, rhymes: ["keep", "sleep", "leap", "cheap", "weep", "steep", "creep", "sheep", "heap", "asleep"]),
        WordMetadata(text: "dope", type: .adjective, rhymes: ["hope", "rope", "scope", "slope", "cope", "soap", "microscope", "telescope"]),
        WordMetadata(text: "raw", type: .adjective, rhymes: ["law", "saw", "draw", "claw", "jaw", "flaw", "straw", "outlaw"]),
        WordMetadata(text: "pure", type: .adjective, rhymes: ["cure", "sure", "endure", "secure", "obscure", "mature", "allure", "tour", "poor"]),
        WordMetadata(text: "wild", type: .adjective, rhymes: ["child", "mild", "styled", "compiled", "filed", "piled", "beguiled"]),
        WordMetadata(text: "broke", type: .adjective, rhymes: ["smoke", "woke", "spoke", "choke", "joke", "stroke", "cloak", "provoke", "evoke"]),
        WordMetadata(text: "slick", type: .adjective, rhymes: ["quick", "thick", "kick", "trick", "stick", "click", "brick", "pick", "politic"]),
        WordMetadata(text: "stray", type: .adjective, rhymes: ["day", "way", "say", "play", "gray", "stay", "display", "decay", "array", "delay", "betray"]),
        WordMetadata(text: "grim", type: .adjective, rhymes: ["brim", "slim", "trim", "dim", "hymn", "swim", "interim", "victim"]),
        WordMetadata(text: "grand", type: .adjective, rhymes: ["band", "land", "hand", "stand", "brand", "demand", "expand", "command", "understand"]),
        WordMetadata(text: "sweet", type: .adjective, rhymes: ["beat", "heat", "street", "feet", "meet", "sheet", "repeat", "defeat", "complete"]),
        WordMetadata(text: "fake", type: .adjective, rhymes: ["make", "take", "break", "wake", "shake", "quake", "snake", "mistake", "awake", "forsake"]),
        WordMetadata(text: "brave", type: .adjective, rhymes: ["save", "wave", "cave", "grave", "slave", "crave", "behave", "engrave"]),
        WordMetadata(text: "vague", type: .adjective, rhymes: ["plague", "brogue", "rogue", "colleague"]),
        WordMetadata(text: "ill", type: .adjective, rhymes: ["will", "skill", "chill", "thrill", "kill", "still", "bill", "hill", "instill", "fulfill"]),
        WordMetadata(text: "savage", type: .adjective, rhymes: ["ravage", "baggage", "damage", "manage", "average"]),
        WordMetadata(text: "classic", type: .adjective, rhymes: ["jurasic", "drastic", "plastic", "elastic", "fantastic", "sarcastic", "enthusiastic"]),
        WordMetadata(text: "doomed", type: .adjective, rhymes: ["bloomed", "groomed", "consumed", "assumed", "presumed", "entombed"]),
        WordMetadata(text: "sharp", type: .adjective, rhymes: ["harp", "tarp", "scarp", "counterscarp"]),
        WordMetadata(text: "smooth", type: .adjective, rhymes: ["groove", "soothe", "booth", "youth", "truth"]),
        WordMetadata(text: "fierce", type: .adjective, rhymes: ["pierce", "tierce", "traverse", "reverse", "diverse", "universe"]),
        WordMetadata(text: "vivid", type: .adjective, rhymes: ["livid", "rigid", "frigid", "pivotid", "liquid"]),
        WordMetadata(text: "bold", type: .adjective, rhymes: ["cold", "gold", "old", "told", "hold", "sold", "fold", "unfold", "behold"]),
        WordMetadata(text: "hollow", type: .adjective, rhymes: ["swallow", "follow", "wallow", "shallow", "mellow", "yellow"]),
        WordMetadata(text: "strange", type: .adjective, rhymes: ["change", "range", "arrange", "exchange", "derange", "estrange"]),
        WordMetadata(text: "tight", type: .adjective, rhymes: ["bright", "light", "night", "flight", "sight", "might", "height", "fright", "white"]),
        WordMetadata(text: "tame", type: .adjective, rhymes: ["fame", "blame", "claim", "flame", "game", "name", "shame", "aim", "frame"]),
        WordMetadata(text: "heavy", type: .adjective, rhymes: ["levy", "bevy", "ready", "steady", "eddy"]),
        WordMetadata(text: "steady", type: .adjective, rhymes: ["ready", "heavy", "already", "unsteady", "eddy"]),
        WordMetadata(text: "swift", type: .adjective, rhymes: ["gift", "lift", "shift", "drift", "rift", "thrift", "uplift"]),
        WordMetadata(text: "dense", type: .adjective, rhymes: ["sense", "tense", "defense", "intense", "immense", "expense", "suspense"]),
        WordMetadata(text: "tense", type: .adjective, rhymes: ["dense", "sense", "defense", "intense", "immense", "expense", "suspense"]),
        WordMetadata(text: "grave", type: .adjective, rhymes: ["brave", "save", "wave", "cave", "slave", "crave", "behave", "engrave"]),
        WordMetadata(text: "vast", type: .adjective, rhymes: ["past", "last", "fast", "cast", "blast", "contrast", "forecast", "outcast"]),
        WordMetadata(text: "fast", type: .adjective, rhymes: ["vast", "past", "last", "cast", "blast", "contrast", "forecast", "outcast"]),
        WordMetadata(text: "crude", type: .adjective, rhymes: ["rude", "nude", "mood", "food", "conclude", "exclude", "include", "delude", "elude", "attitude"]),
        WordMetadata(text: "rude", type: .adjective, rhymes: ["crude", "nude", "mood", "food", "conclude", "exclude", "include", "delude", "elude"]),
        WordMetadata(text: "proud", type: .adjective, rhymes: ["loud", "crowd", "cloud", "shroud", "allowed", "bowed"]),
        WordMetadata(text: "loud", type: .adjective, rhymes: ["proud", "crowd", "cloud", "shroud", "allowed", "bowed"]),
        WordMetadata(text: "stiff", type: .adjective, rhymes: ["cliff", "iff", "sniff", "whiff", "tariff", "sheriff"]),
        WordMetadata(text: "bleak", type: .adjective, rhymes: ["speak", "seek", "weak", "peak", "leak", "meek", "unique", "antique", "mystique", "critique"]),
        WordMetadata(text: "weak", type: .adjective, rhymes: ["bleak", "speak", "seek", "peak", "leak", "meek", "unique", "antique", "mystique", "critique"]),
        WordMetadata(text: "meek", type: .adjective, rhymes: ["bleak", "weak", "speak", "seek", "peak", "leak", "unique", "antique", "mystique"]),
        WordMetadata(text: "sly", type: .adjective, rhymes: ["sky", "fly", "high", "why", "try", "cry", "dry", "rely", "defy", "comply", "apply"]),
        WordMetadata(text: "dry", type: .adjective, rhymes: ["sly", "sky", "fly", "high", "why", "try", "cry", "rely", "defy", "comply", "apply"]),
        WordMetadata(text: "clever", type: .adjective, rhymes: ["never", "ever", "sever", "forever", "however", "endeavor"]),
        WordMetadata(text: "bitter", type: .adjective, rhymes: ["glitter", "litter", "critter", "twitter", "bitter", "emitter", "transmitter"]),
        WordMetadata(text: "harsher", type: .adjective, rhymes: ["archer", "marcher", "departure"]),
        WordMetadata(text: "rare", type: .adjective, rhymes: ["bare", "care", "dare", "fare", "hare", "share", "stare", "ware", "aware", "prepare", "declare", "compare"]),
        WordMetadata(text: "bare", type: .adjective, rhymes: ["rare", "care", "dare", "fare", "hare", "share", "stare", "ware", "aware", "prepare", "declare", "compare"]),
        WordMetadata(text: "crisp", type: .adjective, rhymes: ["wisp", "lisp"]),
        WordMetadata(text: "vile", type: .adjective, rhymes: ["style", "while", "file", "mile", "pile", "smile", "trial", "profile", "compile", "worthwhile"]),
        WordMetadata(text: "coarse", type: .adjective, rhymes: ["force", "source", "course", "horse", "divorce", "remorse", "enforce"])
    ]
}
