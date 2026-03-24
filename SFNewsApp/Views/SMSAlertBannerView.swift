import SwiftUI

/// Tappable banner that opens the phone signup sheet.
/// Placed below the trending section on the home screen.
struct SMSAlertBannerView: View {

    @EnvironmentObject var viewModel: HomeViewModel

    var body: some View {
        Button {
            viewModel.showPhoneSignupSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.title3)
                    .foregroundStyle(HETheme.primaryGreen)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable SMS Alerts")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("Get benefit update reminders via text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(HETheme.lightGreen)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
}

#Preview {
    SMSAlertBannerView()
        .environmentObject(HomeViewModel())
}
