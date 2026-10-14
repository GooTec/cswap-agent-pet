Unicode true
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"

!ifndef VERSION
!error "Pass VERSION, PAYLOAD and OUTPUT to makensis."
!endif
Name "Chiikawa Pet ${VERSION}"
OutFile "${OUTPUT}"
InstallDir "$LOCALAPPDATA\Programs\ChiikawaPet"
RequestExecutionLevel user
SetCompressor /SOLID lzma
VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "Chiikawa Agent Pet"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "FileDescription" "Chiikawa Agent Pet Installer"
VIAddVersionKey "LegalCopyright" "Copyright (c) 2026 meengi07"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "Korean"

!macro RequirePetClosed
  System::Call 'kernel32::OpenMutexW(i 0x00100000, i 0, w "Local\ChiikawaAgentPet") p.r0'
  ${If} $0 P<> 0
    System::Call 'kernel32::CloseHandle(p r0)'
    IfSilent +2
    MessageBox MB_OK|MB_ICONSTOP "Close the running Chiikawa Pet before installing or uninstalling."
    SetErrorLevel 1
    Abort
  ${EndIf}
!macroend

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_OK|MB_ICONSTOP "This package requires 64-bit Windows."
    Abort
  ${EndIf}
  SetRegView 64
  SetShellVarContext current
  !insertmacro RequirePetClosed
FunctionEnd

Function un.onInit
  !insertmacro RequirePetClosed
FunctionEnd

Section "Install"
  SetOutPath "$INSTDIR"
  File /r "${PAYLOAD}\*"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateDirectory "$SMPROGRAMS\Chiikawa Pet"
  CreateShortCut "$SMPROGRAMS\Chiikawa Pet\Chiikawa Pet.lnk" "$INSTDIR\ChiikawaPet.exe"
  CreateShortCut "$SMPROGRAMS\Chiikawa Pet\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChiikawaPet" "DisplayName" "Chiikawa Pet"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChiikawaPet" "DisplayVersion" "${VERSION}"
  ; Preserve a quoted executable path for Windows' uninstall entry.
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChiikawaPet" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChiikawaPet" "InstallLocation" "$INSTDIR"
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChiikawaPet" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChiikawaPet" "NoRepair" 1
SectionEnd

Section "Uninstall"
  SetRegView 64
  SetShellVarContext current
  ; The installer has no directory picker: it owns only this fixed app folder.
  StrCpy $INSTDIR "$LOCALAPPDATA\Programs\ChiikawaPet"
  RMDir /r "$INSTDIR"
  Delete "$SMPROGRAMS\Chiikawa Pet\Chiikawa Pet.lnk"
  Delete "$SMPROGRAMS\Chiikawa Pet\Uninstall.lnk"
  RMDir "$SMPROGRAMS\Chiikawa Pet"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChiikawaPet"
  ; Preferences and CLI credentials are stored elsewhere and are preserved.
SectionEnd
