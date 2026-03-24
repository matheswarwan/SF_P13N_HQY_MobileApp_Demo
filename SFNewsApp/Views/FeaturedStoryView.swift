import SwiftUI

/// Hero banner at the top of the home screen.
/// Content is driven by a SF p13n decision for `SDKConfig.featuredStoryPoint`.
/// Shows a skeleton placeholder while loading, then transitions to the article image and text.
struct FeaturedStoryView: View {

    @EnvironmentObject var viewModel: HomeViewModel

    var body: some View {
        Group {
            if let article = viewModel.featuredArticle {
                heroCard(article: article)
            } else {
                skeletonPlaceholder
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Hero Card

    @ViewBuilder
    private func heroCard(article: Article) -> some View {
        NavigationLink(value: article) {
            ZStack(alignment: .bottomLeading) {

                // Background image
                AsyncImage(url: article.imageURL) { phase in
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
                .frame(height: 280)
                .clipped()

                // Gradient scrim so text is legible over any image
                LinearGradient(
                    colors: [.black.opacity(0.75), .black.opacity(0.3), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )

                // Article metadata
                VStack(alignment: .leading, spacing: 5) {
                    Text(article.category.uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(HETheme.primaryGreen)

                    Text(article.headline)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(article.readTimeMinutes) min read")
                            .font(.caption)
                    }
                    .foregroundStyle(.white.opacity(0.75))
                }
                .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            // "Personalized" badge — only visible when live SF p13n data is active
            .overlay(alignment: .topTrailing) {
                if viewModel.hasPersonalizedContent {
                    personalizationBadge
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            viewModel.trackImpression(for: article)
        }
        .simultaneousGesture(TapGesture().onEnded {
            viewModel.trackClick(for: article)
        })
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
            .frame(height: 280)
    }

    private var skeletonPlaceholder: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color(.systemGray5))
            .frame(height: 280)
            .redacted(reason: .placeholder)
    }

    private var personalizationBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.caption2)
            Text("Personalized")
                .font(.caption2.bold())
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .foregroundStyle(.white)
        .clipShape(Capsule())
        .padding(12)
    }
}

#Preview {
    FeaturedStoryView()
        .environmentObject(HomeViewModel())
}
