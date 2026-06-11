import SwiftUI
import SwiftData

@Model
public final class Note {
    public var title: String
    public var content: String
    public var imageData: Data?
    public var creationDate: Date
    public var lastModifiedDate: Date

    init(title: String, content: String, imageData: Data? = nil, creationDate: Date = Date(), lastModifiedDate: Date = Date()) {
        self.title = title
        self.content = content
        self.imageData = imageData
        self.creationDate = creationDate
        self.lastModifiedDate = lastModifiedDate
    }
}

struct ContentView: View {
    @Query(sort: \Note.lastModifiedDate, order: .reverse) private var allNotes: [Note]
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var selectedNote: Note?
    @State private var showingNewNote = false

    private var notes: [Note] {
        if searchText.isEmpty {
            return allNotes
        } else {
            return allNotes.filter { note in
                note.title.localizedStandardContains(searchText) ||
                note.content.localizedStandardContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedNote) {
                ForEach(notes) { note in
                    NavigationLink(value: note) {
                        VStack(alignment: .leading) {
                            Text(note.title)
                                .font(.headline)
                            Text(note.lastModifiedDate, style: .date)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteNotes)
            }
            .navigationTitle("Notes")
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewNote = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        } detail: {
            if let note = selectedNote {
                NoteDetailView(note: note)
            } else {
                ContentUnavailableView(
                    "Select a Note",
                    systemImage: "note.text",
                    description: Text("Choose a note or create a new one")
                )
            }
        }
        .sheet(isPresented: $showingNewNote) {
            NewNoteView()
        }
    }

    private func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(notes[index])
        }
    }
}

struct NoteDetailView: View {
    @Bindable var note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            TextField("Title", text: $note.title)
                .font(.largeTitle)
                .bold()

            Divider()

            TextEditor(text: $note.content)
                .frame(minHeight: 200)
                .border(Color.gray.opacity(0.3))

            Spacer()

            Text("Last modified: \(note.lastModifiedDate, style: .date)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle("Edit Note")
    }
}

struct NewNoteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextEditor(text: $content)
                    .frame(minHeight: 200)
            }
            .navigationTitle("New Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let note = Note(title: title.isEmpty ? "Untitled" : title, content: content)
                        modelContext.insert(note)
                        dismiss()
                    }
                    .disabled(title.isEmpty && content.isEmpty)
                }
            }
        }
    }
}
