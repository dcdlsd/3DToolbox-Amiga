-> ZSetupMUI.e
-> Petite interface MUI pour ZSetup.
-> Place ZSetup et ZSetupMUI dans le meme tiroir.

OPT PREPROCESS
OPT OSVERSION=39

MODULE 'muimaster','libraries/mui'
MODULE 'utility/tagitem','utility/hooks'
MODULE 'intuition/classes','intuition/classusr'
MODULE 'dos/dos'

#define Z_CFG 'S:zsetup.cfg'

ENUM ID_START=1,
     ID_DOWN,
     ID_UP,
     ID_SAVE,
     ID_SHOW,
     ID_SET

DEF ap_app, wi_main
DEF st_offset
DEF tx_current, tx_status
DEF bt_start, bt_down, bt_up, bt_save, bt_show, bt_set, bt_quit
DEF g_offset

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

PROC begins(texte:PTR TO CHAR, debut:PTR TO CHAR)
    WHILE debut[]
        IF texte[] <> debut[] THEN RETURN FALSE
        texte++
        debut++
    ENDWHILE
ENDPROC TRUE

PROC parse_offset(texte:PTR TO CHAR)
    DEF neg=FALSE, whole=0, frac=0, digits=0

    IF texte[] = 45
        neg := TRUE
        texte++
    ENDIF

    WHILE (texte[] >= 48) AND (texte[] <= 57)
        whole := (whole * 10) + (texte[] - 48)
        texte++
    ENDWHILE

    IF texte[] = 46
        texte++
        WHILE (texte[] >= 48) AND (texte[] <= 57) AND (digits < 2)
            frac := (frac * 10) + (texte[] - 48)
            digits++
            texte++
        ENDWHILE
        IF digits = 1 THEN frac := frac * 10
    ENDIF

    whole := (whole * 100) + frac
    IF neg THEN whole := -whole
ENDPROC whole

PROC format_offset(value, destination:PTR TO CHAR)
    DEF neg=FALSE, whole, frac

    IF value < 0
        neg := TRUE
        value := -value
    ENDIF
    whole := value / 100
    frac := value - (whole * 100)

    IF neg
        IF frac < 10
            StringF(destination, '-\d.0\d', whole, frac)
        ELSE
            StringF(destination, '-\d.\d', whole, frac)
        ENDIF
    ELSE
        IF frac < 10
            StringF(destination, '\d.0\d', whole, frac)
        ELSE
            StringF(destination, '\d.\d', whole, frac)
        ENDIF
    ENDIF
ENDPROC

PROC z_config_line(ligne:PTR TO CHAR)
    IF begins(ligne, 'OFFSET=')
        g_offset := Val(ligne + 7)
    ENDIF
ENDPROC

PROC load_z_config()
    DEF h, buffer[256]:STRING
    DEF len, i, start=0

    g_offset := 0
    IF (h := Open(Z_CFG, MODE_OLDFILE)) = NIL THEN RETURN FALSE
    len := Read(h, buffer, 255)
    Close(h)
    IF len <= 0 THEN RETURN FALSE
    buffer[len] := 0

    FOR i := 0 TO len
        IF (buffer[i] = 13) OR (buffer[i] = 10) OR (buffer[i] = 0)
            buffer[i] := 0
            IF i > start THEN z_config_line(buffer + start)
            start := i + 1
        ENDIF
    ENDFOR
ENDPROC TRUE

PROC set_status(text:PTR TO CHAR)
    set(tx_status, MUIA_Text_Contents, text)
ENDPROC

PROC refresh_offset()
    DEF text[96]:STRING, off[32]:STRING

    load_z_config()
    format_offset(g_offset, off)
    StringF(text, 'Offset Z courant: \s mm', off)
    set(tx_current, MUIA_Text_Contents, text)
    set(st_offset, MUIA_String_Contents, off)
ENDPROC

PROC run_shell_command(cmd:PTR TO CHAR)
    DEF entree=NIL, sortie=NIL, ok

    entree := Open('NIL:', MODE_OLDFILE)
    sortie := Open('NIL:', MODE_NEWFILE)
    ok := Execute(cmd, entree, sortie)
    IF entree THEN Close(entree)
    IF sortie THEN Close(sortie)
ENDPROC ok

PROC execute_cmd(args:PTR TO CHAR, label:PTR TO CHAR)
    DEF cmd[160]:STRING
    DEF ok

    set_status('Commande en cours...')

    StringF(cmd, '3dtoolbox:ZSetup \s', args)
    ok := run_shell_command(cmd)

    IF ok
        StringF(cmd, '\s OK', label)
        set_status(cmd)
        refresh_offset()
    ELSE
        StringF(cmd, '\s erreur. ZSetup introuvable dans 3dtoolbox:', label)
        set_status(cmd)
    ENDIF
