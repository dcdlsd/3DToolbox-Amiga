-> Text2STLMUI.e
-> Generate a simple ASCII STL plaque with raised 5x7 bitmap text.

OPT PREPROCESS
OPT LARGE
OPT OSVERSION=39

MODULE 'muimaster','libraries/mui'
MODULE 'utility/tagitem','utility/hooks'
MODULE 'intuition/classes','intuition/classusr'
MODULE 'dos/dos','libraries/asl'
MODULE 'diskfont','graphics/text','libraries/diskfont'
MODULE 'mathffp','mathtrans'
MODULE 'mathieeesingbas','mathieeesingtrans'

ENUM ID_GENERATE=1,
     ID_CLEAR

DEF ap_app, wi_main
DEF st_line1, st_line2, st_line3, st_dest, st_fontsize
DEF cy_mode, cy_font, cy_case
DEF st_cell, st_margin, st_base, st_height, st_radius
DEF bt_generate, bt_clear, bt_quit
DEF tx_status
DEF g_boxes
DEF g_point_x,g_point_y
DEF g_font=NIL:PTR TO textfont
DEF g_metric_w,g_metric_h,g_metric_lines
DEF g_mode_entries,g_font_entries,g_case_entries

PROC bouton(label)
    DEF obj
    obj := TextObject,
        ButtonFrame,
        MUIA_Text_Contents, label,
        MUIA_Text_PreParse, '\ec',
        MUIA_InputMode, MUIV_InputMode_RelVerify,
        MUIA_Background, MUII_ButtonBack,
    End
ENDPROC obj

PROC set_status(text)
    set(tx_status, MUIA_Text_Contents, text)
ENDPROC

PROC same_text(a:PTR TO CHAR, b:PTR TO CHAR)
    IF (a=NIL) OR (b=NIL) THEN RETURN FALSE
    WHILE a[] AND b[]
        IF a[]<>b[] THEN RETURN FALSE
        a++
        b++
    ENDWHILE
ENDPROC (a[]=0) AND (b[]=0)

PROC add_stl_extension(name:PTR TO CHAR)
    DEF len

    len:=StrLen(name)
    name[len]:=46
    name[len+1]:=115
    name[len+2]:=116
    name[len+3]:=108
    name[len+4]:=0
ENDPROC

PROC force_stl_extension(name:PTR TO CHAR)
    DEF i=0,lastdot=-1

    WHILE name[i]
        IF (name[i]=58) OR (name[i]=47)
            lastdot:=-1
        ELSEIF name[i]=46
            lastdot:=i
        ENDIF
        i++
    ENDWHILE

    IF lastdot<>-1 THEN name[lastdot]:=0
    add_stl_extension(name)
ENDPROC

PROC char_upper(c)
    IF (c>=97) AND (c<=122) THEN c:=c-32
ENDPROC c

PROC char_lower(c)
    IF (c>=65) AND (c<=90) THEN c:=c+32
ENDPROC c

PROC apply_text_case(text:PTR TO CHAR, active)
    DEF lower=FALSE

    SELECT active
        CASE 1
            lower:=FALSE
        CASE 2
            lower:=TRUE
        DEFAULT
            RETURN
    ENDSELECT

    WHILE text[]
        IF lower
            text[]:=char_lower(text[])
        ELSE
            text[]:=char_upper(text[])
        ENDIF
        text++
    ENDWHILE
ENDPROC

PROC make_stl_name_from_text(text:PTR TO CHAR, dest:PTR TO CHAR)
    DEF i=0, c, last_us=FALSE

    StrCopy(dest, 'RAM:', ALL)
    i:=4

    WHILE text[] AND (i<240)
        c:=text[]
        IF ((c>=65) AND (c<=90)) OR ((c>=97) AND (c<=122)) OR ((c>=48) AND (c<=57))
            dest[i++]:=c
            last_us:=FALSE
        ELSE
            IF last_us=FALSE
                dest[i++]:=95
                last_us:=TRUE
            ENDIF
        ENDIF
        text++
    ENDWHILE

    IF (i>4) AND (dest[i-1]=95) THEN i--
    IF i=4
        dest[i++]:=116
        dest[i++]:=101
        dest[i++]:=120
        dest[i++]:=116
    ENDIF
    dest[i]:=0
    add_stl_extension(dest)
ENDPROC

PROC append_gui_line(text:PTR TO CHAR,line:PTR TO CHAR,needsep)
    IF line=NIL THEN RETURN FALSE
    IF StrLen(line)<=0 THEN RETURN FALSE

    IF needsep THEN StrAdd(text,'|',1)
    StrAdd(text,line,ALL)
ENDPROC TRUE

PROC build_text_from_lines(text:PTR TO CHAR,l1:PTR TO CHAR,l2:PTR TO CHAR,l3:PTR TO CHAR)
    DEF has=FALSE

    text[0]:=0

    IF append_gui_line(text,l1,has) THEN has:=TRUE
    IF append_gui_line(text,l2,has) THEN has:=TRUE
    append_gui_line(text,l3,has)
ENDPROC

PROC font_name_from_active(active,dest:PTR TO CHAR)
    SELECT active
        CASE 1
            StrCopy(dest,'opal.font',ALL)
        CASE 2
            StrCopy(dest,'diamond.font',ALL)
        DEFAULT
            StrCopy(dest,'topaz.font',ALL)
    ENDSELECT
ENDPROC

PROC bit_for_col(col)
    SELECT col
        CASE 0 ; RETURN 16
        CASE 1 ; RETURN 8
        CASE 2 ; RETURN 4
        CASE 3 ; RETURN 2
        CASE 4 ; RETURN 1
    ENDSELECT
ENDPROC 0

