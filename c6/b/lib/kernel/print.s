TI_GDT equ 0
RPL0 equ 0
SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0

[bits 32]
section .text

; ----------------- put_char ------------------
global put_char
put_char:
    pushad
    mov ax, SELECTOR_VIDEO
    mov gs, ax


    ;; ----- get current position of cursor ---------
    ; first get the high 8 bits
    mov dx, 0x03d4
    mov al, 0x0e
    out dx, al
    mov dx, 0x03d5
    in  al, dx
    mov ah, al

    ; second, get the low 8 bits
    mov dx, 0x03d4
    mov al, 0x0f
    out dx, al
    mov dx, 0x03d5
    in  al, dx
    
    ; move the position to bx
    mov bx, ax
    mov ecx, [esp + 36]
    
    cmp cl, 0xd
    jz .is_carriage_return
    cmp cl, 0xa
    jz .is_line_feed

    cmp cl, 0x8 ; backspace asc is 8
    jz .is_backspace
    jmp .put_other
;;;;;;;;;;;;;;;;;;;;;;;;;;
.is_backspace:
    dec bx
    shl bx, 1 ; * 2

    mov byte [gs:bx], 0x20
    inc bx
    mov byte [gs:bx], 0x07
    shr bx, 1
    jmp .set_cursor
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.put_other:
    shl bx, 1

    mov [gs:bx], cl
    inc bx
    mov byte [gs:bx], 0x07
    shr bx, 1
    inc bx
    cmp bx, 2000
    jl .set_cursor

.is_line_feed: ; this is LF (\n)
.is_carriage_return: ; this is CR (\r)
    xor dx, dx ; make dx zero
    mov ax, bx
    mov si, 80

    div si ; ax / si
    ; dx = ax % si
    sub bx, dx

.is_carriage_return_end:
    add bx,80
    cmp bx, 2000
.is_line_feed_end:
    ; if lower
    ; if bx < 2000
    jl .set_cursor

.roll_screen:
    cld
    mov ecx, 960

    mov esi, 0xc00b80a0
    mov edi, 0xc00b8000
    rep movsd ; once move 4 byte

    mov ebx, 3840
    mov ecx, 80

.cls:
    mov word [gs:ebx], 0x0720
    add ebx, 2
    loop .cls
    mov bx, 1920

.set_cursor:
    mov dx, 0x03d4
    mov al, 0x0e
    out dx, al
    mov dx, 0x03d5
    mov al, bh
    out dx, al

    ;;;;;; 2. set low 8 bits
    mov dx, 0x03d4
    mov al, 0x0f
    out dx, al
    mov dx, 0x03d5
    mov al, bl
    out dx, al
.put_char_done:
    popad
    ret

; ---------------------------------------
; put_str print a string ending with \0
;---------------------------------------
global put_str
put_str:
    push ebx
    push ecx ; 8 byte
    xor ecx, ecx ; clear
    ; get the first address of the str
    mov ebx, [esp + 12]
.goon:
    mov cl, [ebx]
    cmp cl, 0
    ; if ending jmp .str_over
    jz .str_over
    push ecx
    call put_char
    add esp, 4
    ; one char will use 1 byte
    inc ebx
    jmp .goon
.str_over:
    pop ecx
    pop ebx
    ret