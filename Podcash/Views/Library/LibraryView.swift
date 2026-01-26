import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Podcast.title) private var podcasts: [Podcast]
    @Query(sort: \Folder.sortOrder) private var folders: [Folder]

    @State private var showingAddPodcast = false
    @State private var showingAddFolder = false
    @State private var folderToEdit: Folder?

    var body: some View {
        NavigationStack {
            Group {
                if podcasts.isEmpty && folders.isEmpty {
                    ContentUnavailableView(
                        "No Podcasts",
                        systemImage: "mic",
                        description: Text("Add a podcast to get started")
                    )
                } else {
                    List {
                        // Folders section
                        if !folders.isEmpty {
                            Section("Folders") {
                                ForEach(folders) { folder in
                                    NavigationLink(value: folder) {
                                        FolderRowView(folder: folder)
                                    }
                                    .contextMenu {
                                        Button {
                                            folderToEdit = folder
                                        } label: {
                                            Label("Edit Folder", systemImage: "pencil")
                                        }

                                        Button(role: .destructive) {
                                            modelContext.delete(folder)
                                        } label: {
                                            Label("Delete Folder", systemImage: "trash")
                                        }
                                    }
                                }
                                .onDelete(perform: deleteFolders)
                            }
                        }

                        // Podcasts section
                        Section(folders.isEmpty ? "" : "All Podcasts") {
                            ForEach(podcasts) { podcast in
                                NavigationLink(value: podcast) {
                                    PodcastRowView(podcast: podcast)
                                }
                                .contextMenu {
                                    addToFolderMenu(for: podcast)
                                }
                            }
                            .onDelete(perform: deletePodcasts)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Library")
            .navigationDestination(for: Podcast.self) { podcast in
                PodcastDetailView(podcast: podcast)
            }
            .navigationDestination(for: Folder.self) { folder in
                FolderDetailView(folder: folder)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingAddPodcast = true
                        } label: {
                            Label("Add Podcast", systemImage: "plus")
                        }

                        Button {
                            showingAddFolder = true
                        } label: {
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPodcast) {
                AddPodcastView()
            }
            .sheet(isPresented: $showingAddFolder) {
                EditFolderView(folder: nil)
            }
            .sheet(item: $folderToEdit) { folder in
                EditFolderView(folder: folder)
            }
        }
    }

    @ViewBuilder
    private func addToFolderMenu(for podcast: Podcast) -> some View {
        if folders.isEmpty {
            Button {
                showingAddFolder = true
            } label: {
                Label("Create Folder", systemImage: "folder.badge.plus")
            }
        } else {
            Menu {
                ForEach(folders) { folder in
                    Button {
                        togglePodcastInFolder(podcast, folder: folder)
                    } label: {
                        if folder.podcasts.contains(where: { $0.id == podcast.id }) {
                            Label(folder.name, systemImage: "checkmark")
                        } else {
                            Text(folder.name)
                        }
                    }
                }

                Divider()

                Button {
                    showingAddFolder = true
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
            } label: {
                Label("Add to Folder", systemImage: "folder")
            }
        }
    }

    private func togglePodcastInFolder(_ podcast: Podcast, folder: Folder) {
        if let index = folder.podcasts.firstIndex(where: { $0.id == podcast.id }) {
            folder.podcasts.remove(at: index)
        } else {
            folder.podcasts.append(podcast)
        }
        try? modelContext.save()
    }

    private func deletePodcasts(at offsets: IndexSet) {
        for index in offsets {
            let podcast = podcasts[index]
            // Delete downloads first
            DownloadManager.shared.deleteDownloads(for: podcast)
            modelContext.delete(podcast)
        }
    }

    private func deleteFolders(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(folders[index])
        }
    }
}

// MARK: - Folder Row View

struct FolderRowView: View {
    let folder: Folder

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundStyle(folderColor)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .font(.headline)

                Text("\(folder.podcasts.count) podcast\(folder.podcasts.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var folderColor: Color {
        if let hex = folder.colorHex {
            return Color(hex: hex) ?? .accentColor
        }
        return .accentColor
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: [Podcast.self, Folder.self], inMemory: true)
}
