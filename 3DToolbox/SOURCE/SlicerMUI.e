-> SlicerMUI.e
-> MUI frontend for SlicerServer / PrusaSlicer bridge.
-> Sends an Amiga STL to the PC hotfolder, asks the PC to slice it,
-> then downloads the generated G-code back to the Amiga.

OPT PREPROCESS
OPT LARGE
OPT OSVERSION=39

MODULE 'muimaster','libraries/mui'
MODULE 'utility/tagitem','utility/hooks'
MODULE 'intuition/classes','intuition/classusr'
MODULE 'bsdsocket'
MODULE 'amitcp/sys/socket'
MODULE 'amitcp/netinet/in'
MODULE 'dos/dos','libraries/asl'

#define CFG_FILE 'S:slicer_server.cfg'
#define DEFAULT_PORT 18090
#define TRANSFER_BLOCK 1024
#define SEND_RETRY_LIMIT 500
#define UPLOAD_BLOCK_DELAY 1
#define FIONBIO $8004667E

ENUM ID_TEST=1,
     ID_SAVE,
     ID_STLINFO,
     ID_UPLOADSLICE,
     ID_LAST,
     ID_JOB,
     ID_DOWNLOAD,
     ID_FILES,
     ID_DELETE,
     ID_CLEAR

DEF g_ip[64]:STRING
DEF g_port
DEF g_transfer_buffer[TRANSFER_BLOCK]:STRING
DEF g_response[12000]:STRING
DEF g_status[256]:STRING
DEF g_result[8192]:STRING
DEF g_transfer_size, g_transfer_sent, g_transfer_last_percent
DEF g_busy

DEF ap_app, wi_main
DEF st_ip, st_port, st_stl, st_name, st_scale, st_gcode, st_job
DEF bt_test, bt_save, bt_stlinfo, bt_uploadslice, bt_last, bt_job, bt_download, bt_files, bt_delete, bt_clear, bt_quit
DEF tx_status, tx_transfer_progress, ga_transfer_progress, li_result, lv_result

PROC begins(texte:PTR TO CHAR, debut:PTR TO CHAR)
    WHILE debut[]
        IF texte[] <> debut[] THEN RETURN FALSE
        texte++
        debut++
    ENDWHILE
ENDPROC TRUE

PROC same_text(a:PTR TO CHAR, b:PTR TO CHAR)
    IF (a = NIL) OR (b = NIL) THEN RETURN FALSE
    WHILE a[] AND b[]
        IF a[] <> b[] THEN RETURN FALSE
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

PROC normalize_scale(source:PTR TO CHAR, destination:PTR TO CHAR, max)
    DEF i=0, c, dot_seen=FALSE, digit_seen=FALSE

    IF source = NIL THEN RETURN FALSE

    WHILE source[] AND (i < max-1)
        c := source[]

        IF (c >= 48) AND (c <= 57)
            destination[i++] := c
            digit_seen := TRUE
        ELSEIF (c = 44) OR (c = 46)
            IF dot_seen = FALSE
                destination[i++] := 46
                dot_seen := TRUE
            ENDIF
        ELSEIF c = 37
            -> ignore percent sign
            c := c
        ELSEIF c = 32
            -> ignore spaces
            c := c
        ELSE
            RETURN FALSE
        ENDIF

        source++
    ENDWHILE

    destination[i] := 0

    IF digit_seen = FALSE THEN RETURN FALSE
ENDPROC TRUE

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

    IF begins(ligne, 'SLICER=')
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

    g_ip[0] := 0
    g_port := DEFAULT_PORT

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
ENDPROC g_ip[0] <> 0

PROC save_config()
    DEF h, texte[160]:STRING

    h := Open(CFG_FILE, MODE_NEWFILE)
    IF h = NIL THEN RETURN FALSE
    StringF(texte, 'SLICER=\s:\d\n', g_ip, g_port)
    Write(h, texte, StrLen(texte))
    Close(h)
ENDPROC TRUE

PROC read_gui_config()
    DEF source

    get(st_ip, MUIA_String_Contents, {source})
    IF source THEN copy_value(g_ip, source, 64)

    get(st_port, MUIA_String_Contents, {source})
    IF source THEN g_port := Val(source)

    IF g_port <= 0 THEN g_port := DEFAULT_PORT
ENDPROC g_ip[0] <> 0

PROC set_status(text)
    StrCopy(g_status, text, ALL)
    set(tx_status, MUIA_Text_Contents, g_status)
    Delay(1)
ENDPROC

PROC reset_transfer_progress(label:PTR TO CHAR)
    g_transfer_size := 0
    g_transfer_sent := 0
    g_transfer_last_percent := -1
    IF ga_transfer_progress THEN set(ga_transfer_progress, MUIA_Gauge_Current, 0)
    IF tx_transfer_progress THEN set(tx_transfer_progress, MUIA_Text_Contents, label)
    Delay(1)
