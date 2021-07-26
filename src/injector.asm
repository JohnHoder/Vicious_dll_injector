; =====================================================
; Vicious DLL Injector, ver.1.0
; © Jan Hodermarsky (HardC0re, JohnHoder), 2015-2017
; =====================================================

.386					; create 32 bit code
.model flat,stdcall		; 32 bit memory model
option casemap:none 	; case sensitive

    ; -------------------------
    ; Windows API include files
    ; -------------------------

include windows.inc
include kernel32.inc
include user32.inc
include gdi32.inc
include comctl32.inc

    ; ------------------------------------------
    ; import libraries for Windows API functions
    ; ------------------------------------------

includelib kernel32.lib
includelib user32.lib
includelib gdi32.lib
includelib comctl32.lib

.const
	MainDlg				equ 100
	AboutDlg			equ 700
	
	IDC_ABOUT			equ 1787
	IDC_INJECT			equ 1788
	IDC_COPYRIGHT		equ 1098
	IDC_QUIT			equ	1007
	IDC_SOUND			equ 1006
	IDC_PROC			equ 555
	IDC_SELPROCBTN		equ 556
	
	IDB_BACKGROUND		equ	8000
	
	; Colors
	; --------------------------------------------------------------------------------------------
	CR_BACKGROUND		equ RGB(165, 19, 19)	;used currently only for button edges to blend in
	CR_FOREGROUND		equ RGB(120, 111, 117)	;static bg colour of controls / background of button edges
	CR_LIGHTER_RED		equ RGB(189, 26, 27)	;background of input
	CR_HIGHLIGHT		equ RGB(255,255,255)	;text colour of input
	CR_IDLE				equ RGB(103,146,0)		;non-pressed button
	CR_SELECTED			equ RGB(103,139,122)	;pressed button
	CR_TEXT				equ 009999FFh			;text colour of checkboxes
	; --------------------------------------------------------------------------------------------
	TRANSP_MAIN			equ 241
	
.data
	;window dimensions
	wSizeX				dd		308
	wSizeY				dd		444

	szCaption			db		"FTW Injector 1.0",0
	szInjected			db 		"Injected!",0
	
	NAMEFONT			db		"Courier New",0

	sDllName			db 		"vicious.dll",0
	
	;=========================== Loading of ftwlib.dll =========================
	libname				byte	"ftwlib.dll",0
	dllFuncName			db		"drawToWnd",0
	dllChooseProcessWnd	db		"chooseProcessWnd",0
	szLibTitle			db		"LoadLibrary failed",0
	szLibErrorCode		db		"Loading of ftwlib.dll failed.",13,10
						db		"Error code: %ld",0
	;===========================================================================
	
.data?
	sProcName	TCHAR     16 dup(?)

	;=========================== scrolling horizontal===========================
	;canvas declarations, gets drawn in mainDlg
	canvasDC	  dd	?
	canvasBmp	  dd	?
	hDC           dd	?
	canvas_buffer dd	?

	canvas		BITMAPINFO	<>
	;===========================================================================
	hFontMain	HFONT	?
	defaultWndProc WNDPROC ?
	
	Wx          dd ?
	Wy          dd ?
	
	hDll		DWORD	?
	hInstance   HINSTANCE	?
	
	hName		dd	?

	errormsg	db	?
	
	rectx		RECT	<?>
	
	;Brushes & pens
	hLighterRed	HBRUSH    ?
	hBgColor    HBRUSH	  ?
	hFgColor	HBRUSH    ?
	hIdleColor	HBRUSH    ?
	hSelColor	HBRUSH    ?
	hEdge		HPEN      ?
	sBtnText	TCHAR     16 dup(?)
	
	hdcBM		HDC     ?
    hbmp 		HBITMAP ?

.code

doNotRunTwice MACRO lpTitle
	invoke FindWindow,NULL,lpTitle
	cmp eax, 0
	je @F
		push eax
		invoke ShowWindow,eax,SW_RESTORE
		pop eax
		invoke SetForegroundWindow,eax
		xor eax,eax
		ret
	@@:
ENDM

;;;;;;;;;;;;;;;

MainProc		PROTO:DWORD,:DWORD,:DWORD,:DWORD
AboutProc		PROTO:DWORD,:DWORD,:DWORD,:DWORD
Draw_Scroller	PROTO
TopXY 			PROTO:DWORD,:DWORD
FadeOut	    	PROTO:DWORD,:DWORD,:DWORD,:DWORD
DrawItem   		PROTO :HWND,:LPARAM,:WPARAM

