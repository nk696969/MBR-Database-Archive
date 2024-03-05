use16		; use 16 bit code when assembling

;org 07C00h		; Set bootsector to be at memory location hex 7C00h (UNCOMMENT IF USING AS BOOTSECTOR)
org 8000h		; Set memory offsets to start here

;; To work on real hardware e.g. Thinkpad x60, need to zero out data/extra segments first
xor ax, ax
mov ds, ax
mov es, ax

jmp setup_game	; Jump over Variables section so we don't try to execute it

;; CONSTANTS -----------
VIDMEM		 equ 0B800h	; Color text mode VGA memory location
ROWLEN		 equ 160	; 80 Character row * 2 bytes each
PLAYERX		 equ 4		; Player X position
CPUX		 equ 154	; CPU X position
KEY_W		 equ 11h	; Keyboard scancodes...
KEY_S		 equ 1Fh
KEY_C		 equ 2Eh	
KEY_R		 equ 13h
SCREENW		 equ 80
SCREENH		 equ 24
PADDLEHEIGHT equ 5
PLAYERBALLSTARTX equ 66	; Ball X position for start of round - player side
CPUBALLSTARTX    equ 90 ; Ball X position for start of round - cpu side
BALLSTARTY	     equ 7	; Ball Y position for start of round
WINCOND			 equ 3	; Score needed to end game
TIMER            equ 046Ch  ; # of Timer ticks since boot/midnight - from BIOS data area

;; VARIABLES -----------
drawColor: dw 0F020h
playerY:   dw 10	; Start player Y position 
cpuY:	   dw 10	; Start cpu Y position 
ballX:	   dw 66	; Starting ball X position
ballY:	   dw 7		; Starting ball Y position
ballVelX:  db -2	; Ball X direction
ballVelY:  db 1		; Ball Y direction
playerScore: db 0
cpuScore:	 db 0
cpuTimer:	 db 0	; # of cycles before CPU allowed to move
cpuDifficulty: db 1	; CPU "difficulty" level

;; LOGIC ===================
setup_game:
	;; Set up video mode
	mov al, 03h	    ; Set video mode BIOS interrupt 10h AH 00h; AL 03h text mode 80x25 chars, 16 color VGA
	int 10h

	;; Hide cursor
	inc ah
	mov ch, 25
	int 10h			; int 10h AH 01h set cursor shape; CH starting, CL ending line (CH > max row = 24)

	;; Set up video memory
	mov ax, VIDMEM
	mov es, ax	; ES:DI <- B800:0000

