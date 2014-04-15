;------------------------------------------------------------------------------;
;                            The Imperial Ouch !                               ;
;------------------------------------------------------------------------------;
; A 512-bytes version of a war in the stars...                                 ;
;                                                                              ;
; Any similarity with an existing movie or soundtrack would for sure be        ;
; accidental...                                                                ;
;                                                                              ;
; I decline any responsibility for any damage by this code to your ears.       ;
;------------------------------------------------------------------------------;
; This program is free software. It comes without any warranty, to the extent  ;
; permitted by applicable law. You can redistribute it and/or modify it under  ;
; the terms of the Do What The Fuck You Want To Public License, Version 2, as  ;
; published by Sam Hocevar. See http://sam.zoy.org/wtfpl/COPYING for more      ;
; details.                                                                     ;
;------------------------------------------------------------------------------;
;            Christophe Chailloleau-Leclerc (Krap) - 2009                      ;
;      http://tux.ptitsmanchots.info - zekrap 0x40 gmail 0x2e com              ;
;------------------------------------------------------------------------------;
; This program combines a cellular automaton inspired from Conway's Game of    ;
; Life (http://www.conwaylife.com/wiki/index.php?title=Conway%27s_Game_of_Life);
; with a time-driven music player, after a short intro message.                ;
;                                                                              ;
; The goal being to have a nice-looking animation, and of course fitting in    ;
; 512 bytes, the simulation is not a true Life game, in two ways :             ;
;   - the grid is limited to screen size (should be infinite)                  ;
;   - new cells are added during simulation to create a cool animation         ;
;                                                                              ;
; Main algorithm :                                                             ;
;   - start graphics mode                                                      ; 
;   - display a short message (letter by letter, with a delay)                 ;
;   - start the music player (will live its life "in background")              ;
;   - load a gun and a spaceship shapes                                        ;
;   - start simulation                                                         ;
;   - every time music score is finished (told by music player),               ;
;     add a new spaceship to give a little more interest to the animation...   ;
;                                                                              ;
; The resulting animation will depend on your CPU performances, since the      ;
; new spaceships are added on a fixed timing, but the state of the game at     ;
; this time will depend only of number of iterations computed, that depends    ;
; only on CPU speed.                                                           ;
;                                                                              ;
; It seems that in general case, though, the spaceships debris destroys the gun;
; on long term, and keep destroying new spaceships - no winner to this war !   ;
;                                                                              ;
; The code is restricted to Intel 8086 instruction set, but makes use of BIOS  ;
;                                                                              ;
; Of course, this is NOT clean code, usable in real-life programs. Even the    ;
; timer interrupt handler do not preserve all the registers... Be warned !     ;
;------------------------------------------------------------------------------;
; To test this code (designed as a bootsector), after compiling it with NASM,  :
; you could :                                                                  ;
;   - write the bootsector to a floppy or an usb stick (or whatever, but don't ;
;     write it to your real boot hard drive !) and tell your BIOS to boot on it;
;   - run it using an emulator like qemu :                                     ;
;        qemu -soundhw pcspk bootsector_file_name                              ;
;------------------------------------------------------------------------------;

[BITS 16]
[CPU 8086]
org 0

; Couldn't assume any value for segment registers when given hand by BIOS,
; so must setup them.
; CS:IP is forced to 07c0h:Start with a far jump
; SS:SP is set to 0000:0000, stack growing down from the end of first segment
; DS is set at 07c0h, for accessing data without offset correction
; ES will be set only when required, to save a few bytes

; Just for fun (and maybe for virus scanners), this code space is reused as data
NotePosition: 
  jmp 07c0h:Start
Start:
  xor ax,ax
  mov ss,ax
  xor sp,sp  ; No need to cli/sti after setting SS, done automagically by CPU

  push cs    ; Set DS to 07c0h - same size cost as overriding segment with CS
  pop ds     ; for TextLoop lodsb and mov [NotePosition], but more readable

  ; Init VGA mode 13h (320x200, 256 colors, video memory starting at a000:0000)
  mov ax,013h
  int 010h

  ; Position cursor to center (or near) our message
  mov ah,02h
  mov dx,0b0eh
  int 010h

  ; Display text - load each char (until 0) and display it through BIOS int 10h
  mov si,word Text
  mov bx,1    ; BH = 0 (first page), BL = 1 (blue text)
  mov cx,10h  ; CX:DX => delay (microseconds) between chars. No care about DX value.

TextLoop:

  lodsb
  or al,al
  jz .TextDone

  mov ah,0eh  ; Print char
  int 10h

  mov ah,086h
  int 015h    ; Wait

  jmp short TextLoop

.TextDone:

  ; Set "pointer" to the current note in score
  mov [NotePosition],word Score

  ; Init "sound system" ;-)
  ; The pc speaker is used, with a square wave input from the timer
  mov al,10110110b ; Define how we want to use the timer :
                   ;  10 : use timer 2 (the one used for sound generation)
                   ;    11 : want to write LSB and then MSB of counter value
                   ;      011 : generate square wave
                   ;         1 : we speak in binary (not BCD)
  out 043h,al ; Init the timer

  ; Register 1ch (timer) interrupt handler - let's start the music, man !
  ; Interrupt 1ch is called around 18 times a second
  cli
  mov word [ss:070h],MusicPlayer    ; Override with SS - saves a few bytes against
  mov word [ss:072h],cs             ; setting DS to 0 and back to 07c0h
  sti

