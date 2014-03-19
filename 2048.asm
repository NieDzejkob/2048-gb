INCLUDE "constants.asm"

; rst vectors go unused
SECTION "rst00",HOME[0]
    ret

SECTION "rst08",HOME[8]
    ret

SECTION "rst10",HOME[$10]
    ret

SECTION "rst18",HOME[$18]
    ret

SECTION "rst20",HOME[$20]
    ret

SECTION "rst30",HOME[$30]
    ret

SECTION "rst38",HOME[$38]
    ret

SECTION "vblank",HOME[$40]
	jp VBlankHandler
SECTION "lcdc",HOME[$48]
	reti
SECTION "timer",HOME[$50]
	reti
SECTION "serial",HOME[$58]
	reti
SECTION "joypad",HOME[$60]
	reti

SECTION "bank0",HOME[$61]

SECTION "romheader",HOME[$100]
    nop
    jp Start

Section "start",HOME[$150]

VBlankHandler:
    push af
    push bc
    push de
    push hl
    call CopyTilemap
    call $FF80
    call ReadJoypadRegister
    ld hl, H_TIMER
    inc [hl]
    call GetRNG
    pop hl
    pop de
    pop bc
    pop af
    reti

CopyTilemap: ; We can copy just 8 lines per vblank.
; Contains an unrolled loop for speed.
    ;ld de, $9800
    ;ld hl, W_TILEMAP
    ld hl, H_VCOPY_D
    ld a, [hli]
    ld d, a
    ld a, [hli]
    ld e, a
    ld a, [hli]
    ld c, a
    ld a, [hl]
    ld l, a
    ld h, c
    ld a, [H_VCOPY_ROWS]
    ld c, a
.row

    dec c
    jr z, .done

    ld a, [hli]
    ld [de], a
    inc de
    ld a, [hli]
    ld [de], a
    inc de
    ld a, [hli]
    ld [de], a
    inc de
    ld a, [hli]
    ld [de], a
    inc de
    ld a, [hli]
    ld [de], a
    inc de
    ld a, [hli]
    ld [de], a
    inc de
    ld a, [hli]
    ld [de], a
    inc de
    ld a, [hli]
    ld [de], a
    inc de
    ld a, [hli]
    ld [de], a
    inc de
    ld a, [hli]
    ld [de], a
    inc de
    ld a, [hli]
    ld [de], a
    inc de
    ld a, [hli]
    ld [de], a
    inc de
    ld a, [hli]
    ld [de], a
    inc de
    ld a, [hli]
    ld [de], a
    inc de
    ld a, [hli]
    ld [de], a
    inc de
    ld a, [hli]
    ld [de], a
    inc de
    ld a, [hli]
    ld [de], a
    inc de
    ld a, [hli]
    ld [de], a
    inc de
    ld a, [hli]
    ld [de], a
    inc de
    ld a, [hli]
    ld [de], a
    inc de
    
    ld a, e
    add $c
    ld e, a
    jr nc, .row
;carry
    inc d
    jr .row
.done
    ld a, [H_VCOPY_TIMES]
    inc a
    ld [H_VCOPY_TIMES], a
    cp a, $03
    jr z, .reset
    cp a, $02
    jr nz, .eightrows
    ; only 5 rows left
    ld a, $5
    ld [H_VCOPY_ROWS], a

.eightrows
    ld a, d
    ld [H_VCOPY_D], a
    ld a, e
    ld [H_VCOPY_E], a
    ld a, h
    ld [H_VCOPY_H], a
    ld a, l
    ld [H_VCOPY_L], a
    ret
.reset
    ld a, $98
    ld [H_VCOPY_D], a
    xor a
    ld [H_VCOPY_E], a
    ld a, $C0
    ld [H_VCOPY_H], a
    xor a
    ld [H_VCOPY_L], a
    ld [H_VCOPY_TIMES], a
    ld a, $8
    ld [H_VCOPY_ROWS], a
    ret

