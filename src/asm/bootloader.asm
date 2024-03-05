[BITS 16]
[ORG 0x7C00]

CLI
    XOR AX, AX
    MOV DS, AX
    MOV ES, AX
    MOV SS, AX
    MOV SP, 0x7C00
    MOV BP, SP
    STI

_bootloader:

mov ax, 0x00
mov ss, ax
mov sp, 0x6000

call enable_a20_gate
call set_video_mode
call set_protect_mode
jmp c

enable_a20_gate:
        mov ax, 0x2401 
        int 0x15
        ret

set_video_mode:
        mov ah, 0x00
        mov al, 0x13
        int 0x10
        ret

set_protect_mode:
        mov eax, cr0
        or eax, 1
        mov cr0, eax
        jmp 0x08:start_pmode

start_pmode:
mov ax, 0x10
mov ds, ax
mov es, ax
mov fs, ax
mov gs, ax
mov ss, ax
mov esp, 0xfffffff0

c:

times 510-($-$$) db 0
dw      0xAA55