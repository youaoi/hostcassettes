import SwiftUI

struct IconPickerView: View {
    let hostsPath: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedIcon: String?
    @State private var useCustomColor: Bool
    @State private var selectedColor: Color

    init(hosts: Hosts) {
        let path = hosts.path ?? ""
        self.hostsPath = path
        self._selectedIcon = State(initialValue: StatusBarIconStore.iconName(forHostsPath: path))
        if let nsColor = StatusBarIconStore.iconColor(forHostsPath: path) {
            self._useCustomColor = State(initialValue: true)
            self._selectedColor = State(initialValue: Color(nsColor))
        } else {
            self._useCustomColor = State(initialValue: false)
            self._selectedColor = State(initialValue: .accentColor)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchField
            iconGrid
            Divider()
            footer
        }
        .frame(width: 640, height: 600)
        .onAppear {
            // シートの前面にカラーパネルが表示されるようウィンドウレベルを合わせる
            NSColorPanel.shared.level = .modalPanel
        }
        .onDisappear {
            NSColorPanel.shared.close()
            NSColorPanel.shared.level = .floating
        }
    }

    // MARK: - Header

    private var header: some View {
        Text("Select Status Bar Icon", comment: "Icon picker title")
            .font(.headline)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(NSLocalizedString("Search icons…", comment: "Icon picker search"), text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(8)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Grid

    private var iconGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 8)], spacing: 8, pinnedViews: .sectionHeaders) {
                ForEach(filteredCategories) { category in
                    Section {
                        ForEach(category.icons, id: \.self) { name in
                            iconButton(name: name)
                        }
                    } header: {
                        HStack {
                            Text(category.title)
                                .font(.system(size: NSFont.smallSystemFontSize, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 2)
                        .background(.background)
                    }
                }
            }
            .padding(16)
        }
    }

    private func iconButton(name: String) -> some View {
        Button {
            selectedIcon = name
        } label: {
            Image(systemName: name)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(selectedIcon == name ? Color.accentColor.opacity(0.2) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .help(name)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 8) {
            Divider()
            HStack(spacing: 8) {
                Toggle(NSLocalizedString("Custom Color:", comment: "Icon picker color toggle"), isOn: $useCustomColor)
                    .fixedSize()
                ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                    .disabled(!useCustomColor)
                    .frame(width: 44)
                Spacer()
            }
            .padding(.horizontal, 16)
            Divider()
            HStack {
                Button(NSLocalizedString("Reset to Default", comment: "Icon picker reset")) {
                    selectedIcon = nil
                    useCustomColor = false
                }
                .disabled(selectedIcon == nil && !useCustomColor)

                Spacer()

                Button(NSLocalizedString("Cancel", comment: "")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(NSLocalizedString("Apply", comment: "Icon picker apply")) {
                    StatusBarIconStore.setIconName(selectedIcon, forHostsPath: hostsPath)
                    let nsColor = useCustomColor ? NSColor(selectedColor) : nil
                    StatusBarIconStore.setIconColor(nsColor, forHostsPath: hostsPath)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Icon Data

    private var filteredCategories: [IconCategory] {
        if searchText.isEmpty { return Self.iconCategories }
        let query = searchText.lowercased()
        let result = Self.iconCategories.compactMap { category -> IconCategory? in
            let matched = category.icons.filter { $0.lowercased().contains(query) }
            guard !matched.isEmpty else { return nil }
            return IconCategory(title: category.title, icons: matched)
        }
        return result
    }

    struct IconCategory: Identifiable {
        let title: String
        let icons: [String]
        var id: String { title }
    }

    static let iconCategories: [IconCategory] = [
        IconCategory(title: NSLocalizedString("Network", comment: "Icon category"), icons: [
            "network", "globe", "globe.americas.fill", "globe.europe.africa.fill", "globe.asia.australia.fill",
            "wifi", "antenna.radiowaves.left.and.right", "link", "personalhotspot",
            "cable.connector", "fibrechannel", "point.3.connected.trianglepath.dotted",
        ]),
        IconCategory(title: NSLocalizedString("Server & Infrastructure", comment: "Icon category"), icons: [
            "server.rack", "externaldrive.fill", "externaldrive.connected.to.line.below.fill",
            "externaldrive.badge.checkmark", "xserve",
            "cpu.fill", "memorychip.fill", "desktopcomputer", "laptopcomputer",
            "display", "keyboard.fill", "printer.fill",
        ]),
        IconCategory(title: NSLocalizedString("Development", comment: "Icon category"), icons: [
            "terminal.fill", "chevron.left.forwardslash.chevron.right", "hammer.fill", "wrench.fill",
            "wrench.and.screwdriver.fill", "screwdriver.fill",
            "gearshape.fill", "gearshape.2.fill", "tuningfork",
            "ladybug.fill", "ant.fill", "swift",
        ]),
        IconCategory(title: NSLocalizedString("Environment", comment: "Icon category"), icons: [
            "leaf.fill", "leaf.circle.fill", "flame.fill", "flame.circle.fill",
            "bolt.fill", "bolt.circle.fill", "star.fill", "star.circle.fill",
            "flag.fill", "flag.circle.fill", "flag.checkered", "flag.2.crossed.fill",
            "tag.fill", "tag.circle.fill",
            "bookmark.fill", "bookmark.circle.fill",
            "pin.fill", "pin.circle.fill", "mappin.circle.fill",
            "globe.desk.fill", "sparkle", "wand.and.stars",
            "hammer.circle.fill", "wrench.adjustable.fill",
            "theatermasks.fill", "fossil.shell.fill",
        ]),
        IconCategory(title: NSLocalizedString("Shapes & Status", comment: "Icon category"), icons: [
            "circle.fill", "square.fill", "diamond.fill",
            "triangle.fill", "hexagon.fill", "pentagon.fill",
            "octagon.fill", "seal.fill", "capsule.fill",
            "shield.fill", "checkmark.shield.fill", "shield.lefthalf.filled",
            "lock.fill", "lock.open.fill",
            "heart.fill", "heart.circle.fill",
        ]),
        IconCategory(title: NSLocalizedString("Indicators", comment: "Icon category"), icons: [
            "largecircle.fill.circle", "record.circle.fill", "target",
            "scope", "dot.radiowaves.left.and.right",
            "circle.grid.cross.fill", "circle.hexagongrid.fill",
            "circle.circle.fill", "smallcircle.filled.circle.fill",
        ]),
        IconCategory(title: NSLocalizedString("Symbols", comment: "Icon category"), icons: [
            "exclamationmark.triangle.fill",
            "info.circle.fill",
            "questionmark.circle.fill",
            "xmark.circle.fill", "xmark.octagon.fill",
            "checkmark.circle.fill", "checkmark.seal.fill",
            "minus.circle.fill",
            "plus.circle.fill",
            "number.circle.fill", "a.circle.fill",
        ]),
        IconCategory(title: NSLocalizedString("Buildings & Locations", comment: "Icon category"), icons: [
            "house.fill", "building.fill", "building.2.fill", "building.columns.fill",
            "storefront.fill",
            "mappin.and.ellipse",
        ]),
        IconCategory(title: NSLocalizedString("Cloud & Weather", comment: "Icon category"), icons: [
            "cloud.fill", "icloud.fill", "cloud.bolt.fill", "cloud.rain.fill",
            "moon.fill", "sun.max.fill", "sparkles", "snowflake",
            "wind", "thermometer.medium",
        ]),
        IconCategory(title: NSLocalizedString("Transport", comment: "Icon category"), icons: [
            "airplane", "car.fill", "bus.fill", "tram.fill",
            "ferry.fill", "bicycle",
        ]),
        IconCategory(title: NSLocalizedString("Communication", comment: "Icon category"), icons: [
            "bell.fill", "bell.badge.fill", "bell.slash.fill",
            "envelope.fill", "paperplane.fill",
            "phone.fill", "bubble.fill",
            "megaphone.fill",
        ]),
        IconCategory(title: NSLocalizedString("Media", comment: "Icon category"), icons: [
            "play.fill", "pause.fill", "stop.fill",
            "forward.fill", "backward.fill",
            "music.note", "music.mic",
            "speaker.wave.3.fill",
        ]),
        IconCategory(title: NSLocalizedString("People", comment: "Icon category"), icons: [
            "person.fill", "person.2.fill", "person.crop.circle.fill",
            "figure.stand", "hand.raised.fill", "hand.thumbsup.fill",
            "eye.fill", "eye.slash.fill",
        ]),
        IconCategory(title: NSLocalizedString("Objects & Tools", comment: "Icon category"), icons: [
            "doc.fill", "folder.fill", "tray.fill",
            "archivebox.fill", "shippingbox.fill",
            "paintbrush.fill", "paintpalette.fill", "scissors",
            "bandage.fill", "cross.fill",
            "key.fill", "creditcard.fill", "cart.fill",
            "gift.fill", "trophy.fill", "medal.fill",
        ]),
        IconCategory(title: NSLocalizedString("Energy & Science", comment: "Icon category"), icons: [
            "power", "bolt.circle.fill", "atom",
            "waveform", "waveform.circle.fill",
            "battery.100", "lightbulb.fill",
            "puzzlepiece.fill",
        ]),
        IconCategory(title: NSLocalizedString("Nature & Animals", comment: "Icon category"), icons: [
            "tree.fill", "leaf.fill", "camera.macro",
            "mountain.2.fill", "water.waves", "drop.fill",
            "sun.horizon.fill", "moon.stars.fill", "rainbow",
            "snowflake", "wind", "flame.fill",
            "tortoise.fill", "hare.fill", "bird.fill",
            "fish.fill", "lizard.fill", "cat.fill",
            "dog.fill", "pawprint.fill", "ladybug.fill",
            "ant.fill", "spider.fill", "fossil.shell.fill",
            "carrot.fill", "tree.circle.fill", "laurel.leading",
        ]),
        IconCategory(title: NSLocalizedString("Arrows & Directions", comment: "Icon category"), icons: [
            "arrow.up.circle.fill", "arrow.down.circle.fill",
            "arrow.left.circle.fill", "arrow.right.circle.fill",
            "arrow.triangle.2.circlepath.circle.fill",
            "location.fill", "location.circle.fill",
            "safari.fill", "compass.drawing",
        ]),
    ]
}
