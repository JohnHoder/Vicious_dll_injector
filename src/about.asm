; =====================================================
; Vicious DLL Injector, ver.1.0
; © Jan Hodermarsky (HardC0re, JohnHoder), 2015-2017
; =====================================================

.const
	IDC_TIMER		EQU	100
	
	TITLEFONT		EQU "COURIER NEW"
	ABOUTFONT		EQU "Tahoma"
	
	COLORDLG		EQU RGB(91, 34, 37)		;these colours are initialized in maindlg
	COLORPEN		EQU Red
	COLORTEXT	    EQU RGB(255, 91, 126)
	
	SCROLLSPEED		EQU 20		;scroll speed
	
	SIZEOFTITLEBAR	EQU 20
	SPACEDLGTOP		EQU	27		;space from top
	SPACEDLGSIDE	EQU 4		;space from left and right side
	DLGLENGTH		EQU	177		;length of dialog
	
	DLGTRANSP		EQU 245		;transparency 0-255

.data
;========================== scroller ===============================
	AboutTitle              db "About",0

	ScrollOffset			DWORD	1

	AboutTxt    db "Vicious Injector 1.0",10,13,10,13
				db "Code and GFX by HardC0re ",10,13
				db "Scroll algo by Sp0ke, modified by HardC0re",10,13
				db "Greetz to mfmplayer's author - pozdrawiam!",10,13
				db "SFX by AZED",10,13,10,13
				db "----[Greetings]----",10,13,10,13
				db "Thanks to all the teams, the support of which",10,13
				db "has got me where I am now.", 10, 13,10,13
				db "----[Shoutouts]----", 10,13,10,13
				db " Lionaneesh ",10,13,10,13
				db " Evisceration ",10,13,10,13
				db " Coded32 ",10,13,10,13
				db " Mishraji ",10,13,10,13
				db " Maini ",10,13,10,13
				db " .---==================---.",10,13
				db "|        \\\------------------------///         |",10,13
				db " ",10,13,10,13
				db "© 2017 Jan Hodermarsky (HardC0re)",10,13,10,13
				db "All rights reserved.",10,13,10,13,0
				
.data?

	hBckgColor     	HBRUSH				?
	hpen         	HPEN				?
	hFontTitle   	HFONT				?
	hFontAbout		HFONT				?
	AboutRect    	RECT				<?>
	rScroll			RECT				<?>
	rClientAbout	RECT				<?>
	PosRect         RECT                <?>
	;hbmp			HANDLE				?
	chdc			HDC					?
	hdc				HDC					?

	TimerID			DWORD				?
	szAboutMsg      db                	500 dup(?)
	
	; ps is used in main and about.asm as well
	ps		  PAINTSTRUCT	<?>
	
; DRAW STARS
	Tick	        dd	?


; DRAW STARS
.data

	dword_40CCA0	dd 0
	dword_40CCA4	dd 0
	dword_40CCB8	dd 0
	dword_40CD24	dd 0
				dd 1F2h	dup(0)
	dword_40DCC4	dd 0
				dd 1F3h	dup(0)
	dword_40D4F0	dd 0
	dword_40D4F4	dd 0
				dd 1F3h	dup(0)
	
.code
SADD MACRO quoted_text:VARARG
	LOCAL local_text
.data
	local_text db quoted_text,0;
	align 4
.code
	EXITM <ADDR local_text>
ENDM

RGB MACRO red, green, blue
    EXITM % blue SHL 16 + green SHL 8 + red
ENDM

DrawStars	PROTO

TranspWindow proc hWnd :DWORD, Tnsp:BYTE

.data
		Tfunc		db "SetLayeredWindowAttributes",0
		libuser32 	db "user32.dll",0
.code
		push		0FFFFFFECh
		push		hWnd
		call		GetWindowLong
		or			eax, 80000h
		push		eax
		push		0FFFFFFECh
		push		hWnd
		call		SetWindowLong
		test		eax, eax
		jnz			short Do_Tns
		ret

Do_Tns:
		invoke 		LoadLibrary,addr libuser32
		invoke 		GetProcAddress,eax,addr Tfunc
		cmp 		eax,0
		jz 			quit
		mov 		edx,eax

		xor 		ebx,ebx
		mov 		bl,Tnsp
		push		2
		push		ebx
		push		0
		push		hWnd
		call		edx
quit:
		ret
		
TranspWindow endp


