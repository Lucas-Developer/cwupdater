; ClamWin NSIS/VPatch updater
;
; Copyright (c) 2006 Gianluigi Tiesi <sherpya@netfarm.it>
;
; This program is free software; you can redistribute it and/or
; modify it under the terms of the GNU Library General Public
; License as published by the Free Software Foundation; either
; version 2 of the License, or (at your option) any later version.
;
; This library is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
; Library General Public License for more details.
;
; You should have received a copy of the GNU Library General Public
; License along with this software; if not, write to the
; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA

SetCompressor /solid lzma
Name "ClamWin Updater"
OutFile "cwupdater.exe"

!packhdr tmp.dat "upx --best tmp.dat"
XPStyle on
SetDateSave on
SetDatablockOptimize on
CRCCheck on
SilentInstall normal
ShowInstDetails show
InstallColors FF8080 000030
Icon "cwupdater.ico"

!include "MUI.nsh"
!include "TextFunc.nsh"

; VPatch macro definition
!macro VPatchFile PATCHDATA SOURCEFILE TEMPFILE
	vpatch::vpatchfile "${PATCHDATA}" "${SOURCEFILE}" "${TEMPFILE}"
	Pop $1
	DetailPrint $1
	StrCpy $1 $1 2
	StrCmp $1 "OK" ok_${SOURCEFILE}
	SetErrors
ok_${SOURCEFILE}:
	IfFileExists "${TEMPFILE}" +1 end_${SOURCEFILE}
	Delete "${SOURCEFILE}"
	Rename /REBOOTOK "${TEMPFILE}" "${SOURCEFILE}"
end_${SOURCEFILE}:
!macroend

!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "${NSISDIR}\Contrib\Graphics\Header\nsis.bmp"
!define MUI_ICON "cwupdater.ico"
!define MUI_ABORTWARNING

!insertmacro MUI_PAGE_LICENSE "License.rtf"
!insertmacro MUI_PAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Function StripEol
	Exch $0
	Push $1
	Push $2
	StrCpy $1 0
loop:
    IntOp $1 $1 + 1
    StrCpy $2 $0 1 $1
	StrCmp $2 $\r found
	StrCmp $2 $\n found
    StrCmp $2 "" end
    Goto loop
found:
	StrCpy $0 $0 $1
end:
	Pop $2
	Pop $1
	Exch $0
FunctionEnd

Section "CwUpdater"
 	Var /GLOBAL DESTDIR
	Var /GLOBAL BINDIR
	Var /GLOBAL VERSTR
	Var /GLOBAL VERDW

	Var /GLOBAL REGUNI
	StrCpy $REGUNI "Software\Microsoft\Windows\CurrentVersion\Uninstall\ClamWin Free Antivirus_is1"

	; Search for ClamWin installation path
	ClearErrors
	ReadRegStr $0 HKLM Software\ClamWin "Path"
	IfErrors 0 found
	ReadRegStr $0 HKCU Software\ClamWin "Path"
	IfErrors 0 found
	DetailPrint "Cannot find ClamWin Installation, aborting..."
	Goto abort

found:
	StrCpy $BINDIR $0
	StrCpy $DESTDIR $BINDIR -3

	SetOutPath $DESTDIR
	File /nonfatal /r "missing\*"

	InitPluginsDir
	File /oname=$PLUGINSDIR\cwupdate.pat cwupdate.pat
	File /oname=$PLUGINSDIR\cwupdate.lst cwupdate.lst

	FileOpen $0 $PLUGINSDIR\cwupdate.lst r

	; Read the version string from the manifest
	FileRead $0 $VERSTR
	Push $VERSTR
	Call StripEol
	Pop $VERSTR

	; Read the version number from the manifest
	FileRead $0 $VERDW
	Push $VERDW
	Call StripEol
	Pop $VERDW

	DetailPrint "Closing ClamTray..."
	ExecWait '"$BINDIR\WClose.exe"'

	DetailPrint "Upgrading ClamWin to version $VERSTR ($VERDW)"
	Loop:
		ClearErrors
		; Read a line from the manifest
		FileRead $0 $1
		IfErrors loopend

		; Strip end of line char
		Push $1
		Call StripEol
		Pop $1
		StrCpy $R1 "$DESTDIR$1"

		; Check if the destination file exists, if not skip the patch
		; to avoid creating 0 sized files
		IfFileExists $R1 gentemp
		DetailPrint "Skipping not installed $R1"
		Goto Loop

	gentemp:
		; Generate a random tmp name
		GetTempFileName $R0

		DetailPrint "Patching $R1"

		; PatchIt
		ClearErrors
		!insertmacro VPatchFile "$PLUGINSDIR\cwupdate.pat" $R1 $R0
		Goto Loop
	loopend:
		FileClose $0

	DetailPrint "Updating registry keys..."

	ClearErrors
	WriteRegDWORD HKLM "Software\ClamWin" "Version" $VERDW
	IfErrors 0 reguni
	WriteRegDWORD HKCU "Software\ClamWin" "Version" $VERDW
	IfErrors 0 reguni
	DetailPrint "Cannot update version key in the registry"

reguni:
	WriteRegStr HKLM "$REGUNI" "DisplayName" "ClamWin Free Antivirus $VERSTR"
	IfErrors 0 regdone
	WriteRegStr HKCU "$REGUNI" "DisplayName" "ClamWin Free Antivirus $VERSTR"
	IfErrors 0 regdone
	DetailPrint "Cannot update uninstall string in the registry"

regdone:
	IfRebootFlag 0 startctray
		MessageBox MB_YESNO "A reboot is required to finish the upgrade. Do you wish to reboot now?" IDNO theend
		Reboot
startctray:
	Exec '"$BINDIR\ClamTray.exe"'

theend:
	DetailPrint "ClamWin Upgraded to $VERSTR"
abort:

SectionEnd