PROC font_row(c,row)
    DEF r=0

    IF ((c<65) OR (c>90)) AND ((c<97) OR (c>122)) AND ((c<48) OR (c>57)) AND (c<>32) AND (c<>45) AND (c<>46) AND (c<>95) AND (c<>33) AND (c<>63)
        c:=63
    ENDIF

    IF (c>=97) AND (c<=122)
        SELECT c
            CASE 97
                SELECT row
                    CASE 2 ; r:=14
                    CASE 3 ; r:=1
                    CASE 4 ; r:=15
                    CASE 5 ; r:=17
                    CASE 6 ; r:=15
                ENDSELECT
            CASE 98
                SELECT row
                    CASE 0 ; r:=16
                    CASE 1 ; r:=16
                    CASE 2 ; r:=30
                    CASE 3 ; r:=17
                    CASE 4 ; r:=17
                    CASE 5 ; r:=17
                    CASE 6 ; r:=30
                ENDSELECT
            CASE 99
                SELECT row
                    CASE 2 ; r:=14
                    CASE 3 ; r:=16
                    CASE 4 ; r:=16
                    CASE 5 ; r:=16
                    CASE 6 ; r:=14
                ENDSELECT
            CASE 100
                SELECT row
                    CASE 0 ; r:=1
                    CASE 1 ; r:=1
                    CASE 2 ; r:=15
                    CASE 3 ; r:=17
                    CASE 4 ; r:=17
                    CASE 5 ; r:=17
                    CASE 6 ; r:=15
                ENDSELECT
            CASE 101
                SELECT row
                    CASE 2 ; r:=14
                    CASE 3 ; r:=17
                    CASE 4 ; r:=31
                    CASE 5 ; r:=16
                    CASE 6 ; r:=14
                ENDSELECT
            CASE 102
                SELECT row
                    CASE 0 ; r:=6
                    CASE 1 ; r:=8
                    CASE 2 ; r:=30
                    CASE 3 ; r:=8
                    CASE 4 ; r:=8
                    CASE 5 ; r:=8
                    CASE 6 ; r:=8
                ENDSELECT
            CASE 103
                SELECT row
                    CASE 2 ; r:=15
                    CASE 3 ; r:=17
                    CASE 4 ; r:=17
                    CASE 5 ; r:=15
                    CASE 6 ; r:=1
                ENDSELECT
            CASE 104
                SELECT row
                    CASE 0 ; r:=16
                    CASE 1 ; r:=16
                    CASE 2 ; r:=30
                    CASE 3 ; r:=17
                    CASE 4 ; r:=17
                    CASE 5 ; r:=17
                    CASE 6 ; r:=17
                ENDSELECT
            CASE 105
                SELECT row
                    CASE 0 ; r:=4
                    CASE 2 ; r:=12
                    CASE 3 ; r:=4
                    CASE 4 ; r:=4
                    CASE 5 ; r:=4
                    CASE 6 ; r:=14
                ENDSELECT
            CASE 106
                SELECT row
                    CASE 0 ; r:=2
                    CASE 2 ; r:=6
                    CASE 3 ; r:=2
                    CASE 4 ; r:=2
                    CASE 5 ; r:=18
                    CASE 6 ; r:=12
                ENDSELECT
            CASE 107
                SELECT row
                    CASE 0 ; r:=16
                    CASE 1 ; r:=16
                    CASE 2 ; r:=18
                    CASE 3 ; r:=20
                    CASE 4 ; r:=24
                    CASE 5 ; r:=20
                    CASE 6 ; r:=18
                ENDSELECT
            CASE 108
                SELECT row
                    CASE 0 ; r:=12
                    CASE 1 ; r:=4
                    CASE 2 ; r:=4
                    CASE 3 ; r:=4
                    CASE 4 ; r:=4
                    CASE 5 ; r:=4
                    CASE 6 ; r:=14
                ENDSELECT
            CASE 109
                SELECT row
                    CASE 2 ; r:=26
                    CASE 3 ; r:=21
                    CASE 4 ; r:=21
                    CASE 5 ; r:=21
                    CASE 6 ; r:=21
                ENDSELECT
            CASE 110
                SELECT row
                    CASE 2 ; r:=30
                    CASE 3 ; r:=17
                    CASE 4 ; r:=17
                    CASE 5 ; r:=17
                    CASE 6 ; r:=17
                ENDSELECT
            CASE 111
                SELECT row
                    CASE 2 ; r:=14
                    CASE 3 ; r:=17
                    CASE 4 ; r:=17
                    CASE 5 ; r:=17
                    CASE 6 ; r:=14
                ENDSELECT
            CASE 112
                SELECT row
                    CASE 2 ; r:=30
                    CASE 3 ; r:=17
                    CASE 4 ; r:=17
                    CASE 5 ; r:=30
                    CASE 6 ; r:=16
                ENDSELECT
            CASE 113
                SELECT row
                    CASE 2 ; r:=15
                    CASE 3 ; r:=17
                    CASE 4 ; r:=17
                    CASE 5 ; r:=15
                    CASE 6 ; r:=1
                ENDSELECT
            CASE 114
                SELECT row
                    CASE 2 ; r:=22
                    CASE 3 ; r:=24
                    CASE 4 ; r:=16
                    CASE 5 ; r:=16
                    CASE 6 ; r:=16
                ENDSELECT
            CASE 115
                SELECT row
                    CASE 2 ; r:=15
                    CASE 3 ; r:=16
                    CASE 4 ; r:=14
                    CASE 5 ; r:=1
                    CASE 6 ; r:=30
                ENDSELECT
            CASE 116
                SELECT row
                    CASE 1 ; r:=8
                    CASE 2 ; r:=30
                    CASE 3 ; r:=8
                    CASE 4 ; r:=8
                    CASE 5 ; r:=8
                    CASE 6 ; r:=6
                ENDSELECT
            CASE 117
                SELECT row
                    CASE 2 ; r:=17
                    CASE 3 ; r:=17
                    CASE 4 ; r:=17
                    CASE 5 ; r:=19
                    CASE 6 ; r:=13
                ENDSELECT
            CASE 118
                SELECT row
                    CASE 2 ; r:=17
                    CASE 3 ; r:=17
                    CASE 4 ; r:=17
                    CASE 5 ; r:=10
                    CASE 6 ; r:=4
                ENDSELECT
            CASE 119
                SELECT row
                    CASE 2 ; r:=17
                    CASE 3 ; r:=17
                    CASE 4 ; r:=21
                    CASE 5 ; r:=21
                    CASE 6 ; r:=10
                ENDSELECT
            CASE 120
                SELECT row
                    CASE 2 ; r:=17
                    CASE 3 ; r:=10
                    CASE 4 ; r:=4
                    CASE 5 ; r:=10
                    CASE 6 ; r:=17
                ENDSELECT
            CASE 121
                SELECT row
                    CASE 2 ; r:=17
                    CASE 3 ; r:=17
                    CASE 4 ; r:=17
                    CASE 5 ; r:=15
                    CASE 6 ; r:=1
                ENDSELECT
            CASE 122
                SELECT row
                    CASE 2 ; r:=31
                    CASE 3 ; r:=2
                    CASE 4 ; r:=4
                    CASE 5 ; r:=8
                    CASE 6 ; r:=31
                ENDSELECT
        ENDSELECT
        RETURN r
    ENDIF

    SELECT c
        CASE 32
            r:=0
        CASE 45
            SELECT row
                CASE 3 ; r:=31
            ENDSELECT
        CASE 46
            SELECT row
                CASE 6 ; r:=4
            ENDSELECT
        CASE 95
            SELECT row
                CASE 6 ; r:=31
            ENDSELECT
        CASE 33
            SELECT row
                CASE 0 ; r:=4
                CASE 1 ; r:=4
                CASE 2 ; r:=4
                CASE 3 ; r:=4
                CASE 5 ; r:=4
                CASE 6 ; r:=4
            ENDSELECT
        CASE 63
            SELECT row
                CASE 0 ; r:=14
                CASE 1 ; r:=17
                CASE 2 ; r:=1
                CASE 3 ; r:=2
                CASE 4 ; r:=4
                CASE 6 ; r:=4
            ENDSELECT
        CASE 48
            SELECT row
                CASE 0 ; r:=14
                CASE 1 ; r:=17
                CASE 2 ; r:=19
                CASE 3 ; r:=21
                CASE 4 ; r:=25
                CASE 5 ; r:=17
                CASE 6 ; r:=14
            ENDSELECT
        CASE 49
            SELECT row
                CASE 0 ; r:=4
                CASE 1 ; r:=12
                CASE 2 ; r:=4
                CASE 3 ; r:=4
                CASE 4 ; r:=4
                CASE 5 ; r:=4
                CASE 6 ; r:=14
            ENDSELECT
        CASE 50
            SELECT row
                CASE 0 ; r:=14
                CASE 1 ; r:=17
                CASE 2 ; r:=1
                CASE 3 ; r:=2
                CASE 4 ; r:=4
                CASE 5 ; r:=8
                CASE 6 ; r:=31
            ENDSELECT
        CASE 51
            SELECT row
                CASE 0 ; r:=30
                CASE 1 ; r:=1
                CASE 2 ; r:=1
                CASE 3 ; r:=14
                CASE 4 ; r:=1
                CASE 5 ; r:=1
                CASE 6 ; r:=30
            ENDSELECT
        CASE 52
            SELECT row
                CASE 0 ; r:=2
                CASE 1 ; r:=6
                CASE 2 ; r:=10
                CASE 3 ; r:=18
                CASE 4 ; r:=31
                CASE 5 ; r:=2
                CASE 6 ; r:=2
            ENDSELECT
        CASE 53
            SELECT row
                CASE 0 ; r:=31
                CASE 1 ; r:=16
                CASE 2 ; r:=16
                CASE 3 ; r:=30
                CASE 4 ; r:=1
                CASE 5 ; r:=1
                CASE 6 ; r:=30
            ENDSELECT
        CASE 54
            SELECT row
                CASE 0 ; r:=14
                CASE 1 ; r:=16
                CASE 2 ; r:=16
                CASE 3 ; r:=30
                CASE 4 ; r:=17
                CASE 5 ; r:=17
                CASE 6 ; r:=14
            ENDSELECT
        CASE 55
            SELECT row
                CASE 0 ; r:=31
                CASE 1 ; r:=1
                CASE 2 ; r:=2
                CASE 3 ; r:=4
                CASE 4 ; r:=8
                CASE 5 ; r:=8
                CASE 6 ; r:=8
            ENDSELECT
        CASE 56
            SELECT row
                CASE 0 ; r:=14
                CASE 1 ; r:=17
                CASE 2 ; r:=17
                CASE 3 ; r:=14
                CASE 4 ; r:=17
                CASE 5 ; r:=17
                CASE 6 ; r:=14
            ENDSELECT
        CASE 57
            SELECT row
                CASE 0 ; r:=14
                CASE 1 ; r:=17
                CASE 2 ; r:=17
                CASE 3 ; r:=15
                CASE 4 ; r:=1
                CASE 5 ; r:=1
                CASE 6 ; r:=14
            ENDSELECT
        CASE 65
            SELECT row
                CASE 0 ; r:=14
                CASE 1 ; r:=17
                CASE 2 ; r:=17
                CASE 3 ; r:=31
                CASE 4 ; r:=17
                CASE 5 ; r:=17
                CASE 6 ; r:=17
            ENDSELECT
        CASE 66
            SELECT row
                CASE 0 ; r:=30
                CASE 1 ; r:=17
                CASE 2 ; r:=17
                CASE 3 ; r:=30
                CASE 4 ; r:=17
                CASE 5 ; r:=17
                CASE 6 ; r:=30
            ENDSELECT
        CASE 67
            SELECT row
                CASE 0 ; r:=14
                CASE 1 ; r:=17
                CASE 2 ; r:=16
                CASE 3 ; r:=16
                CASE 4 ; r:=16
                CASE 5 ; r:=17
                CASE 6 ; r:=14
            ENDSELECT
        CASE 68
            SELECT row
                CASE 0 ; r:=30
                CASE 1 ; r:=17
                CASE 2 ; r:=17
                CASE 3 ; r:=17
                CASE 4 ; r:=17
                CASE 5 ; r:=17
                CASE 6 ; r:=30
            ENDSELECT
        CASE 69
            SELECT row
                CASE 0 ; r:=31
                CASE 1 ; r:=16
                CASE 2 ; r:=16
                CASE 3 ; r:=30
                CASE 4 ; r:=16
                CASE 5 ; r:=16
                CASE 6 ; r:=31
            ENDSELECT
        CASE 70
            SELECT row
                CASE 0 ; r:=31
                CASE 1 ; r:=16
                CASE 2 ; r:=16
                CASE 3 ; r:=30
                CASE 4 ; r:=16
                CASE 5 ; r:=16
                CASE 6 ; r:=16
            ENDSELECT
        CASE 71
            SELECT row
                CASE 0 ; r:=14
                CASE 1 ; r:=17
                CASE 2 ; r:=16
                CASE 3 ; r:=23
                CASE 4 ; r:=17
                CASE 5 ; r:=17
                CASE 6 ; r:=15
            ENDSELECT
        CASE 72
            SELECT row
                CASE 0 ; r:=17
                CASE 1 ; r:=17
                CASE 2 ; r:=17
                CASE 3 ; r:=31
                CASE 4 ; r:=17
                CASE 5 ; r:=17
                CASE 6 ; r:=17
            ENDSELECT
        CASE 73
            SELECT row
                CASE 0 ; r:=14
                CASE 1 ; r:=4
                CASE 2 ; r:=4
                CASE 3 ; r:=4
                CASE 4 ; r:=4
                CASE 5 ; r:=4
                CASE 6 ; r:=14
            ENDSELECT
        CASE 74
            SELECT row
                CASE 0 ; r:=1
                CASE 1 ; r:=1
                CASE 2 ; r:=1
                CASE 3 ; r:=1
                CASE 4 ; r:=17
                CASE 5 ; r:=17
                CASE 6 ; r:=14
            ENDSELECT
        CASE 75
            SELECT row
                CASE 0 ; r:=17
                CASE 1 ; r:=18
                CASE 2 ; r:=20
                CASE 3 ; r:=24
                CASE 4 ; r:=20
                CASE 5 ; r:=18
                CASE 6 ; r:=17
            ENDSELECT
        CASE 76
            SELECT row
                CASE 0 ; r:=16
                CASE 1 ; r:=16
                CASE 2 ; r:=16
                CASE 3 ; r:=16
                CASE 4 ; r:=16
                CASE 5 ; r:=16
                CASE 6 ; r:=31
            ENDSELECT
        CASE 77
            SELECT row
                CASE 0 ; r:=17
                CASE 1 ; r:=27
                CASE 2 ; r:=21
                CASE 3 ; r:=21
                CASE 4 ; r:=17
                CASE 5 ; r:=17
                CASE 6 ; r:=17
            ENDSELECT
        CASE 78
            SELECT row
                CASE 0 ; r:=17
                CASE 1 ; r:=25
                CASE 2 ; r:=21
                CASE 3 ; r:=19
                CASE 4 ; r:=17
                CASE 5 ; r:=17
                CASE 6 ; r:=17
            ENDSELECT
        CASE 79
            SELECT row
                CASE 0 ; r:=14
                CASE 1 ; r:=17
                CASE 2 ; r:=17
                CASE 3 ; r:=17
                CASE 4 ; r:=17
                CASE 5 ; r:=17
                CASE 6 ; r:=14
            ENDSELECT
        CASE 80
            SELECT row
                CASE 0 ; r:=30
                CASE 1 ; r:=17
                CASE 2 ; r:=17
                CASE 3 ; r:=30
                CASE 4 ; r:=16
                CASE 5 ; r:=16
                CASE 6 ; r:=16
            ENDSELECT
        CASE 81
            SELECT row
                CASE 0 ; r:=14
                CASE 1 ; r:=17
                CASE 2 ; r:=17
                CASE 3 ; r:=17
                CASE 4 ; r:=21
                CASE 5 ; r:=18
                CASE 6 ; r:=13
            ENDSELECT
        CASE 82
            SELECT row
                CASE 0 ; r:=30
                CASE 1 ; r:=17
                CASE 2 ; r:=17
                CASE 3 ; r:=30
                CASE 4 ; r:=20
                CASE 5 ; r:=18
                CASE 6 ; r:=17
            ENDSELECT
        CASE 83
            SELECT row
                CASE 0 ; r:=15
                CASE 1 ; r:=16
                CASE 2 ; r:=16
                CASE 3 ; r:=14
                CASE 4 ; r:=1
                CASE 5 ; r:=1
                CASE 6 ; r:=30
            ENDSELECT
        CASE 84
            SELECT row
                CASE 0 ; r:=31
                CASE 1 ; r:=4
                CASE 2 ; r:=4
                CASE 3 ; r:=4
                CASE 4 ; r:=4
                CASE 5 ; r:=4
                CASE 6 ; r:=4
            ENDSELECT
        CASE 85
            SELECT row
                CASE 0 ; r:=17
                CASE 1 ; r:=17
                CASE 2 ; r:=17
                CASE 3 ; r:=17
                CASE 4 ; r:=17
                CASE 5 ; r:=17
                CASE 6 ; r:=14
            ENDSELECT
        CASE 86
            SELECT row
                CASE 0 ; r:=17
                CASE 1 ; r:=17
                CASE 2 ; r:=17
                CASE 3 ; r:=17
                CASE 4 ; r:=17
                CASE 5 ; r:=10
                CASE 6 ; r:=4
            ENDSELECT
        CASE 87
            SELECT row
                CASE 0 ; r:=17
                CASE 1 ; r:=17
                CASE 2 ; r:=17
                CASE 3 ; r:=21
                CASE 4 ; r:=21
                CASE 5 ; r:=21
                CASE 6 ; r:=10
            ENDSELECT
        CASE 88
            SELECT row
                CASE 0 ; r:=17
                CASE 1 ; r:=17
                CASE 2 ; r:=10
                CASE 3 ; r:=4
                CASE 4 ; r:=10
                CASE 5 ; r:=17
                CASE 6 ; r:=17
            ENDSELECT
        CASE 89
            SELECT row
                CASE 0 ; r:=17
                CASE 1 ; r:=17
                CASE 2 ; r:=10
                CASE 3 ; r:=4
                CASE 4 ; r:=4
                CASE 5 ; r:=4
                CASE 6 ; r:=4
            ENDSELECT
        CASE 90
            SELECT row
                CASE 0 ; r:=31
                CASE 1 ; r:=1
                CASE 2 ; r:=2
                CASE 3 ; r:=4
                CASE 4 ; r:=8
                CASE 5 ; r:=16
                CASE 6 ; r:=31
            ENDSELECT
    ENDSELECT
