BasicUpstart2(start)

.const charset = $2000
.const rowsize = 39
.const screen = $0400
.const wolframrule = $06
.const clearscreen = $e544
.const currentrowhigh = $03
.const currentrowlow = $02

// Example rule 030:
//  0   0   0   1   1   1   1   0
// 111 110 101 100 011 010 001 000

start:
    /* Clear screen. */
    jsr clearscreen

    /* Store address of screen in current row vector. */
    lda #0
    sta currentrowlow

    /* Initialize the first row. */
    ldy #rowsize
    fill:
        sta screen,Y
        dey
        bpl fill
    lda #1
    sta $0413

    lda #4
    sta currentrowhigh

    /* Screen at $0400, charset at $2000. */
    lda #$18
    sta $d018

    ldx #8
    fillchar:
        lda #0
        sta charset,X
        sta charset+32*8,X
        lda #$ff
        sta charset+8,X
        dex
        bpl fillchar

    inc wolframrule

update:
    /* Copy old current row address. */
    lda currentrowhigh
    sta $05
    ldx currentrowlow
    stx $04
    /* Check if current row is one after the last row. */
    clc
    adc $04
    cmp #$c7        // 0x7 + 0xc0
    beq start

    /* Increase the current row number by adding the rowsize to the 02-03 vector .*/
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
        // Load a cell's neighbourhood and store in A.
        // If a neighbourhood contains the states 111,
        // the value in A will be: 00000111.
        // Uses periodic boundary conditions, e.g. the left neighbour of cell 0 is cell 39
        // and the right neighbour of cell 39 is cell 0.
        // The value of the current colom is given in Y.
        lda ($04),Y
        clc
        rol
        jsr previousneighbour
        clc
        adc ($04),Y
        rol

        /* Goto next neighbour by jumping to previousneighbour rowsize-1 times.
        /* This takes slightly fewer bytes then using a nextneighbour routine. */
        ldx #rowsize-1
        decrement:
        jsr previousneighbour
        dex
        bne decrement

        clc
        adc ($04),Y
        jsr previousneighbour


        tax
        lda #1
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
        beq zero
        lda #1
        zero:
        sta (currentrowlow),Y
        dey
        bpl updatecolumn

    jmp update

/* Decreases the Y register modulo rowsize. */
previousneighbour:
    cpy #0
    bne returnprevious
    ldy #rowsize+1
    returnprevious:
    dey
    rts