ENDPROC

PROC update_transfer_progress(force)
    DEF percent, sent_k, total_k
    DEF texte[96]:STRING

    IF g_transfer_size <= 0 THEN RETURN
    IF g_transfer_size > 100000
        percent := ((g_transfer_sent / 1024) * 100) / (g_transfer_size / 1024)
    ELSE
        percent := (g_transfer_sent * 100) / g_transfer_size
    ENDIF
    IF percent < 0 THEN percent := 0
    IF percent > 100 THEN percent := 100

    IF force OR (percent <> g_transfer_last_percent)
        g_transfer_last_percent := percent
        sent_k := g_transfer_sent / 1024
        total_k := g_transfer_size / 1024
        IF sent_k < 0 THEN sent_k := 0
        IF total_k < 0 THEN total_k := 0
        IF (g_transfer_sent > 0) AND (sent_k = 0) THEN sent_k := 1
        IF (g_transfer_size > 0) AND (total_k = 0) THEN total_k := 1
        IF ga_transfer_progress THEN set(ga_transfer_progress, MUIA_Gauge_Current, percent)
        StringF(texte, 'Transfer: \d %  (\d / \d Ko)', percent, sent_k, total_k)
        IF tx_transfer_progress THEN set(tx_transfer_progress, MUIA_Text_Contents, texte)
        Delay(1)
    ENDIF
ENDPROC

PROC list_clear(listobj)
    IF listobj THEN doMethod(listobj, [MUIM_List_Clear])
ENDPROC

PROC list_add(listobj, texte)
    IF listobj THEN doMethod(listobj, [MUIM_List_InsertSingle, texte, MUIV_List_Insert_Bottom])
ENDPROC

PROC set_result(text)
    DEF pos=0, start=0, i=0

    IF li_result THEN set(li_result, MUIA_List_Quiet, MUI_TRUE)
    list_clear(li_result)

    WHILE text[i] AND (i < 8191)
        g_result[i] := text[i]
        i++
    ENDWHILE
    g_result[i] := 0

    WHILE g_result[pos]
        IF (g_result[pos] = 13) OR (g_result[pos] = 10)
            g_result[pos] := 0
            IF pos > start THEN list_add(li_result, g_result + start)
            IF (g_result[pos+1] = 10) OR (g_result[pos+1] = 13) THEN pos++
            pos++
            start := pos
        ELSE
            pos++
        ENDIF
    ENDWHILE

    IF pos > start
        list_add(li_result, g_result + start)
    ENDIF

    IF pos = 0 THEN list_add(li_result, '(empty answer)')
    IF li_result THEN set(li_result, MUIA_List_Quiet, FALSE)
    Delay(1)
ENDPROC

PROC send_bytes(sock, data:PTR TO CHAR, taille)
    DEF position=0, envoye, essais=0

    WHILE position < taille
        envoye := Send(sock, data + position, taille - position, 0)
        IF envoye <= 0
            essais++
            IF essais >= SEND_RETRY_LIMIT THEN RETURN FALSE
            Delay(1)
        ELSE
            position := position + envoye
            essais := 0
        ENDIF
    ENDWHILE
ENDPROC TRUE

PROC send_all(sock, texte:PTR TO CHAR)
ENDPROC send_bytes(sock, texte, StrLen(texte))

PROC recv_response(sock, reponse:PTR TO CHAR, max, max_idle)
    DEF recu, utilise=0, idle=0

    WHILE (utilise < max-1) AND (idle < max_idle)
        recu := Recv(sock, reponse + utilise, max-1-utilise, 0)
        IF recu > 0
            utilise := utilise + recu
            idle := 0
        ELSE
            idle++
            Delay(1)
        ENDIF
    ENDWHILE
    reponse[utilise] := 0
ENDPROC utilise

PROC connect_server()
    DEF adresse:sockaddr_in
    DEF sock

    sock := Socket(AF_INET, SOCK_STREAM, 0)
    IF sock < 0 THEN RETURN -1
    socket_nonblock(sock, TRUE)

    clear_memory(adresse, SIZEOF sockaddr_in)
    adresse.family := AF_INET
    adresse.addr.addr := Inet_Addr(g_ip)
    adresse.port := g_port

    Connect(sock, adresse, SIZEOF sockaddr_in)
ENDPROC sock

PROC http_get(path:PTR TO CHAR, reponse:PTR TO CHAR, max)
    DEF requete[1536]:STRING
    DEF sock, utilise

    StringF(requete,
        'GET \s HTTP/1.0\r\nHost: \s\r\nConnection: close\r\n\r\n',
        path, g_ip)

    sock := connect_server()
    IF sock < 0 THEN RETURN FALSE

    IF send_all(sock, requete) = FALSE
        CloseSocket(sock)
        RETURN FALSE
    ENDIF

    utilise := recv_response(sock, reponse, max, 250)
    CloseSocket(sock)
