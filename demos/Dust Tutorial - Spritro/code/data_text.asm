//============================================================
// Four lines of text, 40 characters each. The custom charset
// shows the ']' character as a heart. It holds only the first
// 48 screen codes (letters, space and the punctuation up to '/'),
// but this font leaves '!', ',' and '/' blank, so no digits or
// punctuation. Lines 1 and 2 are the tutorial's credits, 3 and
// 4 were added with the controls and the new features.
//============================================================

.encoding "screencode_mixed"
.var text1 = "     ]]] dustlayer.com presents ]]]     "
.var text2 = " ]]] spritro tutorial by actraiser ]]]  "
.var text3 = " u and d or joystick steer  space fires "
.var text4 = "  ] rockets and rocks by retrodubtrva ] "
.errorif text1.size() != 40, "line1 must be 40 chars"
.errorif text2.size() != 40, "line2 must be 40 chars"
.errorif text3.size() != 40, "line3 must be 40 chars"
.errorif text4.size() != 40, "line4 must be 40 chars"
line1:  .text text1
line2:  .text text2
line3:  .text text3
line4:  .text text4
