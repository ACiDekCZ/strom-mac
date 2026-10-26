import AppKit
import SwiftUI

/// Colours of the host window (§8): paper background, cards, labels; dark tokens from §0.
struct HostPalette {
    var window, card, cardBorder, label, text, muted, primary, primaryText, secondaryBorder, warnFill, warnBorder, warnTitle, code, ok, ring: Color

    static let light = HostPalette(
        window: Color(hex: 0xf6f2ea), card: Color(hex: 0xfffdf8), cardBorder: Color(hex: 0xddd4c2), label: Color(hex: 0x8a5528),
        text: Color(hex: 0x2b2822), muted: Color(hex: 0x5c5546), primary: Color(hex: 0x3f6b4f), primaryText: .white,
        secondaryBorder: Color(hex: 0xb9ad95), warnFill: Color(hex: 0xfbf5e6), warnBorder: Color(hex: 0xe8d7ae),
        warnTitle: Color(hex: 0x7f5500), code: Color(hex: 0xf1ece1), ok: Color(hex: 0x3f6b4f), ring: Color(hex: 0xa59d8c))

    static let dark = HostPalette(
        window: Color(hex: 0x211f1a), card: Color(hex: 0x2c2a24), cardBorder: Color(hex: 0x3e3a30), label: Color(hex: 0xc98d59),
        text: Color(hex: 0xe8e3d6), muted: Color(hex: 0xa89f8d), primary: Color(hex: 0x6f9c7f), primaryText: Color(hex: 0x1b1a16),
        secondaryBorder: Color(hex: 0x5e513f), warnFill: Color(hex: 0x3a3324), warnBorder: Color(hex: 0x5e513f),
        warnTitle: Color(hex: 0xe8c47c), code: Color(hex: 0x34302a), ok: Color(hex: 0x6f9c7f), ring: Color(hex: 0x9a927f))
}

private struct HostPaletteReader<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    var content: (HostPalette) -> Content
    var body: some View { content(scheme == .dark ? .dark : .light) }
}

func withHostPalette<Content: View>(@ViewBuilder _ content: @escaping (HostPalette) -> Content) -> some View {
    HostPaletteReader(content: content)
}

struct HostActions {
    var setLanguage: (LanguageChoice) -> Void = { _ in }
    var allowAccess: () -> Void = {}
    var uninstall: () -> Void = {}
    var openHelp: (URL) -> Void = { _ in }
}

struct HostSectionLabel: View {
    var text: String
    var lang: Lang
    var body: some View {
        withHostPalette { p in
            Text(text.uppercased(with: lang.locale))
                .font(.system(size: 11, weight: .semibold))
                .tracking(11 * 0.08)
                .foregroundStyle(p.label)
        }
    }
}

/// „S.“ app icon drawn in SwiftUI (window header, how-to picture).
struct IconTile: View {
    var size: CGFloat
    var body: some View {
        withHostPalette { _ in
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0xfffdf8), Color(hex: 0xefe8d9)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.18), radius: size * 0.04, y: size * 0.02)
                RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                    .strokeBorder(Color(hex: 0xddd4c2), lineWidth: 1)
                HStack(spacing: 0) {
                    Text("S").foregroundStyle(Color(hex: 0x2b2822))
                    Text(".").foregroundStyle(Color(hex: 0xb0703c))
                }
                .font(.custom("Georgia-Bold", fixedSize: size * 0.5))
            }
            .frame(width: size, height: size)
        }
    }
}

/// Code word inside a sentence (`strom`) on the code background, padded by thin spaces.
private func codeText(_ s: String, _ background: Color) -> Text {
    var a = AttributedString("\u{2009}\(s)\u{2009}")
    a.font = .system(size: 13, design: .monospaced)
    a.backgroundColor = background
    return Text(a)
}

struct HostMainView: View {
    var snapshot: HostSnapshot
    var actions = HostActions()
    @State private var confirmUninstall = false

    private var L: L10n { snapshot.lang.strings }

    var body: some View {
        withHostPalette { p in
            VStack(alignment: .leading, spacing: 0) {
                header(p).padding(.bottom, 22)
                switch snapshot.access {
                case .ok:
                    HostSectionLabel(text: L.appResearches, lang: snapshot.lang).padding(.bottom, 8)
                    researchList(p)
                    (Text(L.appStartPrefix + " ") + codeText("strom", p.code) + Text(L.appStartSuffix))
                        .font(.system(size: 12.5)).foregroundStyle(p.muted)
                        .padding(.top, 10)
                case .noResearch:
                    noResearchCard(p)
                case .noAccess:
                    noAccessCard(p)
                }
                HostSectionLabel(text: L.appHowTo, lang: snapshot.lang).padding(.top, 24).padding(.bottom, 10)
                howTo(p)
                Rectangle().fill(p.cardBorder).frame(height: 1).padding(.top, 20).padding(.bottom, 14)
                footer(p)
            }
            .padding(.horizontal, 24)
            .padding(.top, 34)
            .padding(.bottom, 22)
            .frame(width: 560)
            .background(p.window)
            .environment(\.locale, snapshot.lang.locale)
            .sheet(isPresented: $confirmUninstall) {
                UninstallSheet(lang: snapshot.lang, onCancel: { confirmUninstall = false },
                               onConfirm: { confirmUninstall = false; actions.uninstall() })
            }
        }
    }

