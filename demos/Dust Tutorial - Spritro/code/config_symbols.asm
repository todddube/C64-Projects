//============================================================
// general symbols used in the code
//============================================================

.label screen_ram    = $0400          // screen RAM
.label init_sid      = music.init     // music init ($11ed)
.label play_sid      = music.play     // music play ($1004)
.label delay_counter = $90            // times the border colour switch
.label pra           = $dc00          // CIA#1 port A
.label prb           = $dc01          // CIA#1 port B
.label ddra          = $dc02          // CIA#1 data direction A
.label ddrb          = $dc03          // CIA#1 data direction B