ENDPROC r

PROC uword(v)
    IF v<0 THEN v:=v+65536
ENDPROC v

PROC amiga_font_char_width(ch)
    DEF idx,w

    IF g_font=NIL THEN RETURN 0
    IF (ch<g_font.lochar) OR (ch>g_font.hichar) THEN RETURN g_font.xsize

    idx:=(ch-g_font.lochar)*2
    w:=uword(g_font.charloc[idx+1])
    IF w<=0 THEN w:=g_font.xsize
ENDPROC w

PROC amiga_font_char_advance(ch)
    DEF w

    IF g_font=NIL THEN RETURN 0
    IF (ch>=g_font.lochar) AND (ch<=g_font.hichar)
        IF g_font.charspace
            w:=uword(g_font.charspace[ch-g_font.lochar])
        ELSE
            w:=amiga_font_char_width(ch)
        ENDIF
    ELSE
        w:=g_font.xsize
    ENDIF
ENDPROC w

PROC amiga_font_pixel(ch,row,col)
    DEF idx,bitoff,w,absbit,bytepos,bitmask,b

    IF g_font=NIL THEN RETURN FALSE
    IF (ch<g_font.lochar) OR (ch>g_font.hichar) THEN RETURN FALSE

    idx:=(ch-g_font.lochar)*2
    bitoff:=uword(g_font.charloc[idx])
    w:=uword(g_font.charloc[idx+1])
    IF (col<0) OR (col>=w) THEN RETURN FALSE

    absbit:=bitoff+col
    bytepos:=(row*g_font.modulo)+(absbit/8)
    bitmask:=Shl(1,7-(absbit AND 7))
    b:=g_font.chardata[bytepos] AND 255
