import SwiftUI
import SwiftData

struct EditFolderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let folder: Folder?

    @State private var name: String = ""
    @State private var selectedColor: String = "007AFF" // Default blue

    private let colorOptions = [
        "007AFF", // Blue
        "34C759", // Green
        "FF9500", // Orange
        "FF3B30", // Red
        "AF52DE", // Purple
        "FF2D55", // Pink
        "5856D6", // Indigo
        "00C7BE", // Teal
    ]

    private var isEditing: Bool { folder != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Folder Name") {
                    TextField("Name", text: $name)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Button {
                                selectedColor = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex) ?? .gray)
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        if selectedColor == hex {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.white)
                                                .fontWeight(.bold)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(isEditing ? "Edit Folder" : "New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        saveFolder()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let folder = folder {
                    name = folder.name
                    selectedColor = folder.colorHex ?? "007AFF"
                }
            }
        }
    }

    private func saveFolder() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let folder = folder {
            // Edit existing
            folder.name = trimmedName
            folder.colorHex = selectedColor
        } else {
            // Create new
            let newFolder = Folder(name: trimmedName, colorHex: selectedColor)
            modelContext.insert(newFolder)
        }

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    EditFolderView(folder: nil)
        .modelContainer(for: Folder.self, inMemory: true)
}