include music.asm
include horizontalScroller.asm
include about.asm
include inject.asm

include libs\btnt.inc

start:
;====================================
	invoke GetModuleHandle,NULL
	mov hInstance,eax
	doNotRunTwice addr szCaption
	push eax
	
	; load dll
	push offset libname
    call LoadLibrary
    and eax,eax
    jz @F
    mov hDll,eax
    pop eax
    ; let it roll
    call main
    jmp fin
@@:
	call GetLastError
	invoke wsprintf,addr errormsg, addr szLibErrorCode,eax
	invoke MessageBox,0,addr errormsg, addr szLibTitle,0
fin:
	invoke ExitProcess,eax
;====================================

main proc
	; The following gfx stuff has to be done here in main, in AboutProc it doesn't seem to work
	;===========================================================================================
	; setup nice fonts
	invoke CreateFont,17, 0, 0, 0, FW_MEDIUM, 0, 0, 0, 0, 0, 0, 0, 0, SADD(TITLEFONT)
	mov hFontTitle,eax
	invoke CreateFont,13, 0, 0, 0, FW_MEDIUM, 0, 0, 0, 0, 0, 0, 0, 0, SADD(ABOUTFONT)
	mov hFontAbout,eax
	invoke CreateFont, 21, 0, 0, 0, FW_BOLD, 0, 0, 0,
					DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
					DEFAULT_QUALITY, DEFAULT_PITCH, addr NAMEFONT
	mov hFontMain, eax
	
	; Create brushes for custom colors
	INVOKE CreateSolidBrush, CR_BACKGROUND
	mov hBgColor, eax
	INVOKE CreateSolidBrush, CR_LIGHTER_RED
	mov hLighterRed, eax
	INVOKE CreateSolidBrush, CR_FOREGROUND
	mov hFgColor, eax
	INVOKE CreateSolidBrush, CR_IDLE
	mov hIdleColor, eax
	INVOKE CreateSolidBrush, CR_SELECTED
	mov hSelColor, eax
	INVOKE CreatePen, PS_INSIDEFRAME, 1, CR_FOREGROUND
	mov hEdge, eax
	;===========================================================================================

	invoke InitCommonControls
	invoke DialogBoxParam,hInstance,MainDlg,0,addr MainProc,0
	ret
main endp

callFuncDll	proc	hWin:HWND,funcName:DWORD
		invoke 		GetProcAddress,hDll,funcName
		cmp 		eax,0
		jz 			quit
		mov 		edx,eax
		push		hWin
		call		edx
		ret
quit:
		call 		GetLastError
		invoke 		wsprintf,addr errormsg, addr szLibErrorCode,eax
		invoke		MessageBox,0,addr errormsg, addr szCaption,0
		ret
callFuncDll endp

nameTextProc proc hWinx:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM, origWnd:HWND
	LOCAL psx:PAINTSTRUCT
	
	.if uMsg == WM_CHAR
		nop
		ret
		
	.elseif uMsg == WM_TIMER
		;ret
		
	;.elseif uMsg == WM_CTLCOLORSTATIC
		;invoke	SetTextColor,wParam,RGB(208,180,180)
		;invoke GetStockObject,NULL_BRUSH
		;ret

	.elseif uMsg == WM_PAINT
		invoke	BeginPaint,hWinx,addr ps
		;invoke CreateSolidBrush, RGB(56,76,98)
		;mov ahBrush, eax
		;invoke SelectObject, ps.hdc, eax
		invoke 	SelectObject, ps.hdc, hFontMain
		invoke	SetTextColor,ps.hdc,RGB(208,180,180)
		invoke	SetBkMode,ps.hdc,RGB(56,76,98)
		invoke FillRect,ps.hdc,ADDR rectx,hSelColor
		; left line+
		add rectx.left,20
		mov edi,rectx.left
		dec edi
		invoke MoveToEx,ps.hdc,edi,rectx.top,NULL
		invoke LineTo,ps.hdc,edi,rectx.bottom
		invoke	lstrlen, addr szCaption
		mov	ecx,eax
		invoke	TextOut,ps.hdc,0,0,addr szCaption,ecx
    	invoke  EndPaint,hWinx,addr ps
		;xor eax,eax
		;ret
	.elseif [uMsg] == WM_LBUTTONDOWN
		invoke GetParent,hWinx
		invoke SendMessage, eax, WM_NCLBUTTONDOWN, HTCAPTION, NULL
	.endif
	;invoke GetWindowLong,defaultWndProc,GWL_USERDATA
	;push eax
	;cmp eax,defaultWndProc
	;jnz nope
	;invoke MessageBox,0,addr szCaption, addr szCaption,0