ENDPROC (b AND bitmask)<>0

PROC open_amiga_font(fontname:PTR TO CHAR, fontsize)
    IF g_font
        CloseFont(g_font)
        g_font:=NIL
    ENDIF

    IF fontname=NIL THEN RETURN FALSE
    IF fontname[]=0 THEN RETURN FALSE
    IF fontsize<=0 THEN fontsize:=9

    g_font:=OpenDiskFont([fontname, fontsize, 0, 0]:textattr)
ENDPROC g_font<>NIL

PROC close_amiga_font()
    IF g_font
        CloseFont(g_font)
        g_font:=NIL
    ENDIF
ENDPROC

PROC openLibraries()
    IF (mathbase:=OpenLibrary('mathffp.library',34))=NIL THEN RETURN FALSE
    IF (mathtransbase:=OpenLibrary('mathtrans.library',34))=NIL THEN RETURN FALSE
    IF (mathieeesingbasbase:=OpenLibrary('mathieeesingbas.library',34))=NIL THEN RETURN FALSE
    IF (mathieeesingtransbase:=OpenLibrary('mathieeesingtrans.library',34))=NIL THEN RETURN FALSE
    IF (diskfontbase:=OpenLibrary('diskfont.library',37))=NIL THEN RETURN FALSE
ENDPROC TRUE

PROC closeLibraries()
    close_amiga_font()
    IF diskfontbase THEN CloseLibrary(diskfontbase)
    IF mathieeesingtransbase THEN CloseLibrary(mathieeesingtransbase)
    IF mathieeesingbasbase THEN CloseLibrary(mathieeesingbasbase)
    IF mathtransbase THEN CloseLibrary(mathtransbase)
    IF mathbase THEN CloseLibrary(mathbase)
ENDPROC

PROC writeSTLFloat(f)
    DEF a,i,d

    IF IeeeSPCmp(f,0.0)<0
        WriteF('-')
        a:=IeeeSPAbs(f)
    ELSE
        a:=f
    ENDIF

    i:=IeeeSPFix(a)
    d:=IeeeSPFix(IeeeSPMul(IeeeSPSub(a,IeeeSPFlt(i)),10000.0))
    WriteF('\d.\z\d[4]',i,d)
ENDPROC

PROC writeVertex(x,y,z)
    WriteF('      vertex ')
    writeSTLFloat(x)
    WriteF(' ')
    writeSTLFloat(y)
    WriteF(' ')
    writeSTLFloat(z)
    WriteF('\n')
ENDPROC

PROC writeFacet(nx,ny,nz, ax,ay,az, bx,by,bz, cx,cy,cz)
    WriteF('  facet normal ')
    writeSTLFloat(nx)
    WriteF(' ')
    writeSTLFloat(ny)
    WriteF(' ')
    writeSTLFloat(nz)
    WriteF('\n')
    WriteF('    outer loop\n')
    writeVertex(ax,ay,az)
    writeVertex(bx,by,bz)
    writeVertex(cx,cy,cz)
    WriteF('    endloop\n')
    WriteF('  endfacet\n')
ENDPROC

