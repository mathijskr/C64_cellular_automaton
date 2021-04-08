BasicUpstart2(init)

.const border = $d020
.const background = $d021
.const backcolor = BLACK
.const charbackground = $d800
.const charset = $2000
.const rowsize = 39
.const screen = $0400
.const wolframrule = 2049
.const state1color = WHITE
.const chrout = $ffd2
.const clearscreen = $e544
.const currentrowhigh = $03
.const currentrowlow = $02
.const updaterate = 4
.const pausetime = 50
.const raster = $d012

// Example rule 030:
//  0   0   0   1   1   1   1   0
// 111 110 101 100 011 010 001 000

init:
    FillCharsetChar(0, 0)
    FillCharsetChar(1, $ff)
    FillCharsetChar(32, 0)

    lda #$ff
    sta wolframrule

start:
    /* Clear screen. */
    jsr clearscreen

    /* Set background and border color to black. */
    lda #backcolor
    sta background
    sta border

    SetCharBackground(state1color)

    /* Store address of screen in current row vector. */
    lda #0
    sta currentrowlow
    lda #4
    sta currentrowhigh

    /* Screen at $0400, charset at $2000. */
    lda #$18
    sta $d018

    adc wolframrule
    sta wolframrule

    /* Initialize the first row. */
    ldy #rowsize
    fill:
        lda #0
        sta (currentrowlow),Y
        dey
        bpl fill
    lda #1
    sta $0413

update:
    /* Comment to update instantaneously. */
    /* jsr waitraster */
    /* bne update */
    /* iny */
    /* cpy #updaterate */
    /* bne update */
    /* ldy #0 */
    ldx #updaterate
    jsr pause

    /* Copy old current row address. */
    lda currentrowhigh
    sta $05
    ldx currentrowlow
    stx $04
    /* Check if current row is one after the last row. */
    cmp #$07
    bne notlastrow
    cpx #$c0
    bne notlastrow
    ldx #pausetime
    jsr pause   // Stop updating after the last row is calculated.
    jmp start   //
    notlastrow:

    /* Increase the current row number bij adding the rowsize to the 02-03 vector .*/
    lda #rowsize+1
    clc
    adc currentrowlow
    sta currentrowlow
    lda #0
    adc currentrowhigh
    sta currentrowhigh

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
        sta (currentrowlow),Y
        dey
        bpl updatecolumn

    jmp update

/* Increases the Y register modulo rowsize. */
nextneighbour:
    iny
    cpy #rowsize+1
    bne returnnext
    ldy #0
    returnnext:
    rts

/* Decreases the Y register modulo rowsize. */
previousneighbour:
    cpy #0
    bne returnprevious
    ldy #rowsize+1
    returnprevious:
    dey
    rts

/* Load a cell's neighbourhood and store in 002a. */
/* If a neighbourhood contains the states 111, the value in 002a will be: 00000111. */
/* Uses periodic boundary conditions, e.g. the left neighbour of cell 0 is cell 39 and the right neighbour of cell 39 is cell 0. */
/* The value of the current colom is given in Y. */
neighbourhood:
    jsr previousneighbour
    lda ($04),Y         // Load left neighbour.
    jsr nextneighbour
    clc
    rol
    adc ($04),Y
    rol
    jsr nextneighbour
    clc
    adc ($04),Y            // Load right neighbour.
    jsr previousneighbour
    sta $002a
    rts

waitraster:
    lda raster
    cmp #$42
    bne waitraster
    rts

pause:
    jsr waitraster
    dex
    bne pause
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