DisableLCD: ; $0061
	xor a
	ld [$ff0f],a
	ld a,[$ffff]
	ld b,a
	res 0,a
	ld [$ffff],a
.waitVBlank
	ld a,[$ff44]
	cp a,$91
	jr nz,.waitVBlank
	ld a,[$ff40]
	and a,$7f	; res 7,a
	ld [$ff40],a
	ld a,b
	ld [$ffff],a
	ret

EnableLCD:
	ld a,[$ff40]
	set 7,a
	ld [$ff40],a
	ret

CopyData:
; copy bc bytes of data from hl to de
	ld a,[hli]
	ld [de],a
	inc de
	dec bc
	ld a,c
	or b
	jr nz,CopyData
	ret

CopyDataFF:
; copy data from hl to de ending with $ff (inclusive)
	ld a,[hli]
	ld [de],a
	inc de
	inc a
	ret z
	jr CopyDataFF

WriteDataInc:
; write data in hl increasing a until b.
.loop
    ld [hli], a
    inc a
    cp a, b
    jr nz, .loop
    ret

FillMemory:
; write a in hl b times
.loop
    ld [hli], a
    dec b
    jr nz, .loop
    ret

ModuloC: ; modulo c
.loop
    cp a, c
    ret c
    sub a, c
    jr .loop

WriteSpriteRow:
    ; a = tile id
    ; b = amount
    ; de = xy
    ; hl = target
.loop
    ld [hl], d
    inc hl
    ld [hl], e
    ld c, a
    ld a, e
    add 8
    ld e, a
    ld a, c
    inc hl
    ld [hli], a
    inc a
    inc a
    ld [hl], 0
    inc hl
    dec b
    jr nz, .loop
    ret

ClearOAM:
    xor a
    ld hl, W_OAM
    ld b, 4*$28
    call FillMemory
    ret

; a standard function:
; this function directly reads the joypad I/O register
; it reads many times in order to give the joypad a chance to stabilize
; it saves a result in [H_JOY] in the following format
; (set bit indicates pressed button)
; bit 0 - A button
; bit 1 - B button
; bit 2 - Select button
; bit 3 - Start button
; bit 4 - Right
; bit 5 - Left
; bit 6 - Up
; bit 7 - Down
ReadJoypadRegister: ; 15F
    ld a, [H_JOY]
    ld [H_JOYOLD], a
	ld a,%00100000 ; select direction keys
	ld c,$00
	ld [rJOYP],a
	ld a,[rJOYP]
	ld a,[rJOYP]
	ld a,[rJOYP]
	ld a,[rJOYP]
	ld a,[rJOYP]
	ld a,[rJOYP]
	cpl ; complement the result so that a set bit indicates a pressed key
	and a,%00001111
	swap a ; put direction keys in upper nibble
	ld b,a
	ld a,%00010000 ; select button keys
	ld [rJOYP],a
	ld a,[rJOYP]
	ld a,[rJOYP]
	ld a,[rJOYP]
	ld a,[rJOYP]
	ld a,[rJOYP]
	ld a,[rJOYP]
	ld a,[rJOYP]
	ld a,[rJOYP]
	ld a,[rJOYP]
	ld a,[rJOYP]
	cpl ; complement the result so that a set bit indicates a pressed key
	and a,%00001111
	or b ; put button keys in lower nibble
	ld [$fff8],a ; save joypad state
	ld a,%00110000 ; unselect all keys
	ld [rJOYP],a
	
	ld a, [H_JOY]
	ld b, a
	ld a, [H_JOYOLD]
	xor $ff
	and b
	ld [H_JOYNEW], a
	ret

GetRNG:
    ld a, [rDIV]
    ld b, a
    ld a, [H_RNG1]
    xor b
    ld [H_RNG1], a
    ret

WaitForKey:
.loop
    halt
    ld a, [H_JOYNEW]
    and a, %00001001 ; A or START
    jr z, .loop
    ret

