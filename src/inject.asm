; =====================================================
; Vicious DLL Injector, ver.1.0
; =====================================================

	CreateToolhelp32Snapshot PROTO :DWORD, :DWORD
	Process32FirstW PROTO :DWORD, :DWORD
	Process32NextW PROTO :DWORD, :DWORD

	CloseHandle PROTO :DWORD
	GetModuleHandleW PROTO :DWORD
	GetProcAddress PROTO :DWORD, :DWORD
	OpenProcess PROTO :DWORD, :DWORD, :DWORD

	VirtualAllocEx PROTO :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
	VirtualFreeEx PROTO :DWORD, :DWORD, :DWORD, :DWORD
	
	WriteProcessMemory PROTO :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
	CreateRemoteThread PROTO :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
	WaitForSingleObject PROTO :DWORD, :DWORD

	TH32CS_SNAPPROCESS EQU 00000002h

	PROCESS_CREATE_THREAD EQU 0002h
	PROCESS_QUERY_INFORMATION EQU 0400h
	PROCESS_VM_READ EQU 0010h
	PROCESS_VM_WRITE EQU 0020h
	PROCESS_VM_OPERATION EQU 0008h

	MEM_RESERVE EQU 00002000h
	MEM_COMMIT EQU 00001000h
	MEM_RELEASE EQU 00008000h
	PAGE_READWRITE EQU 04h

	;PROCESSENTRY32 STRUCT
	;	dwSize              DWORD ?
	;	cntUsage            DWORD ?
	;	th32ProcessID       DWORD ?
	;	th32DefaultHeapID   DWORD ?
	;	th32ModuleID        DWORD ?
	;	cntThreads          DWORD ?
	;	th32ParentProcessID DWORD ?
	;	pcPriClassBase      DWORD ?
	;	dwFlags             DWORD ?
	;	szExeFile           DW 260 dup(?)
	;PROCESSENTRY32 ENDS


.DATA
	dwKernel32Dll DW "k","e","r","n","e","l","3","2",".","d","l","l",0
	dbLoadLibraryProc DB "LoadLibraryW",0

.CODE

TestMessageBox2 proc
	push	delta
delta:
	pop	ecx
	sub	ecx,offset delta

	lea	eax,[ecx + szWndTitle]
	lea	ebx,[ecx + szWndText]

	push	MB_OK
	push	eax
	push	ebx
	push	0
	call	MessageBoxA
	ret

	szWndTitle	db	"Title",0
	szWndText	db	"Text",0
TestMessageBox2 ENDP

TestMessageBox proc szMessage:DWORD, szCap:DWORD
	push	MB_OK
	push	szMessage
	push	szCap
	push	0
	call	MessageBoxA
	ret
TestMessageBox ENDP



StringCompareW PROC s1:DWORD, s2:DWORD
	mov edx, s1
	mov edi, s2
	mov eax, -2
	xor ecx, ecx

StringCompareWLabel1:
	add eax, 2
	mov cx, WORD PTR [edx + eax]
	cmp cx, WORD PTR [edi + eax]
	jne StringCompareWEnd1
	test cx, cx
	jnz StringCompareWLabel1
	shr eax, 1
	ret

StringCompareWEnd1:
	xor eax, eax
	ret
StringCompareW ENDP

StringLengthW PROC s:DWORD
	mov ecx, s
	mov edx, -2
	mov eax, -1
StringLengthLabel1:
	add edx, 2
	inc eax
	cmp DWORD PTR [ecx + edx], 0
	jne StringLengthLabel1
	ret
StringLengthW ENDP


Inject	proc	exeName:DWORD, dllPath:DWORD
	LOCAL procEntry:PROCESSENTRY32
	LOCAL toolhelp32Handle:DWORD
	LOCAL procId:DWORD

	LOCAL llAddr:DWORD
	LOCAL hProc:DWORD
	LOCAL dllAddrAlloc:DWORD
	LOCAL dllThread:DWORD

	;invoke TestMessageBox, exeName, dllPath

	; Get Process Id
	mov procEntry.dwSize, sizeof PROCESSENTRY32

	push 0
	push TH32CS_SNAPPROCESS
	call CreateToolhelp32Snapshot
	mov toolhelp32Handle, eax

	mov procId, 0

	lea edx, [procEntry]
	push edx
	push eax
	call Process32FirstW

	test al,al
	je GetProcessIdWhile1End
	
GetProcIdWhile1:
	lea eax, [procEntry]
	push eax
	push toolhelp32Handle
	call Process32NextW

	test al,al
	je GetProcessIdWhile1End

	lea eax, [procEntry.szExeFile]
	push eax
	push exeName
	call StringCompareW

	test eax, eax
	je GetProcIdWhile1

	mov eax, procEntry.th32ProcessID
	mov procId, eax

GetProcessIdWhile1End:
	push toolhelp32Handle
	call CloseHandle

	; it looks like it's 0 here:(
	cmp procId, 0
	je MainEnd1
	; Get Process Id END

	; Inj
	push OFFSET dwKernel32Dll
	call GetModuleHandleW

	test eax, eax
	je MainEnd1

	push OFFSET dbLoadLibraryProc
	push eax
	call GetProcAddress

	test eax, eax
	je MainEnd1

	mov llAddr, eax

	push procId
	push 0
	push PROCESS_CREATE_THREAD OR PROCESS_QUERY_INFORMATION OR PROCESS_VM_READ OR PROCESS_VM_WRITE OR PROCESS_VM_OPERATION
	call OpenProcess
	
	test eax, eax
	je MainEnd1

	mov hProc, eax

	push dllPath
	call StringLengthW

	add eax, eax
	inc eax
	mov edx, eax
	push edx

	push PAGE_READWRITE
	push MEM_RESERVE OR MEM_COMMIT
	push eax
	push 0
	push hProc
	call VirtualAllocEx

	test eax, eax
	je MainEnd2

	mov dllAddrAlloc, eax
	pop eax

	push 0
	push eax
	push dllPath
	push dllAddrAlloc
	push hProc
	call WriteProcessMemory

	test eax, eax
	je MainEnd3

	push 0
	push 0
	push dllAddrAlloc
	push llAddr
	push 0
	push 0
	push hProc
	call CreateRemoteThread

	test eax, eax
	je MainEnd3

	mov dllThread, eax

	push 5000
	push eax
	call WaitForSingleObject

	push dllThread
	call CloseHandle
MainEnd3:
	push MEM_RELEASE
	push 0
	push dllAddrAlloc
	push hProc
	call VirtualFreeEx
MainEnd2:
	push hProc
	call CloseHandle
	; Inj END

MainEnd1:
	xor eax, eax
	;invoke TestMessageBox, exeName, exeName
	ret
Inject ENDP