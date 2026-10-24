//============================================================
// 8-bit linear feedback shift register (taps $1d), with the zero
// state spliced in so the period is 256. Returns the next value in
// A and keeps it in rnd_seed.
//============================================================

random:             lda rnd_seed
                    beq do_eor                     // never get stuck at 0
                    asl
                    beq no_eor                     // $80 shifts to 0: keep it
                    bcc no_eor
do_eor:             eor #$1d
no_eor:             sta rnd_seed
                    rts
