import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var selectedItem: MetaPreview?

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 20)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search field
                    searchField

                    // Results
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .scaleEffect(2)
                            .tint(.white)
                        Spacer()
                    } else if viewModel.results.isEmpty && !viewModel.query.isEmpty {
                        emptyResultsView
                    } else if viewModel.results.isEmpty {
                        searchPromptView
                    } else {
                        resultsGrid
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedItem) { item in
                DetailView(
                    contentId: item.id,
                    contentType: item.type,
                    previewItem: item
                )
            }
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.title3)

            TextField("Search movies, series...", text: $viewModel.query)
                .font(.title3)
                .foregroundStyle(.primary)
                .onChange(of: viewModel.query) { _, newValue in
                    viewModel.search(newValue)
                }
                .submitLabel(.search)
                .onSubmit {
                    viewModel.search(viewModel.query)
                }

            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                    viewModel.search("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 60)
        .padding(.vertical, 20)
    }

    // MARK: - Results

    private var resultsGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 30) {
                ForEach(viewModel.results) { item in
                    Button {
                        selectedItem = item
                    } label: {
                        ContentCardView(item: item, width: 200, height: 300)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Empty States

    private var emptyResultsView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No results for \"\(viewModel.query)\"")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var searchPromptView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 80))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("Search for movies and series")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Use an addon with search support to find content")
                .font(.callout)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }
}
