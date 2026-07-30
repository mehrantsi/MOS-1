; ED 1.0 - line editor + two-pass assembler for MSAP-2, runs under MOS
; load with R ED; text buffer 0x1790-0x1DFF; symbol table 0x1E00+
.equ DISK, 2
.equ DSKST, 5

.equ SYS_PUTC, 0x010
.equ SYS_GETC, 0x013
.equ SYS_PUTS, 0x016
.equ SYS_GETLN, 0x019
.equ SYS_EXIT, 0x01C
.equ PTR, 0x1F00
.equ LINEBUF, 0x1F20

.equ TABPTR, 0x01F

.equ EP, 0x1B00
.equ EQ, 0x1B02
.equ ES, 0x1B04
.equ EDD, 0x1B06
.equ ER, 0x1B08
.equ BUFE, 0x1B0A
.equ LNUM, 0x1B0C
.equ GN, 0x1B0E
.equ CNT, 0x1B10
.equ EVAL, 0x1B12
.equ EHAVE, 0x1B14
.equ EPC, 0x1B15
.equ ELEN, 0x1B17
.equ PASS, 0x1B19
.equ ELN, 0x1B1A
.equ M1, 0x1B1C
.equ M2, 0x1B1D
.equ M3, 0x1B1E
.equ FORM, 0x1B1F
.equ E4, 0x1B20
.equ E5, 0x1B21
.equ DIG, 0x1B22
.equ DIG2, 0x1B23
.equ DIG3, 0x1B24
.equ SYMN, 0x1B25
.equ SI, 0x1B26
.equ FOUND, 0x1B27
.equ LOFLAG, 0x1B28
.equ TSAVE, 0x1B29
.equ EHX, 0x1B2A
.equ TOK, 0x1B30
.equ NAMBUF, 0x1B40
.equ TXT, 0x1B50
.equ TXTTOPH, 0x1E
.equ SYMTAB, 0x1E00
.equ ABASE, 0x1000

.org 0x1000
start:  lda #<TXT
        sta BUFE
        lda #>TXT
        sta BUFE+1
        lda #0
        sta SYMN
        lda #<m_hi
        sta PTR
        lda #>m_hi
        sta PTR+1
        jsr SYS_PUTS
edloop: ldx #0xFF
        txs
        lda #93
        jsr SYS_PUTC
        lda #32
        jsr SYS_PUTC
        jsr SYS_GETLN
        ldx #0
        jsr eskips
        lda LINEBUF,x
        jz edloop
        cmp #46
        jz command
        jsr gethex
        lda EHAVE
        jz ederr
        lda EVAL
        sta LNUM
        lda EVAL+1
        sta LNUM+1
        jsr eskips
        jsr delline
        lda LINEBUF,x
        jz edloop
        jsr insline
        jmp edloop

command:
        inx
        lda LINEBUF,x
        inx
        and #0xDF
        cmp #76
        jz cmd_l
        cmp #81
        jz cmd_q
        cmp #72
        jz cmd_h
        cmp #83
        jz cmd_s
        cmp #79
        jz cmd_o
        cmp #65
        jz cmd_a
ederr:  lda #<m_err
        sta PTR
        lda #>m_err
        sta PTR+1
        jsr SYS_PUTS
        jmp edloop

cmd_q:  jmp SYS_EXIT

cmd_h:  lda #<m_help
        sta PTR
        lda #>m_help
        sta PTR+1
        jsr SYS_PUTS
        jmp edloop

cmd_l:  lda #<TXT
        sta EP
        lda #>TXT
        sta EP+1
cl_l:   jsr cepbe
        jc cl_d
        jsr getnum
        lda GN+1
        jsr puthex
        lda GN
        jsr puthex
        lda #32
        jsr SYS_PUTC
        jsr incep
        jsr incep
cl_c:   lda (EP)
        jz cl_e
        jsr SYS_PUTC
        jsr incep
        jmp cl_c
cl_e:   jsr incep
        lda #10
        jsr SYS_PUTC
        jmp cl_l
cl_d:   jmp edloop

cmd_s:  jsr eskips
        lda LINEBUF,x
        jz ederr
        lda #83
        jsr sendnm
        lda BUFE
        sub #<TXT
        sta CNT
        lda BUFE+1
        jc cs_nb
        sub #1
