    %include "boot.inc"
    section loader vstart=LOADER_BASE_ADDR
    LOADER_STACK_TOP equ LOADER_BASE_ADDR
    jmp loader_start

; create gdt table
    GDT_BASE: dd 0x00000000
              dd 0x00000000
    
    CODE_DESC: dd 0x0000FFFF
              dd DESC_CODE_HIGH4
    
    DATA_STACK_DESC: dd 0x0000FFFF
                     dd DESC_DATA_HIGH4
    
    VIDEO_DESC: dd 0x80000007
                dd DESC_VIDEO_HIGH4 ;dpl is 0
    
    GDT_SIZE equ $ - GDT_BASE
    GDT_LIMIT equ GDT_SIZE - 1
    times 60 dq 0
    SELECTOR_CODE equ (0x0001<<3) + TI_GDT + RPL0
    SELECTOR_DATA equ (0x0002<<3) + TI_GDT + RPL0
    SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0

;=============
    total_mem_bytes dd 0
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;


    ; gdt pointer
    gdt_ptr dw GDT_LIMIT
            dd GDT_BASE
    
    ards_buf times 244 db 0
    ards_nr dw 0
    error_msg db 'get mem error'

loader_start:

; int 15h eax=0000E820h, edx=534D4150h ('SMAP') get memory struct

    xor ebx, ebx
    mov edx, 0x534d4150
    mov di, ards_buf ; ards buffer address

.e820_mem_get_loop:
    mov eax, 0x0000e820 ; eax will be set 0x534d4150
    mov ecx, 20
    int 0x15
    jc .e820_failed_so_try_e801
    add di, cx
    inc word [ards_nr]
    cmp ebx, 0
    jnz .e820_mem_get_loop
    ; loop number
    mov cx, [ards_nr]
    mov ebx, ards_buf
    xor edx, edx ; edx is max memory size
.find_max_mem_area:
    mov eax, [ebx] ;base_add_low
    add eax, [ebx + 8]
    add ebx, 20
    cmp edx, eax
    ; if edx >= eax
    jge .next_ards
    ; if edx < eax
    mov edx, eax
.next_ards:
    loop .find_max_mem_area
    jmp .mem_get_ok

;-------------- int 15h ax = E801h max memory size is 4G
.e820_failed_so_try_e801:
    mov ax, 0xe801
    int 0x15
    jc .e801_failed_so_try88

; 1. first low 15M memory size
    mov cx, 0x400
    mul cx
    shl edx, 16
    and eax, 0x0000FFFF
    or  edx, eax
    add edx, 0x100000
    mov esi, edx
; 2. second above 15M memory size
    xor eax, eax
    mov ax, bx
    mov ecx, 0x10000 ; 64kb
    mul ecx
    add esi, eax
    mov edx, esi ; edx is total memory size
    jmp .mem_get_ok

;---------------- int 15h ah = 0x88 ; lower 64M
.e801_failed_so_try88:
    mov ah, 0x88
    int 0x15
    jc .error_hlt
    and eax, 0x0000FFFF

    mov cx, 0x400 ; 1kb
    mul cx
    shl edx, 16
    or  edx, eax
    add edx, 0x100000 ; add 1M

.mem_get_ok:
    mov [total_mem_bytes], edx
    jmp .open_a20

.error_hlt:
    push ax
    mov ax, 0xb800
    mov gs, ax
    pop ax
    mov byte [gs:0x0a], 'E'
    mov byte [gs:0x0b], 0xA4

    jmp $


.open_a20:
    ; enter protect mode
    ; open a20
    in al, 0x92
    or al, 0000_0010b
    out 0x92, al

    ; load gdt
    lgdt [gdt_ptr]

    ; set the first bit of cr0 zero
    mov eax, cr0
    or  eax, 0x00000001
    mov cr0, eax

    jmp dword SELECTOR_CODE:p_mode_start ; reflash


