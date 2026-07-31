-> GCodeColorPause.e
-> AmigaE port of gcode_color_pause_inserter.py.
-> Inserts an OctoPrint pause block for filament/color change.
->
-> Usage:
->   GCodeColorPause source.gcode 7
->   GCodeColorPause source.gcode 7 DEST ram:test.gcode
->
-> The requested layer is the layer observed in OctoPrint.
-> The pause block is inserted 2 layers earlier, like the Python version.

OPT PREPROCESS
OPT LARGE

MODULE 'dos/dos'

CONST OBSERVED_LAYER_OFFSET=2
CONST MAX_LINE=2048

ENUM ER_NONE,ER_ARGS,ER_OPEN_IN,ER_OPEN_OUT,ER_NOT_FOUND,ER_WRITE

PROC main() HANDLE
    DEF args:PTR TO LONG,rdargs=NIL
    DEF source,destarg,layerarg
    DEF dest[256]:STRING
    DEF observed_layer,insert_layer

    args:=[0,0,0]:LONG

    IF rdargs:=ReadArgs('SOURCE/A,LAYER/A,DEST/K',args,NIL)
        source:=args[0]
        layerarg:=args[1]
        destarg:=args[2]
        observed_layer:=Val(layerarg,NIL)
        IF observed_layer<1 THEN Raise(ER_ARGS)

        IF destarg
            StrCopy(dest,destarg,ALL)
        ELSE
            make_output_name(source,dest,observed_layer)
        ENDIF

        insert_layer:=observed_layer-OBSERVED_LAYER_OFFSET
        IF insert_layer<0 THEN insert_layer:=0

        WriteF('GCodeColorPause\n')
        WriteF('Source: \s\n',source)
        WriteF('Dest  : \s\n',dest)
        WriteF('Layer observe demande: \d\n',observed_layer)
        WriteF('Insertion apres ;LAYER:\d\n',insert_layer)

        IF convert_file(source,dest,insert_layer,observed_layer)=FALSE THEN Raise(ER_NOT_FOUND)

        WriteF('Fichier cree: \s\n',dest)
    ELSE
        Raise(ER_ARGS)
    ENDIF

    Raise(ER_NONE)

EXCEPT DO
    SELECT exception
        CASE ER_ARGS
            WriteF('Usage: GCodeColorPause SOURCE LAYER DEST/K\n')
            WriteF('Example: GCodeColorPause work:cube.gcode 7\n')
            WriteF('Layer = layer observe dans OctoPrint.\n')
        CASE ER_OPEN_IN
            WriteF('Erreur: impossible d ouvrir le fichier source.\n')
        CASE ER_OPEN_OUT
            WriteF('Erreur: impossible de creer le fichier destination.\n')
        CASE ER_NOT_FOUND
            WriteF('Erreur: layer introuvable dans ce fichier G-code.\n')
        CASE ER_WRITE
            WriteF('Erreur: probleme pendant l ecriture.\n')
    ENDSELECT

    IF rdargs THEN FreeArgs(rdargs)
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

PROC convert_file(source,dest,insert_layer,observed_layer)
    DEF hin=NIL,hout=NIL
    DEF line[MAX_LINE]:ARRAY OF CHAR
    DEF len,done=FALSE,inserted=FALSE
    DEF layer,next_layer
    DEF prusa_layer=-1
    DEF insert_mode

    next_layer:=insert_layer+1

    insert_mode:=find_insert_mode(source,insert_layer,next_layer)
    IF insert_mode=0 THEN RETURN FALSE

    hin:=Open(source,MODE_OLDFILE)
    IF hin=NIL THEN Raise(ER_OPEN_IN)

    hout:=Open(dest,MODE_NEWFILE)
    IF hout=NIL
        Close(hin)
        Raise(ER_OPEN_OUT)
    ENDIF

    WHILE done=FALSE
        len:=read_line(hin,line,MAX_LINE)
        IF len<0
            done:=TRUE
        ELSE
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
                Raise(ER_WRITE)
            ENDIF

            IF inserted=FALSE
                IF (insert_mode=2) AND (layer=insert_layer)
                    write_pause_block(hout,insert_layer,observed_layer)
                    inserted:=TRUE
                ENDIF
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

    h:=Open(source,MODE_OLDFILE)
    IF h=NIL THEN Raise(ER_OPEN_IN)

    WHILE done=FALSE
        len:=read_line(h,line,MAX_LINE)
        IF len<0
            done:=TRUE
        ELSE
            IF is_layer_change(line)
                prusa_layer++
                layer:=prusa_layer
            ELSE
                layer:=get_layer_number(line)
            ENDIF
            IF layer=insert_layer THEN found_insert:=TRUE
            IF layer=next_layer THEN found_next:=TRUE
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