cs_nb:  sub #>TXT
        sta CNT+1
        lda CNT
        out #DISK
        lda CNT+1
        out #DISK
        lda #<TXT
        sta EP
        lda #>TXT
        sta EP+1
        lda CNT
        ora CNT+1
        jz cs_d
cs_l:   lda (EP)
        out #DISK
        jsr incep
        jsr deccnt
        jnz cs_l
cs_d:   jsr prok
        jmp edloop

cmd_o:  jsr eskips
        lda LINEBUF,x
        jz ederr
        lda #76
        jsr sendnm
        jsr edskrd
        sta CNT
        jsr edskrd
        sta CNT+1
        cmp #0xFF
        jnz co_ok
        lda CNT
        cmp #0xFF
        jnz co_ok
        lda #<m_nf
        sta PTR
        lda #>m_nf
        sta PTR+1
        jsr SYS_PUTS
        jmp edloop
co_ok:  lda #<TXT
        sta EP
        lda #>TXT
        sta EP+1
        lda CNT
        ora CNT+1
        jz co_set
co_l:   jsr edskrd
        sta (EP)
        jsr incep
        jsr deccnt
        jnz co_l
co_set: lda EP
        sta BUFE
        lda EP+1
        sta BUFE+1
        jsr prok
        jmp edloop

cmd_a:  jsr eskips
        lda LINEBUF,x
        jz ederr
        lda #<NAMBUF
        sta ER
        lda #>NAMBUF
        sta ER+1
ca_c:   lda LINEBUF,x
        jz ca_c2
        cmp #32
        jz ca_c2
        sta (ER)
        jsr incer
        inx
        jmp ca_c
ca_c2:  lda #0
        sta (ER)
        sta SYMN
        sta PASS
        jsr apass
        lda EPC
        sta ELEN
        lda EPC+1
        sub #>ABASE
        sta ELEN+1
        lda #1
        sta PASS
        jsr apass
        lda #83
        out #DISK
        lda #32
        out #DISK
        lda #<NAMBUF
        sta ER
        lda #>NAMBUF
        sta ER+1
ca_s:   lda (ER)
        jz ca_s2
        out #DISK
        jsr incer
        jmp ca_s
ca_s2:  lda #0
        out #DISK
        lda ELEN
        out #DISK
        lda ELEN+1
        out #DISK
        lda #2
        sta PASS
        jsr apass
        jsr prok
        jmp edloop

apass:  lda #<ABASE
        sta EPC
        lda #>ABASE
        sta EPC+1
        lda #<TXT
        sta EP
        lda #>TXT
        sta EP+1
ap_l:   jsr cepbe
        jc ap_d
        jsr copyrec
        jsr asmline
        jmp ap_l
ap_d:   rts

copyrec:
        jsr getnum
        lda GN
        sta ELN
        lda GN+1
        sta ELN+1
        jsr incep
        jsr incep
        ldx #0
cr_l:   lda (EP)
        sta LINEBUF,x
        jz cr_d
        jsr incep
        inx
        jmp cr_l
cr_d:   jsr incep
        rts

asmline:
        ldx #0
        jsr eskips
        lda LINEBUF,x
        jz al_rts
        cmp #59
        jz al_rts
        jsr gettok
        lda DIG2
        jz al_dot
        lda LINEBUF,x
        cmp #58
        jnz al_mn
        inx
        lda PASS
        jnz al_lb2
        jsr symdef
al_lb2: jsr eskips
        lda LINEBUF,x
        jz al_rts
        cmp #59
        jz al_rts
        jsr gettok
        lda DIG2
        jz al_dot
al_mn:  lda TOK
        sta M1
        lda TOK+1
        sta M2
        lda TOK+2
        sta M3
        jmp al_form
al_dot: lda LINEBUF,x
        cmp #46
        jnz aerr
        inx
        jsr gettok
        lda TOK
        cmp #66
        jnz aerr
ab_l:   jsr eskips
        jsr parseval
        lda EVAL
        jsr emitb
        jsr eskips
        lda LINEBUF,x
        cmp #44
        jnz al_rts
        inx
        jmp ab_l
al_rts: rts