AddShapes:

  ; Before calling LoadShapes, we must point DS:SI to the shapes to load.

  ; Set DS to CS (07c0h) - useless on first iteration, but required for next ones
  ; SI already points on the shapes to be loaded (after text if coming from begin,
  ; set to "spaceship" if called during loop to add more shapes)
  push cs
  pop ds

  call LoadShapes

  ; LoadShapes sets ES to 1000h (offscreen buffer).
  ; Game of Life computes from offscreen buffer to video memory, so we must have
  ; DS:SI pointing to offscreen buffer and ES:DI to video memory
  ; Swap offscreen buffer from ES to DS
  push es
  pop ds

  ; Make ES point to video memory base
  mov ax,0a000h
  mov es,ax
  
  ; CX is used as a trigger to add new spaceships - it is checked in main loop
  ; If different from 0, we jump back to AddShapes before computing iteration
  ; This is used to add a new spaceship each time the "music" is finished (the
  ; interrupt handler increments CX when resetting score)
  ; As LoadShapes leaves CX dirty, we clean it to avoid mess...
  xor cx,cx

LifeLoop:
  ; After checking wether new spaceship should be added, 
  ; display the last computed (or just freshly loaded) generation, and then
  ; loop on each cell, computing the next generation's value to offscreen buffer

  mov si,Dart     ; Set SI to the spaceship shape, in the case we need to add it
  or cx,cx        ; Check wether to add a new spaceship or just continue
  jnz AddShapes

  call RefreshScreen   ; Display the offscreen buffer

  mov si,64000         ; Let's loop on the 64000 pixels of the mode 13h screen

  .NextCell:

    ; Handle borders (no computation on borders, to avoid using random data outside screen)
    ; Yes, i know, this is not a true (space unlimited) game of life ;-)
    mov ax,si
    xor dx,dx
    mov bx,320
    div bx

    ; Division give current row in AX and current column in DX
    or ax,ax
    jz .DoneCell
    cmp ax,199
    je .DoneCell
    or dx,dx
    jz .DoneCell
    cmp dx,319
    je .DoneCell

    call ComputeCell

  .DoneCell:

    ; Compute next cell
    dec si
    jnz .NextCell

    ; Do this forever...
    jmp short LifeLoop

RefreshScreen:
  ; Reset both DS:SI and ES:DI pointers to begin of offscreen and onscreen memory
  ; Segments must already be loaded with correct values
  xor si,si
  xor di,di

  ; Wait for vertical retrace to avoid blinking
  .Wait0:
    mov dx,03dah
    in al,dx
    test al,8
    jnz .Wait0
  .Wait1:
    in al,dx
    test al,8
    jz .Wait1

  ; Copy buffer to video memory
  mov cx,32000
  rep movsw
  ret

