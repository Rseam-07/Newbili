import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var libraryStore: LibraryStore
    @ObservedObject var accessoryStore: SearchBottomAccessoryStore
    @StateObject private var holder = SearchViewModelHolder()

    init(accessoryStore: SearchBottomAccessoryStore) {
        self.accessoryStore = accessoryStore
    }

    var body: some View {
        Group {
            if let viewModel = holder.viewModel {
                SearchContentView(
                    viewModel: viewModel,
                    showsHotSearches: libraryStore.showsHotSearches,
                    accessoryStore: accessoryStore
                )
            } else {
                SearchLoadingList()
                    .task {
                        holder.configure(api: dependencies.api, libraryStore: libraryStore)
                    }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: libraryStore.showsSearchSuggestions) { _, _ in
            holder.viewModel?.queryChanged()
        }
    }
}
