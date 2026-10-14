# 릴리즈

[English](RELEASING.md) | [한국어](RELEASING.ko.md)

## 버전 관리

루트 `VERSION`을 `MAJOR.MINOR.PATCH`로 갱신하고 `docs/releases/v<버전>.md`에
릴리즈 노트를 작성합니다. `CHANGELOG.md`와 두 언어 README의 파일 이름도 갱신하세요.
macOS 빌드가 앱 Info.plist에 버전을 넣고 Windows 프로젝트가 어셈블리·파일 버전으로 읽습니다.
배포할 정확한 커밋에 `v<버전>` Git 태그를 붙입니다.

## 로컬 패키징

저장소 루트에서 실행합니다. macOS는 Swift 6 이상과 Apple 개발 도구가,
Windows 설치 프로그램은 .NET 10과 NSIS가 필요합니다.

```sh
./scripts/test.sh
./scripts/package-macos.sh arm64
./scripts/package-macos.sh x86_64
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\package-windows.ps1
```

배포 파일은 `build/release/<버전>/`에 생성됩니다. Windows 스크립트는 포터블 ZIP도
만듭니다. 모든 배포본에 문서, 코드 라이선스, 별도 이미지 안내를 포함합니다.
Windows 설치·실행 검사는 다음 명령으로 실행합니다.

```powershell
.\scripts\test-installed-windows.ps1 -Installer .\build\release\1.0.0\ChiikawaPet-1.0.0-win-x64-setup.exe
```

전체 배포본을 모은 뒤 체크섬을 생성하고 검사합니다.

```sh
python3 scripts/check-release.py build/release/1.0.0
```

파일 이름, ZIP 무결성, Windows 버전·필수 파일·런타임 라이선스, 설치 EXE 헤더를 확인하고
`SHA256SUMS`를 만듭니다. Windows 화면의 수동 검증을 대신하지는 않습니다.

## GitHub 릴리즈 자동화

[릴리즈 workflow](../.github/workflows/release.yml)를 수동 실행하면 검토용 배포 파일을
빌드합니다. `v*` 태그를 푸시하면 Apple Silicon·Intel DMG와 Windows x64 배포본을
만들고 플랫폼 검사를 실행한 뒤 파일·체크섬·릴리즈 노트를 붙인 **초안**을 만듭니다.
태그는 `VERSION`과 정확히 일치해야 하며 다르면 빌드를 중단합니다.

푸시 전에 로컬 커밋, 버전, 릴리즈 노트, 이미지 재배포 권한을 확인하세요.
이 문서를 추가하는 것만으로 릴리즈가 게시되거나 저장소 공개 여부가 바뀌지는 않습니다.

```sh
git tag -a v1.0.0 -m 'Chiikawa Agent Pet v1.0.0'
git push origin main
git push origin v1.0.0
```

workflow 결과와 첨부 파일을 검토한 뒤 GitHub Releases에서 초안을 게시합니다.
저장소에 접근할 수 있는 사람에게 공개되며 Private 저장소의 릴리즈는 계속 비공개입니다.

## 현재 제한 사항

- macOS는 ad-hoc 서명이며 Apple Developer ID 서명·공증은 설정하지 않았습니다.
- Windows 설치 파일에는 공인 코드 서명이 없습니다.
- Windows CI는 설치, 미리보기 프로세스 시작, 제거를 확인합니다. 투명 배경·드래그·트레이·실제 계정 조회·혼합 DPI는 완전한 지원을 주장하기 전에 직접 확인해야 합니다.
- 코드 라이선스는 캐릭터 이미지와 서비스 로고를 제외합니다. 앱 배포 시 `ARTWORK-NOTICE.md`를 함께 포함하세요.
