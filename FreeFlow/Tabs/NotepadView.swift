//
//  NotepadView.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 21/05/2026.
//

import SwiftUI
import CoreData

struct NotepadView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    
    // NATIVE CORE DATA SOURCE: Tracks and sorts notes in real-time as they update locally or via iCloud pushes
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FlowNoteEntity.lastModified, ascending: false)],
        animation: .default
    )
    private var databaseNotes: FetchedResults<FlowNoteEntity>
    
    // Tracks the active selection using the unique identifier managed by Core Data
    @State private var selectedNote: FlowNoteEntity? = nil
    
    // Adaptive background styling
    private var workspaceBackground: Color {
        colorScheme == .dark ? Color(white: 0.15) : Color.white
    }
    
    private var sidebarBackground: Color {
        colorScheme == .dark ? Color(white: 0.10) : Color(white: 0.97)
    }

    var body: some View {
        NavigationSplitView {
            // --- LEFT/MASTER COLUMN: THE LIST INDEX ---
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("My Sheets")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Spacer()
                    Button(action: createNewNoteAction) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                
                Divider().opacity(0.1)
                
                List(selection: $selectedNote) {
                    ForEach(databaseNotes) { note in
                        NavigationLink(value: note) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text((note.title ?? "").isEmpty ? "Untitled Sheet" : (note.title ?? ""))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text((note.content ?? "").isEmpty ? "No lyrics yet..." : (note.content ?? ""))
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
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
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteNoteAction(note: note)
                            } label: {
                                Label("Delete Sheet", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .overlay {
                    if databaseNotes.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "note.text")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("No notes saved")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .background(sidebarBackground)
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
            
        } detail: {
            // --- RIGHT/DETAIL COLUMN: THE EDITOR CANVAS ---
            if let activeNote = selectedNote {
                VStack(alignment: .leading, spacing: 0) {
                    // Safe bindings to write optional Core Data properties directly on change
                    TextField("Untitled Sheet...", text: Binding(
                        get: { activeNote.title ?? "" },
                        set: { newValue in
                            activeNote.title = newValue
                            activeNote.lastModified = Date()
                            saveContext()
                        }
                    ))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    
                    Divider().opacity(0.1)
                    
                    TextEditor(text: Binding(
                        get: { activeNote.content ?? "" },
                        set: { newValue in
                            activeNote.content = newValue
                            activeNote.lastModified = Date()
                            saveContext()
                        }
                    ))
                    .font(.system(size: 14, design: .monospaced))
                    .padding(20)
                    .scrollContentBackground(.hidden)
                    .background(workspaceBackground)
                }
                .background(workspaceBackground)
            } else {
                // Initial Default State Detail View
                VStack(spacing: 12) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("Select a sheet or click the pencil icon to begin writing.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(workspaceBackground)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            // If nothing is selected, gracefully auto-focus the first note if available
            if selectedNote == nil, let first = databaseNotes.first {
                selectedNote = first
            }
        }
    }
    
    // --- PERSISTENCE DATABASE INTERACTIONS LOGIC ---
    
    private func createNewNoteAction() {
        withAnimation {
            let freshNote = FlowNoteEntity(context: viewContext)
            freshNote.id = UUID()
            freshNote.title = "New Sheet"
            freshNote.content = ""
            freshNote.lastModified = Date()
            
            saveContext()
            selectedNote = freshNote // Navigate right into the fresh document
        }
    }
    
    private func deleteNoteAction(note: FlowNoteEntity) {
        withAnimation {
            viewContext.delete(note)
            saveContext()
            
            if selectedNote == note {
                selectedNote = databaseNotes.first
            }
        }
    }
    
    private func saveContext() {
        do {
            if viewContext.hasChanges {
                try viewContext.save()
            }
        } catch {
            let nsError = error as NSError
            print("Unresolved core data mutation write fault: \(nsError), \(nsError.userInfo)")
        }
    }
}

#Preview {
    NotepadView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