AboutProc	proc	hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
	;LOCAL	ps:PAINTSTRUCT
	;LOCAL	hdc:HDC
	
	.if uMsg == WM_INITDIALOG
		invoke TranspWindow,hWnd,DLGTRANSP
		invoke SetWindowPos,hWnd,HWND_NOTOPMOST,0,0,0,0,SWP_NOMOVE or SWP_NOSIZE
		; register esc to close the aboutdlg
		invoke RegisterHotKey, hWnd, NULL, NULL, VK_ESCAPE
		
		; setup background and border colors
		invoke CreateSolidBrush,COLORDLG
		mov hBckgColor,eax
		invoke CreatePen,PS_SOLID,0,COLORPEN
		mov hpen,eax
		
		; dimensions and position
		invoke GetParent,hWnd
		invoke GetWindowRect,eax,addr PosRect
		mov eax,PosRect.left
		add eax, SPACEDLGSIDE	;starting point X
		mov ebx,PosRect.top
		add ebx, SPACEDLGTOP	;starting point Y
		mov ecx, PosRect.right
		sub ecx, PosRect.left
		sub ecx, 2*SPACEDLGSIDE	;ecx=width
		invoke MoveWindow,hWnd,eax,ebx,ecx,DLGLENGTH,TRUE

		invoke GetClientRect,hWnd,ADDR AboutRect
		invoke GetDC,hWnd
		mov hdc,eax
		invoke CreateCompatibleDC,hdc
		mov chdc,eax
		invoke CreateCompatibleBitmap,hdc,AboutRect.right,AboutRect.bottom
		mov hbmp,eax
		invoke SelectObject,chdc,hbmp
		mov rClientAbout.top,1
		mov rClientAbout.left,1
		push AboutRect.right
		pop	rClientAbout.right
		push AboutRect.bottom
		pop rClientAbout.bottom
		dec rClientAbout.bottom
		dec rClientAbout.right
		invoke FillRect,chdc,ADDR AboutRect,hBckgColor
		invoke FrameRect,chdc,ADDR rClientAbout,hpen
		invoke SelectObject,chdc,hpen
		invoke MoveToEx,chdc,rClientAbout.left,SIZEOFTITLEBAR,NULL
		invoke LineTo,chdc,rClientAbout.right,SIZEOFTITLEBAR

		invoke SetTextColor,chdc,COLORTEXT		;we are in initdlg, here we set color for both title and text 
		invoke SetBkMode,chdc,TRANSPARENT
		;invoke SetBkColor,chdc,TRANSPARENT
		invoke SelectObject,chdc,hFontTitle

		mov rClientAbout.bottom,SIZEOFTITLEBAR

		invoke DrawText,chdc,addr AboutTitle,-1,ADDR rClientAbout,DT_VCENTER or DT_CENTER or DT_SINGLELINE or DT_NOCLIP

		inc rClientAbout.left
		dec rClientAbout.right
		push AboutRect.bottom
		pop rClientAbout.bottom
		sub rClientAbout.bottom,2
		add rClientAbout.top,SIZEOFTITLEBAR
		
		; upper line+
		add rClientAbout.top,2;;;;;
		mov edi,rClientAbout.top
		dec edi
		invoke MoveToEx,chdc,rClientAbout.left,edi,NULL
		invoke LineTo,chdc,rClientAbout.right,edi

		; bottom line+
		sub rClientAbout.bottom,2
		mov edi,rClientAbout.bottom
		invoke MoveToEx,chdc,rClientAbout.left,edi,NULL
		invoke LineTo,chdc,rClientAbout.right,edi
		
		; right line+
		sub rClientAbout.right,2
		mov edi,rClientAbout.right
		invoke MoveToEx,chdc,edi,rClientAbout.top,NULL
		invoke LineTo,chdc,edi,rClientAbout.bottom
		
		; left line+
		add rClientAbout.left,2
		mov edi,rClientAbout.left
		dec edi
		invoke MoveToEx,chdc,edi,rClientAbout.top,NULL
		invoke LineTo,chdc,edi,rClientAbout.bottom
		
		invoke IntersectClipRect,chdc,rClientAbout.left,rClientAbout.top,rClientAbout.right,rClientAbout.bottom

		invoke SelectObject,hdc,hFontAbout
		invoke DrawText,hdc,ADDR szAboutMsg,-1,ADDR rScroll,DT_CALCRECT + DT_NOPREFIX + DT_CENTER + DT_TOP + DT_NOCLIP

		push rClientAbout.right
		pop rScroll.right
		sub rScroll.right,5
		mov eax,rClientAbout.bottom
		add rScroll.top,eax
		add rScroll.bottom,eax
		
		invoke ReleaseDC,hWnd,hdc

		invoke SetTimer,hWnd,IDC_TIMER,SCROLLSPEED,NULL
		mov TimerID,eax

	.elseif uMsg == WM_PAINT
		invoke BeginPaint,hWnd,addr ps
		mov hdc,eax
		invoke FillRect,chdc,ADDR rScroll,hBckgColor
		invoke SelectObject,chdc,hFontAbout
		invoke SetBkMode,chdc,TRANSPARENT
		invoke DrawText,chdc,ADDR szAboutMsg,-1,ADDR rScroll,DT_CENTER + DT_TOP + DT_NOPREFIX + DT_NOCLIP
		invoke BitBlt,hdc,0,0,AboutRect.right,AboutRect.bottom,chdc,0,0,SRCCOPY
		invoke EndPaint,hWnd,addr ps

	.elseif uMsg == WM_CTLCOLORDLG
		;invoke SetTextColor,chdc,RGB(67,234,123) ;diff color of text than title
		mov eax,hBckgColor
		ret

	.elseif uMsg == WM_TIMER
		;call	DrawStars
		mov eax,ScrollOffset
		add rScroll.top,eax
		add rScroll.bottom,eax
		mov eax,rClientAbout.bottom
		.if SDWORD PTR rScroll.top >= eax
			mov ScrollOffset,-1
		.else
			mov eax,rClientAbout.top
			.if SDWORD PTR rScroll.bottom <= eax
				mov ScrollOffset,1
				;invoke SetTextColor,chdc,RGB(67,234,123) ; change color on direction change
				;jmp quit
			.endif
		.endif
		
		invoke InvalidateRect,hWnd,NULL,FALSE
		
	.elseif uMsg == WM_HOTKEY
		mov eax, wParam
		jmp quit

	.elseif uMsg == WM_CLOSE || uMsg == WM_LBUTTONDOWN