; copies DMA routine to HRAM. By GB specifications, all DMA needs to be done in HRAM (no other memory section is available during DMA)
WriteDMACodeToHRAM:
	ld c, $80
	ld b, $a
	ld hl, DMARoutine
.copyLoop
	ld a, [hli]
	ld [$ff00+c], a
	inc c
	dec b
	jr nz, .copyLoop
	ret

; this routine is copied to HRAM and executed there on every VBlank
DMARoutine:
	ld a, W_OAM >> 8
	ld [$ff00+$46], a   ; start DMA
	ld a, $28
.waitLoop               ; wait for DMA to finish
	dec a
	jr nz, .waitLoop
	ret

Start:
    di
    
    ; palettes
    ld a, %11100100
    ld [rBGP], a
    ld a, %11010000
    ld [rOBP0], a
    
    ld a, 0
    ld [rSCX], a
    ld [rSCY], a
    
    ld a, %11000111
    ld [rLCDC], a
    
    ei
    
    call DisableLCD
    
    ; seed the RNG
    ld hl, $C000
    ld l, [hl]
    ld a, [hl]
    push af
    
    ; fill the memory with zeroes
    ld hl, $C000
.loop
    ld a, 0
    ld [hli], a
    ld a, h
    cp $e0
    jr nz, .loop
    
    pop af
    ; set up the stack pointer
    ld sp, $dffe
    push af

    ld hl, $ff80
.loop2
    ld a, 0
    ld [hli], a
    ld a, h
    cp $00
    jr nz, .loop2
    
    pop af
    ld [H_RNG1], a
    
    call WriteDMACodeToHRAM
    
    ; set up vblank copy offsets
    ld a, $98
    ld [H_VCOPY_D], a
    ld a, $C0
    ld [H_VCOPY_H], a
    ld a, $8
    ld [H_VCOPY_ROWS], a
    
    ; set up graphics
    ld hl, Tiles
    ld de, $9000
    ld bc, $800
    call CopyData
    
    ld hl, Tiles+$800
    ld de, $8800
    ld bc, $800
    call CopyData
    
    ld hl, Sprites
    ld de, $8000
    ld bc, $800
    call CopyData
    
        
    call EnableLCD
    xor a
    ld [$ffff], a
    ld a, %00000001
    ld [$ffff], a
    ei
    jp InitGame

ModuloB:
.loop
    cp a, b
    ret c
    sub a, b
    jr .loop

DivB:
    ld c, 0
.loop
    cp a, b
    jr c, .ret
    sub a, b
    inc c
    jr .loop
.ret
    ld a, c
    ret

Powers:
    dw 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048

AddScore:
    push hl
    push de
    ld hl, Powers
    ld e, a
    ld d, 0
    add hl, de
    add hl, de
    ld a, [hli]
    ld h, [hl]
    ld l, a
    ld a, [H_SCORE]
    ld e, a
    ld a, [H_SCORE+1]
    ld d, a
    add hl, de
    ld a, l
    ld [H_SCORE], a
    ld a, h
    ld [H_SCORE+1], a
    ld a, [H_HIGHSCORE]
    ld e, a
    ld a, [H_HIGHSCORE+1]
    ld d, a
    cp h
    jr z, .maybe
    jr nc, .nothi
.maybe
    ld a, e
    cp l
    jr nc, .nothi
    ld a, l
    ld [H_HIGHSCORE], a
    ld a, h
    ld [H_HIGHSCORE+1], a
.nothi
    pop de
    pop hl
    ret

Modulo10: ; bc %= 10
.loop
    ld a, b
    and a
    jr nz, .nz
    ld a, c
    cp 10
    ret c
.nz
    ld a, c
    sub 10
    ld c, a
    jr nc, .loop
    dec b
    jr .loop

Div10: ; bc /= 10
    push de
    ld de, 0
.loop
    ld a, b
    and a
    jr nz, .nz
    ld a, c
    cp 10
    jr c, .ret
.nz
    ld a, c
    sub 10
    ld c, a
    jr nc, .ok
    dec b
.ok
    inc de
    jr .loop
