-> GCodeColorPauseMUI.e
-> MUI frontend for GCodeColorPause.
-> Inserts an OctoPrint pause block for filament/color change.

OPT PREPROCESS
OPT LARGE
OPT OSVERSION=39

MODULE 'muimaster','libraries/mui'
MODULE 'utility/tagitem','utility/hooks'
MODULE 'intuition/classes','intuition/classusr'
MODULE 'dos/dos','libraries/asl'

CONST OBSERVED_LAYER_OFFSET=2
CONST MAX_LINE=2048
CONST PROGRESS_STEP=500

ENUM ID_INSERT=1,
     ID_CLEAR

DEF ap_app, wi_main
DEF st_source, st_dest, st_layer
DEF bt_insert, bt_clear, bt_quit
DEF tx_status
DEF g_scan_lines,g_copy_lines

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
    Delay(1)
ENDPROC

PROC make_output_name(source:PTR TO CHAR,dest:PTR TO CHAR,layer)
    DEF base[220]:STRING
    DEF i=0,lastdot=-1

    StrCopy(base,source,ALL)

    WHILE base[i]
        IF (base[i]=58) OR (base[i]=47)
            lastdot:=-1
        ELSEIF base[i]=46
            lastdot:=i
        ENDIF
        i++
    ENDWHILE

    IF lastdot<>-1 THEN base[lastdot]:=0
    StringF(dest,'\s_color_layer\d.gcode',base,layer)
ENDPROC

PROC insert_from_gui()
    DEF srcptr,dstptr,layerptr
    DEF source[256]:STRING,dest[256]:STRING,layer_text[32]:STRING
    DEF observed_layer,insert_layer,msg[256]:STRING

    get(st_source, MUIA_String_Contents, {srcptr})
    get(st_dest, MUIA_String_Contents, {dstptr})
    get(st_layer, MUIA_String_Contents, {layerptr})

    IF srcptr=NIL
        set_status('Status: choose a G-code source file.')
        RETURN
    ENDIF
    IF layerptr=NIL
        set_status('Status: enter INSERT_COLOR_LAYER.')
        RETURN
    ENDIF

    StrCopy(source,srcptr,ALL)
    IF dstptr THEN StrCopy(dest,dstptr,ALL) ELSE StrCopy(dest,'',ALL)
    StrCopy(layer_text,layerptr,ALL)

    IF StrLen(source)=0
        set_status('Status: choose a G-code source file.')
        RETURN
    ENDIF

    observed_layer:=Val(layer_text,NIL)
    IF observed_layer<1
        set_status('Status: insert layer must be 1 or more.')
        RETURN
    ENDIF

    IF StrLen(dest)=0
        make_output_name(source,dest,observed_layer)
        set(st_dest,MUIA_String_Contents,dest)
    ENDIF

    insert_layer:=observed_layer-OBSERVED_LAYER_OFFSET
    IF insert_layer<0 THEN insert_layer:=0

    StringF(msg,'Status: scan source... insert layer \d',observed_layer)
    set_status(msg)

    IF convert_file(source,dest,insert_layer,observed_layer)=FALSE
        set_status('Status: layer not found or conversion failed.')
        RETURN
    ENDIF

    StringF(msg,'Status: done. Lines copied \d. File saved.',g_copy_lines)
    set_status(msg)
ENDPROC

PROC convert_file(source,dest,insert_layer,observed_layer)
    DEF hin=NIL,hout=NIL
    DEF line[MAX_LINE]:ARRAY OF CHAR
    DEF len,done=FALSE,inserted=FALSE
    DEF layer,next_layer,insert_mode
    DEF prusa_layer=-1
    DEF progress_count=0
    DEF msg[256]:STRING

    g_scan_lines:=0
    g_copy_lines:=0
    next_layer:=insert_layer+1

    insert_mode:=find_insert_mode(source,insert_layer,next_layer)
    IF insert_mode=0 THEN RETURN FALSE

    hin:=Open(source,MODE_OLDFILE)
    IF hin=NIL THEN RETURN FALSE

    hout:=Open(dest,MODE_NEWFILE)
    IF hout=NIL
        Close(hin)
        RETURN FALSE
    ENDIF

    StringF(msg,'Status: copy... 0 lines')
    set_status(msg)

    WHILE done=FALSE
        len:=read_line(hin,line,MAX_LINE)
        IF len<0
            done:=TRUE
        ELSE
            g_copy_lines++
            IF is_layer_change(line)
                prusa_layer++
                layer:=prusa_layer
            ELSE
                layer:=get_layer_number(line)
            ENDIF

            IF inserted=FALSE
                IF (insert_mode=1) AND (layer=next_layer)
                    write_pause_block(hout,insert_layer,observed_layer)
                    inserted:=TRUE
                ENDIF
            ENDIF

            IF Write(hout,line,len)<>len
                Close(hout)
                Close(hin)
                RETURN FALSE
            ENDIF

            IF inserted=FALSE
                IF (insert_mode=2) AND (layer=insert_layer)
                    write_pause_block(hout,insert_layer,observed_layer)
                    inserted:=TRUE
                ENDIF
            ENDIF

            progress_count++
            IF progress_count>=PROGRESS_STEP
                progress_count:=0
                StringF(msg,'Status: copy... \d lines',g_copy_lines)
                set_status(msg)
            ENDIF
        ENDIF
    ENDWHILE

    Close(hout)
    Close(hin)
