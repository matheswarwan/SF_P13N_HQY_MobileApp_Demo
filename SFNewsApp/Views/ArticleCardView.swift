import SwiftUI

/// A single row in the "For You" article feed.
/// Displays a thumbnail, category chip, headline, and estimated read time.
struct ArticleCardView: View {

    let article: Article

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            // Thumbnail
            AsyncImage(url: article.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                }
            }
            .frame(width: 88, height: 68)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(article.category.uppercased())
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)

                Text(article.headline)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("\(article.readTimeMinutes) min read")
                        .font(.caption)
                }
                .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

#Preview {
    ArticleCardView(article: MockData.forYouArticles[0])
        .padding()
}
