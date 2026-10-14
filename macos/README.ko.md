# macOS 치이카와 펫

[English](README.md) | [한국어](README.ko.md)

macOS 14 이상에서 실행하는 비공식 도트 펫입니다. Swift·AppKit·SwiftUI를 사용하며
Dock 아이콘 없이 메뉴바에서 제어합니다.

## 설치

Apple Silicon은 `macos-arm64.dmg`, Intel은 `macos-x86_64.dmg`를 선택하세요.
DMG를 열고 `ChiikawaPet.app`을 응용 프로그램 폴더로 옮긴 뒤 실행합니다.
업데이트할 때는 실행 중인 펫을 먼저 종료한 뒤 앱을 교체하세요.

현재 앱은 ad-hoc 서명이며 Apple Developer ID 공증은 없습니다. macOS가 차단하면
소스와 릴리즈 체크섬을 확인한 뒤 실행을 원할 경우 시스템 설정 → 개인정보 보호 및
보안 → 확인 없이 열기 옵션을 사용할 수 있습니다.

## 조작

- 펫 클릭으로 사용량 패널을 열고 닫으며, 드래그로 이동합니다.
- 펫 우클릭이나 메뉴바 항목 클릭으로 제어 메뉴를 엽니다.
- 패널에서 캐릭터 선택, 크기 40–120% 조절(기본 65%), 산책·표시 설정, 새로고침·종료를 합니다.
- 데스크톱 펫을 숨겨도 메뉴바는 유지됩니다.

메뉴바에는 캐릭터, 서비스 로고, 현재 잔여량을 표시합니다. Claude는 조회된 첫 두
한도를, Codex는 조회된 한도 중 최솟값을 표시합니다. 실패·미연결 서비스는 `—`입니다.

## 계정 연결

Claude Code에서 `/login`하거나 Codex에서 `codex login`한 뒤 **새로고침**을 누르세요.
기본 CLI 인증 파일이나 해당 macOS 키체인을 읽습니다. 자동 조회는 키체인 인증 창을
띄우지 않으므로 권한이 필요하면 직접 새로고침해서 허용하세요.

`CLAUDE_CONFIG_DIR`, `CODEX_HOME`으로 커스텀 경로를 사용할 수 있습니다.
Finder는 셸 환경 변수를 상속하지 않으므로 설정한 터미널에서 설치 앱 내부 실행 파일을 실행하세요.

```sh
/Applications/ChiikawaPet.app/Contents/MacOS/ChiikawaPet
```

펫은 토큰을 갱신하거나 CLI 인증 파일·키체인을 수정하지 않습니다.
기존 CLI에서 재인증하세요. API 키 요금제에는 구독 잔여 퍼센트가 없습니다.

## 소스 빌드

Xcode 또는 Command Line Tools로 Swift 6 이상을 설치한 뒤 저장소 루트에서 실행합니다.

```sh
./Launch.command
./scripts/test.sh
./scripts/package-macos.sh arm64
```

Intel DMG는 `x86_64`를 지정합니다. 배포 파일은 `build/release/1.0.0/`에 생성됩니다.
미리보기는 기존 앱을 종료한 뒤 실행하며 실제 사용량을 조회하지 않습니다.

```sh
open -n build/ChiikawaPet.app --args --preview 10 --show-usage
```

Hidden Bar 배치·접기 동작은 완전히 검증하지 않았습니다.
소스 코드는 MIT입니다. 배포본에는 `LICENSE`와 캐릭터 이미지·로고의 별도 범위를 안내하는
`ARTWORK-NOTICE.md`를 포함합니다.