ENDPROC inserted

PROC find_insert_mode(source,insert_layer,next_layer)
    DEF h=NIL,line[MAX_LINE]:ARRAY OF CHAR
    DEF len,done=FALSE,layer
    DEF prusa_layer=-1
    DEF found_insert=FALSE,found_next=FALSE
    DEF progress_count=0
    DEF msg[256]:STRING

    h:=Open(source,MODE_OLDFILE)
    IF h=NIL THEN RETURN 0

    WHILE done=FALSE
        len:=read_line(h,line,MAX_LINE)
        IF len<0
            done:=TRUE
        ELSE
            g_scan_lines++
            IF is_layer_change(line)
                prusa_layer++
                layer:=prusa_layer
            ELSE
                layer:=get_layer_number(line)
            ENDIF
            IF layer=insert_layer THEN found_insert:=TRUE
            IF layer=next_layer THEN found_next:=TRUE

            progress_count++
            IF progress_count>=PROGRESS_STEP
                progress_count:=0
                StringF(msg,'Status: scan... \d lines',g_scan_lines)
                set_status(msg)
            ENDIF
        ENDIF
    ENDWHILE

    Close(h)

    IF found_next THEN RETURN 1
    IF found_insert THEN RETURN 2
ENDPROC 0

PROC read_line(h,line,maxlen)
    DEF c[2]:ARRAY OF CHAR
    DEF len=0,readlen

    WHILE len<(maxlen-1)
        readlen:=Read(h,c,1)
        IF readlen<=0
            IF len=0 THEN RETURN -1
            line[len]:=0
            RETURN len
        ENDIF

        line[len]:=c[0]
        len++

        IF c[0]=10
            line[len]:=0
            RETURN len
        ENDIF
    ENDWHILE

    line[len]:=0
ENDPROC len

PROC is_layer_change(line:PTR TO CHAR)
    DEF i=0

    WHILE (line[i]=32) OR (line[i]=9)
        i++
    ENDWHILE

    IF line[i]<>59 THEN RETURN FALSE
    i++

    WHILE (line[i]=32) OR (line[i]=9)
        i++
    ENDWHILE

    IF (line[i]<>76) AND (line[i]<>108) THEN RETURN FALSE
    i++
    IF (line[i]<>65) AND (line[i]<>97) THEN RETURN FALSE
    i++
    IF (line[i]<>89) AND (line[i]<>121) THEN RETURN FALSE
    i++
    IF (line[i]<>69) AND (line[i]<>101) THEN RETURN FALSE
    i++
    IF (line[i]<>82) AND (line[i]<>114) THEN RETURN FALSE
    i++
    IF line[i]<>95 THEN RETURN FALSE
    i++
    IF (line[i]<>67) AND (line[i]<>99) THEN RETURN FALSE
    i++
    IF (line[i]<>72) AND (line[i]<>104) THEN RETURN FALSE
    i++
    IF (line[i]<>65) AND (line[i]<>97) THEN RETURN FALSE
    i++
    IF (line[i]<>78) AND (line[i]<>110) THEN RETURN FALSE
    i++
    IF (line[i]<>71) AND (line[i]<>103) THEN RETURN FALSE
    i++
    IF (line[i]<>69) AND (line[i]<>101) THEN RETURN FALSE
ENDPROC TRUE

PROC get_layer_number(line:PTR TO CHAR)
    DEF i=0,n=0,sign=1,found=FALSE

    WHILE (line[i]=32) OR (line[i]=9)
        i++
    ENDWHILE

    IF line[i]<>59 THEN RETURN -999999
    i++

    WHILE (line[i]=32) OR (line[i]=9)
        i++
    ENDWHILE

    IF (line[i]<>76) AND (line[i]<>108) THEN RETURN -999999
    i++
    IF (line[i]<>65) AND (line[i]<>97) THEN RETURN -999999
    i++
    IF (line[i]<>89) AND (line[i]<>121) THEN RETURN -999999
    i++
    IF (line[i]<>69) AND (line[i]<>101) THEN RETURN -999999
    i++
    IF (line[i]<>82) AND (line[i]<>114) THEN RETURN -999999
    i++

    WHILE (line[i]=32) OR (line[i]=9)
        i++
    ENDWHILE

    IF line[i]<>58 THEN RETURN -999999
    i++

    WHILE (line[i]=32) OR (line[i]=9)
        i++
    ENDWHILE

    IF line[i]=45
        sign:=-1
        i++
    ENDIF

    WHILE (line[i]>=48) AND (line[i]<=57)
        n:=(n*10)+(line[i]-48)
        found:=TRUE
        i++
    ENDWHILE

    IF found=FALSE THEN RETURN -999999
