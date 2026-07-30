-> ZSetup.e
-> Assistant reglage Z pour Tina2S/Marlin via OctoPrint.
-> Utilise S:octocontrol_native.cfg pour OctoPrint.
-> Memorise l offset courant dans S:zsetup.cfg, en centiemes de mm.
-> Usage:
->   ZSetup START
->   ZSetup UP
->   ZSetup DOWN
->   ZSetup SHOW
->   ZSetup HOME
->   ZSetup SET OFFSET=0.00

OPT PREPROCESS
OPT OSVERSION=39

MODULE 'bsdsocket'
MODULE 'amitcp/sys/socket'
MODULE 'amitcp/netinet/in'
MODULE 'dos/dos'

#define OCTO_CFG 'S:octocontrol_native.cfg'
#define Z_CFG 'S:zsetup.cfg'
#define Z_MIN -500
#define Z_MAX 500

DEF g_ip[64]:STRING
DEF g_api[256]:STRING
DEF g_port
DEF g_offset

PROC begins(texte:PTR TO CHAR, debut:PTR TO CHAR)
    WHILE debut[]
        IF texte[] <> debut[] THEN RETURN FALSE
        texte++
        debut++
    ENDWHILE
ENDPROC TRUE

PROC char_upper(c)
    IF (c >= 97) AND (c <= 122) THEN c := c - 32
ENDPROC c

PROC equals(a:PTR TO CHAR, b:PTR TO CHAR)
    WHILE a[] AND b[]
        IF char_upper(a[]) <> char_upper(b[]) THEN RETURN FALSE
        a++
        b++
    ENDWHILE
ENDPROC (a[] = 0) AND (b[] = 0)

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

PROC config_line(ligne:PTR TO CHAR)
    DEF pos=0, termine=FALSE

    IF begins(ligne, 'OCTOPRINT=')
        ligne := ligne + 10
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
    ELSEIF begins(ligne, 'APIKEY=')
        copy_value(g_api, ligne + 7, 256)
    ELSEIF begins(ligne, 'API_KEY=')
        copy_value(g_api, ligne + 8, 256)
    ENDIF
ENDPROC

PROC load_octo_config()
    DEF h, buffer[1024]:STRING
    DEF len, i, start=0

    g_ip[0] := 0
    g_api[0] := 0
    g_port := 80

    IF (h := Open(OCTO_CFG, MODE_OLDFILE)) = NIL THEN RETURN FALSE
    len := Read(h, buffer, 1023)
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
ENDPROC (g_ip[0] <> 0) AND (g_api[0] <> 0)

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

PROC offset_safe(value)
ENDPROC (value >= Z_MIN) AND (value <= Z_MAX)

PROC save_z_config()
    DEF h, texte[64]:STRING

    h := Open(Z_CFG, MODE_NEWFILE)
    IF h = NIL THEN RETURN FALSE
    StringF(texte, 'OFFSET=\d\n', g_offset)
    Write(h, texte, StrLen(texte))
    Close(h)
ENDPROC TRUE

PROC send_all(sock, texte:PTR TO CHAR)
    DEF taille, position=0, envoye

    taille := StrLen(texte)
    WHILE position < taille
        envoye := Send(sock, texte + position, taille - position, 0)
        IF envoye <= 0 THEN RETURN FALSE
        position := position + envoye
    ENDWHILE
ENDPROC TRUE