al_form:
        lda #0
        sta LOFLAG
        jsr eskips
        lda LINEBUF,x
        jz af_none
        cmp #59
        jz af_none
        cmp #35
        jz af_imm
        cmp #40
        jz af_ind
        jsr parseval
        lda LINEBUF,x
        cmp #44
        jz af_absx
        lda #2
        jmp af_set
af_none:
        lda #0
        jmp af_set
af_imm: inx
        lda LINEBUF,x
        cmp #60
        jnz afi_1
        lda #1
        sta LOFLAG
        inx
        jmp afi_2
afi_1:  cmp #62
        jnz afi_2
        lda #2
        sta LOFLAG
        inx
afi_2:  jsr parseval
        lda LOFLAG
        cmp #2
        jnz afi_3
        lda EVAL+1
        sta EVAL
afi_3:  lda #1
        jmp af_set
af_ind: inx
        jsr parseval
        lda #3
        jmp af_set
af_absx:
        lda #4
af_set: sta FORM
        lda TABPTR
        sta ER
        lda TABPTR+1
        sta ER+1
et_l:   lda (ER)
        jz aerr
        sta DIG
        jsr incer
        lda (ER)
        sta DIG2
        jsr incer
        lda (ER)
        sta DIG3
        jsr incer
        lda (ER)
        sta E4
        jsr incer
        lda (ER)
        sta E5
        jsr incer
        lda M1
        cmp DIG
        jnz et_l
        lda M2
        cmp DIG2
        jnz et_l
        lda M3
        cmp DIG3
        jnz et_l
        lda E4
        cmp FORM
        jz al_emit
        cmp #5
        jnz et_l
        lda FORM
        cmp #1
        jz al_emit
        cmp #2
        jz al_emit
        jmp et_l
al_emit:
        lda E5
        jsr emitb
        lda E4
        jz al_r2
        lda EVAL
        jsr emitb
        lda E4
        cmp #1
        jz al_r2
        cmp #5
        jz al_r2
        lda EVAL+1
        jsr emitb
al_r2:  rts

aerr:   lda #<m_aerr
        sta PTR
        lda #>m_aerr
        sta PTR+1
        jsr SYS_PUTS
        lda ELN+1
        jsr puthex
        lda ELN
        jsr puthex
        lda #10
        jsr SYS_PUTC
        jmp edloop

parseval:
        jsr gettok
        lda DIG2
        jz pv_bad2
        jsr symfind
        lda FOUND
        jnz pv_ok
        lda #0
        sta EVAL
        sta EVAL+1
        sta EHAVE
        phx
        ldx #0
pv_l:   cpx #6
        jz pv_d
        lda TOK,x
        cmp #32
        jz pv_d
        jsr hexval
        cmp #0xFF
        jz pv_bad
        sta DIG
        jsr eshl4
        lda EVAL
        ora DIG
        sta EVAL
        lda #1
        sta EHAVE
        inx
        jmp pv_l
pv_d:   plx
        lda EHAVE
        jz pv_bad2
pv_ok:  rts
pv_bad: plx
pv_bad2:
        lda PASS
        jnz aerr
        lda #0
        sta EVAL
        sta EVAL+1
        rts

emitb:  sta DIG
        lda PASS
        cmp #2
        jnz eb_c
        lda DIG
        out #DISK
eb_c:   lda EPC
        add #1
        sta EPC
        jnc eb_d
        lda EPC+1
        add #1
        sta EPC+1
eb_d:   rts

symdef: jsr symfind
        lda FOUND
        jnz aerr
        lda SYMN
        cmp #28
        jc aerr
        lda SYMN
        shl
        shl
        shl
        sta ER
        lda #>SYMTAB
        sta ER+1
        phx
        ldx #0
sd_l:   lda TOK,x
        sta (ER)
        jsr incer
        inx
        cpx #6
        jnz sd_l
        plx
        lda EPC
        sta (ER)
        jsr incer
        lda EPC+1
        sta (ER)
        lda SYMN
        add #1
        sta SYMN
        rts

symfind:
        lda #0
        sta FOUND
        sta SI
sf_l:   lda SI
        cmp SYMN
        jc sf_no
        lda SI
        shl
        shl
        shl
        sta ER
        lda #>SYMTAB
        sta ER+1
        phx
        ldx #0
