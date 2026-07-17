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

                    Text("Based on Gas Mask by Siim Raud")
                        .font(.system(size: 11))

                    HStack(spacing: 4) {
                        Text("E-mail:")
                            .font(.system(size: 11))
                        Text(verbatim: "siim@clockwise.ee")
                            .font(.system(size: 11))
                            .strikethrough()
                            .foregroundColor(.secondary)
                    }

                    LabeledLink(
                        label: "Home Page:",
                        text: "github.com/dmm-aoi-yuki/hostcassettes",
                        destination: URL(string: "https://github.com/dmm-aoi-yuki/hostcassettes")!
                    )
                }
            }

            Text("Copyright © 2009–2026 Clockwise.\nAll rights reserved.")
                .font(.system(size: 10))
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
