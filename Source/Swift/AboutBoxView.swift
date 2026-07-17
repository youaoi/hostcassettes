import SwiftUI

struct AboutBoxView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 16) {
                Image("AboutIcon")
                    .resizable()
                    .frame(width: 96, height: 96)
                    .accessibilityLabel("Host Cassettes application icon")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Host Cassettes")
                        .font(.system(size: 18))

                    Text("Version \(version)")
                        .font(.system(size: 11))

                    Spacer()
                        .frame(height: 2)

                    Text("Developed by Yuki AOI")
                        .font(.system(size: 11))

                    LabeledLink(
                        label: "Home Page:",
                        text: "github.com/youaoi/hostcassettes",
                        destination: URL(string: "https://github.com/youaoi/hostcassettes")!
                    )

                    Spacer()
                        .frame(height: 2)

                    Text("Based on Gas Mask by Siim Raud")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    LabeledLink(
                        label: "Original:",
                        text: "github.com/2ndalpha/gasmask",
                        destination: URL(string: "https://github.com/2ndalpha/gasmask")!
                    )
                }
            }

            VStack(spacing: 2) {
                Text("Original: Copyright © 2009–2026 Clockwise Software")
                    .font(.system(size: 10))
                Text("Modifications: Copyright © 2026 Yuki AOI")
                    .font(.system(size: 10))
                Text("All rights reserved.")
                    .font(.system(size: 10))
            }
            .multilineTextAlignment(.center)
            .padding(.top, 4)
        }
        .fixedSize()
        .padding(20)
    }
}

private struct LabeledLink: View {
    let label: String
    let text: String
    let destination: URL

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11))
            Link(text, destination: destination)
                .font(.system(size: 11))
        }
    }
}
