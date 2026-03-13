import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("Privacy Policy")
                        .font(.largeTitle.bold())

                    Text("Last updated: March 2026")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                section(title: "Overview") {
                    "SaunaPro is a sauna and cold exposure tracking app that uses Apple HealthKit data to detect and analyze your sessions. We are committed to protecting your privacy and keeping your health data secure."
                }

                section(title: "Data Collection") {
                    """
                    SaunaPro accesses the following data from Apple HealthKit:

                    \u{2022} Heart rate samples
                    \u{2022} Heart rate variability (HRV)
                    \u{2022} Resting heart rate
                    \u{2022} Workout records
                    \u{2022} Wrist temperature (where available)

                    This data is used solely to detect sauna and cold exposure sessions, calculate benefit zones, and provide health insights within the app.
                    """
                }

                section(title: "Data Storage") {
                    """
                    All your data is stored locally on your device. SaunaPro does not transmit, upload, or share your health data with any external servers, third parties, analytics services, or advertising networks.

                    Session records are stored using on-device storage (SwiftData) and remain under your control at all times.
                    """
                }

                section(title: "Data Sharing") {
                    "SaunaPro does not share your data with anyone. We have no servers, no accounts, no cloud sync, and no analytics. Your health data never leaves your device."
                }

                section(title: "HealthKit") {
                    """
                    SaunaPro uses Apple HealthKit to read health data for session detection and analysis. In accordance with Apple's HealthKit guidelines:

                    \u{2022} Health data is never used for advertising
                    \u{2022} Health data is not sold to data brokers or third parties
                    \u{2022} Health data is not shared with third parties without your explicit consent
                    \u{2022} Health data access can be revoked at any time in Settings \u{2192} Privacy & Security \u{2192} Health
                    """
                }

                section(title: "Medical Disclaimer") {
                    "SaunaPro is not a medical device and is not intended for medical use. The benefit zones, heart rate analysis, and session insights are for informational and wellness purposes only. Always consult your doctor before starting any heat or cold therapy programme."
                }

                section(title: "Children's Privacy") {
                    "SaunaPro is not intended for use by children under the age of 17. We do not knowingly collect data from children."
                }

                section(title: "Changes to This Policy") {
                    "We may update this privacy policy from time to time. Any changes will be reflected in the app and on our website with an updated revision date."
                }

                section(title: "Contact") {
                    "If you have questions about this privacy policy, please contact us at saunapro@dayshape.app"
                }
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func section(title: String, content: () -> String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
    .preferredColorScheme(.dark)
}