PROC http_request(method:PTR TO CHAR, path:PTR TO CHAR, body:PTR TO CHAR, reponse:PTR TO CHAR, max)
    DEF adresse:sockaddr_in
    DEF requete[1536]:STRING
    DEF sock, taille_body, recu, utilise=0, termine=FALSE

    taille_body := StrLen(body)
    StringF(requete,
        '\s \s HTTP/1.0\r\nHost: \s\r\nX-Api-Key: \s\r\nContent-Type: application/json\r\nContent-Length: \d\r\nConnection: close\r\n\r\n\s',
        method, path, g_ip, g_api, taille_body, body)

    sock := Socket(AF_INET, SOCK_STREAM, 0)
    IF sock < 0 THEN RETURN FALSE

    clear_memory(adresse, SIZEOF sockaddr_in)
    adresse.family := AF_INET
    adresse.addr.addr := Inet_Addr(g_ip)
    adresse.port := g_port

    IF Connect(sock, adresse, SIZEOF sockaddr_in) < 0
        CloseSocket(sock)
        RETURN FALSE
    ENDIF

    IF send_all(sock, requete) = FALSE
        CloseSocket(sock)
        RETURN FALSE
    ENDIF

    WHILE (utilise < max-1) AND (termine = FALSE)
        recu := Recv(sock, reponse + utilise, max-1-utilise, 0)
        IF recu <= 0
            termine := TRUE
        ELSE
            utilise := utilise + recu
        ENDIF
    ENDWHILE
    reponse[utilise] := 0
    CloseSocket(sock)
ENDPROC utilise > 0

PROC has_http_success(reponse:PTR TO CHAR)
ENDPROC reponse[9] = 50

PROC http_status_line(reponse:PTR TO CHAR, destination:PTR TO CHAR)
    DEF i=0

    WHILE reponse[i] AND (reponse[i] <> 13) AND (reponse[i] <> 10) AND (i < 255)
        destination[i] := reponse[i]
        i++
    ENDWHILE
    destination[i] := 0
ENDPROC

PROC command_ok(cmd:PTR TO CHAR)
    DEF i=0

    WHILE cmd[i]
        IF cmd[i] = 34 THEN RETURN FALSE
        IF cmd[i] = 92 THEN RETURN FALSE
        i++
    ENDWHILE
ENDPROC TRUE

PROC send_gcode(cmd:PTR TO CHAR)
    DEF body[512]:STRING
    DEF reponse[1024]:STRING
    DEF status[256]:STRING

    IF command_ok(cmd) = FALSE
        WriteF('Erreur: commande non acceptee.\n')
        RETURN FALSE
    ENDIF
    StringF(body, '{"commands":["\s"]}', cmd)
    WriteF('Send: \s\n', cmd)
    IF http_request('POST', '/api/printer/command', body, reponse, 1024) = FALSE
        WriteF('Erreur: OctoPrint ne repond pas.\n')
        RETURN FALSE
    ENDIF
    IF has_http_success(reponse) = FALSE
        http_status_line(reponse, status)
        WriteF('Erreur: OctoPrint refuse la commande.\n')
        WriteF('\s\n', status)
        RETURN FALSE
    ENDIF
ENDPROC TRUE

PROC apply_offset()
    DEF off[32]:STRING, cmd[64]:STRING

    IF offset_safe(g_offset) = FALSE
        WriteF('Erreur: offset Z hors securite (-5.00 a +5.00 mm).\n')
        RETURN FALSE
    ENDIF

    format_offset(g_offset, off)
    StringF(cmd, 'M851 Z\s', off)
    IF send_gcode(cmd) = FALSE THEN RETURN FALSE
    IF send_gcode('M500') = FALSE THEN RETURN FALSE
    IF save_z_config() = FALSE
        WriteF('Attention: impossible de sauver \s\n', Z_CFG)
    ENDIF
    WriteF('Offset Z courant: \s\n', off)
ENDPROC TRUE

PROC start_setup()
    DEF off[32]:STRING

    format_offset(g_offset, off)
    WriteF('ZSetup START, offset courant: \s\n', off)
    IF send_gcode('G28') = FALSE THEN RETURN FALSE
    IF send_gcode('G29') = FALSE THEN RETURN FALSE
    IF send_gcode('M420 S1') = FALSE THEN RETURN FALSE
    IF send_gcode('G90') = FALSE THEN RETURN FALSE
    IF send_gcode('G1 Z10 F300') = FALSE THEN RETURN FALSE
    IF send_gcode('G1 X50 Y50 F3000') = FALSE THEN RETURN FALSE
    IF send_gcode('G1 Z0.5 F100') = FALSE THEN RETURN FALSE
    WriteF('Place la feuille et utilise ZSetup UP ou ZSetup DOWN.\n')
