OPT PREPROCESS
OPT OSVERSION=39

MODULE 'muimaster', 'libraries/mui'
MODULE 'utility/tagitem', 'utility/hooks'
MODULE 'intuition/classes', 'intuition/classusr'
MODULE 'bsdsocket'
MODULE 'amitcp/sys/socket'
MODULE 'amitcp/netinet/in'
MODULE 'dos/dos'

#define CFG_FILE 'S:pitemp.cfg'
#define FIONBIO $8004667E
#define TEMP_WARNING 45

ENUM ID_READ=1,
     ID_SAVE,
     ID_AUTO

DEF g_ip[64]:STRING
DEF g_port
DEF g_response[2048]:STRING
DEF g_temp[64]:STRING
DEF g_status[160]:STRING
DEF g_auto_enabled, g_auto_ticks

DEF ap_app, wi_main
DEF st_ip, st_port
DEF bt_read, bt_save, bt_auto, bt_quit
DEF tx_temp, tx_status

PROC begins(texte:PTR TO CHAR, debut:PTR TO CHAR)
    WHILE debut[]
        IF texte[] <> debut[] THEN RETURN FALSE
        texte++
        debut++
    ENDWHILE
ENDPROC TRUE

PROC copy_value(destination:PTR TO CHAR, source:PTR TO CHAR, max)
    DEF i=0

    WHILE source[] AND (i < max-1)
        destination[i++] := source[]
        source++
    ENDWHILE
    destination[i] := 0
ENDPROC

PROC clear_memory(memory:PTR TO CHAR, size)
    WHILE size > 0
        memory[] := 0
        memory++
        size--
    ENDWHILE
ENDPROC

/* IoctlSocket() est le vecteur -$72 de bsdsocket.library. */
PROC ioctl_socket(sock, request, argp)
    DEF resultat
    MOVEA.L socketbase, A6
    MOVE.L sock, D0
    MOVE.L request, D1
    MOVEA.L argp, A0
    JSR -114(A6)
    MOVE.L D0, resultat
ENDPROC resultat

PROC socket_nonblock(sock, active)
    DEF mode

    mode := active
ENDPROC ioctl_socket(sock, FIONBIO, {mode}) >= 0

PROC config_line(ligne:PTR TO CHAR)
    DEF pos=0, termine=FALSE

    IF begins(ligne, 'PITEMP=')
        ligne := ligne + 7
        WHILE ligne[pos] AND (termine = FALSE)
            IF ligne[pos] = 58
                ligne[pos] := 0
                g_port := Val(ligne + pos + 1)
                termine := TRUE
            ELSE
                pos++
            ENDIF
        ENDWHILE
        copy_value(g_ip, ligne, 64)
    ELSEIF begins(ligne, 'IP=')
        copy_value(g_ip, ligne + 3, 64)
    ELSEIF begins(ligne, 'PORT=')
        g_port := Val(ligne + 5)
    ENDIF
ENDPROC

PROC load_config()
    DEF h, buffer[512]:STRING
    DEF len, i, start=0

    StrCopy(g_ip, '192.168.1.162', ALL)
    g_port := 8088

    IF (h := Open(CFG_FILE, MODE_OLDFILE)) = NIL THEN RETURN FALSE
    len := Read(h, buffer, 511)
    Close(h)
    IF len <= 0 THEN RETURN FALSE
    buffer[len] := 0

    FOR i := 0 TO len
        IF (buffer[i] = 13) OR (buffer[i] = 10) OR (buffer[i] = 0)
            buffer[i] := 0
            IF i > start THEN config_line(buffer + start)
            start := i + 1
        ENDIF
    ENDFOR
ENDPROC TRUE

PROC save_config()
    DEF h, texte[160]:STRING

    h := Open(CFG_FILE, MODE_NEWFILE)
    IF h = NIL THEN RETURN FALSE
    StringF(texte, 'PITEMP=\s:\d\n', g_ip, g_port)
    Write(h, texte, StrLen(texte))
    Close(h)
ENDPROC TRUE

PROC read_gui_config()
    DEF source

    get(st_ip, MUIA_String_Contents, {source})
    IF source THEN copy_value(g_ip, source, 64)

    get(st_port, MUIA_String_Contents, {source})
    IF source THEN g_port := Val(source)

    IF g_port <= 0 THEN g_port := 8088
ENDPROC g_ip[0] <> 0