ENDPROC utilise > 0

PROC http_status_line(reponse:PTR TO CHAR, destination:PTR TO CHAR)
    DEF i=0

    WHILE reponse[i] AND (reponse[i] <> 13) AND (reponse[i] <> 10) AND (i < 255)
        destination[i] := reponse[i]
        i++
    ENDWHILE
    destination[i] := 0
ENDPROC

PROC has_http_success(reponse:PTR TO CHAR)
ENDPROC reponse[9] = 50

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

    WHILE source[start] AND (i < max-1)
        destination[i++] := source[start]
        start++
    ENDWHILE
    destination[i] := 0
ENDPROC i > 0

PROC path_char_ok(c)
    IF c = 38 THEN RETURN FALSE  -> &
    IF c = 63 THEN RETURN FALSE  -> ?
ENDPROC TRUE

PROC encode_path(source:PTR TO CHAR, destination:PTR TO CHAR, max)
    DEF i=0, c

    WHILE source[] AND (i < max-4)
        c := source[]
        IF path_char_ok(c) = FALSE THEN RETURN FALSE

        IF c = 32
            destination[i++] := 37
            destination[i++] := 50
            destination[i++] := 48
        ELSEIF c = 92
            destination[i++] := 47
        ELSE
            destination[i++] := c
        ENDIF
        source++
    ENDWHILE
    destination[i] := 0
ENDPROC TRUE

PROC base_name(chemin:PTR TO CHAR)
    DEF i=0, debut=0

    WHILE chemin[i]
        IF (chemin[i] = 47) OR (chemin[i] = 58) OR (chemin[i] = 92) THEN debut := i + 1
        i++
    ENDWHILE
ENDPROC chemin + debut

PROC header_end(buffer:PTR TO CHAR, len)
    DEF i=0

    WHILE i < len-3
        IF (buffer[i] = 13) AND (buffer[i+1] = 10) AND (buffer[i+2] = 13) AND (buffer[i+3] = 10)
            RETURN i + 4
        ENDIF
        i++
    ENDWHILE
ENDPROC 0

PROC body_to_result(reponse:PTR TO CHAR)
    DEF status[256]:STRING
    DEF body[8192]:STRING

    http_status_line(reponse, status)
    IF extract_body(reponse, body, 8192)
        set_result(body)
    ELSE
        set_result(status)
    ENDIF
ENDPROC

PROC find_value_line(source:PTR TO CHAR, key:PTR TO CHAR, destination:PTR TO CHAR, max)
    DEF pos=0, klen, i, start

    klen := StrLen(key)
    WHILE source[pos]
        i := 0
        WHILE key[i] AND (source[pos+i] = key[i])
            i++
        ENDWHILE
        IF i = klen
            start := pos + klen
            i := 0
            WHILE source[start] AND (source[start] <> 13) AND (source[start] <> 10) AND (i < max-1)
                destination[i++] := source[start]
                start++
            ENDWHILE
            destination[i] := 0
            RETURN TRUE
        ENDIF

        WHILE source[pos] AND (source[pos] <> 10)
            pos++
        ENDWHILE
        IF source[pos] THEN pos++
    ENDWHILE
ENDPROC FALSE

PROC update_job_from_response(reponse:PTR TO CHAR)
    DEF body[8192]:STRING
    DEF id[32]:STRING

    IF extract_body(reponse, body, 8192)
        IF find_value_line(body, 'ID: ', id, 32)
            set(st_job, MUIA_String_Contents, id)
        ENDIF
    ENDIF
ENDPROC

PROC copy_scale_value(source:PTR TO CHAR, destination:PTR TO CHAR, max)
    DEF i=0

    WHILE source[] AND (source[] <> 37) AND (source[] <> 13) AND (source[] <> 10) AND (i < max-1)
        destination[i++] := source[]
        source++
    ENDWHILE
    destination[i] := 0
ENDPROC i > 0

PROC update_scale_from_response(reponse:PTR TO CHAR)
    DEF body[8192]:STRING
    DEF value[32]:STRING
    DEF scale[32]:STRING

    IF extract_body(reponse, body, 8192)
        IF find_value_line(body, 'SUGGESTED_SCALE: ', value, 32)
            IF copy_scale_value(value, scale, 32)
                set(st_scale, MUIA_String_Contents, scale)
            ENDIF
        ENDIF
    ENDIF
ENDPROC