ENDPROC TRUE

PROC move_down()
    WriteF('Descente de 0.05 mm.\n')
    g_offset := g_offset - 5
    IF send_gcode('G91') = FALSE THEN RETURN FALSE
    IF send_gcode('G1 Z-0.05 F100') = FALSE THEN RETURN FALSE
    IF send_gcode('G90') = FALSE THEN RETURN FALSE
ENDPROC apply_offset()

PROC move_up()
    WriteF('Remontee de 0.05 mm.\n')
    g_offset := g_offset + 5
    IF send_gcode('G91') = FALSE THEN RETURN FALSE
    IF send_gcode('G1 Z0.05 F100') = FALSE THEN RETURN FALSE
    IF send_gcode('G90') = FALSE THEN RETURN FALSE
ENDPROC apply_offset()

PROC show_offset()
    DEF off[32]:STRING

    format_offset(g_offset, off)
    WriteF('Offset Z memorise par ZSetup: \s\n', off)
    WriteF('Verification imprimante possible avec M503 dans OctoPrint.\n')
ENDPROC

PROC home_printer()
    WriteF('Retour home.\n')
ENDPROC send_gcode('G28')

PROC main() HANDLE
    DEF args:PTR TO LONG, rdargs=NIL
    DEF action, offsetarg
    DEF socket_open=FALSE

    args := [0,0]:LONG

    IF rdargs := ReadArgs('ACTION/A,OFFSET/K', args, NIL)
        action := args[0]
        offsetarg := args[1]

        IF load_octo_config() = FALSE
            WriteF('Configuration absente: \s\n', OCTO_CFG)
            Raise(10)
        ENDIF
        load_z_config()

        IF offsetarg
            g_offset := parse_offset(offsetarg)
            IF offset_safe(g_offset) = FALSE
                WriteF('Erreur: OFFSET hors securite (-5.00 a +5.00 mm).\n')
                Raise(10)
            ENDIF
            save_z_config()
        ENDIF

        IF (socketbase := OpenLibrary('bsdsocket.library', 4)) = NIL
            WriteF('Impossible d ouvrir bsdsocket.library.\n')
            Raise(10)
        ENDIF
        socket_open := TRUE

        IF equals(action, 'START')
            start_setup()
        ELSEIF equals(action, 'DOWN')
            move_down()
        ELSEIF equals(action, 'UP')
            move_up()
        ELSEIF equals(action, 'SAVE')
            apply_offset()
        ELSEIF equals(action, 'SHOW')
            show_offset()
        ELSEIF equals(action, 'HOME')
            home_printer()
        ELSEIF equals(action, 'SET')
            IF offsetarg
                show_offset()
            ELSE
                WriteF('SET demande OFFSET, exemple: ZSetup SET OFFSET=0.00\n')
            ENDIF
        ELSE
            WriteF('Action inconnue: \s\n', action)
        ENDIF

        CloseLibrary(socketbase)
        socket_open := FALSE
    ELSE
        WriteF('Usage: ZSetup ACTION/A OFFSET/K\n')
        WriteF('Actions: START, UP, DOWN, SAVE, SHOW, HOME, SET\n')
        WriteF('Exemples:\n')
        WriteF('  ZSetup SET OFFSET=0.00\n')
        WriteF('  ZSetup START\n')
        WriteF('  ZSetup DOWN\n')
        WriteF('  ZSetup UP\n')
        WriteF('  ZSetup SAVE\n')
        WriteF('  ZSetup HOME\n')
    ENDIF

    Raise(0)

EXCEPT DO
    IF socket_open THEN CloseLibrary(socketbase)
    IF rdargs THEN FreeArgs(rdargs)
ENDPROC
