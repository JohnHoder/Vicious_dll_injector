; =====================================================
; Vicious DLL Injector, ver.1.0
; © Jan Hodermarsky (HardC0re, JohnHoder), 2015-2017
; =====================================================

include .\src\libs\mfmplayer\mfmplayer.inc
includelib .\src\libs\mfmplayer\mfmplayer.lib

.const
	IDR_MUSIC		equ		500

.data
	muzax		dd offset muzax_end - offset muzax - 4 ;dane modka w postaci db xx,xx,xx...
	include 	.\res\sfx\chiptune.inc
	muzax_end	equ $

.data?
	nMusicSize		DWORD	?
	pMusic			LPVOID	?

.code

PlayMusic proc
	invoke mfmPlay, offset muzax
	ret
PlayMusic endp

PlayMusicFromRes proc
	push esi
	invoke FindResource, hInstance, IDR_MUSIC, RT_RCDATA
	push eax
	invoke SizeofResource, hInstance, eax
	mov nMusicSize, eax
	pop eax
	invoke LoadResource, hInstance, eax
	invoke LockResource, eax
	mov esi, eax
	mov eax, nMusicSize
	add eax, SIZEOF nMusicSize
	invoke GlobalAlloc, GPTR, eax
	mov pMusic, eax
	mov ecx, nMusicSize
    mov dword ptr [eax], ecx
    add eax, SIZEOF nMusicSize
    mov edi, eax
    rep movsb
    invoke mfmPlay, pMusic
    pop esi
    ret
PlayMusicFromRes endp


StopMusic proc
	push esi
	invoke mfmPlay, 0
    ;invoke GlobalFree, pMusic ;use only when playing from res
    pop esi
	ret
StopMusic endp