PROC writeBox(x1,y1,z1,x2,y2,z2)
    writeFacet(0.0,0.0,-1.0, x1,y2,z1, x2,y2,z1, x2,y1,z1)
    writeFacet(0.0,0.0,-1.0, x1,y2,z1, x2,y1,z1, x1,y1,z1)
    writeFacet(0.0,0.0,1.0, x1,y1,z2, x2,y1,z2, x2,y2,z2)
    writeFacet(0.0,0.0,1.0, x1,y1,z2, x2,y2,z2, x1,y2,z2)
    writeFacet(0.0,-1.0,0.0, x1,y1,z1, x2,y1,z1, x2,y1,z2)
    writeFacet(0.0,-1.0,0.0, x1,y1,z1, x2,y1,z2, x1,y1,z2)
    writeFacet(0.0,1.0,0.0, x2,y2,z1, x1,y2,z1, x1,y2,z2)
    writeFacet(0.0,1.0,0.0, x2,y2,z1, x1,y2,z2, x2,y2,z2)
    writeFacet(-1.0,0.0,0.0, x1,y2,z1, x1,y1,z1, x1,y1,z2)
    writeFacet(-1.0,0.0,0.0, x1,y2,z1, x1,y1,z2, x1,y2,z2)
    writeFacet(1.0,0.0,0.0, x2,y1,z1, x2,y2,z1, x2,y2,z2)
    writeFacet(1.0,0.0,0.0, x2,y1,z1, x2,y2,z2, x2,y1,z2)
    g_boxes++
ENDPROC

PROC roundedPoint(index,w,d,r)
    DEF c1,c2,c3

    c1:=0.3827
    c2:=0.7071
    c3:=0.9239

    SELECT index
        CASE 0
            g_point_x:=r
            g_point_y:=0.0
        CASE 1
            g_point_x:=IeeeSPSub(w,r)
            g_point_y:=0.0
        CASE 2
            g_point_x:=IeeeSPAdd(IeeeSPSub(w,r),IeeeSPMul(r,c1))
            g_point_y:=IeeeSPSub(r,IeeeSPMul(r,c3))
        CASE 3
            g_point_x:=IeeeSPAdd(IeeeSPSub(w,r),IeeeSPMul(r,c2))
            g_point_y:=IeeeSPSub(r,IeeeSPMul(r,c2))
        CASE 4
            g_point_x:=IeeeSPAdd(IeeeSPSub(w,r),IeeeSPMul(r,c3))
            g_point_y:=IeeeSPSub(r,IeeeSPMul(r,c1))
        CASE 5
            g_point_x:=w
            g_point_y:=r
        CASE 6
            g_point_x:=w
            g_point_y:=IeeeSPSub(d,r)
        CASE 7
            g_point_x:=IeeeSPAdd(IeeeSPSub(w,r),IeeeSPMul(r,c3))
            g_point_y:=IeeeSPAdd(IeeeSPSub(d,r),IeeeSPMul(r,c1))
        CASE 8
            g_point_x:=IeeeSPAdd(IeeeSPSub(w,r),IeeeSPMul(r,c2))
            g_point_y:=IeeeSPAdd(IeeeSPSub(d,r),IeeeSPMul(r,c2))
        CASE 9
            g_point_x:=IeeeSPAdd(IeeeSPSub(w,r),IeeeSPMul(r,c1))
            g_point_y:=IeeeSPAdd(IeeeSPSub(d,r),IeeeSPMul(r,c3))
        CASE 10
            g_point_x:=IeeeSPSub(w,r)
            g_point_y:=d
        CASE 11
            g_point_x:=r
            g_point_y:=d
        CASE 12
            g_point_x:=IeeeSPSub(r,IeeeSPMul(r,c1))
            g_point_y:=IeeeSPAdd(IeeeSPSub(d,r),IeeeSPMul(r,c3))
        CASE 13
            g_point_x:=IeeeSPSub(r,IeeeSPMul(r,c2))
            g_point_y:=IeeeSPAdd(IeeeSPSub(d,r),IeeeSPMul(r,c2))
        CASE 14
            g_point_x:=IeeeSPSub(r,IeeeSPMul(r,c3))
            g_point_y:=IeeeSPAdd(IeeeSPSub(d,r),IeeeSPMul(r,c1))
        CASE 15
            g_point_x:=0.0
            g_point_y:=IeeeSPSub(d,r)
        CASE 16
            g_point_x:=0.0
            g_point_y:=r
        CASE 17
            g_point_x:=IeeeSPSub(r,IeeeSPMul(r,c3))
            g_point_y:=IeeeSPSub(r,IeeeSPMul(r,c1))
        CASE 18
            g_point_x:=IeeeSPSub(r,IeeeSPMul(r,c2))
            g_point_y:=IeeeSPSub(r,IeeeSPMul(r,c2))
        CASE 19
            g_point_x:=IeeeSPSub(r,IeeeSPMul(r,c1))
            g_point_y:=IeeeSPSub(r,IeeeSPMul(r,c3))
    ENDSELECT
ENDPROC

PROC writeRoundedBase(w,d,z,r)
    DEF maxr,cx,cy,i
    DEF x,y
    DEF opx,opy,ox,oy

    maxr:=IeeeSPDiv(w,2.0)
    IF IeeeSPCmp(IeeeSPDiv(d,2.0),maxr)<0 THEN maxr:=IeeeSPDiv(d,2.0)
    IF IeeeSPCmp(r,maxr)>0 THEN r:=maxr

    cx:=IeeeSPDiv(w,2.0)
    cy:=IeeeSPDiv(d,2.0)

    IF IeeeSPCmp(r,0.0)<=0
        writeBox(IeeeSPNeg(cx),IeeeSPNeg(cy),0.0,cx,cy,z)
        RETURN
    ENDIF

    roundedPoint(19,w,d,r)
    opx:=IeeeSPSub(g_point_x,cx)
    opy:=IeeeSPSub(g_point_y,cy)

    FOR i:=0 TO 19
        roundedPoint(i,w,d,r)
        x:=g_point_x
        y:=g_point_y
        ox:=IeeeSPSub(x,cx)
        oy:=IeeeSPSub(y,cy)

        writeFacet(0.0,0.0,-1.0, 0.0,0.0,0.0, ox,oy,0.0, opx,opy,0.0)
        writeFacet(0.0,0.0,1.0, 0.0,0.0,z, opx,opy,z, ox,oy,z)
        writeFacet(0.0,0.0,0.0, opx,opy,0.0, ox,oy,0.0, ox,oy,z)
        writeFacet(0.0,0.0,0.0, opx,opy,0.0, ox,oy,z, opx,opy,z)

        opx:=ox
        opy:=oy
    ENDFOR

    g_boxes++
ENDPROC

PROC string2Float(s)
    DEF entier[80]:STRING,decimal[80]:STRING
    DEF pos,len,i,p,ei,di,res

    IF s=NIL THEN RETURN 1.0
    len:=EstrLen(s)
    IF len=0 THEN RETURN 1.0

    pos:=InStr(s,'.',0)
    IF pos=-1 THEN pos:=InStr(s,',',0)
    IF pos=-1 THEN RETURN IeeeSPFlt(Val(s,NIL))

    MidStr(entier,s,0,pos)
    MidStr(decimal,s,pos+1,ALL)

    ei:=Val(entier,NIL)
    di:=Val(decimal,NIL)

    p:=1
    FOR i:=1 TO EstrLen(decimal)
        p:=p*10
    ENDFOR

    res:=IeeeSPAdd(IeeeSPFlt(ei),IeeeSPDiv(IeeeSPFlt(di),IeeeSPFlt(p)))
