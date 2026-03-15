import SwiftUI

// MARK: - Settings Root View

struct SettingsView: View {
    @StateObject private var addonStorage = AddonStorage.shared
    @State private var showAddonManager = false

    var body: some View {
        NavigationStack {
            List {
                Section("Addons") {
                    NavigationLink {
                        AddonManagerView()
                    } label: {
                        HStack {
                            Image(systemName: "puzzlepiece.extension")
                                .foregroundStyle(.blue)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Manage Addons")
                                    .font(.callout.bold())
                                Text("\(addonStorage.addons.count) addon\(addonStorage.addons.count == 1 ? "" : "s") installed")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Playback") {
                    HStack {
                        Image(systemName: "play.rectangle")
                            .foregroundStyle(.green)
                            .frame(width: 32)
                        Text("Playback Settings")
                            .font(.callout)
                    }
                }

                Section("Account") {
                    HStack {
                        Image(systemName: "person.circle")
                            .foregroundStyle(.purple)
                            .frame(width: 32)
                        Text("Sign In with Stremio")
                            .font(.callout)
                    }
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.orange)
                            .frame(width: 32)
                        Text("Sync with Trakt")
                            .font(.callout)
                    }
                }

                Section("About") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.gray)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NuvioTV for Apple TV")
                                .font(.callout)
                            Text("Version 1.0.0")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Addon Manager View

struct AddonManagerView: View {
    @ObservedObject private var addonStorage = AddonStorage.shared
    @StateObject private var viewModel = AddonManagerViewModel()

    @State private var showAddAddon = false
    @State private var editMode = EditMode.inactive

    var body: some View {
        ZStack {
            List {
                if addonStorage.addons.isEmpty {
                    Section {
                        emptyView
                    }
                } else {
                    Section("Installed (\(addonStorage.addons.count))") {
                        ForEach(addonStorage.addons) { addon in
                            AddonRowView(addon: addon) {
                                addonStorage.removeAddon(id: addon.id)
                            }
                        }
                        .onMove { from, to in
                            addonStorage.reorderAddons(fromOffsets: from, toOffset: to)
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { index in
                                addonStorage.removeAddon(id: addonStorage.addons[index].id)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        showAddAddon = true
                    } label: {
                        Label("Add Addon", systemImage: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .navigationTitle("Addon Manager")
            .environment(\.editMode, $editMode)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(editMode == .active ? "Done" : "Edit") {
                        withAnimation {
                            editMode = editMode == .active ? .inactive : .active
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddAddon) {
            AddAddonView(viewModel: viewModel)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No Addons Installed")
                .font(.title3.bold())
            Text("Add Stremio-compatible addons to browse and stream content.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Addon Row

struct AddonRowView: View {
    let addon: Addon
    let onDelete: () -> Void

    @FocusState private var isFocused: Bool
    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 16) {
            // Logo
            ZStack {
                if let logoUrl = addon.logo, let url = URL(string: logoUrl) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFit()
                        } else {
                            defaultLogo
                        }
                    }
                } else {
                    defaultLogo
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(addon.displayName)
                    .font(.callout.bold())
                    .foregroundStyle(.primary)

                Text("v\(addon.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let desc = addon.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Badges
            VStack(alignment: .trailing, spacing: 4) {
                if addon.supportsCatalog {
                    Text("Catalog")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.2))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
                if addon.supportsStreams {
                    Text("Streams")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.2))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Remove \(addon.displayName)?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var defaultLogo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.blue.opacity(0.3))
            Image(systemName: "puzzlepiece.extension.fill")
                .foregroundStyle(.blue)
        }
    }
}

// MARK: - Add Addon View

struct AddAddonView: View {
    @ObservedObject var viewModel: AddonManagerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var urlText = ""
    @State private var isFetchingManifest = false
    @State private var fetchedAddon: Addon?
    @State private var fetchError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // URL input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Addon URL")
                        .font(.callout.bold())
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField("https://addon.example.com/manifest.json", text: $urlText)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.callout)

                        if isFetchingManifest {
                            ProgressView()
                        } else if !urlText.isEmpty {
                            Button("Fetch") {
                                Task { await fetchManifest() }
                            }
                            .disabled(urlText.isEmpty)
                        }
                    }
                    .padding(16)
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    if let error = fetchError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Popular addons suggestion
                VStack(alignment: .leading, spacing: 16) {
                    Text("Popular Addons")
                        .font(.callout.bold())
                        .foregroundStyle(.secondary)

                    ForEach(AddonManagerViewModel.popularAddons, id: \.url) { suggestion in
                        Button {
                            urlText = suggestion.url
                            Task { await fetchManifest() }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(suggestion.name)
                                        .font(.callout.bold())
                                        .foregroundStyle(.primary)
                                    Text(suggestion.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.blue)
                            }
                            .padding(16)
                            .background(.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Fetched addon preview
                if let addon = fetchedAddon {
                    addonPreview(addon)
                }

                Spacer()
            }
            .padding(40)
            .navigationTitle("Add Addon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func addonPreview(_ addon: Addon) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()

            HStack(spacing: 16) {
                if let logo = addon.logo, let url = URL(string: logo) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFit()
                        }
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(addon.displayName)
                        .font(.title3.bold())
                    Text("v\(addon.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let desc = addon.description {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }

            Button {
                AddonStorage.shared.addAddon(addon)
                dismiss()
            } label: {
                Label("Install \(addon.displayName)", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    private func fetchManifest() async {
        guard !urlText.isEmpty else { return }
        isFetchingManifest = true
        fetchError = nil
        fetchedAddon = nil

        do {
            fetchedAddon = try await AddonService.shared.fetchManifest(from: urlText)
        } catch {
            fetchError = error.localizedDescription
        }

        isFetchingManifest = false
    }
}

// MARK: - Addon Manager ViewModel

@MainActor
final class AddonManagerViewModel: ObservableObject {
    struct AddonSuggestion {
        let name: String
        let description: String
        let url: String
    }

    static let popularAddons: [AddonSuggestion] = [
        AddonSuggestion(
            name: "Cinemeta",
            description: "Official Stremio catalog for movies and series",
            url: "https://v3-cinemeta.strem.io/manifest.json"
        ),
        AddonSuggestion(
            name: "Public Domain Movies",
            description: "Free public domain movies",
            url: "https://pdm-addon.strem.io/manifest.json"
        ),
        AddonSuggestion(
            name: "YouTube Channels",
            description: "YouTube channels as catalog",
            url: "https://yt.strem.io/manifest.json"
        )
    ]
}
