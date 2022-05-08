%include "boot.inc"
SECTION MBR vstart=0x7c00
    mov ax,cs
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov fs,ax
    mov sp,0x7c00
    mov ax,0xb800
    mov gs,ax

    ; clear screen
    mov ax, 0600h
    mov bx, 0700h
    mov cx, 0
    mov dx, 184fh
    int 10h

    ; print string
    mov byte [gs:0x00], '1'
    mov byte [gs:0x01], 0xA4

    mov byte [gs:0x02], ' '
    mov byte [gs:0x03], 0xA4

    mov byte [gs:0x04], 'M'
    mov byte [gs:0x05], 0xA4

    mov byte [gs:0x06], 'B'
    mov byte [gs:0x07], 0xA4

    mov byte [gs:0x08], 'R'
    mov byte [gs:0x09], 0xA4

    mov eax, LOADER_START_SECTOR
    mov bx, LOADER_BASE_ADDR
    mov cx, 4
    call rd_disk_m_16

    jmp LOADER_BASE_ADDR

rd_disk_m_16:
    mov esi, eax
    mov di, cx

    ;read disk
    ; 1. set num of reading
    mov dx,0x1f2
    mov al, cl
    out dx, al

    ; reconver data
    mov eax, esi
    ; 2. mov lba addr to 0x1f3 ~ 0x1f6

    mov dx,0x1f3
    out dx, al

    mov cl, 8
    shr eax, cl
    mov dx, 0x1f4
    out dx, al

    shr eax, cl
    mov dx, 0x1f5
    out dx, al

    shr eax, cl
    and al, 0x0f
    or al, 0xe0 ; set 1110
    mov dx, 0x1f6
    out dx, al

    ; read command 
    mov dx, 0x1f7
    mov al, 0x20
    out dx, al

; check disk status
.not_ready:
    nop
    ; get disk status
    in al, dx
    and al, 0x88
    cmp al, 0x08
    jnz .not_ready

; read data from 0x1f0
    mov ax, di
    mov dx, 256
    mul dx
    mov cx, ax ; loop number
    mov dx, 0x1f0

.go_on_read:
    in ax, dx ; read 1 word- two bytes- 16 bits
    mov [bx], ax
    add bx, 2
    loop .go_on_read
    ret

times 510-($-$$) db 0
db 0x55, 0xaa
