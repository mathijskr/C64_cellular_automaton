BasicUpstart2(start)

.const charbackground = $d800
.const charset = $2000
.const rowsize = 39
.const screen = $0400
.const wolframrule = 2049
.const state1color = ORANGE
.const getin = $ffe4
.const chrout = $ffd2
.const clearscreen = $e544

// Example rule 030:
//  0   0   0   1   1   1   1   0
// 111 110 101 100 011 010 001 000

start:
    /* Clear screen. */
    jsr clearscreen

    /* Print greeting. */
    lda #>greet
    sta $23
    lda #<greet
    sta $22
    ldy #0
    print:
        lda ($22),Y
        jsr chrout
        iny
        cpy #17
        bne print

    lda #0
    sta wolframrule
    /* Read first wolfram digit (multiplied by 100). */
    read1:
        jsr getin
        beq read1
        sec
        sbc #48
        clc
        beq read2
        tax
        lda #100
        sta wolframrule
        dex
        beq read2
        adc wolframrule
        sta wolframrule
    /* Read second wolfram digit (multiplied by 10). */
    read2:
        jsr getin
        beq read2
        sec
        sbc #48
        clc
        rol
        tax
        rol
        rol
        adc wolframrule
        sta wolframrule
        txa
        adc wolframrule
        sta wolframrule
    /* Read last wolfram digit. */
    read3:
        jsr getin
        beq read3
        sec
        sbc #48
        clc
        adc wolframrule
        sta wolframrule
        clc

    /* Store address of screen in 02-03 vector. */
    lda #04
    sta $03

    /* Screen at $0400, charset at $2000. */
    lda #$18
    sta $d018

    FillCharsetChar(0, 0)
    FillCharsetChar(1, $ff)
    FillCharsetChar(32, 0)

    SetCharBackground(state1color)

    /* Initialize the first row. */
    ldy #rowsize
    fill:
        lda #0
        sta ($02),Y
        dey
        bpl fill
    lda #1
    sta $0413

update:
    /* Uncomment to update more slowly. */
    /* lda $d012   // Read current raster line. */
    /* cmp #$42 */
    /* bne update */
    /* iny */
    /* cpy #50 */
    /* bne update */
    /* ldy #0 */

    /* Copy old current row address. */
    lda $03
    cmp #$08
    beq update  // Stop updating after the last row is calculated.
    sta $05
    lda $02
    sta $04

    /* Increase the current row number bij adding the rowsize to the 02-03 vector .*/
    lda #rowsize+1
    clc
    adc $02
    sta $02
    lda #0
    adc $03
    sta $03

    /* Update the current row by calculating the states of the next row. */
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

    jmp update

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

.encoding "ascii"
greet: .text "ENTER WOLFRAMCODE"

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