ENDPROC res

PROC is_line_break(ch)
ENDPROC (ch=124) OR (ch=10) OR (ch=13)

PROC calc_pixel_metrics(text:PTR TO CHAR)
    DEF linew=0,maxw=0,lines=1,ch,w

    WHILE text[]
        ch:=text[] AND 255
        IF is_line_break(ch)
            IF linew>0
                w:=linew-1
            ELSE
                w:=0
            ENDIF
            IF w>maxw THEN maxw:=w
            lines++
            linew:=0
        ELSE
            linew:=linew+6
        ENDIF
        text++
    ENDWHILE

    IF linew>0
        w:=linew-1
    ELSE
        w:=0
    ENDIF
    IF w>maxw THEN maxw:=w

    g_metric_w:=maxw
    g_metric_lines:=lines
    g_metric_h:=(lines*7)+(lines-1)
ENDPROC

PROC calc_amiga_font_metrics(text:PTR TO CHAR)
    DEF linew=0,maxw=0,lines=1,ch

    WHILE text[]
        ch:=text[] AND 255
        IF is_line_break(ch)
            IF linew>maxw THEN maxw:=linew
            lines++
            linew:=0
        ELSE
            linew:=linew+amiga_font_char_advance(ch)
        ENDIF
        text++
    ENDWHILE

    IF linew>maxw THEN maxw:=linew

    g_metric_w:=maxw
    g_metric_lines:=lines
    g_metric_h:=(lines*g_font.ysize)+(lines-1)
ENDPROC

PROC pixel_line_width_at(text:PTR TO CHAR,start)
    DEF i,count=0,ch,w

    i:=start

    WHILE text[i]
        ch:=text[i] AND 255
        IF is_line_break(ch)
            IF count>0
                w:=(count*6)-1
            ELSE
                w:=0
            ENDIF
            RETURN w
        ENDIF
        count++
        i++
    ENDWHILE

    IF count>0
        w:=(count*6)-1
    ELSE
        w:=0
    ENDIF
ENDPROC w

PROC amiga_line_width_at(text:PTR TO CHAR,start)
    DEF i,w=0,ch

    i:=start

    WHILE text[i]
        ch:=text[i] AND 255
        IF is_line_break(ch) THEN RETURN w
        w:=w+amiga_font_char_advance(ch)
        i++
    ENDWHILE
ENDPROC w

PROC generate_text_stl(text:PTR TO CHAR,dest:PTR TO CHAR,cell,margin,basez,textz,radius)
    DEF h=NIL,oldout,ret=FALSE
    DEF len,charpos,row,col,rowbits,bit,runstart,line,penx,ch,linew,lineoff
    DEF x1,y1,x2,y2,z1,z2
    DEF platex,platey,offx,offy,msg[256]:STRING

    len:=EstrLen(text)
    IF len<=0
        set_status('Status: empty text.')
        RETURN FALSE
    ENDIF

    calc_pixel_metrics(text)
    IF g_metric_w<=0
        set_status('Status: text width is zero.')
        RETURN FALSE
    ENDIF

    g_boxes:=0

    platex:=IeeeSPAdd(IeeeSPMul(IeeeSPFlt(g_metric_w),cell),IeeeSPMul(margin,2.0))
    platey:=IeeeSPAdd(IeeeSPMul(IeeeSPFlt(g_metric_h),cell),IeeeSPMul(margin,2.0))
    offx:=IeeeSPDiv(platex,2.0)
    offy:=IeeeSPDiv(platey,2.0)

    IF h:=Open(dest,NEWFILE)
        oldout:=stdout
        stdout:=h

        WriteF('solid text2stlmui\n')
        writeRoundedBase(platex,platey,basez,radius)

        z1:=basez
        z2:=IeeeSPAdd(basez,textz)
        line:=0
        penx:=0
        linew:=pixel_line_width_at(text,0)
        lineoff:=IeeeSPDiv(IeeeSPFlt(g_metric_w-linew),2.0)

        FOR charpos:=0 TO len-1
            ch:=text[charpos] AND 255
            IF is_line_break(ch)
                line++
                penx:=0
                linew:=pixel_line_width_at(text,charpos+1)
                lineoff:=IeeeSPDiv(IeeeSPFlt(g_metric_w-linew),2.0)
            ELSE
            FOR row:=0 TO 6
                rowbits:=font_row(ch,row)
                runstart:=-1
                FOR col:=0 TO 5
                    IF col<5
                        bit:=bit_for_col(col)
                    ELSE
                        bit:=0
                    ENDIF

                    IF (bit<>0) AND (rowbits AND bit)
                        IF runstart=-1 THEN runstart:=col
                    ELSE
                        IF runstart<>-1
                            x1:=IeeeSPSub(IeeeSPAdd(margin,IeeeSPMul(IeeeSPAdd(IeeeSPFlt(penx+runstart),lineoff),cell)),offx)
                            x2:=IeeeSPSub(IeeeSPAdd(margin,IeeeSPMul(IeeeSPAdd(IeeeSPFlt(penx+col),lineoff),cell)),offx)
                            y1:=IeeeSPSub(IeeeSPAdd(margin,IeeeSPMul(IeeeSPFlt((g_metric_h-1)-((line*8)+row)),cell)),offy)
                            y2:=IeeeSPAdd(y1,cell)
                            writeBox(x1,y1,z1,x2,y2,z2)
                            runstart:=-1
                        ENDIF
                    ENDIF
                ENDFOR
            ENDFOR
            penx:=penx+6
            ENDIF
        ENDFOR

        WriteF('endsolid text2stlmui\n')

        stdout:=oldout
        Close(h)
        ret:=TRUE
    ELSE
        StringF(msg,'Status: cannot open output file: \s',dest)
        set_status(msg)
    ENDIF

    IF ret
        StringF(msg,'Status: STL saved. Lines \d, parts \d.',g_metric_lines,g_boxes)
        set_status(msg)
    ENDIF
ENDPROC ret

