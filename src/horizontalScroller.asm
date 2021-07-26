; =====================================================
; Vicious DLL Injector, ver.1.0
; © Jan Hodermarsky (HardC0re, JohnHoder), 2015-2017
; =====================================================

; Horizontal scroller

.const
;================================ scroll  horizontal==========================
	ScreenWidth    equ 320
	ScreenHeight   equ 20
;================================ scroll  horizontal==========================

.data

	include .\res\fonts\g_goldyfont.inc

; |************ SCROLLER DATA *************|

	text_message    db "                                      "
					db "VICIOUS DLL INJECTOR 1.0"
					db "      "
					db "LA FIN JUSTIFIE LES MOYENS"
					db "      "
					db "GREETZ TO:"
					db "     TEAM OPENFIRE    CODE104     ICA    ICF      "
					db "THANKZ TO:"
					db "     LIONANEESH      EVISCERATI0N     MISHRAJI     MAINI"
					db "   "
					db "  "
					db "WITH LOVE"
					db "     HARDC0RE      "
					db "                                     ",0

	message_index   dd 0
	posindex        dd 0

.code
Draw_Scroller proc
 
	LOCAL gfx_yindex       :DWORD                         ; Y index of draw position
	LOCAL sm_allcharswidth :DWORD                         ; Width of entire character set
	LOCAL sm_onecharwidth  :DWORD                         ; Width of 1 character 
	LOCAL sm_onecharleng   :DWORD                         ; Length of 1 char  (if ur character set is 8x8 then both are 8)
	LOCAL letter_index     :DWORD                         ; Current character to print to screen
	LOCAL x_position       :DWORD                         ; Onscreen X position of scroller
	LOCAL y_position       :DWORD                         ; Onscreen Y position of scroller
	LOCAL scroll_spacer    :DWORD                         ; Smount of space between letters
	LOCAL msg_index        :DWORD                         ; Index for text message.
	LOCAL draw_buffer      :DWORD

;----
; Scroller Function Setup.
;---------------------------------------------------------------------------------------

	pushad                            ; Save all registers.

	mov draw_buffer,edi

	mov msg_index,0                   ; Start at char 0 in the message.===================////////////////////////////////////////////////////////////////////////////////////////==========
	mov x_position,6                  ; Set the X position on screen.
	mov y_position,4               	  ; Set the Y position on screen.
	mov sm_allcharswidth,512          ; Set length of entire font data.
	mov sm_onecharwidth,8             ; Set character width.   
	mov sm_onecharleng,14             ; Set character length
	mov scroll_spacer,0               ; Reset Scroll Spacer.
next_char:

;----
; Scroller Function Main.
;---------------------------------------------------------------------------------------
	mov gfx_yindex,0                  ; Reset Y plotting variable.
	mov edi,msg_index                 ; Work out what letter we 
	mov eax,offset text_message       ; are currently 
	add eax,message_index             ; starting from.

	movzx edi,byte ptr [eax+edi]      ; Move current letter into edi
	cmp edi,0                         ; Check if we have reached end 
	jnz no_message_reset              ; of message.
	mov message_index,0               ; If yes then we reset the message.
	
no_message_reset:
	sub edi,20h                       ; Subtract 20h from edi to work 
                                      ; out a reference for our gfx 
                                      ; data.
                                                      
	mov letter_index,edi              ; Save resulting offset into variable.
                    
	mov edi,draw_buffer               ; Setup our Screen buffer to write gfx to.
                    
	mov eax,posindex                  ; Add our scrolled amount to edi. 
	shl eax,2                         ; (convert to 32bit).
	sub edi,eax                       ; 
                    
	mov eax,y_position                ; Add Y offset to screen.  
	imul eax,ScreenWidth*4            ; 600*4 = 1 line down.
	add edi,eax                       ;

	mov eax,x_position                ; Add X offset to screen.
	shl eax,2                         ; 
	add edi,eax                       ; 
              
	mov eax,scroll_spacer             ; Add scroller text space position.
	imul eax,sm_onecharwidth          ; (multiply width of space by 1 char)
	shl eax,2                         ; (convert to 32bit)
	add edi,eax                       ;

;----
; Scroller Function Gfx Drawing Start.
;---------------------------------------------------------------------------------------
	mov esi,offset goldyfont_g        ; Set font raw data into esi.
	mov eax,letter_index              ; Move letter being drawn into eax.
	imul eax,sm_onecharwidth          ; Multiply the current letter by the char 
                                      ; width to obtain the exact place to read from.
                                                      
	add esi,eax                       ; Esi now = the correct place to start drawing.
                    
incY_line: 
	xor ecx,ecx                       ; Reset X plotting position.                     
incX_line:
	movzx eax,byte ptr [esi+ecx]      ; Move GFX data byte into eax.
	cmp eax,0                         ; Is it a black color byte?
	jnz pixel_not_black               ; jmp if byte is not black
                    
	jmp clip_pixel                    ; Dont Draw if color is black.
	
pixel_not_black:
	mov edx,offset goldyfont_p
	mov eax,[edx+eax*4]
            

plot_to_screen:
	stosd                             ; Draws pixel to our screen buffer
	
clip_pixel_return:
	inc ecx                           ; Increase X position of current letter gfx.
	cmp ecx,sm_onecharwidth           ; have we completed 1 whole line of X pixels?
	jnz incX_line                     ; If no then we draw the next pixel.

	mov eax,sm_onecharwidth           ; Move character width mutiplier into eax.
	mov ecx,ScreenWidth               ; Move screen width into ecx
	sub ecx,eax                       ; Subtract position of pixels we just drew.
                                                      ; (this places us back at the start of the letter) 
	shl ecx,2                         ; (convert to 32 bit)
                    
	add edi,ecx                       ; This drops the Screen position down 1 whole line.
                                                      ; (so now we are at line 2 of the letter (on screen). 
	add esi,sm_allcharswidth          ; This drops the GFX data down 1 whole line.
                                                      ; (so now we are at line 2 of the letter (gfx data). 
	inc gfx_yindex                    ; Increase overall Y index.
	mov eax,sm_onecharleng            ; Move character length into eax.
	cmp gfx_yindex,eax                ; Have we finished all lines?
	jnz incY_line                     ; If no then we keep drawing the next line.

;----
; Scroller Function Gfx Drawing End.
;---------------------------------------------------------------------------------------
	inc msg_index                     ; Move onto next letter in the text message. 
	inc scroll_spacer                 ; Update scroll offset. 
                                                      ; (so we dont draw the next letter on top of the last one.
   
	cmp msg_index,37                  ; Have we drawn all 40 characters onscreen?
	jnz next_char                     ; If no, we keep drawing from the text message.

	add posindex,1                   ; Move our scroll position along 1 pixel.
	cmp posindex,8                    ; have we scrolled (character width) pixels across the screen?
	jnz keep_scrolling                ; If no then we keep scrolling.
                                               
	mov posindex,0                    ; If yes then we reset the scrolling position back to 0. 
	add message_index,1               ; Add 1 to the overall message index.
                                      ; (IMPORTANT - the above 2 instructions create the illusion
                                      ; that the letter has actually scrolled across the screen) 
keep_scrolling:
	popad                             ; Restore all registers.
	ret                               ; Exit the function.

clip_pixel:
	add edi,4                         ; This moves the screen position on by 1 pixel.
	jmp clip_pixel_return             ; Jump back to drawing loop.

	popad
	ret
Draw_Scroller endp
