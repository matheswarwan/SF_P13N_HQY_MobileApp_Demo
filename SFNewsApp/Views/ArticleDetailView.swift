import SwiftUI

/// Full-screen article detail page shown after tapping any article card.
/// Tracks an ArticleDetailView event on appearance via the shared ViewModel.
struct ArticleDetailView: View {

    let article: Article
    @EnvironmentObject var viewModel: HomeViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Hero image (only if article has an imageURL)
                if let imageURL = article.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            imageFallback
                        case .empty:
                            imageFallback
                                .overlay(ProgressView())
                        @unknown default:
                            imageFallback
                        }
                    }
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
                    .clipped()
                }

                VStack(alignment: .leading, spacing: 12) {
                    // Category chip
                    Text(article.category.uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(HETheme.primaryGreen)

                    // Headline
                    Text(article.headline)
                        .font(.title2.bold())

                    // Metadata row
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text("\(article.readTimeMinutes) min read")
                                .font(.caption)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption)
                            Text(article.publishedDate, style: .date)
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(.secondary)

                    Divider()

                    // Body text
                    Text(article.body)
                        .font(.body)
                        .lineSpacing(6)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.trackArticleDetailView(for: article)
        }
    }

    // MARK: - Supporting Views

    private var imageFallback: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color(.systemGray5), Color(.systemGray4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 240)
    }
}

#Preview {
    NavigationStack {
        ArticleDetailView(article: MockData.featuredArticle)
            .environmentObject(HomeViewModel())
    }
}