PROC generate_amiga_font_stl(text:PTR TO CHAR,dest:PTR TO CHAR,fontname:PTR TO CHAR,fontsize,cell,margin,basez,textz,radius)
    DEF h=NIL,oldout,ret=FALSE
    DEF len,charpos,row,col,cw,advance,penx,runstart,line,line_step,linew,lineoff
    DEF x1,y1,x2,y2,z1,z2
    DEF platex,platey,offx,offy,msg[256]:STRING
    DEF ch

    len:=EstrLen(text)
    IF len<=0
        set_status('Status: empty text.')
        RETURN FALSE
    ENDIF

    IF open_amiga_font(fontname,fontsize)=FALSE
        set_status('Status: cannot open Amiga font.')
        RETURN FALSE
    ENDIF

    calc_amiga_font_metrics(text)
    IF g_metric_w<=0
        close_amiga_font()
        set_status('Status: empty font text.')
        RETURN FALSE
    ENDIF

    g_boxes:=0

    platex:=IeeeSPAdd(IeeeSPMul(IeeeSPFlt(g_metric_w),cell),IeeeSPMul(margin,2.0))
    platey:=IeeeSPAdd(IeeeSPMul(IeeeSPFlt(g_metric_h),cell),IeeeSPMul(margin,2.0))
    offx:=IeeeSPDiv(platex,2.0)
    offy:=IeeeSPDiv(platey,2.0)

    IF h:=Open(dest,NEWFILE)
        oldout:=stdout
        stdout:=h

        WriteF('solid text2stlmui_amigafont\n')
        writeRoundedBase(platex,platey,basez,radius)

        z1:=basez
        z2:=IeeeSPAdd(basez,textz)
        line:=0
        line_step:=g_font.ysize+1
        penx:=0
        linew:=amiga_line_width_at(text,0)
        lineoff:=IeeeSPDiv(IeeeSPFlt(g_metric_w-linew),2.0)

        FOR charpos:=0 TO len-1
            ch:=text[charpos] AND 255
            IF is_line_break(ch)
                line++
                penx:=0
                linew:=amiga_line_width_at(text,charpos+1)
                lineoff:=IeeeSPDiv(IeeeSPFlt(g_metric_w-linew),2.0)
            ELSE
            cw:=amiga_font_char_width(ch)
            advance:=amiga_font_char_advance(ch)

            FOR row:=0 TO g_font.ysize-1
                runstart:=-1
                FOR col:=0 TO cw
                    IF (col<cw) AND amiga_font_pixel(ch,row,col)
                        IF runstart=-1 THEN runstart:=col
                    ELSE
                        IF runstart<>-1
                            x1:=IeeeSPSub(IeeeSPAdd(margin,IeeeSPMul(IeeeSPAdd(IeeeSPFlt(penx+runstart),lineoff),cell)),offx)
                            x2:=IeeeSPSub(IeeeSPAdd(margin,IeeeSPMul(IeeeSPAdd(IeeeSPFlt(penx+col),lineoff),cell)),offx)
                            y1:=IeeeSPSub(IeeeSPAdd(margin,IeeeSPMul(IeeeSPFlt((g_metric_h-1)-((line*line_step)+row)),cell)),offy)
                            y2:=IeeeSPAdd(y1,cell)
                            writeBox(x1,y1,z1,x2,y2,z2)
                            runstart:=-1
                        ENDIF
                    ENDIF
                ENDFOR
            ENDFOR

            penx:=penx+advance
            ENDIF
        ENDFOR

        WriteF('endsolid text2stlmui_amigafont\n')

        stdout:=oldout
        Close(h)
        ret:=TRUE
    ELSE
        StringF(msg,'Status: cannot open output file: \s',dest)
        set_status(msg)
    ENDIF

    close_amiga_font()

    IF ret
        StringF(msg,'Status: Amiga font STL saved. Lines \d, parts \d.',g_metric_lines,g_boxes)
        set_status(msg)
    ENDIF
ENDPROC ret

PROC generate_from_gui()
    DEF l1ptr,l2ptr,l3ptr,destptr,cellptr,marginptr,baseptr,heightptr,radiusptr
    DEF sizeptr,modeactive=0,fontactive=0,caseactive=0
    DEF text[128]:STRING,dest[256]:STRING,fontname[128]:STRING
    DEF line1[128]:STRING,line2[128]:STRING,line3[128]:STRING
    DEF cell,margin,basez,textz,radius,fontsize,use_amiga_font=FALSE

    get(st_line1, MUIA_String_Contents, {l1ptr})
    get(st_line2, MUIA_String_Contents, {l2ptr})
    get(st_line3, MUIA_String_Contents, {l3ptr})
    get(st_dest, MUIA_String_Contents, {destptr})
    get(cy_case, MUIA_Cycle_Active, {caseactive})
    get(cy_mode, MUIA_Cycle_Active, {modeactive})
    get(cy_font, MUIA_Cycle_Active, {fontactive})
    get(st_fontsize, MUIA_String_Contents, {sizeptr})
    get(st_cell, MUIA_String_Contents, {cellptr})
    get(st_margin, MUIA_String_Contents, {marginptr})
    get(st_base, MUIA_String_Contents, {baseptr})
    get(st_height, MUIA_String_Contents, {heightptr})
    get(st_radius, MUIA_String_Contents, {radiusptr})

    line1[0]:=0
    line2[0]:=0
    line3[0]:=0
    IF l1ptr THEN StrCopy(line1,l1ptr,ALL)
    IF l2ptr THEN StrCopy(line2,l2ptr,ALL)
    IF l3ptr THEN StrCopy(line3,l3ptr,ALL)

    build_text_from_lines(text,line1,line2,line3)
    IF EstrLen(text)<=0
        set_status('Status: enter text.')
        RETURN
    ENDIF
    apply_text_case(text,caseactive)

    IF destptr=NIL
        make_stl_name_from_text(text,dest)
    ELSE
        IF (destptr[]=0) OR same_text(destptr,'RAM:text.stl')
            make_stl_name_from_text(text,dest)
        ELSE
            StrCopy(dest,destptr,ALL)
        ENDIF
    ENDIF
    force_stl_extension(dest)
    set(st_dest, MUIA_String_Contents, dest)

    cell:=string2Float(cellptr)
    margin:=string2Float(marginptr)
    basez:=string2Float(baseptr)
    textz:=string2Float(heightptr)
    radius:=string2Float(radiusptr)
    IF sizeptr=NIL
        fontsize:=9
    ELSE
        fontsize:=Val(sizeptr,NIL)
    ENDIF
    IF fontsize<=0 THEN fontsize:=9

    font_name_from_active(fontactive,fontname)
    IF modeactive=1 THEN use_amiga_font:=TRUE

    IF (IeeeSPCmp(cell,0.0)<=0) OR (IeeeSPCmp(margin,0.0)<0) OR (IeeeSPCmp(basez,0.0)<=0) OR (IeeeSPCmp(textz,0.0)<=0) OR (IeeeSPCmp(radius,0.0)<0)
        set_status('Status: bad dimensions.')
        RETURN
    ENDIF

    set_status('Status: generating STL...')

    IF use_amiga_font
        generate_amiga_font_stl(text,dest,fontname,fontsize,cell,margin,basez,textz,radius)
    ELSE
        generate_text_stl(text,dest,cell,margin,basez,textz,radius)
    ENDIF
ENDPROC