;nope:
	;pop eax
	invoke CallWindowProc,defaultWndProc,hWinx,uMsg,wParam,lParam ; Get back to mainDlg
	ret
nameTextProc endp

MainProc	proc	hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
	local ThreadID:DWORD
	push hWnd

Wm_0:
	cmp [uMsg],WM_COMMAND
	jnz Wm_1
		mov eax,wParam
    	mov edx,wParam
    	shr edx,16

		.if ax == IDC_ABOUT
			invoke lstrcpy,addr szAboutMsg,addr AboutTxt
			; mov AboutTxt,1
			invoke DialogBoxParam,hInstance,AboutDlg,hWnd,ADDR AboutProc,NULL
			invoke RtlZeroMemory,addr szAboutMsg,sizeof szAboutMsg
			
			;invoke DialogBoxParam, 0, 110, 0, addr DlgProc_About, 0

		.elseif ax == IDC_INJECT
			invoke GetDlgItemText, hWnd, IDC_PROC, ADDR sProcName, SIZEOF sProcName
			;invoke MessageBox, 0, addr sProcName, addr szInjected, 0
			invoke Inject, addr sProcName, addr sDllName
			;invoke TestMessageBox2
			;invoke TestMessageBox, addr sProcName, addr sProcName

		.elseif ax == IDC_SELPROCBTN
			invoke callFuncDll,hWnd,addr dllChooseProcessWnd
			
		.elseif ax == IDC_QUIT
			invoke SendMessage, hWnd, WM_CLOSE, NULL, NULL
		.elseif ax == IDC_SOUND
			call mfmPause

		.elseif ax == 7777
			;invoke MessageBox, 0, addr szCaption, addr szCaption, 0
			;invoke DialogBoxParam, hInstance, 111, hWnd, ADDR InfoProc, 0
		;.elseif (edx == EN_UPDATE && ax == IDC_ABOUT) || wParam == IDC_SOUND
      		;invoke KeygenProc, hWnd
      	.endif

Wm_1:
	cmp [uMsg],WM_INITDIALOG
	jnz Wm_2
	
		; Load background bitmap
		invoke LoadBitmap, hInstance, IDB_BACKGROUND
		;mov hbmp, eax
		invoke CreatePatternBrush,eax
        mov hbmp,eax
	
		; Conventional stuff here
		invoke GetSystemMetrics, SM_CXSCREEN
        invoke TopXY, wSizeX, eax ;window dims, see main.rc
        mov Wx, eax
        invoke GetSystemMetrics, SM_CYSCREEN
        invoke TopXY, wSizeY, eax
        mov Wy, eax
		invoke SetWindowText,hWnd,addr szCaption
		;invoke SetWindowPos, hWnd, 0, Wx, Wy, 0, 0, SWP_NOSIZE or SWP_NOMOVE
		invoke SetWindowPos, hWnd, HWND_NOTOPMOST, Wx, Wy, wSizeX, wSizeY, SWP_NOZORDER ;or SWP_NOSIZE
		
		; Exit button
		invoke ImageButton,hWnd,283,417,705,704,704,IDC_QUIT		;custom image button (PNG,JPG,BMP) Left,Up,DownID,UpID,OverID
		mov hExit,eax
		
		invoke CheckDlgButton,hWnd,IDC_SOUND,BST_CHECKED ;sound on by default
		
		; Call proc from dll
		invoke callFuncDll,hWnd,addr dllFuncName
		
		; We use this from about.asm for FadeOut to work
		invoke TranspWindow,hWnd,TRANSP_MAIN
		
		;invoke PlayMusicFromRes
		invoke PlayMusic
		
		; override to custom WndProc
		;invoke GetDlgItem, hWnd, IDC_SOUND
		;mov hName, eax
		;invoke	SetWindowLong,hName,GWL_WNDPROC,offset nameTextProc
		;mov defaultWndProc, eax
		
		; dimensions and position
		invoke GetWindowRect,hWnd,addr rectx
		mov eax,rectx.left
		add eax, 10	;starting point X
		mov rectx.left,eax
		mov ebx,rectx.top
		add ebx, 10	;starting point Y
		mov rectx.top,ebx
		mov ecx, rectx.right
		sub ecx, rectx.left
		sub ecx, 2*20	;ecx=width
		mov rectx.right, ecx

		; Fill in important Bitmap elements. ***************=
		;                                                   ;|
		; Nothing complex here.. Just filling in a BITMAP   ;|
		; structure to specify our format to the DIB call.  ;|

		mov canvas.bmiHeader.biSize,sizeof canvas.bmiHeader ;|
		mov canvas.bmiHeader.biWidth,ScreenWidth            ;|
		mov canvas.bmiHeader.biHeight,-ScreenHeight         ;|
		mov canvas.bmiHeader.biPlanes,1                     ;|
		mov canvas.bmiHeader.biBitCount,32                  ;|
		;***************************************************=

		; Setup DibSection. *********************************************************************=
		;                                                                                        ;| 
		; This basically Sets up our buffer to write to.                                         ;|
		; Creates a DC and passes it to the DIBSection call so that it can give us back an       ;|
		; address to our buffer.                                                                 ;|
		;                                                                                        ;|
                                                                                                 ;|
		invoke	GetDC, [hWnd]                                                                	 ;|
		mov		[hDC],eax 	                                                                     ;| IMPORTANT!
		invoke	CreateCompatibleDC, eax                                                          ;|
		mov		[canvasDC], eax                                                                  ;|		
		invoke	CreateDIBSection,hDC,ADDR canvas,DIB_RGB_COLORS, ADDR canvas_buffer, 0, 0        ;|
		mov		[canvasBmp], eax                                                                 ;|
		invoke	SelectObject, [canvasDC], eax                                                    ;|
		invoke	ReleaseDC,hDC,0                                                                  ;|
		;****************************************************************************************=

		invoke	SetTimer, [hWnd], 10, 0, 0
		ret