ComputeCell:
  ; The game of life "heart" : for each cell, computes the number of neighbors
  ; in video memory, and set the new cell state according to the following rules
  ; in offscreen buffer for next generation.
  ;
  ; Rules :
  ;   - less than 2 neighbors : underpopulation => death (if alive)
  ;   - empty cell with 3 neighbors : birth (or stay alive)
  ;   - more than 3 neighbors : overcrowding => death (if alive)

  ; Backup DS:SI (needed by outer loop and to write new cell value)
  push ds
  push si

  ; Point DS to ES, to use lodsb (many times, so worth doing it)
  push es
  pop ds

  ; Store current cell status in BH for latest computation
  ; BL will store the number of neighbors
  mov bh,[si]
  xor bl,bl

  .TopLeft:
    sub si,321
    lodsb
    or al,al
    jz .Top
    inc bl
  .Top:
    lodsb
    or al,al
    jz .TopRight
    inc bl
  .TopRight:
    lodsb
    or al,al
    jz .Left
    inc bl
  .Left:
    add si,317
    lodsb
    or al,al
    jz .Right
    inc bl
  .Right:
    inc si
    lodsb
    or al,al
    jz .BottomLeft
    inc bl
  .BottomLeft:
    add si,317
    lodsb
    or al,al
    jz .Bottom
    inc bl
  .Bottom:
    lodsb
    or al,al
    jz .BottomRight
    inc bl
  .BottomRight:
    lodsb
    or al,al
    jz .Determinate
    inc bl
  .Determinate:
    ; Restore DS:SI to set new value and to avoid breaking outer loop too
    pop si
    pop ds
    ; Set new value according to rules
    cmp bl,3
    je .Live
    cmp bl,2
    jne .Dead
    or bh,bh
    jz .Dead
  .Live:
    mov [si],byte 1
    ret
  .Dead:
    mov [si],byte 0
    ret

LoadShapes:
  ; Loads shape(s) to offscreen buffer
  ; DS:SI must already point to shape(s) to load

  ; Will load shapes until a 0 position found
  ; A shape is stored as :
  ;  - position (1 word)
  ;  - size (2 bytes, width first, then height)
  ;  - data (1 bit per point, width x height bits, rounded to next byte)

  ; Load to offscreen buffer, to avoid cleaning screen from initial text
  ; Need to call RefreshScreen BEFORE first iteration as counterpart
  mov ax,1000h
  mov es,ax

  .NextShape:
    lodsw     ; Get shape position
    or ax,ax  ; Return if no more shapes available
    jnz .ProcessShape
    ret

  .ProcessShape:
    ; Backup shape position to BP. Needed to compute beginning of each line
    mov bp,ax

    mov di,ax ; Set starting output position in buffer

    lodsw     ; Get shape dimensions : AH = height, AL = width
    mov cx,ax ; Store it into CX (CH = height, CL = width)

    xor dx,dx ; Clear DX, used to count number of lines (DL) and number of bits in line (DH)

  .LoadShapeData:
    lodsb     ; Get a byte. Each bit represents a pixel.

    mov bl,al ; Store current byte into BL
    mov bh,7  ; BH is used as a processed bit counter for current BL byte

    .NextBit:
      xor ax,ax ; Value defaults to 0 (no cell)

      shl bl,1  ; Test the BH'th bit of BX (BL, BH being < 8)
      jnc short .BitDone ; Choose action depending on carry
      inc al    ; Cell is alive
    .BitDone:
      stosb   ; Store the cell value

      ; Check width bounds
      inc dh
      cmp dh,cl
      jne .LineContinued

      ; Process next line...
      inc dl

      ; ...unless shape finished
      cmp dl,ch
      je .NextShape

      ; Compute next cell address from shape's base position, height and current line number
      ; Next cell will be base_position+320*lines
      mov ax,320
      push dx
      xor dh,dh
      mul dx
      pop dx
      mov di,bp
      add di,ax
      xor dh,dh  ; Reset column number

     .LineContinued:

      or bh,bh   ; If all byte's bits have been processed, go to next byte
      jz .LoadShapeData

      dec bh     ; Loop on each byte's bit
      jmp short .NextBit

Text:
  db 'Loading ;-)',0 