    private func header(_ p: HostPalette) -> some View {
        HStack(spacing: 14) {
            IconTile(size: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(L.appName).font(.system(size: 18, weight: .semibold)).foregroundStyle(p.text)
                Text(L.appTagline).font(.system(size: 13)).foregroundStyle(p.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func researchList(_ p: HostPalette) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(snapshot.rows.enumerated()), id: \.element.id) { i, row in
                if i > 0 { Rectangle().fill(p.cardBorder.opacity(0.7)).frame(height: 1).padding(.horizontal, 14) }
                HStack(spacing: 12) {
                    Group {
                        if row.running { Circle().fill(p.ok) } else { Circle().strokeBorder(p.ring, lineWidth: 1.5) }
                    }
                    .frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.name).font(.system(size: 14)).foregroundStyle(p.text).lineLimit(1)
                        Text(row.detail).font(.system(size: 12)).foregroundStyle(p.muted).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.widgets).font(.system(size: 12)).foregroundStyle(p.muted).fixedSize()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
            }
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(p.card))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(p.cardBorder, lineWidth: 1))
    }

    private func noResearchCard(_ p: HostPalette) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L.appNoneTitle).font(.system(size: 14, weight: .semibold)).foregroundStyle(p.text)
            (Text(L.appNoneBodyPrefix + (snapshot.lang == .cs ? " " : "")) + codeText("strom", p.code) + Text(")."))
                .font(.system(size: 12.5)).foregroundStyle(p.muted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(p.card))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(p.cardBorder, lineWidth: 1))
    }

    private func noAccessCard(_ p: HostPalette) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(L.appAccessTitle).font(.system(size: 14, weight: .semibold)).foregroundStyle(p.warnTitle)
                Text(L.appAccessBody).font(.system(size: 12.5)).foregroundStyle(p.muted).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(L.appAccessButton) { actions.allowAccess() }
                .buttonStyle(HostPrimaryButtonStyle())
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 10).fill(p.warnFill))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(p.warnBorder, lineWidth: 1))
    }

    private func howTo(_ p: HostPalette) -> some View {
        HStack(alignment: .top, spacing: 18) {
            HowToPicture(lang: snapshot.lang).frame(width: 220, height: 148)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(L.appSteps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(i + 1).").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(p.text).frame(width: 16, alignment: .leading)
                        Text(LocalizedStringKey(step)).font(.system(size: 12.5)).foregroundStyle(p.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func footer(_ p: HostPalette) -> some View {
        HStack(spacing: 10) {
            Text(L.appLanguage).font(.system(size: 13)).foregroundStyle(p.muted)
            let options: [(LanguageChoice, String)] = [
                (.auto, L.appLanguageAuto(L.languageName(snapshot.autoLanguage))),
                (.cs, L10n.nativeName(.cs)), (.en, L10n.nativeName(.en)), (.de, L10n.nativeName(.de))]
            Button {
                PopUpMenu.show(options.map { option in
                    (option.1, option.0 == snapshot.languageChoice, { actions.setLanguage(option.0) })
                })
            } label: {
                HStack(spacing: 8) {
                    Text(options.first { $0.0 == snapshot.languageChoice }?.1 ?? "")
                    Text("▾").font(.system(size: 9)).foregroundStyle(p.muted)
                }
            }
            .buttonStyle(HostSecondaryButtonStyle())
            Spacer()
            if let help = snapshot.helpURL {
                Button(L.appHelp) { actions.openHelp(help) }
                    .buttonStyle(.plain).font(.system(size: 13, weight: .medium)).foregroundStyle(p.primary)
            }
            Button(L.appUninstall) { confirmUninstall = true }
                .buttonStyle(HostSecondaryButtonStyle())
        }
    }
}

struct HostPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        withHostPalette { p in
            configuration.label
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(p.primaryText)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 7).fill(p.primary.opacity(configuration.isPressed ? 0.8 : 1)))
        }
    }
}

struct HostSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        withHostPalette { p in
            configuration.label
                .font(.system(size: 13))
                .foregroundStyle(p.text)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 7).fill(p.card.opacity(configuration.isPressed ? 0.7 : 1)))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(p.secondaryBorder, lineWidth: 1))
        }
    }
}