sf_c:   lda TOK,x
        sta DIG
        lda (ER)
        cmp DIG
        jnz sf_nx
        jsr incer
        inx
        cpx #6
        jnz sf_c
        lda (ER)
        sta EVAL
        jsr incer
        lda (ER)
        sta EVAL+1
        lda #1
        sta FOUND
        plx
        rts
sf_nx:  plx
        lda SI
        add #1
        sta SI
        jmp sf_l
sf_no:  rts

delline:
        lda #<TXT
        sta EP
        lda #>TXT
        sta EP+1
dl_l:   jsr cepbe
        jc dl_d
        jsr getnum
        lda GN
        cmp LNUM
        jnz dl_nx
        lda GN+1
        cmp LNUM+1
        jnz dl_nx
        jsr rlen
        sta DIG3
        lda EP
        sta EQ
        lda EP+1
        sta EQ+1
        lda DIG3
        jsr adeqa
dl_cp:  jsr ceqbe
        jc dl_fx
        lda (EQ)
        sta (EP)
        jsr incep
        jsr inceq
        jmp dl_cp
dl_fx:  lda EP
        sta BUFE
        lda EP+1
        sta BUFE+1
        rts
dl_nx:  jsr rlen
        jsr adepa
        jmp dl_l
dl_d:   rts

insline:
        stx TSAVE
        lda #3
        sta DIG3
il_c:   lda LINEBUF,x
        jz il_c2
        inx
        lda DIG3
        add #1
        sta DIG3
        jmp il_c
il_c2:  lda BUFE
        add DIG3
        sta EQ
        lda BUFE+1
        jnc il_n1
        add #1
il_n1:  sta EQ+1
        cmp #TXTTOPH
        jc il_full
        lda #<TXT
        sta EP
        lda #>TXT
        sta EP+1
il_f:   jsr cepbe
        jc il_at
        jsr getnum
        lda GN+1
        cmp LNUM+1
        jnz il_cm
        lda GN
        cmp LNUM
il_cm:  jnc il_nx
        jmp il_at
il_nx:  jsr rlen
        jsr adepa
        jmp il_f
il_at:  lda BUFE
        sub EP
        sta CNT
        lda BUFE+1
        jc il_n2
        sub #1
il_n2:  sub EP+1
        sta CNT+1
        lda CNT
        ora CNT+1
        jz il_wr
        lda BUFE
        sta ES
        lda BUFE+1
        sta ES+1
        jsr deces
        lda ES
        sta EDD
        lda ES+1
        sta EDD+1
        lda DIG3
        jsr addda
il_mv:  lda (ES)
        sta (EDD)
        jsr deces
        jsr decedd
        jsr deccnt
        jnz il_mv
il_wr:  lda LNUM
        sta (EP)
        jsr incep
        lda LNUM+1
        sta (EP)
        jsr incep
        ldx TSAVE
il_w2:  lda LINEBUF,x
        sta (EP)
        jz il_w3
        jsr incep
        inx
        jmp il_w2
il_w3:  lda EQ
        sta BUFE
        lda EQ+1
        sta BUFE+1
        rts
il_full:
        lda #<m_full
        sta PTR
        lda #>m_full
        sta PTR+1
        jsr SYS_PUTS
        jmp edloop

rlen:   lda EP
        sta ER
        lda EP+1
        sta ER+1
        jsr incer
        jsr incer
        lda #3
        sta DIG2
rl_l:   lda (ER)
        jz rl_d
        jsr incer
        lda DIG2
        add #1
        sta DIG2
        jmp rl_l
rl_d:   lda DIG2
        rts

getnum: lda EP
        sta ER
        lda EP+1
        sta ER+1
        lda (ER)
        sta GN
        jsr incer
        lda (ER)
        sta GN+1
        rts

gettok: lda #32
        sta TOK
        sta TOK+1
        sta TOK+2
        sta TOK+3
        sta TOK+4
        sta TOK+5
        lda #0
        sta DIG2
gt_l:   lda LINEBUF,x
        jz gt_d
        cmp #48
        jnc gt_d
        cmp #58
        jnc gt_k
        and #0xDF
        cmp #65
        jnc gt_d
        cmp #91
        jc gt_d