ENDPROC n*sign

PROC write_pause_block(h,insert_layer,observed_layer)
    DEF oldout

    oldout:=stdout
    stdout:=h

    WriteF('; --- OCTOCOLORPAUSE START layer=\d observed=\d ---\n',insert_layer,observed_layer)
    WriteF('; Pause observee souhaitee au layer \d\n',observed_layer)
    WriteF('; Bloc insere apres ;LAYER:\d\n',insert_layer)
    WriteF('M400\n')
    WriteF('G91\n')
    WriteF('G1 Z8 F300\n')
    WriteF('G90\n')
    WriteF('G1 X5 Y5 F3000\n')
    WriteF('M300 S1000 P250\n')
    WriteF('M300 S1500 P250\n')
    WriteF('M300 S2000 P500\n')
    WriteF('M117 Changement filament\n')
    WriteF('@pause Changement filament\n')
    WriteF('; Reprise apres changement couleur: retrait anti-goutte\n')
    WriteF('M83\n')
    WriteF('G1 E-3 F300\n')
    WriteF('M82\n')
    WriteF('G90\n')
    WriteF('; --- OCTOCOLORPAUSE END ---\n')

    stdout:=oldout
ENDPROC

PROC main() HANDLE
    DEF signal,result,running

    IF (muimasterbase:=OpenLibrary(MUIMASTER_NAME,MUIMASTER_VMIN))=NIL THEN Raise(1)

    ap_app := ApplicationObject,
        MUIA_Application_Title, 'GCodeColorPause',
        MUIA_Application_Version, '0.2',
        MUIA_Application_Author, 'Denis Costils',
        MUIA_Application_Description, 'Insert OctoPrint color pause in G-code',
        MUIA_Application_Base, 'GCPM',

        SubWindow,
            wi_main := WindowObject,
                MUIA_Window_Title, 'GCode Color Pause',
                MUIA_Window_ID, "GCPM",
                MUIA_Width, 520,
                MUIA_Height, 170,
                WindowContents, VGroup,

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        MUIA_FrameTitle, 'G-code',
                        MUIA_Group_Columns, 2,
                        Child, TextObject, MUIA_Text_Contents, 'Source', End,
                        Child, PopaslObject,
                            MUIA_Popasl_Type, 0,
                            MUIA_Popstring_String, st_source := StringObject,
                                StringFrame,
                                MUIA_String_Contents, '',
                                MUIA_String_MaxLen, 255,
                            End,
                            MUIA_Popstring_Button, PopButton(MUII_PopFile),
                        End,
                        Child, TextObject, MUIA_Text_Contents, 'Dest', End,
                        Child, PopaslObject,
                            MUIA_Popasl_Type, 0,
                            MUIA_Popstring_String, st_dest := StringObject,
                                StringFrame,
                                MUIA_String_Contents, '',
                                MUIA_String_MaxLen, 255,
                            End,
                            MUIA_Popstring_Button, PopButton(MUII_PopFile),
                        End,
                        Child, TextObject, MUIA_Text_Contents, 'Insert layer', End,
                        Child, st_layer := StringObject,
                            StringFrame,
                            MUIA_String_Contents, '7',
                            MUIA_String_MaxLen, 31,
                        End,
                    End,

                    Child, HGroup,
                        Child, bt_insert := bouton('Insert pause'),
                        Child, bt_clear := bouton('Clear'),
                        Child, bt_quit := bouton('Quit'),
                    End,

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        Child, tx_status := TextObject,
                            MUIA_Text_Contents, 'Status: ready.',
                        End,
                    End,
                End,
            End,
        End

    IF ap_app=NIL THEN Raise(2)

    doMethod(wi_main, [MUIM_Notify, MUIA_Window_CloseRequest, MUI_TRUE, ap_app, 2, MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])
    doMethod(bt_insert, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_INSERT])
    doMethod(bt_clear, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_CLEAR])
    doMethod(bt_quit, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])

    set(wi_main, MUIA_Window_Open, MUI_TRUE)

    running:=TRUE
    WHILE running
        result:=doMethod(ap_app, [MUIM_Application_Input, {signal}])
        IF result<>MUIV_Application_ReturnID_Quit
            SELECT result
                CASE ID_INSERT
                    insert_from_gui()
                CASE ID_CLEAR
                    set(st_source, MUIA_String_Contents, '')
                    set(st_dest, MUIA_String_Contents, '')
                    set(st_layer, MUIA_String_Contents, '7')
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
    CloseLibrary(muimasterbase)
    muimasterbase:=NIL
    RETURN 0

EXCEPT
    IF ap_app THEN Mui_DisposeObject(ap_app)
    IF muimasterbase THEN CloseLibrary(muimasterbase)
    SELECT exception
        CASE 1 ; WriteF('Cannot open muimaster.library.\n')
        CASE 2 ; WriteF('Cannot create MUI application.\n')
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
