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

    mov byte [gs:160], 'P'

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
