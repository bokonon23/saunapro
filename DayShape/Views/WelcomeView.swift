import SwiftUI

struct WelcomeView: View {
    @Binding var hasCompletedOnboarding: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 20)

                // App icon and title
                VStack(spacing: 12) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(
                            .linearGradient(
                                colors: [.yellow, .orange, .red],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .symbolEffect(.pulse, options: .repeating)

                    Text("SaunaPro")
                        .font(.largeTitle.bold())

                    Text("Track your sauna & cold exposure sessions\nwith rich health data from your smartwatch")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // How it works
                VStack(alignment: .leading, spacing: 20) {
                    Text("How It Works")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)

                    FeatureRow(
                        icon: "applewatch",
                        iconColor: .blue,
                        title: "Start a Workout on Your Watch",
                        description: "Apple Watch: select \"Other\". Garmin or Fitbit: select \"Yoga\" or \"Mind & Body\". Start it before entering the sauna or cold exposure."
                    )

                    FeatureRow(
                        icon: "heart.text.square",
                        iconColor: .red,
                        title: "Rich Data Collection",
                        description: "Your watch collects heart rate every 3-5 seconds during the workout — giving you detailed session insights."
                    )

                    FeatureRow(
                        icon: "iphone",
                        iconColor: .orange,
                        title: "Automatic Detection",
                        description: "Open SaunaPro on your iPhone and your session appears automatically with peak HR, duration, and recovery data."
                    )

                    FeatureRow(
                        icon: "checkmark.circle",
                        iconColor: .green,
                        title: "Confirm or Dismiss",
                        description: "Review auto-detected sessions and confirm them as sauna or cold exposure, or dismiss false positives."
                    )
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Safety & Temperature Disclaimer
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "thermometer.sun.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)
                        Text("Important Safety Information")
                            .font(.title3.bold())
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Apple Watch is designed for temperatures between 0\u{00B0}C and 35\u{00B0}C (55\u{00B0}C for Ultra models). Traditional saunas typically reach 80\u{2013}100\u{00B0}C, which exceeds these limits.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("SaunaPro does not recommend wearing your Apple Watch in a sauna. Sauna tracking uses before & after metrics and manual session logging. Cold plunge temperatures (3\u{2013}5\u{00B0}C) are within the watch\u{2019}s operating range.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Any use of Apple Watch in high-heat environments is at your own risk and may void your warranty. This app is not intended for medical use \u{2014} always consult your doctor before starting heat or cold therapy.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Privacy
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                        Text("Your Data, Your Device")
                            .font(.title3.bold())
                    }

                    Text("SaunaPro reads health data from Apple HealthKit to detect and analyze your sessions. All data stays on your device and is never shared with third parties or uploaded to external servers.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Get started button
                Button {
                    withAnimation {
                        hasCompletedOnboarding = true
                    }
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .padding(.top, 8)

                Spacer().frame(height: 20)
            }
            .padding(.horizontal)
        }
        .background(Color.black)
    }
}

struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    WelcomeView(hasCompletedOnboarding: .constant(false))
        .preferredColorScheme(.dark)
}
