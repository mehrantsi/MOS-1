; MOS 1.1 - the MSAP-2 monitor operating system
.equ CONS, 0
.equ CONSTAT, 1
.equ DISK, 2
.equ DSKST, 5

.equ PTR, 0x1F00
.equ VAL, 0x1F02
.equ LEN, 0x1F04
.equ TMP, 0x1F06
.equ HAVE, 0x1F07
.equ DIGIT, 0x1F08
.equ ROWS, 0x1F09
.equ COLS, 0x1F0A
.equ SRC, 0x1F0B
.equ APTR, 0x1F0D
.equ M1, 0x1F0F
.equ M2, 0x1F10
.equ M3, 0x1F11
.equ FORM, 0x1F12
.equ E1, 0x1F13
.equ E2, 0x1F14
.equ E3, 0x1F15
.equ E4, 0x1F16
.equ E5, 0x1F17
.equ AREG, 0x1F18
.equ XREG, 0x1F19
.equ PUTCT, 0x1F1C
.equ IRQVEC, 0x1F1A
.equ TRAMP, 0x1EF0
.equ LINEBUF, 0x1F20
.equ DISKBUF, 0x1F60
.equ USER, 0x1000

.org 0x000
        jmp main

.org 0x008
        jmp (IRQVEC)

.org 0x00B
        jmp brkh

.org 0x010
        jmp putc
        jmp getc
        jmp puts
        jmp getln
        jmp mainloop
        .word asmtab

main:   lda #<banner
        sta PTR
        lda #>banner
        sta PTR+1
        jsr puts
mainloop:
        ldx #0xFF
        txs
        lda #<irqdef
        sta IRQVEC
        lda #>irqdef
        sta IRQVEC+1
        lda #62
        jsr putc
        lda #32
        jsr putc
        jsr getln
        ldx #0
        jsr skipsp
        jsr rdch
        jz mainloop
        and #0xDF
        cmp #72
        jz cmd_h
        cmp #65
        jz cmd_a
        cmp #67
        jz cmd_c
        cmp #70
        jz cmd_f
        cmp #68
        jz cmd_d
        cmp #69
        jz cmd_e
        cmp #82
        jz cmd_r
        cmp #76
        jz cmd_l
        cmp #83
        jz cmd_s
        cmp #88
        jz cmd_x
        lda #<msg_what
        sta PTR
        lda #>msg_what
        sta PTR+1
        jsr puts
        jmp mainloop

putc:   sta PUTCT
putc_w: in #CONSTAT
        and #2
        jz putc_w
        lda PUTCT
        out #CONS
        rts

getc:   in #CONSTAT
        and #1
        jz getc
        in #CONS
        rts

dskrd:  in #DSKST
        jz dskrd
        in #DISK
        rts

puts:   lda (PTR)
        jz puts_d
        jsr putc
        jsr incptr
        jmp puts
puts_d: rts

incptr: lda PTR
        add #1
        sta PTR
        jnc incp_d
        lda PTR+1
        add #1
        sta PTR+1
incp_d: rts

getln:  ldx #0
getln_l:
        jsr getc
        cmp #13
        jz getln_d
        cmp #10
        jz getln_d
        cmp #8
        jz getln_b
        cpx #62
        jc getln_l
        sta LINEBUF,x
        jsr putc
        inx
        jmp getln_l
getln_b:
        cpx #0
        jz getln_l
        dex
        lda #8
        jsr putc
        jmp getln_l
getln_d:
        lda #10
        jsr putc
        lda #0
        sta LINEBUF,x
        rts

rdch:   lda LINEBUF,x
        inx
        rts

skipsp: lda LINEBUF,x
        cmp #32
        jnz skips_d
        inx
        jmp skipsp
skips_d:
        rts

hexval: cmp #48
        jnc hv_bad
        cmp #58
        jnc hv_dig
        and #0xDF
        cmp #65
        jnc hv_bad
        cmp #71
        jc hv_bad
        sub #55
        rts
hv_dig: sub #48
        rts
hv_bad: lda #0xFF
        rts

parsehex:
        lda #0
        sta VAL
        sta VAL+1
        sta HAVE
ph_l:   lda LINEBUF,x
        jsr hexval
        cmp #0xFF
        jz ph_d
        sta DIGIT
        jsr shl16
        jsr shl16
        jsr shl16
        jsr shl16
        lda VAL
        ora DIGIT
        sta VAL
        lda #1
        sta HAVE
        inx
        jmp ph_l
ph_d:   rts

shl16:  lda VAL+1
        shl
        sta VAL+1
        lda VAL
        shl
        sta VAL
        jnc shl_d
        lda VAL+1
        ora #1
        sta VAL+1