PROC make_gcode_name_from_stl(stl:PTR TO CHAR, dest:PTR TO CHAR)
    DEF i=0,lastdot=-1
    DEF base[256]:STRING

    StrCopy(base, stl, ALL)
    WHILE base[i]
        IF (base[i] = 58) OR (base[i] = 47)
            lastdot := -1
        ELSEIF base[i] = 46
            lastdot := i
        ENDIF
        i++
    ENDWHILE
    IF lastdot <> -1 THEN base[lastdot] := 0
    StringF(dest, '\s.gcode', base)
ENDPROC

PROC update_names_from_stl()
    DEF source, outptr
    DEF stl[256]:STRING, name[256]:STRING, out[256]:STRING

    get(st_stl, MUIA_String_Contents, {source})
    IF source = NIL THEN RETURN FALSE
    IF source[] = 0 THEN RETURN FALSE

    StrCopy(stl, source, ALL)
    StrCopy(name, base_name(stl), ALL)
    set(st_name, MUIA_String_Contents, name)

    get(st_gcode, MUIA_String_Contents, {outptr})
    IF outptr = NIL
        make_gcode_name_from_stl(stl, out)
        set(st_gcode, MUIA_String_Contents, out)
    ELSEIF outptr[] = 0
        make_gcode_name_from_stl(stl, out)
        set(st_gcode, MUIA_String_Contents, out)
    ELSEIF same_text(outptr, 'RAM:modele.gcode')
        make_gcode_name_from_stl(stl, out)
        set(st_gcode, MUIA_String_Contents, out)
    ENDIF
ENDPROC TRUE

PROC lower_char(c)
    IF (c >= 65) AND (c <= 90) THEN c := c + 32
ENDPROC c

PROC has_server_file_extension(texte:PTR TO CHAR)
    DEF i=0, a, b, c, d, e

    WHILE texte[i]
        IF texte[i] = 46
            a := lower_char(texte[i+1])
            b := lower_char(texte[i+2])
            c := lower_char(texte[i+3])
            d := lower_char(texte[i+4])
            e := lower_char(texte[i+5])

            IF a = 115
                IF b = 116
                    IF c = 108
                        IF texte[i+4] = 0 THEN RETURN TRUE
                    ENDIF
                ENDIF
            ENDIF

            IF a = 103
                IF b = 99
                    IF c = 111
                        IF d = 100
                            IF e = 101
                                IF texte[i+6] = 0 THEN RETURN TRUE
                            ENDIF
                        ENDIF
                    ENDIF
                ENDIF
            ENDIF
        ENDIF
        i++
    ENDWHILE
ENDPROC FALSE