.ret
    push de
    pop bc
    pop de
    ret

WriteNumAndCarry:
    push bc
    call Modulo10
    ld a, c
    add $e8
    ld [hld], a
    pop bc
    call Div10
    ret

WriteNumber:
; writes number at de to hl (backwards)
    ld a, [de]
    ld c, a
    inc de
    ld a, [de]
    ld b, a
    call WriteNumAndCarry
    call WriteNumAndCarry
    call WriteNumAndCarry
    call WriteNumAndCarry
    ret

UpdateTilemapScore:
    ; draw score
    hlcoord $11, 1
    ld a, $e1
    ld [hli], a
    inc a
    ld [hli], a
    inc a
    ld [hli], a
    hlcoord $11, $a
    ld a, $e4
    ld [hli], a
    inc a
    ld [hli], a
    inc a
    ld [hli], a
    ld a, $e2
    ld [hli], a
    inc a
    ld [hli], a
    
    hlcoord $11, 8
    ld de, H_SCORE
    call WriteNumber
    hlcoord $11, $13
    ld de, H_HIGHSCORE
    call WriteNumber
    ret

GridTilemap:
    db $00, $00, $10, $11, $12, $13, $10, $11, $12, $13, $10, $11, $12, $13, $10, $11, $12, $13, $00, $00
    db $00, $00, $14, $15, $16, $17, $14, $15, $16, $17, $14, $15, $16, $17, $14, $15, $16, $17, $00, $00
    db $00, $00, $18, $19, $1A, $1B, $18, $19, $1A, $1B, $18, $19, $1A, $1B, $18, $19, $1A, $1B, $00, $00
    db $00, $00, $1C, $1D, $1E, $1F, $1C, $1D, $1E, $1F, $1C, $1D, $1E, $1F, $1C, $1D, $1E, $1F, $00, $00
    db $00, $00, $10, $11, $12, $13, $10, $11, $12, $13, $10, $11, $12, $13, $10, $11, $12, $13, $00, $00
    db $00, $00, $14, $15, $16, $17, $14, $15, $16, $17, $14, $15, $16, $17, $14, $15, $16, $17, $00, $00
    db $00, $00, $18, $19, $1A, $1B, $18, $19, $1A, $1B, $18, $19, $1A, $1B, $18, $19, $1A, $1B, $00, $00
    db $00, $00, $1C, $1D, $1E, $1F, $1C, $1D, $1E, $1F, $1C, $1D, $1E, $1F, $1C, $1D, $1E, $1F, $00, $00
    db $00, $00, $10, $11, $12, $13, $10, $11, $12, $13, $10, $11, $12, $13, $10, $11, $12, $13, $00, $00
    db $00, $00, $14, $15, $16, $17, $14, $15, $16, $17, $14, $15, $16, $17, $14, $15, $16, $17, $00, $00
    db $00, $00, $18, $19, $1A, $1B, $18, $19, $1A, $1B, $18, $19, $1A, $1B, $18, $19, $1A, $1B, $00, $00
    db $00, $00, $1C, $1D, $1E, $1F, $1C, $1D, $1E, $1F, $1C, $1D, $1E, $1F, $1C, $1D, $1E, $1F, $00, $00
    db $00, $00, $10, $11, $12, $13, $10, $11, $12, $13, $10, $11, $12, $13, $10, $11, $12, $13, $00, $00
    db $00, $00, $14, $15, $16, $17, $14, $15, $16, $17, $14, $15, $16, $17, $14, $15, $16, $17, $00, $00
    db $00, $00, $18, $19, $1A, $1B, $18, $19, $1A, $1B, $18, $19, $1A, $1B, $18, $19, $1A, $1B, $00, $00
    db $00, $00, $1C, $1D, $1E, $1F, $1C, $1D, $1E, $1F, $1C, $1D, $1E, $1F, $1C, $1D, $1E, $1F, $00, $00 

TilemapAddValues:
; down up left right
    dw 20, -20, -1, 1