shl_d:  rts

puthexn:
        and #0x0F
        cmp #10
        jc phn_a
        add #48
        jmp putc
phn_a:  add #55
        jmp putc

puthex: sta TMP
        shr
        shr
        shr
        shr
        jsr puthexn
        lda TMP
        jmp puthexn

cmd_c:  lda #12
        jsr putc
        jmp mainloop

cmd_h:  lda #<msg_help
        sta PTR
        lda #>msg_help
        sta PTR+1
        jsr puts
        jmp mainloop

cmd_d:  jsr skipsp
        jsr parsehex
        lda VAL
        sta PTR
        lda VAL+1
        sta PTR+1
        lda #4
        sta ROWS
d_row:  lda PTR+1
        jsr puthex
        lda PTR
        jsr puthex
        lda #58
        jsr putc
        lda #8
        sta COLS
d_col:  lda #32
        jsr putc
        lda (PTR)
        jsr puthex
        jsr incptr
        lda COLS
        sub #1
        sta COLS
        jnz d_col
        lda #10
        jsr putc
        lda ROWS
        sub #1
        sta ROWS
        jnz d_row
        jmp mainloop

cmd_e:  jsr skipsp
        jsr parsehex
        lda HAVE
        jz e_done
        lda VAL
        sta PTR
        lda VAL+1
        sta PTR+1
e_loop: jsr skipsp
        jsr parsehex
        lda HAVE
        jz e_done
        lda VAL
        sta (PTR)
        jsr incptr
        jmp e_loop
e_done: jmp mainloop

cmd_r:  jsr skipsp
        stx TMP
        jsr parsehex
        lda HAVE
        jz r_name
        lda LINEBUF,x
        jz r_go
        cmp #32
        jz r_go
r_name: ldx TMP
        lda LINEBUF,x
        jz r_user
        jsr loadf
        lda HAVE
        jz l_nf
        jmp r_go
r_user: lda #<USER
        sta VAL
        lda #>USER
        sta VAL+1
r_go:   lda #0x31
        sta TRAMP
        lda VAL
        sta TRAMP+1
        lda VAL+1
        sta TRAMP+2
        lda #0x30
        sta TRAMP+3
        lda #<r_ret
        sta TRAMP+4
        lda #>r_ret
        sta TRAMP+5
        jmp TRAMP
r_ret:  sta AREG
        stx XREG
        jsr regdump
        jmp mainloop

irqdef: rti

regdump:
        lda #<msg_ra
        sta PTR
        lda #>msg_ra
        sta PTR+1
        jsr puts
        lda AREG
        jsr puthex
        lda #<msg_rx
        sta PTR
        lda #>msg_rx
        sta PTR+1
        jsr puts
        lda XREG
        jsr puthex
        lda #10
        jmp putc

brkh:   sta AREG
        stx XREG
        pla
        sta TMP
        pla
        sta VAL
        pla
        sta VAL+1
        lda #<msg_brk
        sta PTR
        lda #>msg_brk
        sta PTR+1
        jsr puts
        lda VAL+1
        jsr puthex
        lda VAL
        jsr puthex
        jsr regdump
        jmp mainloop

buildcmd:
        sta DISKBUF
        lda #32
        sta DISKBUF+1
        lda #<DISKBUF+2
        sta PTR
        lda #>DISKBUF
        sta PTR+1
bc_l:   lda LINEBUF,x
        jz bc_d
        cmp #32
        jz bc_d
        sta (PTR)
        jsr incptr
        inx
        jmp bc_l
bc_d:   lda #0
        sta (PTR)
        rts

sendcmd:
        lda #<DISKBUF
        sta PTR
        lda #>DISKBUF
        sta PTR+1
sc_l:   lda (PTR)
        out #DISK
        jz sc_d
        jsr incptr
        jmp sc_l
sc_d:   rts

declen: lda LEN
        sub #1
        sta LEN
        jc dl_d
        lda LEN+1
        sub #1
        sta LEN+1
dl_d:   rts

cmd_f:  lda #70
        out #DISK
        lda #0
        out #DISK
f_l:    jsr dskrd
        jz f_d
        jsr putc
        jmp f_l
f_d:    jmp mainloop

loadf:  lda #76
        jsr buildcmd
        jsr sendcmd
        jsr skipsp
        jsr parsehex
        lda HAVE
        jnz lf_have
        lda #<USER
        sta VAL
        lda #>USER
        sta VAL+1
lf_have:
        lda VAL
        sta PTR
        lda VAL+1
        sta PTR+1
        jsr dskrd
        sta LEN
        jsr dskrd
        sta LEN+1
        cmp #0xFF
        jnz lf_read
        lda LEN
        cmp #0xFF
        jnz lf_read
        lda #0
        sta HAVE
        rts
