//
//  NotepadView.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 21/05/2026.
//

import SwiftUI
import CoreData
import Combine

struct NotepadView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var settings: FlowSettings
    @Environment(\.colorScheme) private var colorScheme
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FlowNoteEntity.lastModified, ascending: false)],
        animation: .default
    )
    private var databaseNotes: FetchedResults<FlowNoteEntity>
    
    @State private var selectedNote: FlowNoteEntity? = nil
    
    // Local memory buffers to insulate keyboard entry from blocking database storage layers
    @State private var localTitleBuffer: String = ""
    @State private var localContentBuffer: String = ""
    
    // Throttling mechanism architecture subjects
    private let textDebounceSubject = PassthroughSubject<(title: String, content: String), Never>()
    @State private var saveCancellable: AnyCancellable? = nil
    
    private var isDarkMode: Bool {
        if settings.appTheme == .system { return colorScheme == .dark }
        return settings.appTheme == .dark
    }
    
    private var workspaceBackground: Color {
        settings.canvasColor.backgroundColor(isDark: isDarkMode)
    }
    
    // 🚀 FIX: Map the sidebar background directly to match the main canvas theme color
    private var sidebarBackground: Color {
        workspaceBackground
    }
    
    private var mainTextColor: Color {
        isDarkMode ? .white : .black
    }

    var body: some View {
        NavigationSplitView(preferredCompactColumn: .constant(.sidebar)) {
            List {
                ForEach(databaseNotes) { note in
                    NavigationLink {
                        editorWorkspaceCanvas(for: note)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                // If inspecting current active editor, load preview parameters cleanly out of local typing buffers
                                Text(isCurrentNoteEditing(note) ? (localTitleBuffer.isEmpty ? "Untitled Sheet" : localTitleBuffer) : ((note.title ?? "").isEmpty ? "Untitled Sheet" : (note.title ?? "")))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(mainTextColor)
                                
                                Text(isCurrentNoteEditing(note) ? (localContentBuffer.isEmpty ? "No lyrics yet..." : localContentBuffer) : ((note.content ?? "").isEmpty ? "No lyrics yet..." : (note.content ?? "")))
                                    .font(.system(size: 11))
                                    .foregroundColor(mainTextColor.opacity(0.4))
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteNoteAction(note: note)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            // 🚀 FIX: Applies background color mapping seamlessly behind invisible list cells
            .background(sidebarBackground)
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
            .navigationTitle("My Sheets")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: createNewNoteAction) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(settings.appAccent.color)
                    }
                }
            }
            .overlay {
                if databaseNotes.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "note.text")
                            .font(.system(size: 24))
                            .foregroundColor(mainTextColor.opacity(0.3))
                        Text("No notes saved")
                            .font(.system(size: 12))
                            .foregroundColor(mainTextColor.opacity(0.4))
                    }
                }
            }
            
        } detail: {
            if let activeNote = selectedNote {
                editorWorkspaceCanvas(for: activeNote)
            } else if let firstNote = databaseNotes.first {
                editorWorkspaceCanvas(for: firstNote)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 32))
                        .foregroundColor(mainTextColor.opacity(0.2))
                    Text("Select a sheet or click the pencil icon to begin writing.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(mainTextColor.opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(workspaceBackground)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .background(workspaceBackground.ignoresSafeArea())
        .onAppear {
            setupDebouncedSavePipeline()
            if selectedNote == nil, let first = databaseNotes.first {
                loadNoteIntoLocalBuffers(first)
            }
        }
        .onDisappear {
            // Force a synchronous write commit if exiting screen while save cycles are pending
            commitPendingBufferChangesToDatabase()
            saveCancellable?.cancel()
        }
    }
    
    @ViewBuilder
    private func editorWorkspaceCanvas(for activeNote: FlowNoteEntity) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title input area handles updates natively inside local buffering layers
            TextField("Untitled Sheet...", text: $localTitleBuffer)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .textFieldStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .foregroundColor(mainTextColor)
                .onChange(of: localTitleBuffer) { oldValue, newValue in
                    textDebounceSubject.send((title: newValue, content: localContentBuffer))
                }
            
            Divider()
                .opacity(isDarkMode ? 0.1 : 0.2)
            
            // Content text area typing works directly with local buffering memory loops
            TextEditor(text: $localContentBuffer)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(mainTextColor)
                .padding(20)
                .scrollContentBackground(.hidden)
                .background(workspaceBackground)
                .onChange(of: localContentBuffer) { oldValue, newValue in
                    textDebounceSubject.send((title: localTitleBuffer, content: newValue))
                }
        }
        .background(workspaceBackground)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        // Re-synchronize memory structures safely if target file reference mutates
        .onChange(of: activeNote) { oldNote, newNote in
            commitPendingBufferChangesToDatabase()
            loadNoteIntoLocalBuffers(newNote)
        }
    }
    
    // --- THROTTLING ENGINE OPERATIONS ---
    
    private func loadNoteIntoLocalBuffers(_ note: FlowNoteEntity) {
        self.selectedNote = note
        self.localTitleBuffer = note.title ?? ""
        self.localContentBuffer = note.content ?? ""
    }
    
    private func isCurrentNoteEditing(_ note: FlowNoteEntity) -> Bool {
        return selectedNote?.objectID == note.objectID
    }
    
    // FIXED THROTTLED PIPELINE: Captures keyboard entries and commits to SQLite only after you pause typing for 1.5 seconds.
    // This stops background worker threads from crashing or causing playback glitching stutters.
    private func setupDebouncedSavePipeline() {
        saveCancellable = textDebounceSubject
            .debounce(for: .seconds(1.5), scheduler: RunLoop.main)
            .sink { [viewContext] updates in
                guard let activeNote = self.selectedNote else { return }
                
                // Mutate the actual parameters inside database tracking scope
                activeNote.title = updates.title
                activeNote.content = updates.content
                activeNote.lastModified = Date()
                
                do {
                    if viewContext.hasChanges {
                        try viewContext.save()
                        print("💾 [NotepadView] Debounced storage snapshot written cleanly to disk.")
                    }
                } catch {
                    print("⚠️ [NotepadView] Throttled save dropped: \(error.localizedDescription)")
                }
            }
    }
    
    private func commitPendingBufferChangesToDatabase() {
        guard let activeNote = selectedNote else { return }
        
        // Match conditions check if buffer deviates from original record parameters
        if activeNote.title != localTitleBuffer || activeNote.content != localContentBuffer {
            activeNote.title = localTitleBuffer
            activeNote.content = localContentBuffer
            activeNote.lastModified = Date()
            
            try? viewContext.save()
        }
    }
    
    private func createNewNoteAction() {
        commitPendingBufferChangesToDatabase()
        
        withAnimation {
            let freshNote = FlowNoteEntity(context: viewContext)
            freshNote.id = UUID()
            freshNote.title = "New Sheet"
            freshNote.content = ""
            freshNote.lastModified = Date()
            
            try? viewContext.save()
            loadNoteIntoLocalBuffers(freshNote)
        }
    }
    
    private func deleteNoteAction(note: FlowNoteEntity) {
        if selectedNote == note {
            saveCancellable?.cancel()
            selectedNote = nil
            localTitleBuffer = ""
            localContentBuffer = ""
        }
        
        withAnimation {
            viewContext.delete(note)
            try? viewContext.save()
            
            // Re-route tracking coordinates if roster items are available
            if selectedNote == nil, let first = databaseNotes.first {
                loadNoteIntoLocalBuffers(first)
                setupDebouncedSavePipeline()
            }
        }
    }
}
