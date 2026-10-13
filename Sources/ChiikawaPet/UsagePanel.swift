import AppKit
import SwiftUI

private let petInk = Color(red: 0.24, green: 0.22, blue: 0.29)
private let petPaper = Color(red: 1, green: 0.98, blue: 0.95)

struct UsagePanel: View {
    static let width: CGFloat = 360
    @ObservedObject var store: UsageStore

    var body: some View {
        ScrollView(.vertical) {
            content
        }
        .frame(width: Self.width)
        .background(petPaper)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(petInk.opacity(0.08)))
        .environment(\.colorScheme, .light)
    }

    var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("CHIIKAWA PET")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(2).foregroundStyle(.secondary)
                    Text("\(store.selectedCharacter.name)의 에너지")
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                    Text(store.mood.caption).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                SpritePreview(character: store.selectedCharacter, remainingPercent: store.remainingPercent)
                    .frame(width: 68, height: 84).accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
            HStack(spacing: 8) {
                ForEach(PetCharacter.allCases) { character in
                    CharacterCard(
                        character: character,
                        remainingPercent: store.remainingPercent,
                        isSelected: store.selectedCharacter == character
                    ) {
                        store.selectedCharacter = character
                    }
                }
            }
            if store.previewPercent != nil {
                Text("표정 미리보기 · 실제 사용량이 아닙니다")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.orange)
            }
            ForEach(store.providers, id: \.provider) { provider in
                ProviderCard(display: provider, refreshing: store.isRefreshing)
            }
            HStack(spacing: 6) {
                Circle().fill(store.remainingPercent == nil ? Color.gray : Color.green)
                    .frame(width: 5, height: 5)
                Text("표정은 조회된 한도 중 가장 낮은 잔여량 기준")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Divider()
            HStack {
                Toggle("느긋하게 산책하기", isOn: $store.wanders)
                    .toggleStyle(.switch).controlSize(.small).font(.system(size: 12))
                Spacer()
                Button {
                    Task { await store.refresh(allowKeychainPrompt: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(store.isRefreshing || store.previewPercent != nil)
                .help("로그인 정보 연결 및 사용량 새로고침")
                .accessibilityLabel("사용량 새로고침 및 연결")
            }
            HStack {
                Text("클릭: 사용량 · 드래그: 이동 · 우클릭: 메뉴")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Button("종료") { NSApp.terminate(nil) }
                    .font(.system(size: 10)).buttonStyle(.borderless).foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .foregroundStyle(petInk)
        .frame(width: Self.width)
        .fixedSize(horizontal: false, vertical: true)
        .environment(\.colorScheme, .light)
    }
}

private struct CharacterCard: View {
    let character: PetCharacter
    let remainingPercent: Double?
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(spacing: 6) {
                SpritePreview(character: character, remainingPercent: remainingPercent)
                    .frame(width: 76, height: 84)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                Text(character.name)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color(red: 0.95, green: 0.85, blue: 0.79) : .white.opacity(0.7), in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(petInk.opacity(isSelected ? 0.6 : 0.1), lineWidth: isSelected ? 2 : 1))
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(7)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Button("\(character.name) 선택", action: select)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }
}

private struct ProviderCard: View {
    let display: ProviderDisplay
    let refreshing: Bool
    private var accent: Color {
        display.provider == .claude
            ? Color(red: 0.78, green: 0.46, blue: 0.34)
            : Color(red: 0.32, green: 0.52, blue: 0.46)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 3).fill(accent).frame(width: 9, height: 9)
                    Text(display.provider.rawValue).font(.system(size: 15, weight: .bold))
                }
                Spacer()
                if let percent = display.reading?.remainingPercent {
                    Text("\(Int(percent.rounded(.down)))")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    + Text("% 남음").font(.system(size: 11, weight: .medium))
                } else {
                    Text(refreshing ? "조회 중…" : "연결 필요")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                }
            }
            if let reading = display.reading {
                ForEach(Array(reading.windows.enumerated()), id: \.offset) { _, window in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(window.title)
                            Spacer()
                            Text("\(Int(window.remainingPercent.rounded(.down)))%")
                                .monospacedDigit()
                        }.font(.system(size: 10, weight: .medium))
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(accent.opacity(0.10))
                                Capsule().fill(window.remainingPercent <= 10 ? Color(red: 0.78, green: 0.37, blue: 0.41) : accent)
                                    .frame(width: geometry.size.width * window.remainingPercent / 100)
                            }
                        }.frame(height: 5)
                        if let reset = window.resetsAt {
                            Text("\(reset.formatted(date: .abbreviated, time: .shortened)) 초기화")
                                .font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    }
                }
                Text("\(reading.fetchedAt.formatted(date: .omitted, time: .standard)) 조회\(display.error == nil ? " · 2분마다 갱신" : " · 이전 데이터")")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }
            if let error = display.error {
                Text(error).font(.system(size: 11)).foregroundStyle(Color(red: 0.66, green: 0.32, blue: 0.28))
                    .fixedSize(horizontal: false, vertical: true)
            } else if display.reading == nil && !refreshing {
                Text(display.provider == .claude ? "Claude Code의 로그인 정보를 연결합니다." : "Codex의 ChatGPT 로그인 정보를 연결합니다.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if display.reading == nil || display.error != nil {
                Text("아래 새로고침 버튼으로 연결 · 인증 정보는 이 Mac에만")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(accent.opacity(0.14)))
        .opacity(display.error != nil && display.reading != nil ? 0.65 : 1)
    }
}

private struct SpritePreview: NSViewRepresentable {
    let character: PetCharacter
    let remainingPercent: Double?
    func makeNSView(context: Context) -> PixelPetView { PixelPetView(frame: .zero) }
    func updateNSView(_ view: PixelPetView, context: Context) {
        view.character = character
        view.remainingPercent = remainingPercent
    }
}