PROC selected_server_file(destination:PTR TO CHAR, max)
    DEF actif, entree
    DEF pos=0, i=0, endpos

    get(li_result, MUIA_List_Active, {actif})
    IF actif < 0 THEN RETURN FALSE

    doMethod(li_result, [MUIM_List_GetEntry, actif, {entree}])
    IF entree = NIL THEN RETURN FALSE

    WHILE entree[pos] = 32
        pos++
    ENDWHILE

    IF entree[pos] = 0 THEN RETURN FALSE
    IF entree[pos] = 40 THEN RETURN FALSE  -> (
    IF begins(entree + pos, 'STATUS:') THEN RETURN FALSE
    IF begins(entree + pos, 'BASE_DIR:') THEN RETURN FALSE
    IF begins(entree + pos, 'STL waiting:') THEN RETURN FALSE
    IF begins(entree + pos, 'STL done:') THEN RETURN FALSE
    IF begins(entree + pos, 'G-code:') THEN RETURN FALSE
    IF begins(entree + pos, 'Errors:') THEN RETURN FALSE

    WHILE entree[pos] AND (i < max-1)
        IF (entree[pos] = 32) AND (entree[pos+1] = 32) AND (entree[pos+2] = 40)
            destination[i] := 0
            IF has_server_file_extension(destination) THEN RETURN TRUE
            RETURN FALSE
        ENDIF
        destination[i++] := entree[pos++]
    ENDWHILE

    destination[i] := 0
    endpos := i - 1
    WHILE endpos >= 0
        IF destination[endpos] = 32
            destination[endpos] := 0
            endpos--
        ELSE
            endpos := -1
        ENDIF
    ENDWHILE
ENDPROC has_server_file_extension(destination)

PROC result_has_selection()
    DEF actif

    get(li_result, MUIA_List_Active, {actif})
ENDPROC actif >= 0

PROC do_get_to_gui(path:PTR TO CHAR)
    DEF status[256]:STRING

    IF read_gui_config() = FALSE
        set_status('Status: enter PC IP address.')
        RETURN FALSE
    ENDIF

    StringF(g_status, 'Status: GET \s', path)
    set_status(g_status)

    IF http_get(path, g_response, 12000) = FALSE
        set_status('Status: SlicerServer does not answer.')
        RETURN FALSE
    ENDIF

    http_status_line(g_response, status)
    IF has_http_success(g_response)
        set_status('Status: OK.')
    ELSE
        set_status(status)
    ENDIF
    body_to_result(g_response)
    update_job_from_response(g_response)
ENDPROC has_http_success(g_response)

PROC upload_file(local_path:PTR TO CHAR, upload_name:PTR TO CHAR, profile:PTR TO CHAR, scale_text:PTR TO CHAR, start_slice)
    DEF h, taille, restant, lu, sock, utilise=0
    DEF requete[1536]:STRING, path[512]:STRING
    DEF name_enc[256]:STRING
    DEF ok=TRUE

    IF encode_path(upload_name, name_enc, 256) = FALSE
        set_status('Status: bad PC STL name.')
        RETURN FALSE
    ENDIF

    h := Open(local_path, MODE_OLDFILE)
    IF h = NIL
        set_status('Status: unable to open local STL.')
        RETURN FALSE
    ENDIF

    Seek(h, 0, OFFSET_END)
    taille := Seek(h, 0, OFFSET_CURRENT)
    Seek(h, 0, OFFSET_BEGINNING)
    IF taille < 0
        Close(h)
        set_status('Status: unable to read STL size.')
        RETURN FALSE
    ENDIF

    g_transfer_size := taille
    g_transfer_sent := 0
    g_transfer_last_percent := -1
    update_transfer_progress(TRUE)

    IF start_slice
        StringF(path, '/upload-and-slice?name=\s&profile=\s&scale=\s', name_enc, profile, scale_text)
    ELSE
        StringF(path, '/upload?name=\s&profile=\s&scale=\s', name_enc, profile, scale_text)
    ENDIF
    StringF(requete,
        'POST \s HTTP/1.0\r\nHost: \s\r\nContent-Type: application/octet-stream\r\nContent-Length: \d\r\nConnection: close\r\n\r\n',
        path, g_ip, taille)

    IF start_slice
        StringF(g_status, 'Status: uploading STL, \d bytes...', taille)
    ELSE
        StringF(g_status, 'Status: reading STL info, \d bytes...', taille)
    ENDIF
    set_status(g_status)

    sock := connect_server()
    IF sock < 0
        Close(h)
        set_status('Status: SlicerServer does not answer.')
        RETURN FALSE
    ENDIF

    IF send_all(sock, requete) = FALSE
        ok := FALSE
        set_status('Status: upload header failed.')
    ENDIF

    restant := taille
    WHILE (restant > 0) AND ok
        lu := Read(h, g_transfer_buffer, TRANSFER_BLOCK)
        IF lu <= 0
            ok := FALSE
            set_status('Status: STL read error.')
        ELSE
            IF send_bytes(sock, g_transfer_buffer, lu) = FALSE
                ok := FALSE
                set_status('Status: STL transfer interrupted.')
            ENDIF
            IF ok
                g_transfer_sent := g_transfer_sent + lu
                update_transfer_progress(FALSE)
                Delay(UPLOAD_BLOCK_DELAY)
            ENDIF
            restant := restant - lu
        ENDIF
    ENDWHILE
    Close(h)

    IF ok
        g_transfer_sent := g_transfer_size
        update_transfer_progress(TRUE)
        set_status('Status: waiting for server answer...')
        IF tx_transfer_progress THEN set(tx_transfer_progress, MUIA_Text_Contents, 'Transfer: 100 %  waiting server...')
        utilise := recv_response(sock, g_response, 12000, 1500)
        body_to_result(g_response)
        update_job_from_response(g_response)
        IF has_http_success(g_response)
            IF start_slice
                set_status('Status: upload sent, slicing started.')
            ELSE
                update_scale_from_response(g_response)
                set_status('Status: STL info received.')
            ENDIF
        ELSE
            set_status('Status: upload/slice refused.')
        ENDIF
    ELSE
        IF tx_transfer_progress THEN set(tx_transfer_progress, MUIA_Text_Contents, 'Transfer: interrupted.')
    ENDIF

    CloseSocket(sock)
ENDPROC ok AND (utilise > 0) AND has_http_success(g_response)

PROC download_file(idarg:PTR TO CHAR, sortie:PTR TO CHAR)
    DEF sock, recu, h=NIL, header_done=FALSE, ok=FALSE, termine=FALSE
    DEF requete[512]:STRING, header[8192]:STRING, status[256]:STRING, body[1024]:STRING
    DEF header_len=0, pos, i, total=0, ecrit, idle=0

    IF idarg = NIL
        set_status('Status: enter job ID.')
        RETURN FALSE
    ENDIF
    IF sortie = NIL
        set_status('Status: enter G-code destination.')
        RETURN FALSE
    ENDIF

    StringF(requete,
        'GET /download?id=\s HTTP/1.0\r\nHost: \s\r\nConnection: close\r\n\r\n',
        idarg, g_ip)

    set_status('Status: downloading G-code...')

    sock := connect_server()
    IF sock < 0
        set_status('Status: SlicerServer does not answer.')
        RETURN FALSE
    ENDIF

    IF send_all(sock, requete) = FALSE
        CloseSocket(sock)
        set_status('Status: download request failed.')
        RETURN FALSE
    ENDIF

    WHILE termine = FALSE
        recu := Recv(sock, g_transfer_buffer, TRANSFER_BLOCK, 0)
        IF recu <= 0
            idle++
            IF idle >= 250
                termine := TRUE
            ELSE
                Delay(1)
            ENDIF
        ELSE
            idle := 0
            IF header_done = FALSE
                IF header_len + recu >= 8191
                    CloseSocket(sock)
                    set_status('Status: HTTP header too large.')
                    RETURN FALSE
                ENDIF
                FOR i := 0 TO recu-1
                    header[header_len+i] := g_transfer_buffer[i]
                ENDFOR
                header_len := header_len + recu
                header[header_len] := 0
                pos := header_end(header, header_len)
                IF pos > 0
                    header_done := TRUE
                    http_status_line(header, status)
                    IF has_http_success(header) = FALSE
                        IF extract_body(header, body, 1024) THEN set_result(body)
                        CloseSocket(sock)
                        set_status(status)
                        RETURN FALSE
                    ENDIF

                    h := Open(sortie, MODE_NEWFILE)
                    IF h = NIL
                        CloseSocket(sock)
                        set_status('Status: unable to create G-code file.')
                        RETURN FALSE
                    ENDIF

                    ecrit := header_len - pos
                    IF ecrit > 0
                        Write(h, header + pos, ecrit)
                        total := total + ecrit
                    ENDIF
                    ok := TRUE
                ENDIF
            ELSE
                Write(h, g_transfer_buffer, recu)
                total := total + recu
            ENDIF
        ENDIF
    ENDWHILE

    IF h THEN Close(h)
    CloseSocket(sock)

    IF ok
        StringF(g_result, 'G-code received: \s\nSize: \d bytes', sortie, total)
        set_result(g_result)
        set_status('Status: G-code downloaded.')
    ELSE
        set_status('Status: invalid download answer.')
    ENDIF
ENDPROC ok

PROC test_server()
    do_get_to_gui('/status')
ENDPROC

PROC save_from_gui()
    DEF port_text[16]:STRING

    IF read_gui_config()
        IF save_config()
            StringF(port_text, '\d', g_port)
            set(st_port, MUIA_String_Contents, port_text)
            set_status('Status: configuration saved in S:slicer_server.cfg')
        ELSE
            set_status('Status: unable to write S:slicer_server.cfg')
        ENDIF
    ELSE
        set_status('Status: enter PC IP address.')
    ENDIF
ENDPROC

PROC upload_slice_from_gui()
    DEF source, nameptr, scaleptr
    DEF stl[256]:STRING, name[256]:STRING
    DEF scale[32]:STRING

    IF g_busy
        set_status('Status: transfer already running.')
        RETURN
    ENDIF
    g_busy := TRUE

    IF read_gui_config() = FALSE
        set_status('Status: enter PC IP address.')
        g_busy := FALSE
        RETURN
    ENDIF

    IF update_names_from_stl() = FALSE
        set_status('Status: choose a local STL.')
        g_busy := FALSE
        RETURN
    ENDIF

    get(st_stl, MUIA_String_Contents, {source})
    get(st_name, MUIA_String_Contents, {nameptr})
    get(st_scale, MUIA_String_Contents, {scaleptr})

    StrCopy(stl, source, ALL)
    StrCopy(name, nameptr, ALL)
    IF normalize_scale(scaleptr, scale, 32) = FALSE
        set_status('Status: bad scale value. Use 30 or 30%.')
        g_busy := FALSE
        RETURN
    ENDIF
    set(st_scale, MUIA_String_Contents, scale)

    upload_file(stl, name, 'standard', scale, TRUE)
    g_busy := FALSE
ENDPROC

PROC stl_info_from_gui()
    DEF source, nameptr, scaleptr
    DEF stl[256]:STRING, name[256]:STRING
    DEF scale[32]:STRING

    IF g_busy
        set_status('Status: transfer already running.')
        RETURN
    ENDIF
    g_busy := TRUE

    IF read_gui_config() = FALSE
        set_status('Status: enter PC IP address.')
        g_busy := FALSE
        RETURN
    ENDIF

    IF update_names_from_stl() = FALSE
        set_status('Status: choose a local STL.')
        g_busy := FALSE
        RETURN
    ENDIF

    get(st_stl, MUIA_String_Contents, {source})
    get(st_name, MUIA_String_Contents, {nameptr})
    get(st_scale, MUIA_String_Contents, {scaleptr})

    StrCopy(stl, source, ALL)
    StrCopy(name, nameptr, ALL)
    IF normalize_scale(scaleptr, scale, 32) = FALSE
        set_status('Status: bad scale value. Use 30 or 30%.')
        g_busy := FALSE
        RETURN
    ENDIF
    set(st_scale, MUIA_String_Contents, scale)

    upload_file(stl, name, 'standard', scale, FALSE)
    g_busy := FALSE
ENDPROC

PROC last_job()
    do_get_to_gui('/last?log=1')
ENDPROC

PROC list_server_files()
    do_get_to_gui('/files')
ENDPROC

PROC delete_server_file()
    DEF nameptr
    DEF name[256]:STRING, name_enc[256]:STRING, path[320]:STRING

    IF read_gui_config() = FALSE
        set_status('Status: enter PC IP address.')
        RETURN
    ENDIF

    IF selected_server_file(name, 256)
        set(st_name, MUIA_String_Contents, name)
    ELSE
        IF result_has_selection()
            set_status('Status: only STL and G-code files can be deleted.')
            RETURN
        ENDIF
        get(st_name, MUIA_String_Contents, {nameptr})
        IF nameptr <> NIL
            IF nameptr[] <> 0
                StrCopy(name, nameptr, ALL)
            ELSE
                set_status('Status: select a server file or enter PC STL name.')
                RETURN
            ENDIF
        ELSE
            set_status('Status: select a server file or enter PC STL name.')
            RETURN
        ENDIF
    ENDIF

    IF encode_path(name, name_enc, 256) = FALSE
        set_status('Status: bad PC file name.')
        RETURN
    ENDIF

    StringF(path, '/delete?name=\s&type=all', name_enc)
    do_get_to_gui(path)
ENDPROC

PROC read_job()
    DEF idptr, path[64]:STRING

    get(st_job, MUIA_String_Contents, {idptr})
    IF idptr = NIL
        set_status('Status: enter job ID.')
        RETURN
    ENDIF
    IF idptr[] = 0
        set_status('Status: enter job ID.')
        RETURN
    ENDIF
    StringF(path, '/job?id=\s&log=1', idptr)
    do_get_to_gui(path)
ENDPROC

PROC download_from_gui()
    DEF idptr, outptr

    IF read_gui_config() = FALSE
        set_status('Status: enter PC IP address.')
        RETURN
    ENDIF

    get(st_job, MUIA_String_Contents, {idptr})
    get(st_gcode, MUIA_String_Contents, {outptr})
    download_file(idptr, outptr)
ENDPROC

PROC clear_gui()
    set(st_stl, MUIA_String_Contents, '')
    set(st_name, MUIA_String_Contents, '')
    set(st_scale, MUIA_String_Contents, '100')
    set(st_gcode, MUIA_String_Contents, 'RAM:modele.gcode')
    set(st_job, MUIA_String_Contents, '')
    set_status('Status: ready.')
    set_result('Result: no job yet.')
    reset_transfer_progress('Transfer: -- %')
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
    g_busy := FALSE

    IF (muimasterbase := OpenLibrary(MUIMASTER_NAME, MUIMASTER_VMIN)) = NIL THEN Raise(1)
    IF (socketbase := OpenLibrary('bsdsocket.library', 4)) = NIL THEN Raise(2)

    li_result := ListObject,
        MUIA_Frame, MUIV_Frame_InputList,
    End

    ap_app := ApplicationObject,
        MUIA_Application_Title, 'SlicerMUI',
        MUIA_Application_Version, '0.1',
        MUIA_Application_Author, 'Denis Costils',
        MUIA_Application_Description, 'Amiga frontend for PC PrusaSlicer bridge',
        MUIA_Application_Base, 'SLCM',

        SubWindow,
            wi_main := WindowObject,
                MUIA_Window_Title, 'Slicer Bridge',
                MUIA_Window_ID, "SLCM",
                MUIA_Width, 560,
                MUIA_Height, 300,
                WindowContents, VGroup,

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        MUIA_FrameTitle, 'PC SlicerServer',
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

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        MUIA_FrameTitle, 'STL / G-code',
                        MUIA_Group_Columns, 2,
                        Child, TextObject, MUIA_Text_Contents, 'Local STL', End,
                        Child, PopaslObject,
                            MUIA_Popasl_Type, 0,
                            MUIA_Popstring_String, st_stl := StringObject,
                                StringFrame,
                                MUIA_String_Contents, '',
                                MUIA_String_MaxLen, 255,
                            End,
                            MUIA_Popstring_Button, PopButton(MUII_PopFile),
                        End,
                        Child, TextObject, MUIA_Text_Contents, 'PC STL name', End,
                        Child, st_name := StringObject,
                            StringFrame,
                            MUIA_String_Contents, '',
                            MUIA_String_MaxLen, 255,
                        End,
                        Child, TextObject, MUIA_Text_Contents, 'Scale %', End,
                        Child, st_scale := StringObject,
                            StringFrame,
                            MUIA_String_Contents, '100',
                            MUIA_String_MaxLen, 31,
                        End,
                        Child, TextObject, MUIA_Text_Contents, 'G-code output', End,
                        Child, PopaslObject,
                            MUIA_Popasl_Type, 0,
                            MUIA_Popstring_String, st_gcode := StringObject,
                                StringFrame,
                                MUIA_String_Contents, 'RAM:modele.gcode',
                                MUIA_String_MaxLen, 255,
                            End,
                            MUIA_Popstring_Button, PopButton(MUII_PopFile),
                        End,
                        Child, TextObject, MUIA_Text_Contents, 'Job ID', End,
                        Child, st_job := StringObject,
                            StringFrame,
                            MUIA_String_Contents, '',
                            MUIA_String_MaxLen, 31,
                        End,
                    End,

                    Child, HGroup,
                        Child, bt_test := bouton('Test'),
                        Child, bt_save := bouton('Save'),
                        Child, bt_stlinfo := bouton('STL Info'),
                        Child, bt_uploadslice := bouton('Upload+Slice'),
                    End,
                    Child, ga_transfer_progress := GaugeObject,
                        GaugeFrame,
                        MUIA_FixHeight, 12,
                        MUIA_Gauge_Horiz, MUI_TRUE,
                        MUIA_Gauge_Max, 100,
                        MUIA_Gauge_Current, 0,
                    End,
                    Child, tx_transfer_progress := TextObject,
                        MUIA_Text_Contents, 'Transfer: -- %',
                    End,
                    Child, HGroup,
                        Child, bt_last := bouton('Last'),
                        Child, bt_job := bouton('Job'),
                        Child, bt_download := bouton('Download'),
                    End,
                    Child, HGroup,
                        Child, bt_files := bouton('Files'),
                        Child, bt_delete := bouton('Delete'),
                        Child, bt_clear := bouton('Clear'),
                        Child, bt_quit := bouton('Quit'),
                    End,

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        MUIA_FrameTitle, 'Information',
                        Child, tx_status := TextObject,
                            MUIA_Text_Contents, 'Status: ready.',
                        End,
                        Child, lv_result := ListviewObject,
                            MUIA_Listview_Input, MUI_TRUE,
                            MUIA_Listview_List, li_result,
                        End,
                    End,
                End,
            End,
        End

    IF ap_app = NIL THEN Raise(3)

    doMethod(wi_main, [MUIM_Notify, MUIA_Window_CloseRequest, MUI_TRUE, ap_app, 2, MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])
    doMethod(bt_test, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_TEST])
    doMethod(bt_save, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_SAVE])
    doMethod(bt_stlinfo, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_STLINFO])
    doMethod(bt_uploadslice, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_UPLOADSLICE])
    doMethod(bt_last, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_LAST])
    doMethod(bt_job, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_JOB])
    doMethod(bt_download, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_DOWNLOAD])
    doMethod(bt_files, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_FILES])
    doMethod(bt_delete, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_DELETE])
    doMethod(bt_clear, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_CLEAR])
    doMethod(bt_quit, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])

    set(wi_main, MUIA_Window_Open, MUI_TRUE)

    running := TRUE
    WHILE running
        result := doMethod(ap_app, [MUIM_Application_Input, {signal}])
        IF result <> MUIV_Application_ReturnID_Quit
            SELECT result
                CASE ID_TEST
                    test_server()
                CASE ID_SAVE
                    save_from_gui()
                CASE ID_STLINFO
                    stl_info_from_gui()
                CASE ID_UPLOADSLICE
                    upload_slice_from_gui()
                CASE ID_LAST
                    last_job()
                CASE ID_JOB
                    read_job()
                CASE ID_DOWNLOAD
                    download_from_gui()
                CASE ID_FILES
                    list_server_files()
                CASE ID_DELETE
                    delete_server_file()
                CASE ID_CLEAR
                    clear_gui()
            ENDSELECT
        ELSE
            running := FALSE
        ENDIF

        IF running
            IF signal <> 0 THEN Wait(signal) ELSE Delay(10)
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
        CASE 1 ; WriteF('Cannot open muimaster.library.\n')
        CASE 2 ; WriteF('Cannot open bsdsocket.library.\n')
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
