# Windows 치이카와 펫

Windows 10/11용 네이티브 C# / WPF 앱입니다. macOS 버전의 스프라이트를 그대로 사용합니다.

## 실행

`ChiikawaPet-win-x64.zip`을 **모두 압축 해제**한 뒤 `ChiikawaPet.exe`를 실행하세요. 런타임이 포함되어 있어 .NET을 따로 설치할 필요가 없습니다. EXE만 다른 폴더로 옮기면 실행되지 않습니다. 서명되지 않은 로컬 빌드입니다.

펫은 기본적으로 화면 오른쪽 아래에 표시됩니다. 작업 표시줄에는 표시되지 않으며 알림 영역의 펫 아이콘으로 제어합니다. Windows가 아이콘을 숨겼다면 알림 영역의 `^` 버튼을 확인하세요.

| 조작 | 동작 |
|---|---|
| 펫 클릭 / 트레이 아이콘 왼쪽 클릭 | 사용량 패널 열기 / 닫기 |
| 펫 드래그 | 이동 및 위치 저장 |
| 펫 우클릭 / 트레이 아이콘 우클릭 | 캐릭터·표시·산책·새로고침·화면 가운데 이동·종료 |
| 사용량 패널 | 캐릭터 선택, 크기 40–120% 조절, 기본값 65%, 표시 및 산책 설정 |
| 패널 밖 클릭 / Escape / 닫기 | 패널 닫기 |

설정은 `%LOCALAPPDATA%\ChiikawaPet\settings.json`에 저장합니다. 모니터 구성이 바뀌어 저장된 위치가 화면 밖이면 화면 안으로 옮깁니다. 펫을 숨겨도 트레이와 사용량 조회는 유지하며 애니메이션은 멈춥니다. 미리보기에서는 설정을 저장하지 않습니다.

## 계정 연결

- Claude: **Windows에 설치된** Claude Code에서 `/login`하세요. `%USERPROFILE%\.claude\.credentials.json`을 읽습니다.
- Codex: Windows 터미널에서 `codex login`하세요. `%USERPROFILE%\.codex\auth.json`의 ChatGPT OAuth 로그인을 읽습니다. API 키는 구독 잔여 퍼센트가 없습니다.
- `CLAUDE_CONFIG_DIR`, `CODEX_HOME`을 지원합니다. 환경 변수를 설정한 터미널에서 EXE를 실행하면 해당 경로를 사용합니다.
- WSL 내부 로그인 파일과 Windows Credential Manager는 자동으로 읽지 않습니다. WSL 파일을 사용하려면 해당 파일에 접근할 수 있는 Windows 경로를 환경 변수로 지정하세요. Credential Manager 전용 저장은 현재 미지원입니다.
- 토큰을 갱신하거나 인증 파일을 수정하지 않습니다. CLI에서 다시 로그인한 뒤 패널의 새로고침을 누르세요.

기존 토큰은 각 제공자의 HTTPS 사용량 엔드포인트에만 전송하며 리디렉션·쿠키·인증정보 로그를 사용하지 않습니다. 두 서비스는 동시에 조회하고 2분마다 갱신합니다. 조회 실패 시 이전 값에는 이전 데이터임을 표시하며 표정과 트레이 잔여량에서 제외합니다. 숫자는 내림하고, 표정은 소수 퍼센트에 따라 macOS 버전과 동일한 경계로 바뀝니다. 제공되는 기간별 한도만 표시합니다.

## 소스 빌드

[.NET 10 SDK](https://dotnet.microsoft.com/en-us/download/dotnet/10.0)를 설치한 뒤 저장소 루트에서 실행하세요.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-windows.ps1
```

테스트 후 `build\windows\win-x64\ChiikawaPet.exe`와 포터블 ZIP이 생성됩니다. ARM64용은 `-Runtime win-arm64`를 추가하세요.

Mac/Linux에서도 [.NET Windows 타기팅](https://learn.microsoft.com/en-us/dotnet/core/tools/sdk-errors/netsdk1100)으로 컴파일할 수 있습니다.

```sh
dotnet run --project windows/Checks/Checks.csproj -c Release
dotnet publish windows/ChiikawaPet.csproj -c Release -r win-x64 --self-contained true -o build/windows/win-x64
```

UI와 트레이 동작은 Windows에서 확인해야 합니다. 로직 검증은 네트워크나 실제 로그인 없이 사용량 응답, 표정 경계, 오류 후 복구, 인증 유효성, 설정 저장을 확인합니다.

표정 미리보기는 기존 앱을 종료한 뒤 실행하며 네트워크 조회를 하지 않습니다.

```powershell
.\build\windows\win-x64\ChiikawaPet.exe --preview 10 --show-usage
```

Windows에서 확인할 항목: 투명 배경과 프레임 애니메이션, 드래그/클릭 구분, 트레이에서 숨긴 펫 복원 및 종료, 실제 계정 새로고침, 혼합 DPI 모니터 간 이동, 재실행 후 설정 복원.