UpdateTilemap:
    ld a, [H_ANIMDIR]
    add a
    ld hl, TilemapAddValues
    ld d, 0
    ld e, a
    add hl, de
    ld a, [hli]
    ld [H_CURTMAPADD], a
    ld a, [hl]
    ld [H_CURTMAPADD+1], a
    ; draw 2048 tiles
    ld hl, GridTilemap
    decoord 1, 0
    ld bc, 320
    di
    call CopyData
    
    ld bc, $0000
    ld a, [H_ANIMATE]
    and a
    jr z, .regular
    ld de, W_ANIMFRAMES
    ld a, [H_ANIMFRAME]
    swap a
    ld e, a
    jr .picked
.regular
    ld de, W_2048GRID
.picked
    hlcoord 1, 2
    dec de
.loop
    inc de
    ld a, [de]
    res 7, a
    and a
    jr z, .blank
    inc a
    sla a
    sla a
    sla a
    sla a
    push af
    push bc
    push de
    ld a, [de]
    bit 7, a
    jr z, .noanim
    ; anim
    ld a, [H_ANIMSUB]
    and a
    jr z, .noanim
    ld b, a
    ld a, [H_CURTMAPADD]
    ld e, a
    ld a, [H_CURTMAPADD+1]
    ld d, a
.shiftloop
    add hl, de
    dec b
    jr nz, .shiftloop
.noanim
    pop de
    pop bc
    pop af
    ld c, 4
.tileloop
    ld [hli], a
    inc a
    ld [hli], a
    inc a
    ld [hli], a
    inc a
    ld [hli], a
    inc a
    push bc
    ld bc, 16
    add hl, bc
    pop bc
    dec c
    jr nz, .tileloop
    push bc
    ld bc,0 -((20*4)-4)
    add hl, bc
    pop bc
    
    push af
    push bc
    push de
    ld a, [de]
    bit 7, a
    jr z, .noanim2
    ; anim
    ld a, [H_ANIMSUB]
    and a
    jr z, .noanim2
    ld b, a
    ld a, [H_CURTMAPADD]
    cpl
    ld e, a
    ld a, [H_CURTMAPADD+1]
    cpl
    ld d, a
.shiftloop2
    add hl, de
    inc hl
    dec b
    jr nz, .shiftloop2
.noanim2
    pop de
    pop bc
    pop af
    
.next
    inc b
    ld a, b
    cp 16
    jr z, .ret
    and %00000011
    jr nz, .loop
    push bc
    ld bc, 20*3+4
    add hl, bc
    pop bc
    jr .loop

.blank
    inc hl
    inc hl
    inc hl
    inc hl
    jr .next
.ret
    ei
    ret

GameOver:
    ld a, 1
    ld [H_GAMEOVER], a
    ld a, %10010100
    ld [rBGP], a
    ;hlcoord 0, $c
    ;ld a, $f4
    ;ld b, $fa
    ;call WriteDataInc
    ;WriteDataInc
    xor a
    ld b, 10
    ld de, $4034
    ld hl, W_OAM
    call WriteSpriteRow
    ld a, $20
    ld b, 6
    ld de, $6444
    ld hl, W_OAM+4*10
    call WriteSpriteRow
    ret

ClearMergeBits:
    ; operates on hl
    ld b, 16
.loop
    res 7, [hl]
    inc hl
    dec b
    jr nz, .loop
    ret

PushAnimFrame:
    push de
    ld hl, W_ANIMFRAME
    ld de, W_ANIMFRAMES
    ld a, [H_CURANIMFRAME]
    inc a
    ld [H_CURANIMFRAME], a
    dec a
    swap a
    ld e, a
    ld bc, 16
    call CopyData
    
    ld hl, W_2048GRID
    ld de, W_ANIMFRAME
    ld bc, 16
    call CopyData
    
    ld hl, W_ANIMFRAME
    call ClearMergeBits
    pop de
    ret
    

AddValues:
; down up left right
    db 4, -4, -1, 1

