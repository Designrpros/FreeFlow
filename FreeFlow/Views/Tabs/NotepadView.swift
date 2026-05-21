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
    @EnvironmentObject private var settings: FlowSettings
    @Environment(\.colorScheme) private var colorScheme
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FlowNoteEntity.lastModified, ascending: false)],
        animation: .default
    )
    private var databaseNotes: FetchedResults<FlowNoteEntity>
    
    @State private var selectedNote: FlowNoteEntity? = nil
    
    // FIXED: Evaluates dark mode state via decoupled app appearance variables
    private var isDarkMode: Bool {
        if settings.appTheme == .system {
            return colorScheme == .dark
        }
        return settings.appTheme == .dark
    }
    
    // FIXED: Uses the unified theme color canvas engine for the writing workspace backplate
    private var workspaceBackground: Color {
        settings.canvasColor.backgroundColor(isDark: isDarkMode)
    }
    
    // FIXED: Formulates a slightly deeper variant background layer for the navigation sidebar structure
    private var sidebarBackground: Color {
        isDarkMode ? Color.black.opacity(0.15) : Color.black.opacity(0.03)
    }
    
    private var mainTextColor: Color {
        isDarkMode ? .white : .black
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
                                    .foregroundColor(mainTextColor)
                                Text((note.content ?? "").isEmpty ? "No lyrics yet..." : (note.content ?? ""))
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
                            // FIXED: Tints tool accents cleanly to your active AppAccent color palette choice
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
            // --- DESKTOP DETAIL WORKSPACE CANVAS ---
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
        // FIXED: Applies global theme background colors safely across the absolute split root
        .background(workspaceBackground.ignoresSafeArea())
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
            .foregroundColor(mainTextColor)
            
            Divider()
                .opacity(isDarkMode ? 0.1 : 0.2)
            
            TextEditor(text: Binding(
                get: { activeNote.content ?? "" },
                set: { newValue in
                    activeNote.content = newValue
                    activeNote.lastModified = Date()
                    saveContext()
                }
            ))
            .font(.system(size: 14, design: .monospaced))
            .foregroundColor(mainTextColor)
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