[bits 32]
p_mode_start:
    mov ax, SELECTOR_DATA
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, LOADER_STACK_TOP
    mov ax, SELECTOR_VIDEO
    mov gs, ax

    ; loader kernel.bin
    mov eax, KERNEL_START_SECTOR
    mov ebx, KERNEL_BASE_ADDR
    ; loop count
    mov ecx, 200
    call rd_disk_m_32
    

    ; init page index
    call setup_page

    sgdt [gdt_ptr]

    mov ebx, [gdt_ptr + 2]
    or dword [ebx + 0x18 + 4], 0xc0000000

    add dword [gdt_ptr + 2], 0xc0000000
    
    add esp, 0xc0000000

    mov eax, PAGE_DIR_TABLE_POS
    mov cr3, eax

    mov eax, cr0
    or eax, 0x8000_0000
    mov cr0, eax

    lgdt [gdt_ptr]

    mov byte [gs:160], 'V'

    jmp $


; ------ create page index and page
setup_page:
    mov ecx, 4096
    mov esi, 0

.clear_page_dir:
    mov byte [PAGE_DIR_TABLE_POS + esi], 0
    inc esi
    loop .clear_page_dir

; create PDE
.create_pde:
    mov eax, PAGE_DIR_TABLE_POS
    add eax, 0x1000 ; this is the first page table's address
    mov ebx, eax

    or eax, PG_US_U | PG_RW_W | PG_P
    mov [PAGE_DIR_TABLE_POS + 0x0], eax
    mov [PAGE_DIR_TABLE_POS + 0xc00], eax

    sub eax, 0x1000 ; this address is the first page index
    mov [PAGE_DIR_TABLE_POS + 4092], eax

; create PTE
    mov ecx, 256
    mov esi, 0
    mov edx, PG_US_U | PG_RW_W | PG_P
.create_pte: ; create Page Table Entry
    mov [ebx + esi*4], edx

    add edx, 4096
    inc esi
    loop .create_pte

; create kernel and other PDE
    mov eax, PAGE_DIR_TABLE_POS
    add eax, 0x2000
    or  eax, PG_US_U | PG_RW_W | PG_P
    mov ebx, PAGE_DIR_TABLE_POS
    mov ecx, 254
    mov esi, 769
.create_kernel_pde:
    mov [ebx+esi*4], eax
    inc esi
    add eax, 0x1000
    loop .create_kernel_pde
    ret


; read disk 32
; eax : start sector number
; ebx : object memory address
; ecx : read count
rd_disk_m_32:
    mov esi, eax
    mov edi, ecx

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
    out edx, al

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
    in eax, edx ; read 1 word- two bytes- 32 bits
    mov [ebx], eax
    add ebx, 2
    loop .go_on_read
    ret

; copy the segments of kernel.bin to secect virtual address
kernel_init:
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    xor edx, edx

    mov dx, [KERNEL_BIN_BASE_ADDR + 42] ; this is the size of program, e_phentsize
    mov ebx, [KERNEL_BIN_BASE_ADDR + 28] ; this is e_phoff

    add ebx, KERNEL_BIN_BASE_ADDR
    ; loop count
    mov cx, [KERNEL_BIN_BASE_ADDR + 44] ; this is show the number of program header

.each_segment:
    cmp byte [ebx + 0], PT_NULL
    je .PT_NULL

    ; push memcpy function's parments
    ; like this memcpy( dst, src, size )
    push dword [ebx + 16] ; this is p_filesz

    mov eax, [ebx + 4] ; this is p_offset
    add eax, KERNEL_BIN_BASE_ADDR ; the first program segment start address

    push eax ; source address
    push dword [ebx + 8] ; this is object address, p_vaddr
    call mem_cpy
    add esp, 12 ; clean the 3 praments of stack
.PT_NULL:
    add ebx, edx ; now, ebx is pointer the next program header
    loop .each_segment
    ret

;----------- mem_cpy( dst, src, size ) --------------------
mem_cpy:
    cld
    push ebp
    mov ebp, esp
    push ecx ; rep command use ecx

    mov edi, [ebp + 8] ; dst
    mov esi, [ebp + 12] ; src
    mov ecx, [ebp + 16] ; size
    rep movsb

    ; recovery environment
    pop ecx
    pop ebp
    ret
