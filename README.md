# FreeFlow 🌊

FreeFlow is a high-performance, cross-platform assistant for lyricists, freestyle artists, and writers built natively for **macOS** and **iOS** using **SwiftUI**, **Combine**, and **Core Data + CloudKit**. 

The app generates adaptive keyword stacks and rhyming streams in real-time, matching words to a built-in crossfading loop studio playback container. It features a responsive multi-column workspace layout that functions seamlessly on an iPhone or a desktop Mac display.

---

## 🚀 Key Features

### 1. Dynamic Lyrics Display Canvas
- **Adaptive Stacks:** Scales typography layouts (`1...6` rows) instantly based on view configuration settings to guarantee clip-free reading.
- **Phonetic Anchor Engine:** Focuses on single anchor words or splits down into multi-tier sub-rhyme flows dynamically.

### 2. Studio Media Center
- **Hybrid Storage Architecture:** Stores physical binary audio elements locally in the device's sandbox document folder while syncing registry metadata records globally across iCloud via Core Data tracking.
- **Loop Matrix Management:** Seamlessly crossfades overlapping track endings over an adjustable timeline, supporting custom audio library imports (`.mp3`).
- **State Persistence:** Repurposes light configuration lifecycle parameters inside local device memory stores using an automated Combine subscription pipeline (`UserDefaults`).

### 3. Asynchronous Semantic Pipelines
- **Datamuse Network Integration:** Queries remote lexical servers asynchronously via modern `async/await` tasks to extract syllable metadata, perfect rhymes, and thematic trigger associations.
- **Resilient Fallback Design:** Drops back automatically to an offline compiled database configuration if the internet connection drops or if server response vectors fall below requested layout count limits.

### 4. iCloud Multi-Column Notepad
- **Modern Split Routing:** Implements native `NavigationSplitView` setups. Expands gracefully into sidebar-driven workspaces on macOS and adapts down to standard stacked swipe navigation views on iPhones.
- **Real-Time Data Streams:** Binds text editors to the background context layer using `@FetchRequest`, providing automatic cloud updates and background merging across devices.

---

## 🛠 Tech Stack

- **UI Framework:** SwiftUI (Adaptive Layout Architecture)
- **Asynchronous Lifecycles:** Combine & Swift Concurrency (`async/await`)
- **Database Layer:** Core Data (Class Definitions / Model extensions)
- **Cloud Synchronization:** CloudKit Private DB Containers
- **Audio Engine:** AVAudioPlayer Framework Utilities
- **API Provider:** Datamuse API (JSON REST Vector Arrays)

---

## 📁 Repository Structure

```text
FreeFlow/
├── API/
│   └── DatamuseAPI.swift          # Live network REST client
├── Data/
│   ├── WordsRepository.swift      # Word generation rule abstractions
│   └── RhymesDatabase.swift       # Local database backup fallback arrays
├── Model/
│   ├── FlowNoteEntity.xcdatamodeld # Core Data model layer blueprints
│   └── FlowSettings.swift         # Global @Published configuration models
├── Tabs/
│   ├── FlowView.swift             # Primary lyrics player viewport
│   ├── FlowInspectorView.swift    # Right-hand global parameter options sheet
│   ├── RhymesView.swift           # Syllable-indexed rhyming search engine
│   ├── ExploreView.swift          # Semantic concept mapping index
│   ├── NotepadView.swift          # Modern adaptive iCloud text canvas
│   └── MediaCenterView.swift      # Advanced audio allocation configuration modal
└── ViewModel/
    └── AppViewModel.swift         # User configuration state disk persistence 