gt_k:   sta DIG
        lda DIG2
        cmp #6
        jc gt_sk
        phx
        ldx DIG2
        lda DIG
        sta TOK,x
        plx
gt_sk:  lda DIG2
        add #1
        sta DIG2
        inx
        jmp gt_l
gt_d:   rts

gethex: lda #0
        sta EVAL
        sta EVAL+1
        sta EHAVE
gh_l:   lda LINEBUF,x
        jsr hexval
        cmp #0xFF
        jz gh_d
        sta DIG
        jsr eshl4
        lda EVAL
        ora DIG
        sta EVAL
        lda #1
        sta EHAVE
        inx
        jmp gh_l
gh_d:   rts

eshl4:  lda #4
        sta SI
es_l:   lda EVAL+1
        shl
        sta EVAL+1
        lda EVAL
        shl
        sta EVAL
        jnc es_n
        lda EVAL+1
        ora #1
        sta EVAL+1
es_n:   lda SI
        sub #1
        sta SI
        jnz es_l
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

eskips: lda LINEBUF,x
        cmp #32
        jnz esk_d
        inx
        jmp eskips
esk_d:  rts

sendnm: out #DISK
        lda #32
        out #DISK
sn_l:   lda LINEBUF,x
        jz sn_d
        cmp #32
        jz sn_d
        out #DISK
        inx
        jmp sn_l
sn_d:   lda #0
        out #DISK
        rts

edskrd: in #DSKST
        jz edskrd
        in #DISK
        rts

prok:   lda #<m_ok
        sta PTR
        lda #>m_ok
        sta PTR+1
        jmp SYS_PUTS

puthexn:
        and #0x0F
        cmp #10
        jc phn_a
        add #48
        jmp SYS_PUTC
phn_a:  add #55
        jmp SYS_PUTC

puthex: sta EHX
        shr
        shr
        shr
        shr
        jsr puthexn
        lda EHX
        jmp puthexn

incep:  lda EP
        add #1
        sta EP
        jnc iep_d
        lda EP+1
        add #1
        sta EP+1
iep_d:  rts

inceq:  lda EQ
        add #1
        sta EQ
        jnc iq_d
        lda EQ+1
        add #1
        sta EQ+1
iq_d:   rts

incer:  lda ER
        add #1
        sta ER
        jnc ir_d
        lda ER+1
        add #1
        sta ER+1
ir_d:   rts

deces:  lda ES
        sub #1
        sta ES
        jc des_d
        lda ES+1
        sub #1
        sta ES+1
des_d:  rts

decedd: lda EDD
        sub #1
        sta EDD
        jc ded_d
        lda EDD+1
        sub #1
        sta EDD+1
ded_d:  rts

adepa:  sta DIG
        lda EP
        add DIG
        sta EP
        jnc aep_d
        lda EP+1
        add #1
        sta EP+1
aep_d:  rts

adeqa:  sta DIG
        lda EQ
        add DIG
        sta EQ
        jnc aq_d
        lda EQ+1
        add #1
        sta EQ+1
aq_d:   rts

addda:  sta DIG
        lda EDD
        add DIG
        sta EDD
        jnc ad_d
        lda EDD+1
        add #1
        sta EDD+1
ad_d:   rts

deccnt: lda CNT
        sub #1
        sta CNT
        jc dc_ok
        lda CNT+1
        sub #1
        sta CNT+1
dc_ok:  lda CNT
        ora CNT+1
        rts

cepbe:  lda EP+1
        cmp BUFE+1
        jnz cpb_d
        lda EP
        cmp BUFE
cpb_d:  rts

ceqbe:  lda EQ+1
        cmp BUFE+1
        jnz cqb_d
        lda EQ
        cmp BUFE
cqb_d:  rts

m_hi:   .asciiz "ED 1.0 - .H FOR HELP\n"
m_help: .asciiz "NN TEXT ADDS LINE, BARE NN DELETES\n.L LIST .A NAME ASM .S/.O NAME SRC .Q QUIT\nLABELS NAME: OPERANDS HEX #<L #>L\n"
m_err:  .asciiz "?\n"
m_aerr: .asciiz "ERR @"
m_nf:   .asciiz "NOT FOUND\n"
m_ok:   .asciiz "OK\n"
m_full: .asciiz "FULL\n"
