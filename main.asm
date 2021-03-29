* = $1000 "Cellular Automaton"  /* SYS 4096 to start program. */

.const charbackground = $d800
.const charset = $2000
.const rowsize = 39
.const screen = $0400
.const wolframrule = 2049   /* Poke 2049,rule to set the used wolframrule. */
.const state1color = GREEN

// Example rule 30:
//  0   0   0   1   1   1   1   0
// 111 110 101 100 011 010 001 000

start:
    /* Clear screen. */
    jsr $e544

    /* Change border and background color. */
    /* ldx #BLACK */
    /* stx $d020 */
    /* stx $d021 */

    /* Screen at $0400, charset at $2000. */
    lda #$18
    sta $d018

    FillCharsetChar(0, 0)
    FillCharsetChar(1, $ff)
    FillCharsetChar(32, 0)

    SetCharBackground(state1color)

    /* Store address of screen in 02-03 vector. */
    lda #0
    sta $02
    lda #$04
    sta $03

    jsr initfirstrow
    jmp loop

initfirstrow:
    ldy #rowsize
    fill:
        lda #0
        sta ($02),Y
        dey
        bpl fill
    lda #1
    ldy #2
    sta ($02),Y
    rts

/* Load a cell's neighbourhood and store in 002a. */
/* If a neighbourhood contains the states 111, the value in 002a will be: 00000111. */
/* Uses periodic boundary conditions, e.g. the left neighbour of cell 0 is cell 39 and the right neighbour of cell 39 is cell 0. */
neighbourhood:
    dey
    bmi leftperiodic    // Periodic boundary.
    lda ($04),Y         // Load left neighbour.
    jmp normalleft
    leftperiodic:
        ldy #rowsize
        lda ($04),Y     // Load left neighbour.
        ldy #$ff
    normalleft:
    iny
    clc
    rol
    adc ($04),Y
    clc
    rol
    iny
    cpy #rowsize+1
    beq rightperiodic   // Periodic boundary.
    adc ($04),Y         // Load right neighbour.
    jmp normalright
    rightperiodic:
        ldy #0
        clc
        adc ($04),Y     // Load right neighbour.
        ldy #rowsize+1
    normalright:
    dey
    sta $002a
    rts

updaterow:
    ldy #rowsize
    updatecolumn:
        jsr neighbourhood
        lda #1
        ldx $002a
        cpx #0
        beq skipshift

        /* Create the mask to read the cell's next state. */
        shift:
            clc
            rol
            dex
            bne shift

        skipshift:

        /* Lookup the cell's next state in the wolfram rule. */
        and wolframrule
        beq store
        lda #1
        store:
        sta ($02),Y
        dey
        bpl updatecolumn
    rts

loop:
    /* Uncomment to only update periodically. */
    /* lda $d012   // Read current raster line. */
    /* cmp #$42 */
    /* bne loop */
    /* iny */
    /* cpy #50 */
    /* bne loop */
    /* ldy #0 */

    jsr update
    jmp loop

update:
    /* Copy old current row address. */
    lda $03
    cmp #$10
    beq skipupdate  // Stop updating after the last row is calculated.
    sta $05
    lda $02
    sta $04

    jsr incrow
    jsr updaterow
    skipupdate:
    rts

incrow:         // Add rowsize to the screen address vector.
    lda #rowsize+1
    clc
    adc $02
    sta $02
    lda #0
    adc $03
    sta $03
    rts

.macro FillCharsetChar(char, val) {
    ldx #8
    lda #val
    fillchar:
        sta charset+8*char,X
        dex
        bpl fillchar
}

.macro SetCharBackground(color) {
    ldx #0
    lda #color
    setback:
        dex
        sta charbackground,X
        sta charbackground+$100,X
        sta charbackground+$200,X
        sta charbackground+$300,X
        bne setback
}
