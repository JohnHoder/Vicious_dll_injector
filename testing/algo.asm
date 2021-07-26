
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
; ASTRAL 2010 MASM32 IM Dialog Template
; ++Meat code & technics
; http://astral.tuxfamily.org/
; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл

.data?

Buffer  db 50 dup (?)

.data

Product db "Adobe Photoshop CS5", 0
Cracker db "Meat * ASTRAL", 0
About   db "Meat * ASTRAL", 13, 10
        db "proudly presents", 13, 10
        db "----------------", 13, 10
        db "XTX Keygen Template", 13, 10, 13, 10
        db "Feel free to use it, it's free, you can even abuse on the About's text lenght... But not that much !", 13, 10, 13, 10
        db "Greetz to : XTX ASTRAL FC and all the things I love !", 13, 10
        db "Peace !", 0
NoName  db "No name, no game !", 0

.code

; ллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл

Algo proc hWnd:HWND

    fn GetDlgItemText, hWnd, eName, ADDR Buffer, 50
    .IF (!eax)
        lea eax, NoName
        ret
    .ENDIF

    lea eax, Buffer                                                         ; return value : ADDR Buffer
    ret

Algo endp