NextValues:
    db 1, 1, 4, 4
    
BeginValues:
    db 8, 4, 1, 2

PrepareDirVals:
    ld a, [H_CURDIR]
    ld hl, AddValues
    ld d, 0
    ld e, a
    add hl, de
    ld a, [hl]
    ld [H_CURADD], a
    
    ld a, [H_CURDIR]
    ld hl, NextValues
    ld d, 0
    ld e, a
    add hl, de
    ld a, [hl]
    ld [H_CURNEXT], a
    ret
    

MoveGrid:
; a = direction
    ld [H_CURDIR], a
    
    call CanMoveGridDir
    ret z
    
    call PushAnimFrame
    xor a
    ld [H_CURANIMFRAME], a
    
    call PrepareDirVals
    
.outerloop
    ld a, [H_CURDIR]
    ld hl, BeginValues
    ld d, 0
    ld e, a
    add hl, de
    ld a, [hl]
    
    ld hl, W_2048GRID
    add l
    ld l, a
    
    ld c, 1
    ld e, 0 ; change occured

.loopx
    ld a, [hl]
    and a
    jr z, .donex
    ld b, a
    ld a, [H_CURADD]
    add l
    ld l, a
    ld a, [hl]
    and a
    jr z, .empty
    cp b
    jr z, .same
.nothing
    ; nothing to do here
    ld a, [H_CURADD]
    ld d, a
    ld a, l
    sub d
    ld l, a
.donex
    inc c
    ld a, c
    and %00000011
    jr z, .next
    
    ld a, [H_CURADD]
    ld d, a
    ld a, l
    sub d
    ld l, a
    jr .loopx
.next
    ld a, c
    cp 16
    jr z, .donestep
    inc c
    ld a, [H_CURADD]
    ld d, a
    ld a, l
    add d
    add d
    ld l, a
    ld a, [H_CURNEXT]
    add l
    ld l, a
    jr .loopx
    
.empty
    ld [hl], b
    ld a, [H_CURADD]
    ld d, a
    ld a, l
    sub d
    ld l, a
    xor a
    ld [hl], a
    set 7, l
    set 7, [hl]
    res 7, l
    ld e, 1
    jr .donex
.same
    bit 7, [hl]
    jr nz, .nothing
    inc [hl]
    ld a, [hl]
    set 7, [hl]
    call AddScore
    ld a, [H_CURADD]
    ld d, a
    ld a, l
    sub d
    ld l, a
    xor a
    ld [hl], a
    set 7, l
    set 7, [hl]
    res 7, l
    ld e, 1
    jr .donex
.donestep
    call PushAnimFrame
    ld a, e
    and a
    jr z, .donemoving
    ld e, 0
    jp .outerloop
.donemoving
    ; setup animation
    ld a, [H_CURDIR]
    ld [H_ANIMDIR], a
    ld a, 1
    ld [H_ANIMATE], a
    xor a
    ld [H_ANIMSUB], a
    ld [H_ANIMFRAME], a
    ; etc
    ld hl, W_2048GRID
    call ClearMergeBits
    ;call UpdateTilemapScore ; do this after an animation
    call AddNewTile
    call CanMoveGrid
    call z, GameOver
    xor a ; else we'll hit other directional keys
    ret

CanMoveGridDir:
; a = direction
    ld [H_CURDIR], a
    
    call PrepareDirVals
    
.outerloop
    ld a, [H_CURDIR]
    ld hl, BeginValues
    ld d, 0
    ld e, a
    add hl, de
    ld a, [hl]
    
    ld hl, W_2048GRID
    add l
    ld l, a
    
    ld c, 1
.loopx
    ld a, [hl]
    and a
    jr z, .donex
    ld b, a
    ld a, [H_CURADD]
    add l
    ld l, a
    ld a, [hl]
    and a
    jr z, .empty
    cp b
    jr z, .same
.nothing
    ; nothing to do here
    ld a, [H_CURADD]
    ld d, a
    ld a, l
    sub d
    ld l, a
