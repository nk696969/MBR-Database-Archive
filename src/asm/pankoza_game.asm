        org 0x7c00

        xor ax,ax
        push ax
        mov cx,0xff
        mov si,0x100
        mov di,0xfffe
        mov bp,0x091c

        adc al,0x13
        mov dx,0x330
        rep outsb
clr:
        int 0x10
        mov ax,0xc4f
        out 0x40,al
        loop clr
        pop ds
        push word 0xa500
        pop es
loop:
        mov ax,0xcccd
        mul di
        mov ax,bp
        sub dh,0xf6
        div dh
        xchg ax,dx
        sub al,0x7f
        imul dl
        add dl,[0x46c]
        xchg ax,dx
        xor dh,al
        imul dh
        aam 0x9
        pushfw
        popfw
        sub al,0x74
        stosb
        scasw
        jmp loop
        leave
        cmp [bx+di+0x6746],bl
        push cx
        db 0x7f

        times 510-($-$$) db 0
        db 0x55,0xaa