Wm_2:
	cmp [uMsg],WM_TIMER
	jnz Wm_3
          
		;All our drawing is done here. ********************************=
                                                              	       ;| This small peice of
		mov edi, [canvas_buffer]                                       ;| code wipes away the
		mov ecx,ScreenWidth * ScreenHeight                             ;| previous frame we 
		xor eax,eax                                                    ;| drew to the screen
		rep stosd                                                      ;| without it we get a mess.

		;--- drawing functions...
		mov	edi, [canvas_buffer]                                       ;| IMPORTANT!
		call	Draw_Scroller                                          ;|
		;**************************************************************=
		invoke	RedrawWindow, [hWnd], 0, 0, RDW_INVALIDATE or RDW_UPDATENOW or RDW_NOCHILDREN      ;| Avoid window blinking
		ret

Wm_3:
	cmp [uMsg],WM_PAINT
	jnz Wm_4

		mov		eax, [hWnd]                                                                ;| If you dont know what
		mov		ecx, OFFSET ps                                                             ;| this stuff does then
		push	ecx	                                                                       ;| I suggest you start
		push	eax                                                                        ;| with something a little
		invoke	BeginPaint, eax, ecx                                                       ;| simpler..
		invoke	BitBlt, eax, 0, 0, ScreenWidth, ScreenHeight, [canvasDC],0, 0, SRCCOPY     ;| goto win32asm.cjb.net
		call	EndPaint                                                                   ;|
		ret

Wm_4:
	;*****************************************************************************;=
	cmp [uMsg],WM_LBUTTONDOWN                                                      ;| Enables you to click on the window
	jnz Wm_5                                                                       ;| and move it around.
		invoke SendMessage, hWnd, WM_NCLBUTTONDOWN, HTCAPTION, NULL                ;|
	;******************************************************************************=
Wm_5:
	cmp [uMsg],WM_CLOSE
	jnz Wm_6
		invoke FadeOut,hWnd,10,TRANSP_MAIN,5
		invoke StopMusic
		invoke FreeLibrary, hDll
		invoke DeleteObject, hEdge
		invoke DeleteObject, hIdleColor
		invoke DeleteObject, hSelColor
		invoke DeleteObject, hFgColor
		invoke DeleteObject, hBgColor
		invoke EndDialog, [hWnd], 0
		ret
Wm_6:

		
Wm_7:
	cmp [uMsg], WM_DRAWITEM
	jnz Wm_8
    	invoke DrawItem, hWnd, lParam, wParam     ;| draws decent buttons for us
    	ret
Wm_8:
	cmp [uMsg],WM_CTLCOLORDLG
	jnz Wm_9
		;mov eax, hBgColor
		mov eax, hbmp                             ;| default background of our dialog
		ret
		