.donex
    inc c
    ld a, c
    and %00000011
    jr z, .next
    ld a, [H_CURADD]
    ld d, a
    ld a, l
    sub d
    ld l, a
    jr .loopx
    
.next
    ld a, c
    cp 16
    jr z, .done
    inc c
    ld a, [H_CURADD]
    ld d, a
    ld a, l
    add d
    add d
    ld l, a
    ld a, [H_CURNEXT]
    add l
    ld l, a
    jr .loopx
    xor a
    ret ; move won't do anything
.empty
.same
    ld a, 1
    and a
    ret
.done
    ; we didn't find any move
    xor a
    ret

CanMoveGrid:
    ld a, 0
    call CanMoveGridDir
    ret nz
    ld a, 1
    call CanMoveGridDir
    ret nz
    ld a, 2
    call CanMoveGridDir
    ret nz
    ld a, 3
    call CanMoveGridDir
    ret

MoveDown:
    ld a, 0
    jp MoveGrid
MoveUp:
    ld a, 1
    jp MoveGrid
MoveLeft:
    ld a, 2
    jp MoveGrid
MoveRight:
    ld a, 3
    jp MoveGrid

AddNewTile:
    ; pick tile (2=90, 4=10%)
    call GetRNG
    cp 256/10
    jr c, .four
    ld d, 1
    jr .picked
.four
    ld d, 2
.picked

    ; find free tiles
    ld b, 16
    ld c, 0 ; amount of free tiles
    ld hl, W_2048GRID
.loop
    ld a, [hli]
    and a
    jr nz, .nonfree
    inc c
.nonfree
    dec b
    jr z, .counted
    jr .loop
.counted
    ld a, c
    and a
    ret z ; no free tiles
    
    call GetRNG
    call ModuloC
    inc a
    ld b, a
    
    ld hl, W_2048GRID
.loop2
    ld a, [hli]
    and a
    jr nz, .loop2
    dec b
    jr nz, .loop2
    dec hl
    ld [hl], d
    ret

InitGame:
    xor a
    ld [H_SCORE], a
    ld [H_SCORE+1], a
    ld [H_GAMEOVER], a
    ld hl, W_2048GRID
    ld b, 16
    call FillMemory
    call ClearOAM
    
    call AddNewTile
    call AddNewTile
    ;ld a, 1
    ;ld [W_2048GRID+5], a
    ;ld [W_2048GRID+10], a
    
    ld a, %11100100
    ld [rBGP], a
    call UpdateTilemap
    call UpdateTilemapScore
    hlcoord 0, 1
    ld a, $04
    ld b, $0e
    call WriteDataInc
    
.gameloop
    halt
    ld a, [H_ANIMATE]
    and a
    jr z, .input
    ; animate

    call UpdateTilemap
    ld a, [H_ANIMSUB]
    inc a
    ld [H_ANIMSUB], a
    cp 3
    jr nz, .gameloop
    xor a
    ld [H_ANIMSUB], a
    ld a, [H_ANIMFRAME]
    inc a
    ld [H_ANIMFRAME], a
    ld b, a
    ld a, [H_CURANIMFRAME]
    cp b
    jr nz, .gameloop
    xor a
    ld [H_ANIMATE], a
    call UpdateTilemapScore
    jr .gameloop
.input
    ld a, [H_GAMEOVER]
    and a
    jr nz, .gameover
    ld hl, H_JOYNEW
    ld a, [hl]
    ld [hl], 0
    
    swap a
; down up left right
    bit 3, a
    call nz, MoveDown
    bit 2, a
    call nz, MoveUp
    bit 1, a
    call nz, MoveLeft
    bit 0, a
    call nz, MoveRight
    call UpdateTilemap
    jr .gameloop
.gameover
    call UpdateTilemap
    call WaitForKey
    jp InitGame
    

Tiles:
    INCBIN "gfx/tiles.2bpp"
Sprites:
    INCBIN "gfx/sprites.2bpp"







