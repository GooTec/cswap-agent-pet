# 치이카와 펫

macOS 화면 위에 떠다니는 비공식 치이카와풍 도트 펫. 클릭하면 Claude·Codex 구독 사용량의 **잔여 퍼센트**를 확인합니다. Swift/AppKit/SwiftUI만 사용하며 외부 패키지 의존성이 없습니다.

## 실행

macOS 14 이상과 Swift 6 이상이 필요합니다. 개발 도구가 없으면 `xcode-select --install`로 설치하세요.

- `Launch.command`를 더블클릭하면 빌드 후 실행합니다.
- 이미 빌드했다면 `build/ChiikawaPet.app`을 더블클릭하세요. 이 앱을 응용 프로그램 폴더로 복사해 사용할 수도 있습니다.
- 터미널에서는 `./Launch.command` 또는 `./scripts/build-app.sh && open build/ChiikawaPet.app`을 실행합니다.

투명한 펫 창은 다른 일반 창보다 위에 표시됩니다. Dock 아이콘 없이 메뉴 막대의 발바닥 버튼으로 제어합니다.

| 조작 | 동작 |
|---|---|
| 펫 클릭 | 사용량 패널 열기 / 닫기 |
| 펫 드래그 | 위치 이동, 다음 실행에 복원 |
| 펫 우클릭 / 메뉴 막대 발바닥 | 사용량·새로고침·산책·화면 가운데 이동·종료 |
| 패널의 새로고침 | 로그인 정보 연결 및 최신 잔여량 조회 |
| 산책 스위치 | 느린 좌우 이동 켜기 / 끄기 |

마우스가 펫 가까이에 있거나 사용량 패널이 열리면 산책을 멈춥니다. 패널 밖을 클릭하면 패널이 닫힙니다.

## 실제 계정 연결

- **Claude:** Claude Code에서 `/login`으로 구독 계정에 로그인합니다. 기본 `~/.claude/.credentials.json` 또는 `Claude Code-credentials` 키체인의 OAuth 정보를 사용합니다.
- **Codex:** `codex login`으로 ChatGPT 계정에 로그인합니다. 기본 `~/.codex/auth.json` 또는 해당 설정 경로에 연결된 `Codex Auth` 키체인의 OAuth 정보를 사용합니다. API 키 요금제는 구독 잔여 %가 없으므로 별도로 안내합니다.
- 자동 조회는 키체인 인증 창을 띄우지 않습니다. 접근이 거부된 경우 패널의 새로고침을 누르고 macOS 키체인 접근을 허용하세요.
- 인증이 만료되면 기존 CLI를 실행하거나 다시 로그인한 뒤 새로고침하세요. 이 앱은 CLI 토큰을 갱신하거나 인증 파일·키체인을 수정하지 않습니다.
- `CLAUDE_CONFIG_DIR`, `CODEX_HOME` 환경 변수도 지원합니다. Finder로 실행한 앱은 터미널의 환경 변수를 상속하지 않으므로, 커스텀 경로는 해당 변수를 설정하고 앱 내부 실행 파일을 직접 실행하세요. 커스텀 Claude 경로는 다른 계정과 혼동하지 않도록 기본 키체인을 읽지 않습니다.

토큰은 기존 로컬 파일·키체인에서 읽어 해당 제공자의 HTTPS 사용량 엔드포인트에만 전송합니다. 별도 서버, 브라우저 쿠키 수집, 토큰 로그·저장 기능은 없습니다.

## 잔여량과 표정

잔여량은 `100 − 사용률`입니다. 각 서비스의 숫자는 조회된 기간별·모델별 한도 중 최솟값이며, 펫 표정은 정상 조회된 두 서비스의 최솟값을 기준으로 합니다. 합산하거나 평균 내지 않습니다. 기간별 잔여량과 초기화 시각은 패널에서 별도로 표시합니다. 정수 표시는 내림하고, 표정 경계는 원래 소수 퍼센트로 판정합니다.

| 잔여량 | 표정 |
|---|---|
| 95–100% | 활짝 웃음과 반짝임 |
| 60% 이상, 95% 미만 | 미소 |
| 30% 이상, 60% 미만 | 걱정 |
| 10% 초과, 30% 미만 | 울상 |
| **10% 이하** | 흐르는 눈물, 흐느끼는 입, 몸 떨림 |
| 조회값 없음 | 물음표, 연결 안내 — 0%로 취급하지 않음 |

앱 시작 시 조회하고 2분마다 갱신합니다. 조회 실패 시 이전 값은 흐리게 표시하고 오류·기존 조회 시각을 함께 남깁니다. 실패한 서비스의 이전 값은 표정 계산에서 제외합니다. Codex가 주간 한도만 제공하면 주간만 표시하며, 없는 5시간 한도를 만들어내지 않습니다.

사용량 엔드포인트는 공개된 관측 계약에 기반하며 공식적으로 안정성이 보장된 API가 아닙니다. 제공자의 응답·정책 변경으로 연동 수정이 필요할 수 있습니다. 참고: [Claude OAuth 동작](https://github.com/steipete/CodexBar/blob/main/docs/claude.md), [Codex 사용량 응답](https://github.com/gubasso/codex-session/blob/develop/docs/wham-usage-api-spec.md), [Codex 키체인 저장 계약](https://github.com/openai/codex/blob/main/codex-rs/login/src/auth/storage.rs).

## 검증

```sh
./scripts/test.sh
build/ChiikawaPet.app/Contents/MacOS/ChiikawaPet --usage
```

`test.sh`는 Xcode 없이 Command Line Tools만 설치된 환경에서도 포함된 Swift Testing 프레임워크 경로를 사용합니다. `--usage`는 실제 로그인으로 조회한 퍼센트 또는 연결 오류만 출력합니다.

표정 미리보기는 기존 앱을 종료한 뒤 실행합니다. 미리보기 패널에는 실제 사용량이 아니라는 표시가 있으며 네트워크 조회를 하지 않습니다.

```sh
open -n build/ChiikawaPet.app --args --preview 100 --show-usage
open -n build/ChiikawaPet.app --args --preview 10 --show-usage
```

공식 이미지 대신 코드로 직접 그린 도트 일러스트입니다. Chiikawa 원작·브랜드와 제휴한 앱이 아니며, 배포 시 캐릭터 관련 권리를 별도로 확인하세요.
