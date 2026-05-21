//
//  NounVocabulary.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 20/05/2026.
//

import Foundation

struct NounVocabulary {
    static let source: [WordMetadata] = [
        // --- ORIGINAL SET ---
        WordMetadata(text: "fame", type: .noun, rhymes: ["blame", "claim", "flame", "game", "name", "shame", "tame", "aim", "frame", "reclaim"]),
        WordMetadata(text: "vine", type: .noun, rhymes: ["line", "nine", "shine", "pine", "fine", "wine", "sign", "design", "align", "combine"]),
        WordMetadata(text: "time", type: .noun, rhymes: ["rhyme", "chime", "climb", "crime", "prime", "slime", "dime", "grime", "sublime"]),
        WordMetadata(text: "mic", type: .noun, rhymes: ["like", "bike", "hike", "spike", "strike", "psych", "dislike", "alike"]),
        WordMetadata(text: "stage", type: .noun, rhymes: ["page", "rage", "cage", "sage", "wage", "gauge", "engage", "outrage"]),
        WordMetadata(text: "voice", type: .noun, rhymes: ["choice", "rejoice", "poise", "noise", "boys", "toys", "employs"]),
        WordMetadata(text: "dream", type: .noun, rhymes: ["scheme", "team", "stream", "gleam", "cream", "scream", "beam", "theme"]),
        WordMetadata(text: "spark", type: .noun, rhymes: ["dark", "bark", "mark", "park", "lark", "shark", "embark", "remark"]),
        
        // --- EXPANDED SET (STREET, CONCEPTUAL, & IMAGERY NOUNS) ---
        WordMetadata(text: "mind", type: .noun, rhymes: ["find", "kind", "blind", "grind", "behind", "remind", "aligned", "combined", "refined"]),
        WordMetadata(text: "game", type: .noun, rhymes: ["fame", "blame", "claim", "flame", "name", "shame", "tame", "aim", "frame", "proclaim"]),
        WordMetadata(text: "night", type: .noun, rhymes: ["bright", "light", "flight", "sight", "might", "tight", "height", "fright", "white", "tonight"]),
        WordMetadata(text: "street", type: .noun, rhymes: ["beat", "heat", "feet", "meet", "sweet", "treat", "cheat", "sheet", "repeat", "defeat"]),
        WordMetadata(text: "heart", type: .noun, rhymes: ["art", "part", "start", "smart", "chart", "apart", "depart", "restart", "counterpart"]),
        WordMetadata(text: "line", type: .noun, rhymes: ["vine", "nine", "shine", "pine", "fine", "wine", "sign", "design", "align", "combine"]),
        WordMetadata(text: "flame", type: .noun, rhymes: ["fame", "blame", "claim", "game", "name", "shame", "tame", "aim", "frame", "inflame"]),
        WordMetadata(text: "crown", type: .noun, rhymes: ["town", "down", "brown", "frown", "clown", "gown", "drown", "renown"]),
        WordMetadata(text: "town", type: .noun, rhymes: ["crown", "down", "brown", "frown", "clown", "gown", "drown", "renown"]),
        WordMetadata(text: "throne", type: .noun, rhymes: ["bone", "stone", "zone", "clone", "alone", "grown", "thrown", "unknown", "postpone"]),
        WordMetadata(text: "stone", type: .noun, rhymes: ["bone", "throne", "zone", "clone", "alone", "grown", "thrown", "unknown", "postpone"]),
        WordMetadata(text: "zone", type: .noun, rhymes: ["bone", "stone", "throne", "clone", "alone", "grown", "thrown", "unknown", "postpone"]),
        WordMetadata(text: "chain", type: .noun, rhymes: ["rain", "pain", "grain", "brain", "main", "crane", "drain", "plain", "explain", "remain"]),
        WordMetadata(text: "brain", type: .noun, rhymes: ["chain", "rain", "pain", "grain", "main", "crane", "drain", "plain", "explain", "remain"]),
        WordMetadata(text: "pain", type: .noun, rhymes: ["chain", "rain", "grain", "brain", "main", "crane", "drain", "plain", "explain", "remain"]),
        WordMetadata(text: "truth", type: .noun, rhymes: ["youth", "booth", "soothe", "smooth", "uncouth"]),
        WordMetadata(text: "youth", type: .noun, rhymes: ["truth", "booth", "soothe", "smooth", "uncouth"]),
        WordMetadata(text: "sound", type: .noun, rhymes: ["bound", "found", "ground", "round", "around", "profound", "astound", "surround"]),
        WordMetadata(text: "ground", type: .noun, rhymes: ["sound", "bound", "found", "round", "around", "profound", "astound", "surround"]),
        WordMetadata(text: "sky", type: .noun, rhymes: ["fly", "high", "why", "try", "cry", "dry", "sly", "rely", "defy", "apply"]),
        WordMetadata(text: "light", type: .noun, rhymes: ["bright", "night", "flight", "sight", "might", "tight", "height", "fright", "white", "tonight"]),
        WordMetadata(text: "sight", type: .noun, rhymes: ["bright", "light", "night", "flight", "might", "tight", "height", "fright", "white", "insight"]),
        WordMetadata(text: "rhythm", type: .noun, rhymes: ["algorithm", "logarithm", "prism", "schism", "vandalism"]),
        WordMetadata(text: "crime", type: .noun, rhymes: ["time", "rhyme", "chime", "climb", "prime", "slime", "dime", "grime", "sublime"]),
        WordMetadata(text: "rhyme", type: .noun, rhymes: ["time", "chime", "climb", "crime", "prime", "slime", "dime", "grime", "sublime"]),
        WordMetadata(text: "block", type: .noun, rhymes: ["rock", "shock", "lock", "clock", "stock", "flock", "knock", "mock", "unlock"]),
        WordMetadata(text: "rock", type: .noun, rhymes: ["block", "shock", "lock", "clock", "stock", "flock", "knock", "mock", "bedrock"]),
        WordMetadata(text: "shadow", type: .noun, rhymes: ["meadow", "shallow", "mellow", "yellow", "window"]),
        WordMetadata(text: "window", type: .noun, rhymes: ["shadow", "meadow", "shallow", "mellow", "yellow", "indigo"]),
        WordMetadata(text: "tempo", type: .noun, rhymes: ["pro", "flow", "glow", "show", "grow", "know", "blow", "row", "portfolio"]),
        WordMetadata(text: "scheme", type: .noun, rhymes: ["dream", "team", "stream", "gleam", "cream", "scream", "beam", "theme", "supreme"]),
        WordMetadata(text: "team", type: .noun, rhymes: ["dream", "scheme", "stream", "gleam", "cream", "scream", "beam", "theme", "esteem"]),
        WordMetadata(text: "theme", type: .noun, rhymes: ["dream", "scheme", "team", "stream", "gleam", "cream", "scream", "beam", "supreme"]),
        WordMetadata(text: "gold", type: .noun, rhymes: ["cold", "bold", "old", "told", "hold", "sold", "fold", "unfold", "behold"]),
        WordMetadata(text: "world", type: .noun, rhymes: ["twirled", "curled", "hurled", "unfurled", "pearled"]),
        WordMetadata(text: "force", type: .noun, rhymes: ["source", "course", "horse", "divorce", "remorse", "enforce", "coarse"]),
        WordMetadata(text: "source", type: .noun, rhymes: ["force", "course", "horse", "divorce", "remorse", "enforce", "resource"]),
        WordMetadata(text: "ghost", type: .noun, rhymes: ["host", "most", "post", "coast", "boast", "toast", "almost"]),
        WordMetadata(text: "coast", type: .noun, rhymes: ["ghost", "host", "most", "post", "boast", "toast", "engrossed"]),
        WordMetadata(text: "storm", type: .noun, rhymes: ["warm", "form", "norm", "swarm", "perform", "reform", "transform", "conform"]),
        WordMetadata(text: "form", type: .noun, rhymes: ["storm", "warm", "norm", "swarm", "perform", "reform", "transform", "platform"])
    ]
}
