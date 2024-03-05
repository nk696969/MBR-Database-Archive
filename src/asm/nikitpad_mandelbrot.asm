    %define MAX_ITER 100

    bits 16
    org 0x7c00

    mov bx, 0xa000
    mov es, bx
    
    ; Initialize FPU.
	fninit
    
    ; Enter 320x200 256-color graphics mode (mode 13h).
	mov ax, 0x13
	int 0x10

frame:
    xor di, di
    mov ds, di

    fld dword [start]
    mov bp, 200
    
.vertical:
    fld dword [start]
    mov dx, 320
.horizontal:
    ; Put z on the stack, initialized as zero.
    ; z is a complex number, therefore, it actually
    ; consists of two floating-point numbers.
    ; Its real part is called zx,
    ; and its imaginary part is called zy.
    fldz
    fldz
    
    ; The core equation of the Mandelbrot set is
    ; z <- z^2 + c. This is complex math,
    ; which can be transformed into
    ; (zx, zy) <- (zx * zx - zy * zy + cx, 2 * zx * xy + cy),
    ; which is what we are implementing here.
    mov al, MAX_ITER
.loop:
    fld st0
    fmul st0, st0
    ; zx * zx 
    fld st2
    fmul st0, st0
    ; zy * zy
    fsubp st1, st0
    ; zx * zx - zy * zy
    fadd st0, st3
    ; zx * zx - zy * zy + cx
    fld st1
    fld st3
    fmulp
    ; zx * zy
    fadd st0, st0
    ; zx * zy + zx * zy = 2 * zx * zy
    fadd st0, st5
    ; 2 * zx * zy + cy
    
    ; So now what we have on the stack
    ; is the result of the z^2 + c formula,
    ; derived from the original z.
    ; Replace the original z with it.
    fstp st3
    fstp st1
    
    fld st0
    fmul st0, st0
    ; zx * zx
    fld st2
    fmul st0, st0
    ; zy * zy
    faddp
    ; zx * zx + zy * zy
    ; (squared magnitude of the new complex number)
    
    ; I tried doing an FPU comparison
    ; then it didn't work for some reason,
    ; so I just sent it to hell lol.
    fistp word [compare]
    ; Is the squared magnitude greater than 4?
    cmp word [compare], 4
    ; If yes, finish iterating.
    jge .exit_loop
    
    dec al
    jnz .loop
    
.exit_loop:
    ; Clear FPU stack.
    fstp st0
    fstp st0

    add ax, si
    stosb
    
    fadd dword [scale_x]
    dec dx
    jnz .horizontal
    fstp st0
    fadd dword [scale_y]
    dec bp
    jnz .vertical
    
    inc si
    fstp st0
    jmp frame

scale_x: dd 0.009375
scale_y: dd 0.015
start: dd -1.5
var1: dd 0.0
var2: dd 0.0
compare: dw 0

times 510-$+$$ db 0
dw 0xaa55