; Shapes used are a Gosper Glider Gun (http://conwaylife.com/wiki/index.php?title=Gosper_glider_gun) 
; that fires Gliders (http://conwaylife.com/wiki/index.php?title=Glider) against
; Dart spaceships (http://conwaylife.com/wiki/index.php?title=Dart)

; Shapes are divided in small parts to reduce memory use (no need to describe the big empty parts)

Gosper_Glider_Gun:
  dw 320*190+11
  db 8,7
  db 00110000b,01000100b,10000010b,10001011b,10000010b,01000100b,00110000b

  dw 320*192+21
  db 5,7
  db 00001001b,01110001b,10001100b,00010100b,00100000b

  dw 320*193+1
  db 2,2
  db 11110000b

  dw 320*195+35
  db 2,2
  db 11110000b

Dart:
  dw 320*40+315
  db 4,15
  db 00100101b,10010100b,11111010b,01110000b,01111010b,11110100b,10010101b,00100000b

  dw 320*45+310
  db 5,5
  db 00101110b,00110001b,10000010b,10000000b

  dw 0 ; End of shapes

; The Imperial Ouch ;-)
Score: 
  ; Ok, so the Imperial March score should begin (thanks to http://forums.jeuxonline.info/showthread.php?t=407163) like 
  ;  G G G Eb Bb G Eb Bb G D+ D+ D+ Eb+ Bb F# Eb Bb G (+ means upper octave)
  ; We'll set ugly tempo from memory to (in 4/18 seconds) :
  ;  3 3 3 2  1  3 2  1  3 3  3  3  2   1  3  2  1  3
  ; The notes frequencies (divided by 4 to save 2 bits per byte, used to store duration information ; sorry for your ears) :
  %define Fs2 92 / 4 ; Well, should be 92.5, but your ears are already dead :-D
  %define G2  98 / 4
  %define Eb2 78 / 4
  %define Bb2 117 / 4
  %define D3  147 / 4
  %define Eb3 156 / 4
  ; The notes durations :
  %define T1 01000000b
  %define T2 10000000b
  %define T3 11000000b
  ; And the final timed score...
  db G2|T3, G2|T3, G2|T3, Eb2|T2, Bb2|T1, G2|T3, Eb2|T2, Bb2|T1, G2|T3, D3|T3, D3|T3, D3|T3, Eb3|T2, Bb2|T1, Fs2|T3, Eb2|T2,Bb2|T1, G2|T3, 0

; Here come the music "engine", driven by timer interrupt
MusicPlayer:
  ; Save all that we change, we are in an hardware interrupt handler... Well... Except cx, because we use it
  ; to tell main loop that we want it to load a new spaceship ! Ugly hack ;-)
  push ax
  push bx
  push dx
  push si
  push ds

  ; Set DS to 07c0h
  push cs
  pop ds

  ; Get score pointer
  mov si,[NotePosition]

  ; Decrease the remaining duration, and tests if delay ended
  dec byte [NoteDuration]
  jnz .NothingToDo

  in al,061h         ; Get speaker status
  test al,00000011b  ; Check wether we're already playing
  jnz .Playing

  ; Was not playing => start playing
  xor ax,ax 
  lodsb              ; Load a note
  or ax,ax
  jnz .Play

  ; If note was 0, we have finished playing score
  inc cx       ; Tell main program to create a new spaceship
  sub si,19    ; Rewind the score
  mov [NoteDuration],byte 18 ; Add a little silence...
  jmp short .NothingToDo

  .Play:
    ; Move the 2 duration bits to AH, and multiply the frequency by 4 in AL
    shl ax,1
    shl ax,1
    ; Multiply the duration by 4 (0, 1, 2 or 3 times 4 / 18 seconds)
    shl ah,1
    shl ah,1
    mov [NoteDuration],ah ; Set counter for note duration
    xor ah,ah
    mov bx,ax

    ; Compute sound frequency (approximately 001234DEh / freq)
    mov dx,0012h
    mov ax,34DEh
    div bx

    ; Set the timer counter for right frequency
    out 042h,al
    xchg ah,al
    out 042h,al

    ; Start playing
    in al,061h ; Get status
    or al,00000011b ; Activate speaker (bit 1) and tell it to be driven by timer 2 (bit 0)
  
    jmp short .ChangesDone

  .Playing: ; Was playing => start a short (1/18 second) silence
  inc byte [NoteDuration]
  and al,11111100b ; Reset speaker

  .ChangesDone:
  out 061h,al ; Set speaker status

  .NothingToDo:

  mov [NotePosition],si ; Store note pointer for next call

  ; Restore all before returning
  pop ds
  pop si
  pop dx
  pop bx
  pop ax
  iret

NoteDuration:
  db 18

db 00 ; This byte for rent ;-)
dw 0aa55h