Wm_9:
	cmp [uMsg],WM_CTLCOLORSTATIC                      ;| default background colour of controls
	jnz Wm_10
    	invoke GetWindowLong,lParam,GWL_ID            ;| IMPORTANT - without this we don't have access to lParam
		.if eax == IDC_PROC
			invoke SelectObject, wParam, eax
			invoke SetBkMode, wParam, TRANSPARENT
			invoke SetTextColor, wParam, CR_HIGHLIGHT
			mov eax, hLighterRed ;hbmp;hFgColor
			ret
		.elseif eax == IDC_COPYRIGHT
			invoke SelectObject, wParam, eax
			invoke SetBkMode, wParam, TRANSPARENT
			invoke SetTextColor, wParam, CR_HIGHLIGHT
			mov eax, hbmp
			ret
		.else
			invoke SetBkMode, wParam, TRANSPARENT
			invoke SetTextColor, wParam, CR_TEXT
			mov eax, hbmp
		.endif
		ret	;IMPORTANT

Wm_10:
	cmp [uMsg], WM_CTLCOLOREDIT
	jnz Wm_11
		;invoke SetBkMode, wParam, TRANSPARENT
		;invoke SetTextColor, wParam, CR_HIGHLIGHT
		mov eax, hIdleColor
		ret
    
Wm_11:
	cmp [uMsg], WM_NOTIFY
	jnz Wm_12
		.if wParam == IDC_PROC
			invoke SetDlgItemText,hWnd,IDC_PROC,lParam
		.endif
		ret

Wm_12:

@@quit:
	xor eax,eax
	ret
MainProc EndP

FadeOut proc hWnd:HWND, sleepTime:DWORD, initTransp:DWORD, subvalue:DWORD
	;LOCAL Transparency:DWORD
	;LOCAL sleepTime:DWORD
	;mov sleepTime,10
	;mov Transparency,255
	;LOCAL subvalue:DWORD
	;mov subvalue,15
	mov eax,subvalue
@@:
	invoke SetLayeredWindowAttributes,hWnd,0,initTransp,LWA_ALPHA
	invoke Sleep,sleepTime
	mov eax,subvalue
	sub initTransp,eax
	cmp initTransp,eax
	jb	belowLimit
	cmp initTransp,0
	jne @b
belowLimit:
	mov initTransp,0
	invoke SetLayeredWindowAttributes,hWnd,0,initTransp,LWA_ALPHA
	ret
FadeOut endp

DrawItem proc hWnd:HWND, lParam:LPARAM, wParam:WPARAM

	push esi
	mov esi, lParam
	assume esi: ptr DRAWITEMSTRUCT

	.if [esi].itemState & ODS_SELECTED
		invoke SelectObject, [esi].hdc, hSelColor
	.else
		invoke SelectObject, [esi].hdc, hIdleColor
	.endif

	invoke SelectObject, [esi].hdc, hEdge
	
	;invoke GetStockObject, HOLLOW_BRUSH
	;SelectObject, [esi].hdc, eax

	invoke FillRect, [esi].hdc, ADDR [esi].rcItem, hBgColor ;hbmp why doesn't it work?
	invoke RoundRect, [esi].hdc, [esi].rcItem.left, [esi].rcItem.top, [esi].rcItem.right, [esi].rcItem.bottom, 6, 6

	.if [esi].itemState & ODS_SELECTED
		invoke OffsetRect, ADDR [esi].rcItem, 1, 1
	.endif

	; Write the text
	invoke GetDlgItemText, hWnd, [esi].CtlID, ADDR sBtnText, SIZEOF sBtnText
	invoke SetBkMode, [esi].hdc, TRANSPARENT
	invoke SetTextColor, [esi].hdc, CR_HIGHLIGHT
	invoke DrawText, [esi].hdc, ADDR sBtnText, -1, ADDR [esi].rcItem, DT_CENTER or DT_VCENTER or DT_SINGLELINE

	.if [esi].itemState & ODS_SELECTED
		invoke OffsetRect, ADDR [esi].rcItem, -1, -1
	.endif

	; Draw the focus rectangle
	.if [esi].itemState & ODS_FOCUS
		invoke InflateRect, ADDR [esi].rcItem, -3, -3
		;invoke DrawFocusRect, [esi].hdc, ADDR [esi].rcItem
	.endif
 
	assume esi:nothing
	pop esi
	mov eax, TRUE
	ret
DrawItem endp


TopXY proc wDim:DWORD, sDim:DWORD
    shr sDim, 1      ; divide screen dimension by 2
    shr wDim, 1      ; divide window dimension by 2
    mov eax, wDim    ; copy window dimension into eax
    sub sDim, eax    ; sub half win dimension from half screen dimension
    mov eax, sDim
    ret
TopXY endp

end start