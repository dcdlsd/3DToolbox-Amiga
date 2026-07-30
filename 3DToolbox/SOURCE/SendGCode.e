-> SendGCode.e
-> Petit outil AmigaE pour envoyer une commande G-code a OctoPrint.
-> Utilise S:octocontrol_native.cfg, comme OctoControlSpeak.
-> Usage:
->   SendGCode "M851"
->   SendGCode "M851 Z-1.45"
->   SendGCode "M500"

OPT PREPROCESS
OPT OSVERSION=39

MODULE 'bsdsocket'
MODULE 'amitcp/sys/socket'
MODULE 'amitcp/netinet/in'
MODULE 'dos/dos'

#define CFG_FILE 'S:octocontrol_native.cfg'

DEF g_ip[64]:STRING
DEF g_api[256]:STRING
DEF g_port

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

PROC load_config()
    DEF h, buffer[1024]:STRING
    DEF len, i, start=0

    g_ip[0] := 0
    g_api[0] := 0
    g_port := 80

    IF (h := Open(CFG_FILE, MODE_OLDFILE)) = NIL THEN RETURN FALSE
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

PROC main() HANDLE
    DEF args:PTR TO LONG, rdargs=NIL
    DEF cmd
    DEF body[512]:STRING
    DEF reponse[8192]:STRING
    DEF status[256]:STRING
    DEF socket_open=FALSE

    args := [0]:LONG

    IF rdargs := ReadArgs('COMMAND/A/F', args, NIL)
        cmd := args[0]
        IF command_ok(cmd) = FALSE
            WriteF('Erreur: commande non acceptee. Evite les guillemets et la barre inverse.\n')
            Raise(10)
        ENDIF

        IF load_config() = FALSE
            WriteF('Configuration absente: \s\n', CFG_FILE)
            WriteF('Il faut OCTOPRINT=IP:PORT et APIKEY=cle.\n')
            Raise(10)
        ENDIF

        IF (socketbase := OpenLibrary('bsdsocket.library', 4)) = NIL
            WriteF('Impossible d ouvrir bsdsocket.library.\n')
            Raise(10)
        ENDIF
        socket_open := TRUE

        StringF(body, '{"commands":["\s"]}', cmd)
        WriteF('Envoi G-code: \s\n', cmd)

        IF http_request('POST', '/api/printer/command', body, reponse, 8192)
            http_status_line(reponse, status)
            IF has_http_success(reponse)
                WriteF('OK: commande acceptee par OctoPrint.\n')
                WriteF('\s\n', status)
            ELSE
                WriteF('OctoPrint a refuse la commande.\n')
                WriteF('\s\n', status)
            ENDIF
        ELSE
            WriteF('Erreur: OctoPrint ne repond pas.\n')
        ENDIF

        CloseLibrary(socketbase)
        socket_open := FALSE
    ELSE
        WriteF('Usage: SendGCode COMMAND/F\n')
        WriteF('Exemples:\n')
        WriteF('  SendGCode "M851"\n')
        WriteF('  SendGCode "M851 Z-1.45"\n')
        WriteF('  SendGCode "M500"\n')
    ENDIF

    Raise(0)

EXCEPT DO
    IF socket_open THEN CloseLibrary(socketbase)
    IF rdargs THEN FreeArgs(rdargs)
ENDPROC