lf_read:
        lda LEN
        ora LEN+1
        jz lf_ok
lf_rl:  jsr dskrd
        sta (PTR)
        jsr incptr
        jsr declen
        lda LEN
        ora LEN+1
        jnz lf_rl
lf_ok:  lda #1
        sta HAVE
        rts

cmd_l:  jsr skipsp
        jsr loadf
        lda HAVE
        jz l_nf
        lda #<msg_ok
        sta PTR
        lda #>msg_ok
        sta PTR+1
        jsr puts
        jmp mainloop
l_nf:   lda #<msg_nf
        sta PTR
        lda #>msg_nf
        sta PTR+1
        jsr puts
        jmp mainloop

cmd_s:  jsr skipsp
        lda #83
        jsr buildcmd
        jsr skipsp
        jsr parsehex
        lda VAL
        sta SRC
        lda VAL+1
        sta SRC+1
        jsr skipsp
        jsr parsehex
        lda VAL
        sta LEN
        lda VAL+1
        sta LEN+1
        jsr sendcmd
        lda LEN
        out #DISK
        lda LEN+1
        out #DISK
        lda SRC
        sta PTR
        lda SRC+1
        sta PTR+1
        lda LEN
        ora LEN+1
        jz s_ok
s_l:    lda (PTR)
        out #DISK
        jsr incptr
        jsr declen
        lda LEN
        ora LEN+1
        jnz s_l
s_ok:   lda #<msg_ok
        sta PTR
        lda #>msg_ok
        sta PTR+1
        jsr puts
        jmp mainloop

cmd_x:  jsr skipsp
        lda #68
        jsr buildcmd
        jsr sendcmd
        jsr dskrd
        jz x_no
        lda #<msg_ok
        sta PTR
        lda #>msg_ok
        sta PTR+1
        jsr puts
        jmp mainloop
x_no:   lda #<msg_nf
        sta PTR
        lda #>msg_nf
        sta PTR+1
        jsr puts
        jmp mainloop

cmd_a:  jsr skipsp
        jsr parsehex
        lda HAVE
        jnz a_set
        lda APTR
        ora APTR+1
        jnz a_loop
        lda #<USER
        sta VAL
        lda #>USER
        sta VAL+1
a_set:  lda VAL
        sta APTR
        lda VAL+1
        sta APTR+1
a_loop: lda APTR+1
        jsr puthex
        lda APTR
        jsr puthex
        lda #58
        jsr putc
        lda #32
        jsr putc
        jsr getln
        ldx #0
        jsr skipsp
        lda LINEBUF,x
        jz a_done
        jsr getlet
        jz a_nav
        sta M1
        lda #32
        sta M2
        sta M3
        jsr getlet
        jz a_form
        sta M2
        jsr getlet
        jz a_form
        sta M3
a_form: jsr skipsp
        lda LINEBUF,x
        jz af_none
        cmp #59
        jz af_none
        cmp #35
        jz af_imm
        cmp #40
        jz af_ind
        jsr parsehex
        lda HAVE
        jz a_err
        lda LINEBUF,x
        cmp #44
        jz af_absx
        lda #2
        jmp af_set
af_none:
        lda #0
        jmp af_set
af_imm: inx
        jsr parsehex
        lda HAVE
        jz a_err
        lda #1
        jmp af_set
af_ind: inx
        jsr parsehex
        lda HAVE
        jz a_err
        lda #3
        jmp af_set
af_absx:
        lda #4
af_set: sta FORM
        lda #<asmtab
        sta PTR
        lda #>asmtab
        sta PTR+1
at_l:   lda (PTR)
        jz a_err
        sta E1
        jsr incptr
        lda (PTR)
        sta E2
        jsr incptr
        lda (PTR)
        sta E3
        jsr incptr
        lda (PTR)
        sta E4
        jsr incptr
        lda (PTR)
        sta E5
        jsr incptr
        lda E1
        cmp M1
        jnz at_l
        lda E2
        cmp M2
        jnz at_l
        lda E3
        cmp M3
        jnz at_l
        lda E4
        cmp FORM
        jz a_emit
        lda E4
        cmp #5
        jnz at_l
        lda FORM
        cmp #1
        jz a_emit
        cmp #2
        jz a_emit
        jmp at_l
a_emit: lda E5
        sta (APTR)
        jsr incaptr
        lda E4
        jz a_loop
        lda VAL
        sta (APTR)
        jsr incaptr
        lda E4
        cmp #1
        jz a_loop
        cmp #5
        jz a_loop
        lda VAL+1
        sta (APTR)
        jsr incaptr
        jmp a_loop