quit:
		invoke FadeOut,hWnd,5,DLGTRANSP,7
		mov rScroll.top,0
		mov rScroll.bottom,0
		mov rScroll.left,0
		mov rScroll.right,0
		invoke DeleteDC,chdc
		invoke DeleteObject,hbmp
		invoke KillTimer,hWnd,TimerID
		invoke EndDialog,hWnd,NULL

	.else
    	xor eax,eax
    	ret
	.endif

  	xor eax,eax
	ret
	
AboutProc EndP

align dword
_rand proc
	mov eax,Tick
	imul eax,eax,0A999h
	add eax,0269EC3h
	mov Tick,eax
	sar eax,010h
	and eax,0FFFFh
	Ret
_rand EndP

DrawStars	proc	
		push ebx
		mov	ebx, SetPixelV
		push	 esi
		push	 edi
		xor	edi, edi

loc_40141B:
		mov	eax, dword_40CD24[edi*4]
		mov	esi, dword_40DCC4[edi*4]
		push 	0h		; COLORREF
		lea	eax, [eax+eax*2]
		lea	eax, [eax+eax*4]
		lea	eax, [eax+eax*4]
		shl	eax, 1
		cdq
		idiv	esi
		mov	ecx, eax
		mov	eax, dword_40D4F4[edi*4]
		imul	eax, 64h
		cdq
		idiv	esi
		add	ecx, 0AFh
		mov	dword_40CCA0, ecx
		add	eax, 50h
		mov	dword_40CCA4, eax
		push	eax		; int
		mov	eax, chdc
		push	ecx		; int
		push	eax		; HDC
		call	ebx ; SetPixelV
		mov	eax, dword_40DCC4[edi*4]
		lea	ecx, [eax-1]
		mov	eax, dword_40CD24[edi*4]
		mov	dword_40DCC4[edi*4], ecx
		lea	eax, [eax+eax*2]
		lea	eax, [eax+eax*4]
		lea	eax, [eax+eax*4]
		shl	eax, 1
		cdq
		idiv	ecx
		mov	esi, eax
		mov	eax, dword_40D4F4[edi*4]
		imul	eax, 70h
		cdq
		idiv	ecx
		add	esi, 0AFh
		mov	dword_40CCA0, esi
		add	eax, 65h
		cmp	ecx, 0FFh
		mov	dword_40CCA4, eax
		jl	short loc_4014BE
		mov	edx, 50h
		jmp	short loc_4014C5

loc_4014BE:
		mov	edx, 0FFFh
		sub	edx, ecx

loc_4014C5:
		mov	ecx, edx
		mov	dword_40CCB8, edx
		and	ecx, 0FFh
		mov	edx, ecx
		shl	edx, 5
		or	edx, ecx
		shl	edx, 5
		or	edx, ecx
		push	edx		; COLORREF
		push	eax		; int
		mov	eax, chdc
		push	esi		; int
		push	eax		; HDC
		call	ebx ; SetPixelV
		cmp	dword_40DCC4[edi*4], 1
		jg	short loc_401552
		call	_rand
		cdq
		mov	ecx, 15Eh
		idiv	ecx
		mov	esi, edx
		call	_rand
		cdq
		mov	ecx, 0AFh
		idiv	ecx
		lea	edx, [esi+edx-15Eh]
		mov	dword_40CD24[edi*4], edx
		call	_rand
		cdq
		mov	ecx, 0A0h
		idiv	ecx
		mov	esi, edx
		call	_rand
		cdq
		mov	ecx, 50h
		idiv	ecx
		lea	eax, [edi+4Bh]
		mov	dword_40DCC4[edi*4], eax
		lea	edx, [esi+edx-0A0h]
		mov	dword_40D4F4[edi*4], edx

loc_401552:
		inc	edi
		cmp	edi, 1F4h
		jl	loc_40141B
		pop	edi
		pop	esi
		pop	ebx
		ret
DrawStars	endp