/// Stylised desktop with the context menu and the widget gallery (§8; the design is a stylisation too).
struct HowToPicture: View {
    var lang: Lang
    var body: some View {
        let L = lang.strings
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Color(hex: 0x7d8b96), Color(hex: 0x4a5661)], startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(L.howToMenu.enumerated()), id: \.offset) { i, item in
                        Text(item)
                            .font(.system(size: 8))
                            .foregroundStyle(i == 1 ? Color.white : Color(hex: 0x2b2822))
                            .lineLimit(1)
                            .padding(.horizontal, 6).padding(.vertical, 2.5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 3).fill(i == 1 ? Color(hex: 0x3f6b4f) : .clear))
                    }
                }
                .padding(3)
                .frame(width: 100)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color(hex: 0xf3f1ec)))
                .padding(.leading, 14).padding(.top, 13)
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(Color.white.opacity(0.75), style: StrokeStyle(lineWidth: 1, dash: [3, 2.5]))
                    .frame(width: 52, height: 52)
                    .padding(.leading, 150).padding(.top, 22)
            }
            .frame(height: 90)
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(L.howToSearch)
                    Text("Strom")
                }
                .font(.system(size: 7.5)).foregroundStyle(Color(hex: 0x5c5546))
                .frame(width: 38, alignment: .leading)
                IconTile(size: 34)
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color(hex: 0x3f6b4f), lineWidth: 1.5).padding(-3))
                    .padding(.horizontal, 3)
                RoundedRectangle(cornerRadius: 7).fill(Color(hex: 0xfffdf8)).frame(width: 64, height: 36)
                RoundedRectangle(cornerRadius: 7).fill(Color(hex: 0xf6f4f0)).frame(height: 36)
            }
            .padding(.horizontal, 9)
            .frame(maxHeight: .infinity)
            .background(Color(hex: 0xe4e2de))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.black.opacity(0.08), lineWidth: 1))
    }
}

/// 8c: sheet with the default button Cancel.
struct UninstallSheet: View {
    var lang: Lang
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        let L = lang.strings
        withHostPalette { p in
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 14) {
                    IconTile(size: 44)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L.uninstallTitle).font(.system(size: 14, weight: .semibold)).foregroundStyle(p.text)
                        Text(L.uninstallBody).font(.system(size: 12.5)).foregroundStyle(p.muted).fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack(spacing: 10) {
                    Spacer()
                    Button(L.uninstallConfirm, action: onConfirm).buttonStyle(HostSecondaryButtonStyle())
                    Button(L.uninstallCancel, action: onCancel).buttonStyle(HostPrimaryButtonStyle()).keyboardShortcut(.defaultAction)
                }
                .padding(.top, 6)
            }
            .padding(20)
            .frame(width: 420)
            .background(p.card)
        }
    }
}

/// 7d: the Strom app could not be opened; the address can be copied.
struct OpenFailedView: View {
    var lang: Lang
    var what: String?
    var address: String
    var onCopy: () -> Void
    var onClose: () -> Void

    var body: some View {
        let L = lang.strings
        withHostPalette { p in
            VStack(alignment: .leading, spacing: 12) {
                Text(L.openFailedTitle).font(.system(size: 15, weight: .semibold)).foregroundStyle(p.text)
                Text(L.openFailedBody(what ?? L.openFailedWhatDefault)).font(.system(size: 13)).foregroundStyle(p.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text(address)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(p.text)
                    .lineLimit(2)
                    .textSelection(.enabled)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 7).fill(p.code))
                HStack(spacing: 10) {
                    Spacer()
                    Button(L.openFailedCopy, action: onCopy).buttonStyle(HostSecondaryButtonStyle())
                    Button(L.openFailedClose, action: onClose).buttonStyle(HostPrimaryButtonStyle()).keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(width: 380)
            .background(p.card)
        }
    }
}

/// Language menu drawn like the design (8a): a bordered button that opens a plain menu at the pointer.
/// A SwiftUI `Picker` would be an AppKit pop-up button with a different look.
@MainActor
enum PopUpMenu {
    private final class Target: NSObject {
        let action: () -> Void
        init(_ action: @escaping () -> Void) { self.action = action }
        @objc func run() { action() }
    }

    static func show(_ items: [(title: String, checked: Bool, action: () -> Void)]) {
        let menu = NSMenu()
        var targets: [Target] = []
        for item in items {
            let target = Target(item.action)
            targets.append(target)
            let menuItem = NSMenuItem(title: item.title, action: #selector(Target.run), keyEquivalent: "")
            menuItem.target = target
            menuItem.state = item.checked ? .on : .off
            menu.addItem(menuItem)
        }
        // The menu item holds its target weakly; keep the targets alive while the menu is open.
        withExtendedLifetime(targets) {
            _ = menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
    }
}
