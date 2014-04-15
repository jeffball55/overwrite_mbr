ORG 0x7C00
use16

jmp 0:begin
 
begin:
xor ax,ax
mov ds, ax

; Videomode auf 80x25 setzen
mov ax, 0x1114
xor bx, bx
int 0x10

; Cursor ausblenden
mov ah, 1
mov cx, 0x2000
int 0x10

; 5 kirschen
mov si, 0x8000
mov dword [si+0x00], 0x1231006F
mov dword [si+0x04], 0x0C35006F
mov dword [si+0x08], 0x0222006F
mov dword [si+0x0C], 0x131F006F
mov dword [si+0x10], 0x1505006F
; schlange (anfangs)
mov dword [si+0x14], 0x0C280640 
mov dword [si+0x18], 0x0C270623
mov dword [si+0x1C], 0x0C260623
mov dword [si+0x20], 0x0C25062A

; IRQ Handler setzen
cli
  mov word[9*4], irq_keybd
  mov word[9*4+2], 0
  
  mov word[8*4], irq_timer
  mov word[8*4+2], 0
sti

call clear

jmp $

; [char]  [Direction]   [x]   [y]    
; ===============================
;   #          1        20    21
;   o          0        15    5
;  0x20        4        5     1

; Direction
;===========
; Left  = 4
; Right = 6
; Up    = 1
; Down  = 9
; Nix   = 0

;%define Up    0x48
;%define Left  0x4B
;%define Right 0x4D
;%define Down  0x50

; cl = max
random:
  in al, 0x70
  and al, 10000000b
  out 0x70, al 
  in al, 0x71
  .test:
    cmp al, cl
    jna .ok
    shr al, 1
  jmp .test
  .ok:
  ret

irq_keybd:
  pusha  
    in al, 0x60
    
    sub al, 0x47
    cmp al, 9
    ja .exit
    
      mov dl, al 
      mov byte [0x8015], al
      
      mov eax, dword [0x8014]
      mov ah, dl
    
      mov bx, word [nextwp]
      mov dword [bx], eax
      add word [nextwp], 4
    
    .exit:
    mov al, 0x20
    out 0x20, al
  popa
  iret

irq_timer:
  pusha
    mov al, byte [interval]
    or al, al
    jnz .next   
      call game_loop
      mov byte [interval], 3    
    .next:
      dec byte [interval]    
    mov al, 0x20
    out 0x20, al    
  popa
  iret

; Nächster freier Speicher für die Schlangeteile:
nextobj: dw 0x8024
; Nächster freier Speicher für die Wegpunkte
nextwp: dw 0xA000

game_loop:
  call clear
  
  ; Alle Schlangeteile durchloopen
  mov si, 0x8000
  .loop:
    ; Char
    mov al, byte [si]   
    or al, al
    jz .lend
    
    push ax
    
    ; Position
    mov dx, word [si+0x02]
    ; Richtung
    mov cl, byte [si+0x01]
    
    ; Richtung auswerten
    cmp cl, 0
    je .noDir
    cmp cl, 1
    je .upDir
    cmp cl, 4
    je .leftDir
    cmp cl, 6
    je .rightDir
    ; kann nur noch 9=down sein
    .downDir:
      inc dh
      jmp .endDir
    .leftDir:
      dec dl
      jmp .endDir
    .rightDir:
      inc dl
      jmp .endDir
    .upDir:
      dec dh
    .endDir:
        push bx
        
        ; Kollisionsprüfung des aktuellen Schlangenteils
        mov bx, 0x8000
        .checkl:
          mov cx, [bx+2]
          or cx, cx
          jz .endl
          cmp cx, dx
          jne .nl
            
            ; Kollidiert man mit sich selbst?
            mov cl, byte [bx]
            cmp cl, '#'
            je dead
            ; Oder mit ner Kirsche?
            cmp cl, 'o'
            jne .nl     ; oder mit garnix
            .kirsche:
              cmp al, '@' ; Kirschen kann nur der Kopf aufsammeln
              jne .nl
              
              mov di, word [nextobj]
              mov eax, dword [di-0x04]
              mov cx, word [di-0x02]
              
              ; Richtung des letzten Schlangeteils bestimmen
              cmp ah, 1
              je .addUp
              cmp ah, 4
              je .addLeft
              cmp ah, 6
              je .addRight
              ;kann nur noch 9 = down sein!
              .addDown:
                dec ch
                jmp .createnew 
              .addUp:
                inc ch
                jmp .createnew
              .addLeft:
                inc cl
                jmp .createnew
              .addRight:
                dec cl
             ; und neues Schlangeteil hintendran setzen
             .createnew:                
                mov byte [di-0x04], '#'
                mov ax, cx
                shl eax, 16
                mov ax, word [di-0x04]
                mov al, '*'
                mov dword [di], eax
                add word [nextobj], 4 
                
                mov cl, 79
                call random
                mov byte [bx+0x02], al
                
                mov cl, 24
                call random
                mov byte [bx+0x03], al    
          .nl:
          add bx, 4
          jmp .checkl
        .endl:
        
        ; Gucken ob aktuelles Schlangenteil auf nem
        ; Wegpunkt ist, wenn ja ==> Richtung des Teils
        ; ändern
        mov bx, 0xA000
        .markloop:
          mov cx, [bx+2]
          or cx, cx
          jz .endmarkloop
          cmp cx, dx
          jne .nl2
      
          mov cl, byte [bx+1]
          or cl, cl
          jz .nl2
              
          mov byte [si+1], cl
          cmp byte [si], '*'
          jne .nl2
          mov byte [bx+1], 0
          .nl2:
          add bx, 4
          jmp .markloop
        .endmarkloop:
           
        pop bx
       .noDir:   
    pop ax  
    
    ; Gucken ob schlangenteil übern rand hinaus geht
    cmp dh, 24
    ja dead
    
    cmp dl, 79
    ja dead 
    
    ; Object zeichnen 
    mov ah, 0x02
    int 0x10
    
    xor bx,bx
    cmp al, 'o'
    jne .psch
    mov bl, 0x04
    jmp .prnt
    .psch:
    mov bl, 0x02
    .prnt:
    mov cx, 1
    
    mov ah, 0x09
    int 0x10
    
    ; Neue Position sichern
    mov word [si+2], dx
 
    add si, 4
    jmp .loop
  .lend:
  ret

clear:
  pusha
  push es
    mov ax, 0xB800
    mov es, ax
    xor di, di
    
    mov ax, 0x0220
    mov cx, 2000
    rep stosw 
  pop es   
  popa
  ret
  
dead:
    mov ax, 0xB800
    mov es, ax
    xor di, di
    
    mov ax, 0x4420
    mov cx, 2000
    rep stosw 

    jmp $

; Timer interval
; 2 = 100ms
interval: db 2

times 510 - ($-$$) db 0
dw 0xAA55