PROC main() HANDLE
    DEF signal,result,running

    IF (muimasterbase:=OpenLibrary(MUIMASTER_NAME,MUIMASTER_VMIN))=NIL THEN Raise(1)
    IF openLibraries()=FALSE THEN Raise(2)

    g_mode_entries:=['PIXEL','AMIGA',NIL]
    g_font_entries:=['topaz.font','opal.font','diamond.font',NIL]
    g_case_entries:=['KEEP','UPPER','LOWER',NIL]

    ap_app := ApplicationObject,
        MUIA_Application_Title, 'Text2STLMUI',
        MUIA_Application_Version, '1.0',
        MUIA_Application_Author, 'Denis Costils',
        MUIA_Application_Description, 'Bitmap and Amiga font text to STL',
        MUIA_Application_Base, 'T2SL',

        SubWindow,
            wi_main := WindowObject,
                MUIA_Window_Title, 'Text2STL MUI',
                MUIA_Window_ID, "T2SL",
                MUIA_Width, 520,
                MUIA_Height, 315,
                WindowContents, VGroup,

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        MUIA_FrameTitle, 'Text STL',
                        MUIA_Group_Columns, 2,
                        Child, TextObject, MUIA_Text_Contents, 'Line 1', End,
                        Child, st_line1 := StringObject,
                            StringFrame,
                            MUIA_String_Contents, 'Pour que',
                            MUIA_String_MaxLen, 127,
                            MUIA_CycleChain, TRUE,
                        End,
                        Child, TextObject, MUIA_Text_Contents, 'Line 2', End,
                        Child, st_line2 := StringObject,
                            StringFrame,
                            MUIA_String_Contents, 'l''Amiga vive',
                            MUIA_String_MaxLen, 127,
                            MUIA_CycleChain, TRUE,
                        End,
                        Child, TextObject, MUIA_Text_Contents, 'Line 3', End,
                        Child, st_line3 := StringObject,
                            StringFrame,
                            MUIA_String_Contents, 'toujours',
                            MUIA_String_MaxLen, 127,
                            MUIA_CycleChain, TRUE,
                        End,
                        Child, TextObject, MUIA_Text_Contents, 'Text case', End,
                        Child, cy_case := CycleObject,
                            MUIA_Cycle_Entries, g_case_entries,
                            MUIA_CycleChain, TRUE,
                        End,
                        Child, TextObject, MUIA_Text_Contents, 'Mode', End,
                        Child, cy_mode := CycleObject,
                            MUIA_Cycle_Entries, g_mode_entries,
                            MUIA_CycleChain, TRUE,
                        End,
                        Child, TextObject, MUIA_Text_Contents, 'AMIGA font only', End,
                        Child, cy_font := CycleObject,
                            MUIA_Cycle_Entries, g_font_entries,
                            MUIA_CycleChain, TRUE,
                        End,
                        Child, TextObject, MUIA_Text_Contents, 'AMIGA size only', End,
                        Child, st_fontsize := StringObject,
                            StringFrame,
                            MUIA_String_Contents, '9',
                            MUIA_String_MaxLen, 15,
                            MUIA_CycleChain, TRUE,
                        End,
                        Child, TextObject, MUIA_Text_Contents, 'STL file', End,
                        Child, PopaslObject,
                            MUIA_Popasl_Type, 0,
                            MUIA_Popstring_String, st_dest := StringObject,
                                StringFrame,
                                MUIA_String_Contents, 'RAM:text.stl',
                                MUIA_String_MaxLen, 255,
                                MUIA_CycleChain, TRUE,
                            End,
                            MUIA_Popstring_Button, PopButton(MUII_PopFile),
                        End,
                        Child, TextObject, MUIA_Text_Contents, 'Pixel mm', End,
                        Child, st_cell := StringObject,
                            StringFrame,
                            MUIA_String_Contents, '1.8',
                            MUIA_String_MaxLen, 31,
                            MUIA_CycleChain, TRUE,
                        End,
                        Child, TextObject, MUIA_Text_Contents, 'Margin mm', End,
                        Child, st_margin := StringObject,
                            StringFrame,
                            MUIA_String_Contents, '3.0',
                            MUIA_String_MaxLen, 31,
                            MUIA_CycleChain, TRUE,
                        End,
                        Child, TextObject, MUIA_Text_Contents, 'Base mm', End,
                        Child, st_base := StringObject,
                            StringFrame,
                            MUIA_String_Contents, '1.6',
                            MUIA_String_MaxLen, 31,
                            MUIA_CycleChain, TRUE,
                        End,
                        Child, TextObject, MUIA_Text_Contents, 'Corner mm', End,
                        Child, st_radius := StringObject,
                            StringFrame,
                            MUIA_String_Contents, '3.0',
                            MUIA_String_MaxLen, 31,
                            MUIA_CycleChain, TRUE,
                        End,
                        Child, TextObject, MUIA_Text_Contents, 'Text height mm', End,
                        Child, st_height := StringObject,
                            StringFrame,
                            MUIA_String_Contents, '0.8',
                            MUIA_String_MaxLen, 31,
                            MUIA_CycleChain, TRUE,
                        End,
                    End,

                    Child, HGroup,
                        Child, bt_generate := bouton('Generate STL'),
                        Child, bt_clear := bouton('Clear'),
                        Child, bt_quit := bouton('Quit'),
                    End,

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        Child, tx_status := TextObject,
                            MUIA_Text_Contents, 'Status: ready. Font fields are used only in AMIGA mode.',
                        End,
                    End,
                End,
            End,
        End

    IF ap_app=NIL THEN Raise(3)

    doMethod(wi_main, [MUIM_Notify, MUIA_Window_CloseRequest, MUI_TRUE, ap_app, 2, MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])
    doMethod(bt_generate, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_GENERATE])
    doMethod(bt_clear, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_CLEAR])
    doMethod(bt_quit, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])

    set(wi_main, MUIA_Window_Open, MUI_TRUE)

    running:=TRUE
    WHILE running
        result:=doMethod(ap_app, [MUIM_Application_Input, {signal}])
        IF result<>MUIV_Application_ReturnID_Quit
            SELECT result
                CASE ID_GENERATE
                    generate_from_gui()
                CASE ID_CLEAR
                    set(st_line1, MUIA_String_Contents, 'Pour que')
                    set(st_line2, MUIA_String_Contents, 'l''Amiga vive')
                    set(st_line3, MUIA_String_Contents, 'toujours')
                    set(cy_case, MUIA_Cycle_Active, 0)
                    set(cy_mode, MUIA_Cycle_Active, 0)
                    set(cy_font, MUIA_Cycle_Active, 0)
                    set(st_fontsize, MUIA_String_Contents, '9')
                    set(st_dest, MUIA_String_Contents, 'RAM:text.stl')
                    set(st_cell, MUIA_String_Contents, '1.8')
                    set(st_margin, MUIA_String_Contents, '3.0')
                    set(st_base, MUIA_String_Contents, '1.6')
                    set(st_radius, MUIA_String_Contents, '3.0')
                    set(st_height, MUIA_String_Contents, '0.8')
                    set_status('Status: ready.')
            ENDSELECT
        ELSE
            running:=FALSE
        ENDIF

        IF running
            IF signal<>0 THEN Wait(signal) ELSE Delay(10)
        ENDIF
    ENDWHILE

    set(wi_main, MUIA_Window_Open, FALSE)
    Mui_DisposeObject(ap_app)
    ap_app:=NIL
    closeLibraries()
    CloseLibrary(muimasterbase)
    muimasterbase:=NIL
    RETURN 0

EXCEPT
    IF ap_app THEN Mui_DisposeObject(ap_app)
    closeLibraries()
    IF muimasterbase THEN CloseLibrary(muimasterbase)
    SELECT exception
        CASE 1 ; WriteF('Cannot open muimaster.library.\n')
        CASE 2 ; WriteF('Cannot open math libraries.\n')
        CASE 3 ; WriteF('Cannot create MUI application.\n')
    ENDSELECT
ENDPROC

PROC doMethod(obj:PTR TO object, msg:PTR TO msg)
    DEF h:PTR TO hook, o:PTR TO object, dispatcher
    IF obj
        o := obj-SIZEOF object
        h := o.class
        dispatcher := h.entry
        MOVEA.L h, A0
        MOVEA.L msg, A1
        MOVEA.L obj, A2
        MOVEA.L dispatcher, A3
        JSR (A3)
        MOVE.L D0, o
        RETURN o
    ENDIF
    RETURN NIL
ENDPROC
