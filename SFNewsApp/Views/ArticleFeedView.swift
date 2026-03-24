import SwiftUI

/// Vertically scrolling list of personalized articles for the "For You" section.
/// Content is driven by a SF p13n decision for `SDKConfig.forYouFeedPoint`.
struct ArticleFeedView: View {

    @EnvironmentObject var viewModel: HomeViewModel

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(viewModel.forYouArticles) { article in
                NavigationLink(value: article) {
                    ArticleCardView(article: article)
                        .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
                .onAppear {
                    viewModel.trackImpression(for: article)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    viewModel.trackClick(for: article)
                })

                if article.id != viewModel.forYouArticles.last?.id {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
    }
}

#Preview {
    ArticleFeedView()
        .environmentObject(HomeViewModel())
}