a_done: jmp mainloop
a_nav:  lda LINEBUF,x
        cmp #59
        jz a_loop
        jsr parsehex
        lda HAVE
        jz a_err
        lda VAL
        sta APTR
        lda VAL+1
        sta APTR+1
        jmp a_loop
a_err:  lda #<msg_what
        sta PTR
        lda #>msg_what
        sta PTR+1
        jsr puts
        jmp a_loop

getlet: lda LINEBUF,x
        jz gl_no
        and #0xDF
        cmp #65
        jnc gl_no
        cmp #91
        jc gl_no
        inx
        rts
gl_no:  lda #0
        rts

incaptr:
        lda APTR
        add #1
        sta APTR
        jnc ica_d
        lda APTR+1
        add #1
        sta APTR+1
ica_d:  rts

banner:   .asciiz "MOS 1.1 - MSAP-2 8KB\nH FOR HELP\n"
msg_help: .asciiz "A [AAAA]        ASSEMBLE (BARE ADDR MOVES, ; COMMENTS, EMPTY LINE ENDS)\nD AAAA          DUMP 32 BYTES\nE AAAA BB ..    ENTER BYTES\nR ADDR OR NAME  RUN - RTS EXITS AND PRINTS A/X\nL NAME [AAAA]   LOAD (DEFAULT 1000)\nS NAME AAAA NN  SAVE NN BYTES FROM AAAA\nX NAME          DELETE\nF               LIST FILES\nC               CLEAR SCREEN\nBRK IN CODE BREAKS BACK TO THE MONITOR\nPUTC 010 GETC 013 PUTS 016 GETLN 019 EXIT 01C\n"
msg_what: .asciiz "?\n"
msg_ok:   .asciiz "OK\n"
msg_nf:   .asciiz "NOT FOUND\n"
msg_ra:   .asciiz " A="
msg_rx:   .asciiz " X="
msg_brk:  .asciiz "\nBRK @"

asmtab:
.ascii "NOP"
.byte 0, 0x00
.ascii "HLT"
.byte 0, 0x01
.ascii "EI "
.byte 0, 0x02
.ascii "DI "
.byte 0, 0x03
.ascii "RTS"
.byte 0, 0x04
.ascii "RTI"
.byte 0, 0x05
.ascii "PHA"
.byte 0, 0x06
.ascii "PLA"
.byte 0, 0x07
.ascii "PHX"
.byte 0, 0x08
.ascii "PLX"
.byte 0, 0x09
.ascii "TAX"
.byte 0, 0x0A
.ascii "TXA"
.byte 0, 0x0B
.ascii "INX"
.byte 0, 0x0C
.ascii "DEX"
.byte 0, 0x0D
.ascii "SHL"
.byte 0, 0x0E
.ascii "SHR"
.byte 0, 0x0F
.ascii "TXS"
.byte 0, 0x1A
.ascii "BRK"
.byte 0, 0x37
.ascii "LDA"
.byte 1, 0x10
.ascii "LDA"
.byte 2, 0x11
.ascii "LDA"
.byte 3, 0x12
.ascii "LDA"
.byte 4, 0x13
.ascii "STA"
.byte 2, 0x14
.ascii "STA"
.byte 3, 0x15
.ascii "STA"
.byte 4, 0x16
.ascii "LDX"
.byte 1, 0x17
.ascii "LDX"
.byte 2, 0x18
.ascii "STX"
.byte 2, 0x19
.ascii "ADD"
.byte 1, 0x20
.ascii "ADD"
.byte 2, 0x21
.ascii "SUB"
.byte 1, 0x22
.ascii "SUB"
.byte 2, 0x23
.ascii "AND"
.byte 1, 0x24
.ascii "AND"
.byte 2, 0x25
.ascii "ORA"
.byte 1, 0x26
.ascii "ORA"
.byte 2, 0x27
.ascii "XOR"
.byte 1, 0x28
.ascii "XOR"
.byte 2, 0x29
.ascii "CMP"
.byte 1, 0x2A
.ascii "CMP"
.byte 2, 0x2B
.ascii "CPX"
.byte 1, 0x2C
.ascii "JMP"
.byte 2, 0x30
.ascii "JMP"
.byte 3, 0x38
.ascii "JSR"
.byte 2, 0x31
.ascii "JZ "
.byte 2, 0x32
.ascii "JNZ"
.byte 2, 0x33
.ascii "JC "
.byte 2, 0x34
.ascii "JNC"
.byte 2, 0x35
.ascii "JN "
.byte 2, 0x36
.ascii "IN "
.byte 5, 0x40
.ascii "OUT"
.byte 5, 0x41
.byte 0
