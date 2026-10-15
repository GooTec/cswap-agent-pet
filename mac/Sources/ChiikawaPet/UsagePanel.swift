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
        .environment(\.locale, store.language.locale)
        .environment(\.colorScheme, .light)
    }

    var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("CHIIKAWA PET")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(2).foregroundStyle(.secondary)
                    Text(T("\(store.selectedCharacter.name)의 에너지"))
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                    Text(store.mood.caption).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                SpritePreview(character: store.selectedCharacter, remainingPercent: store.remainingPercent)
                    .frame(width: 68, height: 84).accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
            Picker("Language / 언어", selection: $store.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.title).tag(language)
                }
            }
            .pickerStyle(.segmented)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(PetCharacter.allCases) { character in
                    CharacterCard(
                        character: character,
                        remainingPercent: store.remainingPercent,
                        isSelected: store.selectedCharacter == character,
                        account: store.account(for: character)?.label
                    ) {
                        store.selectCharacter(character)
                    }
                }
            }
            if store.usesSwap {
                AccountsSection(store: store)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(T("펫 크기")).font(.system(size: 12, weight: .semibold))
                    Text("\(Int((store.petScale * 100).rounded()))%")
                        .font(.system(size: 12, weight: .medium)).monospacedDigit()
                    Spacer()
                    Button(T("기본값 65%")) {
                        store.setPetScale(UsageStore.defaultPetScale)
                    }
                    .controlSize(.small)
                    .accessibilityLabel(T("펫 크기를 기본값 65%로 재설정"))
                }
                Slider(
                    value: Binding(get: { store.petScale }, set: { store.setPetScale($0) }),
                    in: UsageStore.petScaleRange,
                    step: 0.05
                ) {
                    Text(T("펫 크기"))
                } minimumValueLabel: {
                    Text("40%").font(.system(size: 10))
                } maximumValueLabel: {
                    Text("120%").font(.system(size: 10))
                }
                .accessibilityLabel(T("펫 크기"))
                .accessibilityValue("\(Int((store.petScale * 100).rounded()))%")
                Toggle(T("화면에 펫 표시"), isOn: $store.isPetVisible)
                    .toggleStyle(.switch).controlSize(.small).font(.system(size: 12))
                    .accessibilityLabel(T("화면에 펫 표시"))
                Text(T("숨겨도 메뉴바에서 사용량과 펫을 확인할 수 있어요."))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if store.previewPercent != nil {
                Text(T("표정 미리보기 · 실제 사용량이 아닙니다"))
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.orange)
            }
            ForEach(store.providers, id: \.provider) { provider in
                ProviderCard(display: provider, refreshing: store.isRefreshing)
            }
            HStack(spacing: 6) {
                Circle().fill(store.remainingPercent == nil ? Color.gray : Color.green)
                    .frame(width: 5, height: 5)
                Text(T("표정은 조회된 한도 중 가장 낮은 잔여량 기준"))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Divider()
            HStack {
                Toggle(T("느긋하게 산책하기"), isOn: $store.wanders)
                    .toggleStyle(.switch).controlSize(.small).font(.system(size: 12))
                Spacer()
                Button {
                    Task { await store.refresh(allowKeychainPrompt: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(store.isRefreshing || store.previewPercent != nil)
                .help(T("로그인 정보 연결 및 사용량 새로고침"))
                .accessibilityLabel(T("사용량 새로고침 및 연결"))
            }
            HStack {
                Text(T("클릭: 사용량 · 드래그: 이동 · 우클릭: 메뉴"))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Button(T("종료")) { NSApp.terminate(nil) }
                    .font(.system(size: 10)).buttonStyle(.borderless).foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .foregroundStyle(petInk)
        .frame(width: Self.width)
        .fixedSize(horizontal: false, vertical: true)
        .environment(\.locale, store.language.locale)
        .environment(\.colorScheme, .light)
    }
}

private struct CharacterCard: View {
    let character: PetCharacter
    let remainingPercent: Double?
    let isSelected: Bool
    let account: String?
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
                if let account {
                    Text(account).font(.system(size: 9)).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle).padding(.horizontal, 6)
                }
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
            Button(T("\(character.name) 선택"), action: select)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }
}

private struct AccountsSection: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(T("Claude 계정")).font(.system(size: 12, weight: .semibold))
                if store.isSwitchingAccount {
                    ProgressView().controlSize(.mini)
                }
                Spacer()
                Toggle(T("자동 전환"), isOn: Binding(
                    get: { store.swap?.autoSwitchEnabled ?? false },
                    set: { enabled in Task { await store.setAutoSwitch(enabled) } }
                ))
                .toggleStyle(.switch).controlSize(.mini).font(.system(size: 11))
                .disabled(store.swap == nil || store.isSwitchingAccount)
            }
            ForEach(store.swap?.accounts ?? []) { account in
                AccountRow(store: store, account: account)
            }
            HStack {
                Button(T("여유 있는 계정으로")) { Task { await store.switchToBestAccount() } }
                Button(T("현재 로그인 계정 등록")) { Task { await store.addCurrentAccount() } }
            }
            .controlSize(.small)
            .disabled(store.isSwitchingAccount)
            Text(T("새 계정은 터미널에서 claude 실행 후 /login으로 로그인한 다음 등록하세요."))
                .font(.system(size: 9)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let message = store.swapMessage {
                Text(T(message)).font(.system(size: 10)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct AccountRow: View {
    @ObservedObject var store: UsageStore
    let account: SwapAccount

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(PetCharacter.allCases) { character in
                    Button(character.name) { store.assign(character, to: account) }
                }
            } label: {
                Text(store.character(for: account)?.name ?? "—").font(.system(size: 11, weight: .semibold))
            }
            .menuStyle(.borderlessButton).fixedSize()
            .help(T("이 계정의 캐릭터"))
            Button {
                Task { await store.switchAccount(to: account) }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.label).font(.system(size: 11, weight: account.isActive ? .bold : .regular))
                        .lineLimit(1).truncationMode(.middle)
                    Text(usageSummary).font(.system(size: 9)).foregroundStyle(.secondary).monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(account.isActive || store.isSwitchingAccount)
            if account.isActive {
                Text(T("사용 중")).font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color(red: 0.95, green: 0.85, blue: 0.79), in: Capsule())
            }
        }
        .padding(8)
        .background(.white.opacity(account.isActive ? 0.95 : 0.6), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }

    private var usageSummary: String {
        func percent(_ value: Double?) -> String { value.map { "\(Int($0.rounded(.down)))%" } ?? "—" }
        return T("5시간 \(percent(account.fiveHourRemaining)) · 주간 \(percent(account.weeklyRemaining)) 남음")
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
                    + Text(T("% 남음")).font(.system(size: 11, weight: .medium))
                } else {
                    Text(refreshing ? T("조회 중…") : T("연결 필요"))
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                }
            }
            if let reading = display.reading {
                ForEach(Array(reading.windows.enumerated()), id: \.offset) { _, window in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(T(window.title))
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
                            Text(T("\(reset.formatted(.dateTime.year().month().day().hour().minute().locale(AppLanguage.current.locale))) 초기화"))
                                .font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    }
                }
                Text(T("\(reading.fetchedAt.formatted(.dateTime.hour().minute().second().locale(AppLanguage.current.locale))) 조회\(display.error == nil ? " · 2분마다 갱신" : " · 이전 데이터")"))
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }
            if let error = display.error {
                Text(T(error)).font(.system(size: 11)).foregroundStyle(Color(red: 0.66, green: 0.32, blue: 0.28))
                    .fixedSize(horizontal: false, vertical: true)
            } else if display.reading == nil && !refreshing {
                Text(display.provider == .claude ? T("Claude Code의 로그인 정보를 연결합니다.") : T("Codex의 ChatGPT 로그인 정보를 연결합니다."))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if display.reading == nil || display.error != nil {
                Text(T("아래 새로고침 버튼으로 연결 · 인증 정보는 이 Mac에만"))
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
