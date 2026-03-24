import SwiftUI

/// Horizontally scrolling row of trending articles.
/// Uses static mock data only — not personalized via SF p13n.
struct TrendingView: View {

    @EnvironmentObject var viewModel: HomeViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(Array(viewModel.trendingArticles.enumerated()), id: \.element.id) { index, article in
                    NavigationLink(value: article) {
                        trendingCard(rank: index + 1, article: article)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        viewModel.trackClick(for: article)
                    })
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func trendingCard(rank: Int, article: Article) -> some View {
        VStack(alignment: .leading, spacing: 8) {

            // Large rank number as visual anchor
            Text("#\(rank)")
                .font(.system(size: 36, weight: .black))
                .foregroundStyle(Color(.systemGray5))

            Text(article.category.uppercased())
                .font(.caption2.bold())
                .foregroundStyle(HETheme.primaryGreen)

            Text(article.headline)
                .font(.subheadline.bold())
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text("\(article.readTimeMinutes) min read")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 175, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    TrendingView()
        .environmentObject(HomeViewModel())
}