PROC send_bytes_fast(sock, data:PTR TO CHAR, taille)
    DEF position=0, envoye, essais=0

    WHILE position < taille
        envoye := Send(sock, data + position, taille - position, 0)
        IF envoye <= 0
            essais++
            IF essais >= 40 THEN RETURN FALSE
            Delay(1)
        ELSE
            position := position + envoye
            essais := 0
        ENDIF
    ENDWHILE
ENDPROC TRUE

PROC send_all_fast(sock, texte:PTR TO CHAR)
ENDPROC send_bytes_fast(sock, texte, StrLen(texte))

PROC http_get_temp(reponse:PTR TO CHAR, max)
    DEF adresse:sockaddr_in
    DEF requete[512]:STRING
    DEF sock, recu, utilise=0, essais=0

    StringF(requete,
        'GET /temp HTTP/1.0\r\nHost: \s\r\nConnection: close\r\n\r\n',
        g_ip)

    sock := Socket(AF_INET, SOCK_STREAM, 0)
    IF sock < 0 THEN RETURN FALSE
    socket_nonblock(sock, TRUE)

    clear_memory(adresse, SIZEOF sockaddr_in)
    adresse.family := AF_INET
    adresse.addr.addr := Inet_Addr(g_ip)
    adresse.port := g_port

    Connect(sock, adresse, SIZEOF sockaddr_in)

    IF send_all_fast(sock, requete) = FALSE
        CloseSocket(sock)
        RETURN FALSE
    ENDIF

    WHILE (utilise < max-1) AND (essais < 60)
        recu := Recv(sock, reponse + utilise, max-1-utilise, 0)
        IF recu > 0
            utilise := utilise + recu
            essais := 0
        ELSE
            essais++
            Delay(1)
        ENDIF
    ENDWHILE
    reponse[utilise] := 0
    CloseSocket(sock)
ENDPROC utilise > 0

PROC extract_body(source:PTR TO CHAR, destination:PTR TO CHAR, max)
    DEF pos=0, start=0, i=0

    WHILE source[pos]
        IF (source[pos] = 13) AND (source[pos+1] = 10) AND (source[pos+2] = 13) AND (source[pos+3] = 10)
            start := pos + 4
            pos := StrLen(source)
        ELSE
            pos++
        ENDIF
    ENDWHILE

    IF start = 0 THEN start := 0

    WHILE source[start] AND (source[start] <> 13) AND (source[start] <> 10) AND (i < max-1)
        destination[i++] := source[start]
        start++
    ENDWHILE
    destination[i] := 0
ENDPROC i > 0

PROC update_status(texte:PTR TO CHAR)
    StrCopy(g_status, texte, ALL)
    set(tx_status, MUIA_Text_Contents, g_status)
ENDPROC

PROC read_temperature()
    DEF temp_value

    IF read_gui_config() = FALSE
        update_status('Status: enter Raspberry Pi IP address.')
        RETURN
    ENDIF

    update_status('Status: reading temperature...')

    IF http_get_temp(g_response, 2048) = FALSE
        update_status('Status: no answer from PiTempServer.')
        set(tx_temp, MUIA_Text_Contents, 'Pi temperature: -- C')
        RETURN
    ENDIF

    IF extract_body(g_response, g_temp, 64) = FALSE
        update_status('Status: invalid answer.')
        set(tx_temp, MUIA_Text_Contents, 'Pi temperature: -- C')
        RETURN
    ENDIF

    StringF(g_status, 'Status: OK, PiTempServer answered.')
    set(tx_status, MUIA_Text_Contents, g_status)

    temp_value := Val(g_temp)
    IF temp_value >= TEMP_WARNING
        set(tx_temp, MUIA_Background, '2:FFFFFFFF,00000000,00000000')
        StringF(g_status, 'Pi temperature: \s C  WARNING', g_temp)
    ELSE
        set(tx_temp, MUIA_Background, MUII_ButtonBack)
        StringF(g_status, 'Pi temperature: \s C', g_temp)
    ENDIF
    set(tx_temp, MUIA_Text_Contents, g_status)
ENDPROC

PROC toggle_auto()
    g_auto_enabled := Not(g_auto_enabled)
    g_auto_ticks := 0
    IF g_auto_enabled
        set(bt_auto, MUIA_Text_Contents, 'Auto ON')
        update_status('Status: automatic refresh enabled.')
        read_temperature()
    ELSE
        set(bt_auto, MUIA_Text_Contents, 'Auto OFF')
        update_status('Status: automatic refresh stopped.')
    ENDIF
ENDPROC

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

