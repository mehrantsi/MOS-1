; MSAP-2 immutable shadow-ROM bootloader
.equ DISK, 2
.equ DSKST, 5
.equ OVERLAY, 6

.equ PTR, 0x3F00
.equ SUM1, 0x3F02
.equ SUM2, 0x3F03
.equ EXPECT1, 0x3F04
.equ EXPECT2, 0x3F05
.equ WAITLOW, 0x3F06
.equ TMP, 0x3F07
.equ TRAMP, 0x3EF0
.equ FALLBACK, 0x0003

.org 0x1C00
boot:   ldx #0xFF
        txs
        ldx #0x60
        jsr boot_wait
        lda #<boot_command
        sta PTR
        lda #>boot_command
        sta PTR+1
boot_send:
        lda (PTR)
        out #DISK
        jz boot_sent
        jsr boot_incptr
        jmp boot_send
boot_sent:
        jsr boot_read
        cmp #0x10
        jnz boot_fail
        jsr boot_read
        cmp #0x20
        jnz boot_fail

        ldx #0
boot_header_loop:
        jsr boot_read
        sta TMP
        lda boot_header,x
        cmp TMP
        jnz boot_fail
        inx
        cpx #12
        jnz boot_header_loop

        jsr boot_read
        sta EXPECT1
        jsr boot_read
        sta EXPECT2
        jsr boot_read
        jnz boot_fail
        jsr boot_read
        jnz boot_fail

        lda #0
        sta PTR
        sta PTR+1
        sta SUM1
        sta SUM2
boot_payload:
        jsr boot_read
        sta (PTR)
        add SUM1
        jnc boot_sum1_norm
        add #1
boot_sum1_norm:
        cmp #0xFF
        jnz boot_sum1_store
        lda #0
boot_sum1_store:
        sta SUM1
        add SUM2
        jnc boot_sum2_norm
        add #1
boot_sum2_norm:
        cmp #0xFF
        jnz boot_sum2_store
        lda #0
boot_sum2_store:
        sta SUM2
        jsr boot_incptr
        lda PTR+1
        cmp #0x20
        jnz boot_payload

        lda SUM1
        cmp EXPECT1
        jnz boot_fail
        lda SUM2
        cmp EXPECT2
        jnz boot_fail

        ldx #0
boot_trampoline_loop:
        lda boot_trampoline,x
        sta TRAMP,x
        inx
        cpx #5
        jnz boot_trampoline_loop
        jmp TRAMP

boot_read:
        phx
        ldx #0x20
        jsr boot_wait
        plx
        in #DISK
        rts

boot_wait:
        lda #0xFF
        sta WAITLOW
boot_wait_loop:
        in #DSKST
        jnz boot_ready
        lda WAITLOW
        sub #1
        sta WAITLOW
        jc boot_wait_loop
        dex
        jnz boot_wait
boot_fail:
        jmp FALLBACK
boot_ready:
        rts

boot_incptr:
        lda PTR
        add #1
        sta PTR
        jnc boot_incptr_done
        lda PTR+1
        add #1
        sta PTR+1
boot_incptr_done:
        rts

boot_command:
        .asciiz "L MOS.BIN"
boot_header:
        .byte 0x4D, 0x32, 0x4F, 0x53
        .byte 1, 16
        .word 0
        .word 0x2000
        .word 0
boot_trampoline:
        .byte 0x41, OVERLAY, 0x30, 0, 0
