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
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FlowNoteEntity.lastModified, ascending: false)],
        animation: .default
    )
    private var databaseNotes: FetchedResults<FlowNoteEntity>
    
    @State private var selectedNote: FlowNoteEntity? = nil
    
    private var workspaceBackground: Color {
        colorScheme == .dark ? Color(white: 0.15) : Color.white
    }
    
    private var sidebarBackground: Color {
        colorScheme == .dark ? Color(white: 0.10) : Color(white: 0.97)
    }

    var body: some View {
        NavigationSplitView(preferredCompactColumn: .constant(.sidebar)) {
            
            // --- MASTER SIDEBAR COLUMN ---
            List {
                ForEach(databaseNotes) { note in
                    NavigationLink {
                        editorWorkspaceCanvas(for: note)
                    } label: {
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
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(sidebarBackground)
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
            
            // FIXED: Using navigation inline structures cleanly places the actions up top
            .navigationTitle("My Sheets")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: createNewNoteAction) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            }
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
            
        } detail: {
            // --- DESKTOP DETAIL WORKSPACE CANVAS ---
            if let activeNote = selectedNote {
                editorWorkspaceCanvas(for: activeNote)
            } else if let firstNote = databaseNotes.first {
                editorWorkspaceCanvas(for: firstNote)
            } else {
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
            if selectedNote == nil, let first = databaseNotes.first {
                selectedNote = first
            }
        }
    }
    
    // --- TEXT EDITOR SHEET CANVAS COMPONENT ---
    @ViewBuilder
    private func editorWorkspaceCanvas(for activeNote: FlowNoteEntity) -> some View {
        VStack(alignment: .leading, spacing: 0) {
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
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    // --- DATABASE OPERATIONS ---
    
    private func createNewNoteAction() {
        withAnimation {
            let freshNote = FlowNoteEntity(context: viewContext)
            freshNote.id = UUID()
            freshNote.title = "New Sheet"
            freshNote.content = ""
            freshNote.lastModified = Date()
            
            saveContext()
            selectedNote = freshNote
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
            print("Unresolved core data mutation write fault: \(error)")
        }
    }
}
