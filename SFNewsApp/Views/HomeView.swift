import SwiftUI

/// Root container view for the news feed.
/// Hosts three sections: personalized hero banner, personalized "For You" feed, and static trending.
struct HomeView: View {

    @EnvironmentObject var viewModel: HomeViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // Section 1: Personalized featured story hero (SF p13n)
                    FeaturedStoryView()
                        .padding(.bottom, 28)

                    // Section 2: Personalized "For You" article feed (SF p13n)
                    sectionHeader(title: "For You", isPersonalized: viewModel.hasPersonalizedContent)
                    ArticleFeedView()
                        .padding(.bottom, 28)

                    // Section 3: Static trending content (no p13n)
                    sectionHeader(title: "Trending", isPersonalized: false)
                    TrendingView()
                        .padding(.bottom, 40)
                }
            }
            .navigationDestination(for: Article.self) { article in
                ArticleDetailView(article: article)
            }
            .navigationTitle("HealthEquity")
            .navigationBarTitleDisplayMode(.large)
            .task {
                // Fires once on first appearance; re-fires only if the task is cancelled and restarted.
                await viewModel.loadContent()
            }
            .refreshable {
                await viewModel.loadContent()
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(title: String, isPersonalized: Bool) -> some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.title2.bold())

            if isPersonalized {
                Text("Personalized")
                    .font(.caption2.bold())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(HETheme.lightGreen)
                    .foregroundStyle(HETheme.primaryGreen)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }
}

#Preview {
    HomeView()
        .environmentObject(HomeViewModel())
}