;; Game loop
game_loop:
	;; Clear Screen to black every cycle
	xor ax, ax
	xor di, di
	mov cx, 80*25
	rep stosw

	;; Draw middle separating line
	mov ax, [drawColor]	; White bg, black fg
	mov di, 78			; Start at middle of 80 character row
	mov cl, 13			; 'Dashed' line - only draw every other row
	.draw_middle_loop:
		stosw
		add di, 2*ROWLEN-2		; Only draw every other row and subtract off extra word
		loop .draw_middle_loop	; Loops CX # of times

	;; Draw player and CPU paddles
	imul di, [playerY], ROWLEN	; Y position is Y # rows * length of row
	imul bx, [cpuY], ROWLEN
	mov cl, PADDLEHEIGHT
	.draw_player_loop:
		mov [es:di+PLAYERX], ax
		mov [es:bx+CPUX], ax
		add di, ROWLEN
		add bx, ROWLEN
		loop .draw_player_loop
	
	;; Draw Scores
	draw_player_score:
		mov ah, 0E0h
		mov cl, [playerScore]
		jcxz draw_cpu_score
		mov di, ROWLEN+66		; Player score
		.loop:
			stosw				; Draw the score
			inc di
			inc di				; Draw next point 2 cells over
			loop .loop

	draw_cpu_score:
		mov cl, [cpuScore]
		jcxz get_player_input
		mov di, ROWLEN+90
		.loop:
			stosw				; Draw the score
			inc di
			inc di				; Draw next point 2 cells over
			loop .loop

	get_player_input:
		;; Get Player input
		mov ah, 1			; BIOS get keyboard status int 16h AH 01h
		int 16h
		jz move_cpu_up		; No key entered, don't check, move on

		cbw					; Zero out AH in 1 byte
		int 16h				; BIOS get keystroke, scancode in AH, character in AL
			
		cmp ah, KEY_W		; Check what key user entered...
		je w_pressed
		cmp ah, KEY_S
		je s_pressed
		cmp ah, KEY_C
		je c_pressed
		cmp ah, KEY_R
		je r_pressed

		jmp move_cpu_up		; Otherwise user entered some other key, move on, don't worry about it

	;; Move player paddle up
	w_pressed:
		dec word [playerY]	; Move 1 row up
		jge	move_cpu_up		; If player Y is at/above 0 (minimum Y value), then move on
		inc word [playerY]	; Else increment row # for collision check
		jmp move_cpu_up
	
	;; Move player paddle down
	s_pressed:
		cmp word [playerY], SCREENH - PADDLEHEIGHT	; Is player going to pass bottom of screen?
		jg move_cpu_up								; Yes, don't move
		inc word [playerY]						; No, can move 1 row down
		jmp move_cpu_up

	;; Reset game to initial state
	r_pressed:
		int 19h			; Reloads the bootsector (in QEMU)

	;; Change Color of Middle line and paddles
	c_pressed:
		add word [drawColor], 1000h		; Move to next VGA color
		
	;; Move CPU 
	move_cpu_up:
		;; CPU difficulty: Only move cpu every cpuDifficulty # of game loop cycles
		mov bl, [cpuDifficulty]
		cmp [cpuTimer], bl		; Did we reach the difficulty # of cycles?
		jl inc_cpu_timer
		mov byte [cpuTimer], 0
		jmp move_ball

		inc_cpu_timer:
			inc byte [cpuTimer]

		mov bx, [cpuY]
		cmp bx, [ballY]		; Is top of CPU paddle at or above the ball?
		jl move_cpu_down	; Yes, move on	
		dec word [cpuY]		; No, move cpu up
		jge move_ball		; CPU at or above Y minimum (0), move on
		inc word [cpuY]		; If CPU hit top of area, move back down to correct
		jmp move_ball

	move_cpu_down:	
		add bx, PADDLEHEIGHT-1
		cmp bx, [ballY]		; Is bottom of CPU paddle at or below the ball?
		jg move_ball		; Yes, move on
		cmp bx, 24			; No, is bottom of cpu at bottom of screen?
		je move_ball		; Yes, move on
		inc word [cpuY]		; No, move cpu down one row
	
	;; Move Ball
	move_ball:
		;; Draw ball
		imul di, [ballY], ROWLEN
		add di, [ballX]
		mov word [es:di], 2020h		; Green bg, black fg

		mov bl, [ballVelX]		; Ball X position change
		add [ballX], bl	
		mov bl, [ballVelY]		; Ball Y position change
		add [ballY], bl

	;; Check collisions
	check_hit_top_or_bottom:
		mov cx, [ballY]
		jcxz reverse_ballY		; If ball hit top of screen
		cmp cx, 24				; Did ball hit bottom of screen? (Y maximum value = 24)
		jne check_hit_player
				
	reverse_ballY:
		neg byte [ballVelY]

	check_hit_player:
		cmp word [ballX], PLAYERX+2		; Is ball at same position as player paddle?
		jne check_hit_cpu			; No, move on
		mov bx, [playerY]
		cmp bx, [ballY]				; Is top of player paddle equal or above the ball?
		jg check_hit_cpu			; No, move on
		add bx, PADDLEHEIGHT		; Check if hit bottom of player paddle			
		cmp bx, [ballY]				
		jl check_hit_cpu			; Bottom of paddle is above ball, move on
		jmp reverse_ballX			; Otherwise hit ball, reverse X direction

	check_hit_cpu:
		cmp word [ballX], CPUX-2		; Is ball at same position as CPU paddle?
		jne check_hit_left			; No, move on
		mov bx, [cpuY]
		cmp bx, [ballY]				; Is top of cpu paddle <= the ball?
		jg check_hit_left			; No, move on
		add bx, PADDLEHEIGHT
		cmp bx, [ballY]				; Is bottom of cpu paddle >= the ball?
		jl check_hit_left			; No, move on

	reverse_ballX:
		neg byte [ballVelX]			; Yes, hit player/cpu,  reverse X direction

	check_hit_left:
		cmp word [ballX], 0			; Did ball hit/pass left side of screen?
		jg check_hit_right			; No, move on
		inc byte [cpuScore]
		mov bx, PLAYERBALLSTARTX	; No, reset ball for next round
		jmp reset_ball

	check_hit_right:
		cmp word [ballX], ROWLEN	; Did ball hit/pass right side of screen?
		jl end_collision_checks		; No, move on
		inc byte [playerScore]
		mov bx, CPUBALLSTARTX		; No, reset ball for next round

	;; Reset Ball for next round
	reset_ball:
		cmp byte [cpuScore], WINCOND	    ; Did CPU win the game?
		je game_lost
		cmp byte [playerScore], WINCOND		; Did player win game?
		je game_won
		
		;; Check/Change cpu difficulty for every player point scored 
		imul cx, [playerScore], 20
		jcxz reset_ball_2
		mov [cpuDifficulty], cx
	
		;; Randomize ball start X position a bit for variety
		cbw		    ; AH = 0 if AL < 128
		int 1Ah	    ; # of timer ticks since midnight in CX:DX
		mov ax, dx  ; lower half of timer ticks #
		xor dx, dx
		mov cx, 10
		div cx		; AX / CX, DX(DL) = remainder (0-9)
		shl dx, 1	; DX *= 2
		add bx, dx

	reset_ball_2:	
		mov [ballX], bx	
		mov word [ballY], BALLSTARTY

	end_collision_checks:
		;; Delay timer for next cycle
		mov bx, [TIMER]
		inc bx              ; 2 tick delay
		inc bx              ; 1 tick delay
		.delay:
			cmp [TIMER], bx	
			jl .delay

jmp game_loop

game_won:
	mov dword [es:0000], 0F490F57h  ; WI
	mov dword [es:0004], 0F210F4Eh	; N!
	cli
	hlt	

game_lost:
	mov dword [es:0000], 0F4F0F4Ch	; LO
	mov dword [es:0004], 0F450F53h	; SE
	cli
	hlt	

;; END LOGIC ================

;; Bootsector padding
times 510-($-$$) db 0
dw 0AA55h       ; Bootsector signature