ENDPROC ok

PROC set_from_string()
    DEF ptr, cmd[96]:STRING

    get(st_offset, MUIA_String_Contents, {ptr})
    IF ptr = NIL
        set_status('Offset absent.')
        RETURN FALSE
    ENDIF
    IF ptr[] = 0
        set_status('Offset absent.')
        RETURN FALSE
    ENDIF

    StringF(cmd, 'SET OFFSET=\s', ptr)
ENDPROC execute_cmd(cmd, 'Offset memorise')

PROC main() HANDLE
    DEF signal,result,running
    DEF off[32]:STRING

    load_z_config()
    format_offset(g_offset, off)

    IF (muimasterbase:=OpenLibrary(MUIMASTER_NAME,MUIMASTER_VMIN))=NIL THEN Raise(1)

    ap_app := ApplicationObject,
        MUIA_Application_Title, 'ZSetupMUI',
        MUIA_Application_Version, '0.1',
        MUIA_Application_Author, 'Denis Costils',
        MUIA_Application_Description, 'Z offset setup helper for OctoPrint',
        MUIA_Application_Base, 'ZSET',

        SubWindow,
            wi_main := WindowObject,
                MUIA_Window_Title, 'Z setup OctoPrint',
                MUIA_Window_ID, "ZSET",
                MUIA_Width, 360,
                MUIA_Height, 180,
                WindowContents, VGroup,

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        MUIA_FrameTitle, 'Offset',
                        MUIA_Group_Columns, 2,
                        Child, TextObject, MUIA_Text_Contents, 'Current/start offset', End,
                        Child, st_offset := StringObject,
                            StringFrame,
                            MUIA_String_Contents, off,
                            MUIA_String_MaxLen, 31,
                        End,
                        Child, bt_set := bouton('Set'),
                        Child, tx_current := TextObject,
                            MUIA_Text_Contents, 'Offset Z courant',
                        End,
                    End,

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        MUIA_FrameTitle, 'Reglage',
                        Child, bt_start := bouton('Start auto-level + centre'),
                        Child, HGroup,
                            Child, bt_down := bouton('Z -0.05'),
                            Child, bt_up := bouton('Z +0.05'),
                        End,
                        Child, HGroup,
                            Child, bt_save := bouton('Save'),
                            Child, bt_show := bouton('Show'),
                            Child, bt_quit := bouton('Quit'),
                        End,
                    End,

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        Child, tx_status := TextObject,
                            MUIA_Text_Contents, 'Attention: modifie M851/M500. Regle par petits pas.',
                        End,
                    End,
                End,
            End,
        End

    IF ap_app=NIL THEN Raise(2)

    refresh_offset()

    doMethod(wi_main, [MUIM_Notify, MUIA_Window_CloseRequest, MUI_TRUE, ap_app, 2, MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])
    doMethod(bt_start, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_START])
    doMethod(bt_down, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_DOWN])
    doMethod(bt_up, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_UP])
    doMethod(bt_save, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_SAVE])
    doMethod(bt_show, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_SHOW])
    doMethod(bt_set, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_SET])
    doMethod(bt_quit, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])

    set(wi_main, MUIA_Window_Open, MUI_TRUE)

    running := TRUE
    WHILE running
        result := doMethod(ap_app, [MUIM_Application_Input, {signal}])
        IF result <> MUIV_Application_ReturnID_Quit
            SELECT result
                CASE ID_START
                    execute_cmd('START', 'Position reglage')
                CASE ID_DOWN
                    execute_cmd('DOWN', 'Descente 0.05')
                CASE ID_UP
                    execute_cmd('UP', 'Remontee 0.05')
                CASE ID_SAVE
                    execute_cmd('SAVE', 'Sauvegarde EEPROM')
                CASE ID_SHOW
                    refresh_offset()
                    set_status('Offset affiche depuis S:zsetup.cfg.')
                CASE ID_SET
                    set_from_string()
            ENDSELECT
        ELSE
            running := FALSE
        ENDIF

        IF running
            IF signal <> 0 THEN Wait(signal) ELSE Delay(10)
        ENDIF
    ENDWHILE

    execute_cmd('HOME', 'Retour home')
    set(wi_main, MUIA_Window_Open, FALSE)
    Mui_DisposeObject(ap_app)
    ap_app := NIL
    CloseLibrary(muimasterbase)
    muimasterbase := NIL
    Raise(0)

EXCEPT DO
    IF ap_app THEN Mui_DisposeObject(ap_app)
    IF muimasterbase THEN CloseLibrary(muimasterbase)
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
