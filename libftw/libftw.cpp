// libftw.cpp : Defines the entry point for the DLL application.
//

#include "stdafx.h"
#include <tlhelp32.h>

#define IDCX 456
#define IDC_REFRESH	120
#define IDC_SELECT	121
#define IDC_WINPROC	100
#define IDC_PROC	555


char Data[260];
HWND ProcessesBox;
HANDLE RecvProc;

HWND	parentWnd;

DWORD WINAPI PWindow(HWND parent);

typedef BOOL (WINAPI *TH32_PROCESS)  
(HANDLE hSnapShot, LPPROCESSENTRY32 lppe); 

static TH32_PROCESS pProcess32First = NULL;  
static TH32_PROCESS pProcess32Next = NULL; 

HANDLE hInst = NULL;

extern "C" void __declspec(dllexport) showMessageBox(const LPCSTR sometext)
{
    MessageBoxA(0, sometext, "DLL Message", MB_OK | MB_ICONINFORMATION);
}

extern "C" DWORD __declspec(dllexport) drawToWnd(HWND hWin)
{
    //MessageBoxA(hWin, "Handle obtained?", "DLL Message", MB_OK | MB_ICONINFORMATION);
	
	CreateWindowEx(0,"BUTTON","DLL",
		WS_CHILD | BS_AUTOCHECKBOX | WS_VISIBLE,
		5,318,60,15,
		hWin,HMENU(IDCX),
		(HINSTANCE)hInst,0);
	
	return 0;
}

extern "C" DWORD __declspec(dllexport) chooseProcessWnd(HWND hWin)
{
	parentWnd = hWin;
	PWindow(hWin);
	return 0;
}

BOOL APIENTRY DllMain( HANDLE hInstance, DWORD  dwReason,  LPVOID lpReserved)
{
	switch (dwReason)
	{
	case DLL_PROCESS_ATTACH:
		{
			hInst = hInstance;
			//showMessageBox("TOF owns ya, byatch!");
			//MessageBox(0, "dll", "DLL Message", MB_OK | MB_ICONINFORMATION);
		}
	}
	return true;
}



//333333333333333333333333333333333333333333333333333333333333333333333333333333333333333

DWORD WINAPI GetProcesses(LPVOID)
{
    
	PROCESSENTRY32 pe32 = {0};
	HANDLE hSnapshot = NULL; 
	HINSTANCE hDll = LoadLibrary("kernel32.dll"); 
	
	pProcess32First=(TH32_PROCESS)GetProcAddress(hDll, "Process32First"); 
	pProcess32Next=(TH32_PROCESS)GetProcAddress(hDll, "Process32Next"); 
	
	hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);               
	if(hSnapshot != (HANDLE) -1) 
	{ 
		pe32.dwSize = sizeof(PROCESSENTRY32); 
		int proc_cnt = 0, thrd_cnt = 0;
		
		if(pProcess32First(hSnapshot, &pe32)) 
		{ 
			do 
			{ 
				strcpy(Data, pe32.szExeFile);
				SendMessage(ProcessesBox, LB_INSERTSTRING, (WPARAM)-1, (LPARAM)Data);
			}  
			while(pProcess32Next(hSnapshot, &pe32)); 
			CloseHandle(hSnapshot);
		}
	}
	return 0;
}


LRESULT CALLBACK ProcessesCallback (HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
{
	int Cursel;
	
    switch (message)
    {
    case WM_DESTROY:
		strcpy(Data, "");
		PostQuitMessage(0);
		break;
		
    case WM_CREATE:
		CreateWindowEx(0, "Button", "Refresh", WS_VISIBLE | WS_CHILD | WS_BORDER, 40, 260, 70, 20, hwnd, (HMENU)IDC_REFRESH, 0, NULL);
		CreateWindowEx(0, "Button", "Select", WS_VISIBLE | WS_CHILD | WS_BORDER, 130, 260, 70, 20, hwnd, (HMENU)IDC_SELECT, 0, NULL);
		ProcessesBox = CreateWindowEx(0, "ListBox", 0, WS_VISIBLE | WS_CHILD | WS_BORDER | WS_VSCROLL | LBS_DISABLENOSCROLL, 20, 10, 200, 240, hwnd, (HMENU)IDC_WINPROC, 0, NULL);
		
		RecvProc = CreateThread(NULL, 0, GetProcesses, 0, 0, NULL);
		break;
		
    case WM_COMMAND:
		switch(LOWORD(wParam))
		{
		case IDC_REFRESH:
			TerminateThread(RecvProc, 0);
			SendMessage(ProcessesBox, LB_RESETCONTENT, 0, 0);
			RecvProc = CreateThread(NULL, 0, GetProcesses, 0, 0, NULL);
			break;
			
		case IDC_SELECT:
			Cursel = SendMessage(ProcessesBox, LB_GETCURSEL, 0, 0);
			SendMessage(ProcessesBox, LB_GETTEXT, (WPARAM)Cursel, (LPARAM)Data);
			SendMessage(parentWnd, WM_NOTIFY, IDC_PROC, (LPARAM)Data);
			DestroyWindow(hwnd);
			break;
		}
		
		default:
			return DefWindowProc (hwnd, message, wParam, lParam);
    }
	return 0;
}

DWORD WINAPI PWindow(HWND parent)
{
    HWND hwnd;
    MSG messages;
    WNDCLASSEX wincl;
	
    wincl.hInstance = 0;
    wincl.lpszClassName = "Processes";
    wincl.lpfnWndProc = ProcessesCallback;
    wincl.style = CS_DBLCLKS;
    wincl.cbSize = sizeof (WNDCLASSEX);
	
    wincl.hIcon = LoadIcon (NULL, IDI_APPLICATION);
    wincl.hIconSm = LoadIcon (NULL, IDI_APPLICATION);
    wincl.hCursor = LoadCursor (NULL, IDC_ARROW);
    wincl.lpszMenuName = NULL;
    wincl.cbClsExtra = 0;
    wincl.cbWndExtra = 0;
    wincl.hbrBackground = (HBRUSH) COLOR_BACKGROUND+4;
	
    RegisterClassEx(&wincl);
	
    hwnd = CreateWindowEx (
		0,
		"Processes",
		"Processes",
		WS_SYSMENU | WS_VISIBLE | WS_POPUP, //here we added WS_POPUP and it's not tested yet
		CW_USEDEFAULT,
		CW_USEDEFAULT,
		250,
		380,
		parent,
		NULL,
		0,
		NULL
		);
	
    while (GetMessage (&messages, NULL, 0, 0))
    {
        TranslateMessage(&messages);
        DispatchMessage(&messages);
    }
	return 0;
}