PROC main() HANDLE
    DEF signal, result, running
    DEF port_text[16]:STRING

    load_config()
    StringF(port_text, '\d', g_port)
    g_auto_enabled := FALSE
    g_auto_ticks := 0

    IF (muimasterbase := OpenLibrary(MUIMASTER_NAME, MUIMASTER_VMIN)) = NIL THEN Raise(1)
    IF (socketbase := OpenLibrary('bsdsocket.library', 4)) = NIL THEN Raise(2)

    ap_app := ApplicationObject,
        MUIA_Application_Title, 'PiTemp',
        MUIA_Application_Version, '0.1',
        MUIA_Application_Author, 'Denis Costils',
        MUIA_Application_Description, 'Raspberry Pi temperature monitor',
        MUIA_Application_Base, 'PITEMP',

        SubWindow,
            wi_main := WindowObject,
                MUIA_Window_Title, 'PiTemp',
                MUIA_Window_ID, "PITM",
                MUIA_Width, 360,
                MUIA_Height, 170,
                WindowContents, VGroup,

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        MUIA_FrameTitle, 'PiTempServer',
                        MUIA_Group_Columns, 2,
                        Child, TextObject, MUIA_Text_Contents, 'IP address', End,
                        Child, st_ip := StringObject,
                            StringFrame,
                            MUIA_String_Contents, g_ip,
                            MUIA_String_MaxLen, 63,
                        End,
                        Child, TextObject, MUIA_Text_Contents, 'Port', End,
                        Child, st_port := StringObject,
                            StringFrame,
                            MUIA_String_Contents, port_text,
                            MUIA_String_MaxLen, 8,
                        End,
                    End,

                    Child, HGroup,
                        Child, bt_read := bouton('Read'),
                        Child, bt_auto := bouton('Auto OFF'),
                        Child, bt_save := bouton('Save'),
                        Child, bt_quit := bouton('Quit'),
                    End,

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        Child, tx_temp := TextObject,
                            ButtonFrame,
                            MUIA_Text_Contents, 'Pi temperature: -- C',
                            MUIA_Text_PreParse, '\ec',
                            MUIA_Background, MUII_ButtonBack,
                        End,
                        Child, tx_status := TextObject,
                            MUIA_Text_Contents, 'Status: ready.',
                        End,
                    End,
                End,
            End,
        End

    IF ap_app = NIL THEN Raise(3)

    doMethod(wi_main, [MUIM_Notify, MUIA_Window_CloseRequest, MUI_TRUE, ap_app, 2, MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])
    doMethod(bt_read, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_READ])
    doMethod(bt_auto, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_AUTO])
    doMethod(bt_save, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_SAVE])
    doMethod(bt_quit, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])

    set(wi_main, MUIA_Window_Open, MUI_TRUE)

    running := TRUE
    WHILE running
        result := doMethod(ap_app, [MUIM_Application_Input, {signal}])
        IF result <> MUIV_Application_ReturnID_Quit
            SELECT result
                CASE ID_READ
                    read_temperature()
                CASE ID_AUTO
                    toggle_auto()
                CASE ID_SAVE
                    IF read_gui_config()
                        IF save_config()
                            update_status('Status: configuration saved in S:pitemp.cfg')
                        ELSE
                            update_status('Status: unable to write S:pitemp.cfg')
                        ENDIF
                    ELSE
                        update_status('Status: enter Raspberry Pi IP address.')
                    ENDIF
            ENDSELECT
        ELSE
            running := FALSE
        ENDIF

        IF running AND g_auto_enabled
            g_auto_ticks++
            IF g_auto_ticks >= 25
                g_auto_ticks := 0
                read_temperature()
            ENDIF
        ENDIF

        IF running
            IF g_auto_enabled
                Delay(10)
            ELSEIF signal <> 0
                Wait(signal)
            ELSE
                Delay(10)
            ENDIF
        ENDIF
    ENDWHILE

    set(wi_main, MUIA_Window_Open, FALSE)
    Mui_DisposeObject(ap_app)
    ap_app := NIL
    CloseLibrary(socketbase)
    socketbase := NIL
    CloseLibrary(muimasterbase)
    muimasterbase := NIL
    RETURN 0

EXCEPT
    IF ap_app THEN Mui_DisposeObject(ap_app)
    IF socketbase THEN CloseLibrary(socketbase)
    IF muimasterbase THEN CloseLibrary(muimasterbase)
    SELECT exception
        CASE 1 ; WriteF('Impossible d ouvrir muimaster.library.\n')
        CASE 2 ; WriteF('Impossible d ouvrir bsdsocket.library.\n')
        CASE 3 ; WriteF('Impossible de creer l application MUI.\n')
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
