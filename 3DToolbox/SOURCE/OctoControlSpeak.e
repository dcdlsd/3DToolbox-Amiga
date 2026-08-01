OPT PREPROCESS
OPT OSVERSION=39
OPT LARGE

MODULE 'muimaster', 'libraries/mui'
MODULE 'utility/tagitem', 'utility/hooks'
MODULE 'intuition/classes', 'intuition/classusr'
MODULE 'bsdsocket'
MODULE 'amitcp/sys/socket'
MODULE 'amitcp/netinet/in'
MODULE 'dos/dos', 'libraries/asl'

#define CFG_FILE 'S:octocontrol_native.cfg'
#define SPEECH_CFG_FILE 'S:octocontrol_speech.cfg'
#define IMAGE_TINA '5:PROGDIR:tina2s.iff'
#define UPLOAD_BLOCK 8192
#define FILES_BUFFER 8192
#define FIONBIO $8004667E

ENUM ID_SAVE=1,
     ID_TEST,
     ID_STATUS,
     ID_JOB,
     ID_M105,
     ID_HOME,
     ID_MOTORSOFF,
     ID_PLA,
     ID_HEATOFF,
     ID_PAUSE,
     ID_RESUME,
     ID_CANCEL,
     ID_PRECHAUFFE,
     ID_INSERTION,
     ID_RETRAIT,
     ID_FILES,
     ID_PRINTSELECTED,
     ID_DELETEFILE,
     ID_EMERGENCY,
     ID_CONNECT,
     ID_RAZ,
     ID_HELP,
     ID_ABOUT,
     ID_UPLOAD,
     ID_UPLOADPRINT,
     ID_MONITOR_CLOSE,
     ID_MAIN_HIDE,
     ID_MAIN_SHOW

DEF g_ip[64]:STRING
DEF g_api[256]:STRING
DEF g_port
DEF g_result[256]:STRING
DEF g_response[8192]:STRING
DEF g_files[FILES_BUFFER]:STRING
DEF g_upload_buffer[16384]:STRING
DEF g_upload_error[256]:STRING
DEF g_upload_size, g_upload_total, g_upload_sent
DEF g_upload_errno
DEF g_upload_last_percent
DEF g_job_file_line[320]:STRING
DEF g_job_state_line[128]:STRING
DEF g_job_progress_line[128]:STRING
DEF g_job_time_line[128]:STRING
DEF g_job_left_line[128]:STRING
DEF g_status_state_line[160]:STRING
DEF g_status_tool_line[160]:STRING
DEF g_status_bed_line[160]:STRING
DEF g_monitor_file_line[320]:STRING
DEF g_progress_short[32]:STRING
DEF g_status_state_raw[80]:STRING
DEF g_job_state_raw[80]:STRING
DEF g_job_file_raw[256]:STRING
DEF g_nozzle_actual, g_nozzle_target
DEF g_voice_last_state[80]:STRING
DEF g_voice_temp_hot, g_voice_printing_seen, g_voice_offline_announced
DEF sp_temp_ok[128]:STRING
DEF sp_printing[128]:STRING
DEF sp_paused[128]:STRING
DEF sp_pausing[128]:STRING
DEF sp_resuming[128]:STRING
DEF sp_done[128]:STRING
DEF sp_status_ready[128]:STRING
DEF sp_status_offline[128]:STRING
DEF sp_status_received[128]:STRING
DEF sp_octoprint_offline[128]:STRING
DEF sp_preheat[128]:STRING
DEF sp_heat_off[128]:STRING
DEF sp_pause[128]:STRING
DEF sp_resume[128]:STRING
DEF sp_cancel[128]:STRING
DEF sp_nozzle_heat[128]:STRING
DEF sp_insert[128]:STRING
DEF sp_retract[128]:STRING
DEF sp_emergency[128]:STRING
DEF sp_connect[128]:STRING

DEF ap_native, wi_native
DEF wi_monitor
DEF st_ip, st_port, st_api
DEF bt_save, bt_test, bt_status, bt_job, bt_m105, bt_quit, bt_mini
DEF bt_home, bt_motorsoff, bt_pla, bt_heatoff
DEF bt_pause, bt_resume, bt_cancel
DEF bt_prechauffe, bt_insertion, bt_retrait
DEF bt_files, bt_printselected, bt_deletefile
DEF bt_emergency
DEF bt_connect, bt_raz
DEF bt_upload, bt_uploadprint
DEF bt_monitor_main
DEF mi_help, mi_about
DEF st_upload
DEF ga_upload_progress
DEF tx_upload_progress
DEF li_result, lv_result, li_files, lv_files
DEF tx_monitor_state, tx_monitor_tool, tx_monitor_bed, tx_monitor_file, tx_monitor_job, tx_monitor_left
DEF monitor_open, monitor_ticks, main_open

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

PROC same_text(a:PTR TO CHAR, b:PTR TO CHAR)
    WHILE a[] AND b[]
        IF a[] <> b[] THEN RETURN FALSE
        a++
        b++
    ENDWHILE
ENDPROC (a[] = 0) AND (b[] = 0)

PROC voice_say(texte:PTR TO CHAR)
    DEF commande[256]:STRING
    DEF entree, sortie

    IF texte[0] = 0 THEN RETURN

    StringF(commande, 'Run >NIL: SAY "\s"', texte)
    entree := Open('NIL:', MODE_OLDFILE)
    sortie := Open('NIL:', MODE_NEWFILE)
    Execute(commande, entree, sortie)
    IF entree THEN Close(entree)
    IF sortie THEN Close(sortie)
ENDPROC

PROC reset_voice_state()
    g_voice_temp_hot := FALSE
    g_voice_printing_seen := FALSE
    g_voice_offline_announced := FALSE
    g_voice_last_state[0] := 0
ENDPROC

PROC set_default_speech()
    StrCopy(sp_temp_ok, 'La buse est a temperature', ALL)
    StrCopy(sp_printing, 'L impression est en cours', ALL)
    StrCopy(sp_paused, 'L impression est en pause', ALL)
    StrCopy(sp_pausing, 'Pause de l impression demandee', ALL)
    StrCopy(sp_resuming, 'Reprise de l impression', ALL)
    StrCopy(sp_done, 'Impression terminee', ALL)
    StrCopy(sp_status_ready, 'Imprimante prete', ALL)
    StrCopy(sp_status_offline, 'Imprimante hors ligne', ALL)
    StrCopy(sp_status_received, 'Statut de l imprimante recu', ALL)
    StrCopy(sp_octoprint_offline, 'OctoPrint est hors ligne', ALL)
    StrCopy(sp_preheat, 'Prechauffage de la buse', ALL)
    StrCopy(sp_heat_off, 'Chauffe arretee', ALL)
    StrCopy(sp_pause, 'Pause impression', ALL)
    StrCopy(sp_resume, 'Reprise impression', ALL)
    StrCopy(sp_cancel, 'Impression annulee', ALL)
    StrCopy(sp_nozzle_heat, 'Chauffe de la buse demandee', ALL)
    StrCopy(sp_insert, 'Insertion du filament', ALL)
    StrCopy(sp_retract, 'Retrait du filament', ALL)
    StrCopy(sp_emergency, 'Arret d urgence', ALL)
    StrCopy(sp_connect, 'Connexion de l imprimante', ALL)
ENDPROC

PROC speech_line(ligne:PTR TO CHAR)
    IF begins(ligne, 'TEMP_OK=')
        copy_value(sp_temp_ok, ligne + 8, 128)
    ELSEIF begins(ligne, 'PRINTING=')
        copy_value(sp_printing, ligne + 9, 128)
    ELSEIF begins(ligne, 'PAUSED=')
        copy_value(sp_paused, ligne + 7, 128)
    ELSEIF begins(ligne, 'PAUSING=')
        copy_value(sp_pausing, ligne + 8, 128)
    ELSEIF begins(ligne, 'RESUMING=')
        copy_value(sp_resuming, ligne + 9, 128)
    ELSEIF begins(ligne, 'DONE=')
        copy_value(sp_done, ligne + 5, 128)
    ELSEIF begins(ligne, 'STATUS_READY=')
        copy_value(sp_status_ready, ligne + 13, 128)
    ELSEIF begins(ligne, 'STATUS_OFFLINE=')
        copy_value(sp_status_offline, ligne + 15, 128)
    ELSEIF begins(ligne, 'STATUS_RECEIVED=')
        copy_value(sp_status_received, ligne + 16, 128)
    ELSEIF begins(ligne, 'OCTOPRINT_OFFLINE=')
        copy_value(sp_octoprint_offline, ligne + 18, 128)
    ELSEIF begins(ligne, 'PREHEAT=')
        copy_value(sp_preheat, ligne + 8, 128)
    ELSEIF begins(ligne, 'HEAT_OFF=')
        copy_value(sp_heat_off, ligne + 9, 128)
    ELSEIF begins(ligne, 'PAUSE=')
        copy_value(sp_pause, ligne + 6, 128)
    ELSEIF begins(ligne, 'RESUME=')
        copy_value(sp_resume, ligne + 7, 128)
    ELSEIF begins(ligne, 'CANCEL=')
        copy_value(sp_cancel, ligne + 7, 128)
    ELSEIF begins(ligne, 'NOZZLE_HEAT=')
        copy_value(sp_nozzle_heat, ligne + 12, 128)
    ELSEIF begins(ligne, 'INSERT=')
        copy_value(sp_insert, ligne + 7, 128)
    ELSEIF begins(ligne, 'RETRACT=')
        copy_value(sp_retract, ligne + 8, 128)
    ELSEIF begins(ligne, 'EMERGENCY=')
        copy_value(sp_emergency, ligne + 10, 128)
    ELSEIF begins(ligne, 'CONNECT=')
        copy_value(sp_connect, ligne + 8, 128)
    ENDIF
ENDPROC

PROC load_speech_config()
    DEF h, buffer[4096]:STRING
    DEF len, i, start=0

    set_default_speech()
    IF (h := Open(SPEECH_CFG_FILE, MODE_OLDFILE)) = NIL THEN RETURN FALSE
    len := Read(h, buffer, 4095)
    Close(h)
    IF len <= 0 THEN RETURN FALSE
    buffer[len] := 0

    FOR i := 0 TO len
        IF (buffer[i] = 13) OR (buffer[i] = 10) OR (buffer[i] = 0)
            buffer[i] := 0
            IF i > start THEN speech_line(buffer + start)
            start := i + 1
        ENDIF
    ENDFOR
ENDPROC TRUE

PROC append_text(destination:PTR TO CHAR, pos, source:PTR TO CHAR)
    WHILE source[]
        destination[pos++] := source[]
        source++
    ENDWHILE
ENDPROC pos

PROC append_crlf(destination:PTR TO CHAR, pos)
    destination[pos++] := 13
    destination[pos++] := 10
ENDPROC pos

PROC build_upload_parts(partie:PTR TO CHAR, fin:PTR TO CHAR, boundary:PTR TO CHAR, nom:PTR TO CHAR)
    DEF pos=0

    pos := append_text(partie, pos, '--')
    pos := append_text(partie, pos, boundary)
    pos := append_crlf(partie, pos)
    pos := append_text(partie, pos, 'Content-Disposition: form-data; name="file"; filename="')
    pos := append_text(partie, pos, nom)
    pos := append_text(partie, pos, '"')
    pos := append_crlf(partie, pos)
    pos := append_text(partie, pos, 'Content-Type: application/octet-stream')
    pos := append_crlf(partie, pos)
    pos := append_crlf(partie, pos)
    partie[pos] := 0

    pos := 0
    pos := append_crlf(fin, pos)
    pos := append_text(fin, pos, '--')
    pos := append_text(fin, pos, boundary)
    pos := append_text(fin, pos, '--')
    pos := append_crlf(fin, pos)
    fin[pos] := 0
ENDPROC

PROC build_upload_request(requete:PTR TO CHAR, boundary:PTR TO CHAR, total)
    DEF pos=0, nombre[32]:STRING

    StringF(nombre, '\d', total)
    pos := append_text(requete, pos, 'POST /api/files/local HTTP/1.0')
    pos := append_crlf(requete, pos)
    pos := append_text(requete, pos, 'Host: ')
    pos := append_text(requete, pos, g_ip)
    pos := append_crlf(requete, pos)
    pos := append_text(requete, pos, 'X-Api-Key: ')
    pos := append_text(requete, pos, g_api)
    pos := append_crlf(requete, pos)
    pos := append_text(requete, pos, 'Content-Length: ')
    pos := append_text(requete, pos, nombre)
    pos := append_crlf(requete, pos)
    pos := append_text(requete, pos, 'Connection: close')
    pos := append_crlf(requete, pos)
    pos := append_text(requete, pos, 'Content-Type: multipart/form-data; boundary=')
    pos := append_text(requete, pos, boundary)
    pos := append_crlf(requete, pos)
    pos := append_crlf(requete, pos)
    requete[pos] := 0
ENDPROC

/* Errno() est le vecteur -$A2 de bsdsocket.library. */
PROC socket_errno()
    DEF resultat
    MOVEA.L socketbase, A6
    JSR -162(A6)
    MOVE.L D0, resultat
ENDPROC resultat

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

PROC save_config()
    DEF h, texte[512]:STRING

    h := Open(CFG_FILE, MODE_NEWFILE)
    IF h = NIL THEN RETURN FALSE
    StringF(texte, 'OCTOPRINT=\s:\d\nAPIKEY=\s\n', g_ip, g_port, g_api)
    Write(h, texte, StrLen(texte))
    Close(h)
ENDPROC TRUE

PROC read_gui_config()
    DEF source

    get(st_ip, MUIA_String_Contents, {source})
    IF source THEN copy_value(g_ip, source, 64)

    get(st_port, MUIA_String_Contents, {source})
    IF source THEN g_port := Val(source)

    get(st_api, MUIA_String_Contents, {source})
    IF source THEN copy_value(g_api, source, 256)

    IF g_port <= 0 THEN g_port := 80
ENDPROC (g_ip[0] <> 0) AND (g_api[0] <> 0)

PROC send_bytes(sock, data:PTR TO CHAR, taille)
    DEF position=0, envoye, essais=0

    WHILE position < taille
        envoye := Send(sock, data + position, taille - position, 0)
        IF envoye <= 0
            /* AmiTCP peut signaler temporairement que le tampon TCP est plein. */
            essais++
            IF essais >= 100
                g_upload_errno := socket_errno()
                RETURN FALSE
            ENDIF
            Delay(1)
        ELSE
            position := position + envoye
            essais := 0
        ENDIF
    ENDWHILE
ENDPROC TRUE

PROC send_all(sock, texte:PTR TO CHAR)
ENDPROC send_bytes(sock, texte, StrLen(texte))

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

PROC http_request(method:PTR TO CHAR, path:PTR TO CHAR, body:PTR TO CHAR, reponse:PTR TO CHAR, max)
    DEF adresse:sockaddr_in
    DEF requete[1024]:STRING
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

PROC http_request_fast(method:PTR TO CHAR, path:PTR TO CHAR, body:PTR TO CHAR, reponse:PTR TO CHAR, max)
    DEF adresse:sockaddr_in
    DEF requete[1024]:STRING
    DEF sock, taille_body, recu, utilise=0, essais=0

    taille_body := StrLen(body)
    StringF(requete,
        '\s \s HTTP/1.0\r\nHost: \s\r\nX-Api-Key: \s\r\nContent-Type: application/json\r\nContent-Length: \d\r\nConnection: close\r\n\r\n\s',
        method, path, g_ip, g_api, taille_body, body)

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

PROC list_clear(listobj)
    doMethod(listobj, [MUIM_List_Clear])
ENDPROC

PROC list_add(listobj, texte)
    doMethod(listobj, [MUIM_List_InsertSingle, texte, MUIV_List_Insert_Bottom])
ENDPROC

PROC show_message(texte)
    StrCopy(g_result, texte, ALL)
    list_clear(li_result)
    list_add(li_result, g_result)
ENDPROC

PROC http_status_line(destination:PTR TO CHAR)
    DEF i=0, pos=0, debut=0

    WHILE (g_response[i] = 13) OR (g_response[i] = 10) OR (g_response[i] = 32)
        i++
    ENDWHILE
    IF begins(g_response + i, 'HTTP/') = FALSE
        i := 0
        WHILE (i < 64) AND g_response[i]
            IF begins(g_response + i, 'HTTP/')
                debut := i
                i := 64
            ENDIF
            i++
        ENDWHILE
        i := debut
    ENDIF

    WHILE g_response[i] AND (g_response[i] <> 13) AND (g_response[i] <> 10) AND (pos < 255)
        destination[pos] := g_response[i]
        i++
        pos++
    ENDWHILE
    destination[pos] := 0
ENDPROC

PROC upload_progress(force)
    DEF percent, sent_k, total_k

    IF g_upload_size <= 0 THEN RETURN
    IF g_upload_size > 100000
        percent := ((g_upload_sent / 1024) * 100) / (g_upload_size / 1024)
    ELSE
        percent := (g_upload_sent * 100) / g_upload_size
    ENDIF
    IF percent > 100 THEN percent := 100

    IF force OR (percent <> g_upload_last_percent)
        g_upload_last_percent := percent
        sent_k := g_upload_sent / 1024
        total_k := g_upload_size / 1024
        IF ga_upload_progress THEN set(ga_upload_progress, MUIA_Gauge_Current, percent)
        StringF(g_result, 'Envoi: \d %  (\d / \d Ko)', percent, sent_k, total_k)
        IF tx_upload_progress THEN set(tx_upload_progress, MUIA_Text_Contents, g_result)
    ENDIF
ENDPROC

PROC has_http_success()
    DEF i=0

    /* Cherche HTTP/1.x 2xx au debut de la reponse, meme si la pile ajoute du bruit. */
    WHILE (i < 32) AND g_response[i]
        IF begins(g_response + i, 'HTTP/')
            IF g_response[i+9] = 50 THEN RETURN TRUE
            RETURN FALSE
        ENDIF
        i++
    ENDWHILE
ENDPROC FALSE

PROC request_reply(method, path, body, label)
    IF read_gui_config() = FALSE
        show_message('Indique une IP et une cle API OctoPrint.')
        RETURN FALSE
    ENDIF

    StringF(g_result, '\s...', label)
    show_message(g_result)
    IF http_request(method, path, body, g_response, 8192) = FALSE
        StringF(g_result, '\s: OctoPrint ne repond pas.', label)
        show_message(g_result)
        RETURN FALSE
    ENDIF

    IF has_http_success()
        StringF(g_result, '\s: commande acceptee.', label)
        show_message(g_result)
        RETURN TRUE
    ELSE
        StringF(g_result, '\s: OctoPrint a refuse la commande.', label)
        show_message(g_result)
        RETURN FALSE
    ENDIF
ENDPROC FALSE

PROC request_reply_quiet(method, path, body)
    IF read_gui_config() = FALSE THEN RETURN FALSE
    IF http_request_fast(method, path, body, g_response, 8192) = FALSE THEN RETURN FALSE
ENDPROC has_http_success()

PROC test_octoprint()
    IF request_reply('GET', '/api/version', '', 'Test OctoPrint')
        list_clear(li_result)
        list_add(li_result, 'OctoPrint est en ligne.')
    ENDIF
ENDPROC

PROC send_m105()
    IF request_reply('POST', '/api/printer/command', '{"commands":["M105"]}', 'M105')
        list_clear(li_result)
        list_add(li_result, 'M105 envoye a l imprimante.')
        list_add(li_result, 'Commande acceptee par OctoPrint.')
        list_add(li_result, 'Clique Status pour lire les temperatures.')
    ENDIF
ENDPROC

PROC clean_value(source:PTR TO CHAR, destination:PTR TO CHAR, max)
    IF (source[0] = 0) OR begins(source, 'null')
        StrCopy(destination, '--', ALL)
    ELSE
        copy_value(destination, source, max)
    ENDIF
ENDPROC

PROC fetch_printer_status()
    DEF etat[80]:STRING, buse[64]:STRING, buse_cible[64]:STRING
    DEF plateau[64]:STRING, plateau_cible[64]:STRING
    DEF valeur_etat[80]:STRING, valeur_buse[64]:STRING, valeur_buse_cible[64]:STRING
    DEF valeur_plateau[64]:STRING, valeur_plateau_cible[64]:STRING
    DEF pos_buse, pos_plateau

    IF request_reply_quiet('GET', '/api/printer', '') = FALSE THEN RETURN FALSE

    pos_buse := find_text(g_response, '"tool0"', 0)
    pos_plateau := find_text(g_response, '"bed"', 0)
    IF pos_buse < 0 THEN pos_buse := 0
    IF pos_plateau < 0 THEN pos_plateau := 0

    json_value(g_response, '"text"', 0, etat, 80)
    json_value(g_response, '"actual"', pos_buse, buse, 64)
    json_value(g_response, '"target"', pos_buse, buse_cible, 64)
    json_value(g_response, '"actual"', pos_plateau, plateau, 64)
    json_value(g_response, '"target"', pos_plateau, plateau_cible, 64)
    clean_value(etat, valeur_etat, 80)
    clean_value(buse, valeur_buse, 64)
    clean_value(buse_cible, valeur_buse_cible, 64)
    clean_value(plateau, valeur_plateau, 64)
    clean_value(plateau_cible, valeur_plateau_cible, 64)

    StrCopy(g_status_state_raw, valeur_etat, ALL)
    g_nozzle_actual := Val(valeur_buse)
    g_nozzle_target := Val(valeur_buse_cible)
    StringF(g_status_state_line, 'Etat: \s', valeur_etat)
    StringF(g_status_tool_line, 'Buse: \s C / cible \s C', valeur_buse, valeur_buse_cible)
    StringF(g_status_bed_line, 'Plateau: \s C / cible \s C', valeur_plateau, valeur_plateau_cible)
ENDPROC TRUE

PROC voice_monitor_events()
    IF g_nozzle_target > 0
        IF (g_nozzle_actual >= (g_nozzle_target - 2)) AND (g_voice_temp_hot = FALSE)
            voice_say(sp_temp_ok)
            g_voice_temp_hot := TRUE
        ELSEIF g_nozzle_actual < (g_nozzle_target - 6)
            g_voice_temp_hot := FALSE
        ENDIF
    ELSE
        g_voice_temp_hot := FALSE
    ENDIF

    IF g_job_file_raw[0]
        g_voice_printing_seen := TRUE
        IF same_text(g_job_state_raw, g_voice_last_state) = FALSE
            IF same_text(g_job_state_raw, 'Printing')
                voice_say(sp_printing)
            ELSEIF same_text(g_job_state_raw, 'Paused')
                voice_say(sp_paused)
            ELSEIF same_text(g_job_state_raw, 'Pausing')
                voice_say(sp_pausing)
            ELSEIF same_text(g_job_state_raw, 'Resuming')
                voice_say(sp_resuming)
            ENDIF
            StrCopy(g_voice_last_state, g_job_state_raw, ALL)
        ENDIF
    ELSE
        IF g_voice_printing_seen
            voice_say(sp_done)
            g_voice_printing_seen := FALSE
            g_voice_last_state[0] := 0
        ENDIF
    ENDIF

    g_voice_offline_announced := FALSE
ENDPROC

PROC voice_status_now()
    IF same_text(g_status_state_raw, 'Operational')
        voice_say(sp_status_ready)
    ELSEIF same_text(g_status_state_raw, 'Printing')
        voice_say(sp_printing)
    ELSEIF same_text(g_status_state_raw, 'Paused')
        voice_say(sp_paused)
    ELSEIF same_text(g_status_state_raw, 'Offline')
        voice_say(sp_status_offline)
    ELSE
        voice_say(sp_status_received)
    ENDIF
ENDPROC

PROC update_monitor_window()
    IF tx_monitor_state
        set(tx_monitor_state, MUIA_Text_Contents, g_status_state_line)
        set(tx_monitor_tool, MUIA_Text_Contents, g_status_tool_line)
        set(tx_monitor_bed, MUIA_Text_Contents, g_status_bed_line)
        set(tx_monitor_file, MUIA_Text_Contents, g_monitor_file_line)
        set(tx_monitor_job, MUIA_Text_Contents, g_job_progress_line)
        set(tx_monitor_left, MUIA_Text_Contents, g_job_left_line)
    ENDIF
ENDPROC

PROC monitor_offline()
    monitor_open := FALSE
    monitor_ticks := 0
    IF g_voice_offline_announced = FALSE
        voice_say(sp_octoprint_offline)
        g_voice_offline_announced := TRUE
    ENDIF
    g_voice_temp_hot := FALSE
    StrCopy(g_status_state_line, 'Etat: OctoPrint hors ligne', ALL)
    StrCopy(g_status_tool_line, 'Buse: -- C / cible -- C', ALL)
    StrCopy(g_status_bed_line, 'Plateau: -- C / cible -- C', ALL)
    StrCopy(g_monitor_file_line, 'Fichier: --', ALL)
    StrCopy(g_job_progress_line, 'Avancement: -- %', ALL)
    StrCopy(g_job_left_line, 'Auto refresh stoppe', ALL)
    update_monitor_window()
ENDPROC

PROC refresh_monitor_status()
    IF fetch_printer_status()
        fetch_job_status()
    ELSE
        monitor_offline()
        RETURN
    ENDIF
    voice_monitor_events()
    update_monitor_window()
ENDPROC

PROC read_printer_status()
    IF fetch_printer_status() = FALSE
        show_message('Status: impossible de lire OctoPrint.')
        monitor_offline()
        RETURN
    ENDIF

    fetch_job_status()
    voice_status_now()
    voice_monitor_events()
    list_clear(li_result)
    list_add(li_result, 'ETAT IMPRIMANTE')
    list_add(li_result, g_status_state_line)
    list_add(li_result, g_status_tool_line)
    list_add(li_result, g_status_bed_line)
    update_monitor_window()
ENDPROC

PROC find_text(texte:PTR TO CHAR, marque:PTR TO CHAR, depart)
    WHILE texte[depart]
        IF begins(texte + depart, marque) THEN RETURN depart
        depart++
    ENDWHILE
ENDPROC -1

PROC json_value(texte:PTR TO CHAR, marque:PTR TO CHAR, depart, destination:PTR TO CHAR, max)
    DEF pos, i=0, entre_guillemets=FALSE, termine=FALSE

    destination[0] := 0
    pos := find_text(texte, marque, depart)
    IF pos < 0 THEN RETURN FALSE
    pos := pos + StrLen(marque)
    WHILE texte[pos] AND (texte[pos] <> 58)
        pos++
    ENDWHILE
    IF texte[pos] <> 58 THEN RETURN FALSE
    pos++
    WHILE (texte[pos] = 32) OR (texte[pos] = 9) OR (texte[pos] = 13) OR (texte[pos] = 10)
        pos++
    ENDWHILE
    IF texte[pos] = 34
        entre_guillemets := TRUE
        pos++
    ENDIF

    WHILE texte[pos] AND (termine = FALSE) AND (i < max-1)
        IF entre_guillemets
            IF texte[pos] = 34
                termine := TRUE
            ELSE
                destination[i++] := texte[pos]
            ENDIF
        ELSE
            IF (texte[pos] = 44) OR (texte[pos] = 125) OR (texte[pos] = 93) OR (texte[pos] = 13) OR (texte[pos] = 10)
                termine := TRUE
            ELSE
                destination[i++] := texte[pos]
            ENDIF
        ENDIF
        pos++
    ENDWHILE
    destination[i] := 0
ENDPROC i > 0

PROC readable_time(source:PTR TO CHAR, destination:PTR TO CHAR)
    DEF total, heures, minutes, secondes

    IF (source[0] = 0) OR begins(source, 'null')
        StrCopy(destination, '--', ALL)
        RETURN
    ENDIF
    total := Val(source)
    heures := total / 3600
    minutes := (total - (heures * 3600)) / 60
    secondes := total - (heures * 3600) - (minutes * 60)
    IF heures > 0
        StringF(destination, '\dh \dmin', heures, minutes)
    ELSEIF minutes > 0
        StringF(destination, '\dmin \ds', minutes, secondes)
    ELSE
        StringF(destination, '\ds', secondes)
    ENDIF
ENDPROC

PROC short_percent(source:PTR TO CHAR, destination:PTR TO CHAR)
    DEF i=0, point=-1, maxcopy

    IF (source[0] = 0) OR begins(source, 'null')
        StrCopy(destination, '--', ALL)
        RETURN
    ENDIF

    WHILE source[i] AND (i < 30)
        IF source[i] = 46 THEN point := i
        i++
    ENDWHILE

    IF point >= 0
        maxcopy := point + 2
    ELSE
        maxcopy := i
    ENDIF
    IF maxcopy > 30 THEN maxcopy := 30

    i := 0
    WHILE source[i] AND (i < maxcopy)
        destination[i] := source[i]
        i++
    ENDWHILE
    destination[i] := 0
ENDPROC

PROC fetch_job_status()
    DEF fichier[256]:STRING, etat[80]:STRING, avance[64]:STRING
    DEF restant[64]:STRING, restant_lisible[64]:STRING

    IF request_reply_quiet('GET', '/api/job', '') = FALSE THEN RETURN FALSE

    json_value(g_response, '"name"', 0, fichier, 256)
    json_value(g_response, '"state"', 0, etat, 80)
    json_value(g_response, '"completion"', 0, avance, 64)
    json_value(g_response, '"printTimeLeft"', 0, restant, 64)
    readable_time(restant, restant_lisible)
    clean_value(fichier, g_job_file_raw, 256)
    clean_value(etat, g_job_state_raw, 80)

    IF (fichier[0] = 0) OR begins(fichier, 'null')
        g_job_file_raw[0] := 0
        IF etat[0]
            StringF(g_job_progress_line, 'Impression: \s', etat)
        ELSE
            StrCopy(g_job_progress_line, 'Impression: aucune', ALL)
        ENDIF
        StrCopy(g_job_left_line, 'Temps restant: --', ALL)
        StrCopy(g_monitor_file_line, 'Fichier: --', ALL)
    ELSE
        short_percent(avance, g_progress_short)
        StringF(g_job_progress_line, 'Avancement: \s %', g_progress_short)
        StringF(g_job_left_line, 'Temps restant: \s', restant_lisible)
        StringF(g_monitor_file_line, 'Fichier: \s', fichier)
    ENDIF
ENDPROC TRUE

PROC read_job()
    DEF fichier[256]:STRING, etat[80]:STRING, avance[64]:STRING
    DEF temps[64]:STRING, restant[64]:STRING
    DEF temps_lisible[64]:STRING, restant_lisible[64]:STRING

    IF request_reply('GET', '/api/job', '', 'Lecture impression') = FALSE THEN RETURN

    json_value(g_response, '"name"', 0, fichier, 256)
    json_value(g_response, '"state"', 0, etat, 80)
    json_value(g_response, '"completion"', 0, avance, 64)
    json_value(g_response, '"printTime"', 0, temps, 64)
    json_value(g_response, '"printTimeLeft"', 0, restant, 64)

    list_clear(li_result)
    IF (fichier[0] = 0) OR begins(fichier, 'null')
        list_add(li_result, 'Aucune impression en cours.')
        IF etat[0]
            StringF(g_job_state_line, 'Etat imprimante: \s', etat)
            list_add(li_result, g_job_state_line)
        ENDIF
        RETURN
    ENDIF

    readable_time(temps, temps_lisible)
    readable_time(restant, restant_lisible)
    list_add(li_result, 'IMPRESSION EN COURS')
    StringF(g_job_file_line, 'Fichier: \s', fichier)
    list_add(li_result, g_job_file_line)
    StringF(g_job_state_line, 'Etat: \s', etat)
    list_add(li_result, g_job_state_line)
    short_percent(avance, g_progress_short)
    StringF(g_job_progress_line, 'Avancement: \s %', g_progress_short)
    list_add(li_result, g_job_progress_line)
    StringF(g_job_time_line, 'Temps ecoule: \s', temps_lisible)
    list_add(li_result, g_job_time_line)
    StringF(g_job_left_line, 'Temps restant: \s', restant_lisible)
    list_add(li_result, g_job_left_line)
ENDPROC

PROC home_printer()
    request_reply('POST', '/api/printer/command', '{"commands":["G28"]}', 'Home')
ENDPROC

PROC motors_off()
    request_reply('POST', '/api/printer/command', '{"commands":["M84"]}', 'Moteurs off')
ENDPROC

PROC pla_heat()
    IF request_reply('POST', '/api/printer/command', '{"commands":["M104 S180","M140 S70"]}', 'Chauffe PLA')
        voice_say(sp_preheat)
    ENDIF
ENDPROC

PROC heat_off()
    IF request_reply('POST', '/api/printer/command', '{"commands":["M104 S0","M140 S0"]}', 'Chauffe off')
        voice_say(sp_heat_off)
    ENDIF
ENDPROC

PROC pause_print()
    IF request_reply('POST', '/api/job', '{"command":"pause","action":"pause"}', 'Pause')
        voice_say(sp_pause)
    ENDIF
ENDPROC

PROC resume_print()
    IF request_reply('POST', '/api/job', '{"command":"pause","action":"resume"}', 'Resume')
        voice_say(sp_resume)
    ENDIF
ENDPROC

PROC cancel_cleanup()
    Delay(100)
    IF request_reply('POST', '/api/printer/command', '{"commands":["M104 S0","M140 S0","G91","G1 Z10 F300","G90","G28 X0 Y0","M84"]}', 'Remise a zero')
        list_clear(li_result)
        list_add(li_result, 'Impression annulee.')
        list_add(li_result, 'Chauffe coupee, Z releve, axes X/Y ranges.')
    ENDIF
ENDPROC

PROC cancel_print()
    IF request_reply('POST', '/api/job', '{"command":"cancel"}', 'Annulation')
        voice_say(sp_cancel)
        cancel_cleanup()
    ENDIF
ENDPROC

PROC preheat_nozzle()
    IF request_reply('POST', '/api/printer/command', '{"commands":["M104 S200"]}', 'Chauffe buse')
        voice_say(sp_nozzle_heat)
    ENDIF
ENDPROC

PROC insert_filament()
    IF request_reply('POST', '/api/printer/command', '{"commands":["M83","G1 E30 F120","M82"]}', 'Insertion filament')
        voice_say(sp_insert)
    ENDIF
ENDPROC

PROC retract_filament()
    IF request_reply('POST', '/api/printer/command', '{"commands":["M83","G1 E-80 F600","M82"]}', 'Retrait filament')
        voice_say(sp_retract)
    ENDIF
ENDPROC

PROC emergency_stop()
    IF request_reply('POST', '/api/printer/command', '{"commands":["M112"]}', 'ARRET URGENCE M112')
        voice_say(sp_emergency)
        list_clear(li_result)
        list_add(li_result, 'ARRET URGENCE envoye.')
        list_add(li_result, 'Reset/reconnecte l imprimante, puis Connect impr.')
    ENDIF
ENDPROC

PROC connect_cleanup()
    Delay(100)
    IF request_reply('POST', '/api/printer/command', '{"commands":["M104 S0","M140 S0","G91","G1 Z10 F300","G90","G28 X0 Y0","M84"]}', 'Remise a zero connexion')
        list_clear(li_result)
        list_add(li_result, 'Imprimante reconnectee.')
        list_add(li_result, 'Chauffe coupee, Z releve, axes X/Y ranges.')
    ENDIF
ENDPROC

PROC raz_printer()
    IF request_reply('POST', '/api/printer/command', '{"commands":["M104 S0","M140 S0","G91","G1 Z10 F300","G90","G28 X0 Y0","M84"]}', 'RAZ imprimante')
        list_clear(li_result)
        list_add(li_result, 'RAZ imprimante terminee.')
        list_add(li_result, 'Chauffe coupee, Z releve, axes X/Y ranges.')
    ENDIF
ENDPROC

PROC connect_printer()
    IF request_reply('POST', '/api/connection', '{"command":"connect"}', 'Connexion imprimante')
        voice_say(sp_connect)
        connect_cleanup()
    ENDIF
ENDPROC

PROC show_help()
    list_clear(li_result)
    list_add(li_result, 'AIDE - OctoControl Speak')
    list_add(li_result, 'Tester: verifie OctoPrint et la cle API.')
    list_add(li_result, 'Connect impr.: reconnecte la Tina2S apres un redemarrage.')
    list_add(li_result, 'Files puis Print choix: lance un G-code deja sur OctoPrint.')
    list_add(li_result, 'Le moniteur peut annoncer les evenements avec SAY.')
    list_add(li_result, 'URGENCE M112: arret immediat, a utiliser seulement en cas de probleme.')
ENDPROC

PROC show_about()
    list_clear(li_result)
    list_add(li_result, 'OctoControl Speak 0.4')
    list_add(li_result, 'Controle OctoPrint depuis AmigaE et MUI.')
    list_add(li_result, 'Projet de Denis Costils - 2026.')
    list_add(li_result, 'Contact: costils.denis@free.fr')
    list_add(li_result, 'Connexion HTTP directe, sans navigateur.')
ENDPROC

PROC is_gcode(nom)
    DEF n=0

    WHILE nom[n]
        n++
    ENDWHILE

    IF n >= 6
        IF (nom[n-6] = 46) AND ((nom[n-5] = 103) OR (nom[n-5] = 71)) AND ((nom[n-4] = 99) OR (nom[n-4] = 67)) AND ((nom[n-3] = 111) OR (nom[n-3] = 79)) AND ((nom[n-2] = 100) OR (nom[n-2] = 68)) AND ((nom[n-1] = 101) OR (nom[n-1] = 69)) THEN RETURN TRUE
    ENDIF

    IF n >= 4
        IF (nom[n-4] = 46) AND ((nom[n-3] = 103) OR (nom[n-3] = 71)) AND ((nom[n-2] = 99) OR (nom[n-2] = 67)) AND ((nom[n-1] = 111) OR (nom[n-1] = 79)) THEN RETURN TRUE
    ENDIF

    IF n >= 3
        IF (nom[n-3] = 46) AND ((nom[n-2] = 103) OR (nom[n-2] = 71)) AND ((nom[n-1] = 99) OR (nom[n-1] = 67)) THEN RETURN TRUE
    ENDIF
ENDPROC FALSE

PROC fill_files_list()
    DEF i=0, debut, fin, nombre=0

    list_clear(li_files)
    WHILE (i < FILES_BUFFER-1) AND g_files[i]
        IF begins(g_files + i, '"name"')
            i := i + 6
            WHILE (i < FILES_BUFFER-1) AND g_files[i] AND (g_files[i] <> 58)
                i++
            ENDWHILE
            IF g_files[i] = 58
                i++
                WHILE (i < FILES_BUFFER-1) AND ((g_files[i] = 32) OR (g_files[i] = 9))
                    i++
                ENDWHILE
                IF g_files[i] = 34
                    debut := i + 1
                    fin := debut
                    WHILE (fin < FILES_BUFFER-1) AND g_files[fin] AND (g_files[fin] <> 34)
                        fin++
                    ENDWHILE
                    IF g_files[fin] = 34
                        g_files[fin] := 0
                        IF is_gcode(g_files + debut)
                            list_add(li_files, g_files + debut)
                            nombre++
                        ENDIF
                        i := fin + 1
                    ELSE
                        /* Reponse incomplete : sortir du parser sans boucler. */
                        i := fin
                    ENDIF
                ELSE
                    i++
                ENDIF
            ELSE
                i++
            ENDIF
        ELSE
            i++
        ENDIF
    ENDWHILE

    IF nombre = 0 THEN list_add(li_files, '(aucun fichier G-code)')
    IF g_files[FILES_BUFFER-2]
        list_add(li_files, '(liste partielle: trop de fichiers)')
    ENDIF
ENDPROC

PROC read_files()
    DEF statut[256]:STRING

    IF read_gui_config() = FALSE
        show_message('Indique une IP et une cle API OctoPrint.')
        RETURN
    ENDIF

    list_clear(li_files)
    list_add(li_files, 'Lecture des fichiers...')
    clear_memory(g_files, FILES_BUFFER)
    IF http_request('GET', '/api/files/local?recursive=false', '', g_files, FILES_BUFFER) = FALSE
        list_clear(li_files)
        list_add(li_files, '(OctoPrint ne repond pas)')
        show_message('Impossible de lire les fichiers OctoPrint.')
        RETURN
    ENDIF
    copy_value(g_response, g_files, 8192)
    IF (has_http_success() = FALSE) AND (find_text(g_files, '"files"', 0) < 0)
        http_status_line(statut)
        list_clear(li_files)
        list_add(li_files, '(erreur OctoPrint)')
        list_add(li_files, statut)
        StringF(g_result, 'OctoPrint refuse la lecture: \s', statut)
        show_message(g_result)
        RETURN
    ENDIF

    fill_files_list()
ENDPROC

PROC url_encode(destination:PTR TO CHAR, source:PTR TO CHAR, max)
    DEF pos=0, code, hex:PTR TO CHAR

    hex := '0123456789ABCDEF'
    WHILE source[] AND (pos < max-1)
        code := source[]
        IF ((code >= 48) AND (code <= 57)) OR ((code >= 65) AND (code <= 90)) OR ((code >= 97) AND (code <= 122)) OR (code = 45) OR (code = 46) OR (code = 95)
            destination[pos++] := code
        ELSE
            IF pos >= max-3 THEN RETURN
            destination[pos++] := 37
            destination[pos++] := hex[code / 16]
            destination[pos++] := hex[code AND 15]
        ENDIF
        source++
    ENDWHILE
    destination[pos] := 0
ENDPROC

PROC print_named_file(nom, label)
    DEF nom_encode[512]:STRING, chemin[600]:STRING

    url_encode(nom_encode, nom, 512)
    StringF(chemin, '/api/files/local/\s', nom_encode)
    IF request_reply('POST', chemin, '{"command":"select","print":true}', label)
        list_clear(li_result)
        StringF(g_result, 'Impression lancee: \s', nom)
        list_add(li_result, g_result)
    ENDIF
ENDPROC

PROC selected_octoprint_file()
    DEF actif, entree

    get(li_files, MUIA_List_Active, {actif})
    IF actif < 0
        show_message('Clique Files puis selectionne un fichier G-code.')
        RETURN
    ENDIF

    doMethod(li_files, [MUIM_List_GetEntry, actif, {entree}])
    IF entree = NIL
        show_message('Fichier OctoPrint non selectionne.')
        RETURN
    ENDIF
    IF begins(entree, '(')
        show_message('Selectionne un vrai fichier G-code.')
        RETURN
    ENDIF
ENDPROC entree

PROC print_selected()
    DEF entree

    entree := selected_octoprint_file()
    IF entree = NIL THEN RETURN
    print_named_file(entree, 'Impression choisie')
ENDPROC

PROC delete_selected_file()
    DEF entree, nom_encode[512]:STRING, chemin[600]:STRING

    entree := selected_octoprint_file()
    IF entree = NIL THEN RETURN

    url_encode(nom_encode, entree, 512)
    StringF(chemin, '/api/files/local/\s', nom_encode)
    show_message('Effacement fichier...')
    IF request_reply_quiet('DELETE', chemin, '')
        read_files()
        list_clear(li_result)
        StringF(g_result, 'Fichier efface: \s', entree)
        list_add(li_result, g_result)
    ELSE
        show_message('Effacement refuse ou OctoPrint ne repond pas.')
    ENDIF
ENDPROC

PROC file_basename(chemin:PTR TO CHAR)
    DEF i=0, debut=0

    WHILE chemin[i]
        IF (chemin[i] = 47) OR (chemin[i] = 58) THEN debut := i + 1
        i++
    ENDWHILE
ENDPROC chemin + debut

PROC upload_gcode(chemin:PTR TO CHAR, nom:PTR TO CHAR)
    DEF h, taille, restant, lu, sock, recu, utilise=0, termine=FALSE
    DEF adresse:sockaddr_in
    DEF requete[1024]:STRING, partie[1024]:STRING, fin[128]:STRING
    DEF total, ok=TRUE
    DEF boundary:PTR TO CHAR

    g_response[0] := 0
    StrCopy(g_upload_error, 'Aucune reponse recue pendant l envoi.', ALL)
    g_upload_size := 0
    g_upload_total := 0
    g_upload_sent := 0
    g_upload_errno := 0
    g_upload_last_percent := -1
    h := Open(chemin, MODE_OLDFILE)
    IF h = NIL
        StrCopy(g_upload_error, 'Impossible d ouvrir le fichier G-code.', ALL)
        RETURN FALSE
    ENDIF

    Seek(h, 0, OFFSET_END)
    taille := Seek(h, 0, OFFSET_CURRENT)
    Seek(h, 0, OFFSET_BEGINNING)
    IF taille < 0
        Close(h)
        StrCopy(g_upload_error, 'Impossible de lire la taille du fichier G-code.', ALL)
        RETURN FALSE
    ENDIF

    boundary := '----OctoControlAmigaBoundary'
    build_upload_parts(partie, fin, boundary, nom)
    total := StrLen(partie) + taille + StrLen(fin)
    g_upload_size := taille
    g_upload_total := total
    g_upload_sent := 0
    upload_progress(TRUE)
    build_upload_request(requete, boundary, total)

    sock := Socket(AF_INET, SOCK_STREAM, 0)
    IF sock < 0
        Close(h)
        StrCopy(g_upload_error, 'Impossible d ouvrir le socket reseau.', ALL)
        RETURN FALSE
    ENDIF
    clear_memory(adresse, SIZEOF sockaddr_in)
    adresse.family := AF_INET
    adresse.addr.addr := Inet_Addr(g_ip)
    adresse.port := g_port
    IF Connect(sock, adresse, SIZEOF sockaddr_in) < 0
        CloseSocket(sock)
        Close(h)
        StrCopy(g_upload_error, 'OctoPrint ne repond pas a la connexion upload.', ALL)
        RETURN FALSE
    ENDIF

    IF send_all(sock, requete) = FALSE
        ok := FALSE
        StrCopy(g_upload_error, 'Erreur envoi entete HTTP upload.', ALL)
    ENDIF
    IF ok AND (send_all(sock, partie) = FALSE)
        ok := FALSE
        StrCopy(g_upload_error, 'Erreur envoi debut du fichier.', ALL)
    ENDIF

    restant := taille
    WHILE (restant > 0) AND ok
        lu := Read(h, g_upload_buffer, UPLOAD_BLOCK)
        IF lu <= 0
            ok := FALSE
            StrCopy(g_upload_error, 'Erreur de lecture pendant le transfert du fichier.', ALL)
        ELSE
            IF send_bytes(sock, g_upload_buffer, lu) = FALSE
                ok := FALSE
                StrCopy(g_upload_error, 'Connexion coupee pendant le transfert du fichier.', ALL)
            ENDIF
            g_upload_sent := g_upload_sent + lu
            upload_progress(FALSE)
            restant := restant - lu
        ENDIF
    ENDWHILE
    Close(h)

    IF ok AND (send_all(sock, fin) = FALSE)
        ok := FALSE
        StrCopy(g_upload_error, 'Erreur envoi fin du fichier.', ALL)
    ENDIF
    IF ok
        g_upload_sent := taille
        upload_progress(TRUE)
    ENDIF
    /* Si le serveur coupe pendant l envoi, il a souvent deja envoye HTTP 400/413. */
    IF ok OR begins(g_upload_error, 'Connexion coupee')
        WHILE (utilise < 8191) AND (termine = FALSE)
            recu := Recv(sock, g_response + utilise, 8191-utilise, 0)
            IF recu <= 0
                termine := TRUE
            ELSE
                utilise := utilise + recu
            ENDIF
        ENDWHILE
        g_response[utilise] := 0
    ENDIF
    CloseSocket(sock)
ENDPROC ok AND (utilise > 0) AND has_http_success()

PROC upload_selected(start_print)
    DEF source, chemin[512]:STRING, nom[256]:STRING, origine

    get(st_upload, MUIA_String_Contents, {source})
    IF source = NIL
        show_message('Indique le chemin d un fichier G-code.')
        RETURN
    ENDIF
    IF source[] = 0
        show_message('Indique le chemin d un fichier G-code.')
        RETURN
    ENDIF
    IF read_gui_config() = FALSE
        show_message('Indique une IP et une cle API OctoPrint.')
        RETURN
    ENDIF

    copy_value(chemin, source, 512)
    origine := file_basename(chemin)
    copy_value(nom, origine, 256)
    IF nom[0] = 0
        show_message('Nom de fichier G-code invalide.')
        RETURN
    ENDIF
    IF is_gcode(nom) = FALSE
        show_message('Selectionne un fichier G-code (.gcode, .gco ou .gc).')
        RETURN
    ENDIF

    show_message('Envoi du fichier G-code vers OctoPrint...')
    IF upload_gcode(chemin, nom) = FALSE
        list_clear(li_result)
        list_add(li_result, 'Echec envoi G-code.')
        IF g_response[0]
            list_add(li_result, 'OctoPrint a refuse le transfert.')
            http_status_line(g_result)
            list_add(li_result, g_result)
        ELSE
            list_add(li_result, g_upload_error)
            StringF(g_result, 'Chemin choisi: \s', chemin)
            list_add(li_result, g_result)
        ENDIF
        RETURN
    ENDIF

    IF start_print
        print_named_file(nom, 'Envoi et impression')
    ELSE
        list_clear(li_result)
        StringF(g_result, 'Fichier envoye vers OctoPrint: \s', nom)
        list_add(li_result, g_result)
        list_add(li_result, 'Clique Files pour actualiser la liste.')
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

PROC bouton_urgence()
    DEF obj
    obj := TextObject,
        ButtonFrame,
        MUIA_Text_Contents, 'URGENCE M112',
        MUIA_Text_PreParse, '\ec',
        MUIA_InputMode, MUIV_InputMode_RelVerify,
        /* Composantes RGB 32 bits: rouge complet, vert et bleu a zero. */
        MUIA_Background, '2:FFFFFFFF,00000000,00000000',
    End
ENDPROC obj

PROC main() HANDLE
    DEF signal, result, running
    DEF port_text[16]:STRING

    load_config()
    load_speech_config()
    reset_voice_state()
    IF g_port <= 0 THEN g_port := 80
    StringF(port_text, '\d', g_port)

    IF (muimasterbase := OpenLibrary(MUIMASTER_NAME, MUIMASTER_VMIN)) = NIL THEN Raise(1)
    IF (socketbase := OpenLibrary('bsdsocket.library', 4)) = NIL THEN Raise(2)

    li_result := ListObject,
        MUIA_Frame, MUIV_Frame_InputList,
    End

    ap_native := ApplicationObject,
        MUIA_Application_Title, 'OctoControl Speak',
        MUIA_Application_Version, '0.4',
        MUIA_Application_Author, 'Denis Costils',
        MUIA_Application_Description, 'Controle OctoPrint parlant direct AmigaE',
        MUIA_Application_Base, 'OCTOSPEAK',

        SubWindow,
            wi_native := WindowObject,
                MUIA_Window_Title, 'OctoControl Speak',
                MUIA_Window_ID, "OCSP",
                MUIA_Width, 560,
                MUIA_Height, 680,
                MUIA_Window_Menustrip, MenustripObject,
                    Child, MenuObject,
                        MUIA_Menu_Title, 'Aide',
                        Child, mi_help := MenuitemObject,
                            MUIA_Menuitem_Title, 'Utilisation',
                        End,
                        Child, mi_about := MenuitemObject,
                            MUIA_Menuitem_Title, 'A propos',
                        End,
                    End,
                End,
                WindowContents, VGroup,

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        MUIA_FrameTitle, 'Connexion OctoPrint',
                        MUIA_Group_Columns, 2,
                        Child, TextObject, MUIA_Text_Contents, 'Adresse IP', End,
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
                        Child, TextObject, MUIA_Text_Contents, 'Cle API', End,
                        Child, st_api := StringObject,
                            StringFrame,
                            MUIA_String_Contents, g_api,
                            MUIA_String_MaxLen, 255,
                        End,
                    End,

                    Child, HGroup,
                        Child, bt_save := bouton('Sauver'),
                        Child, bt_test := bouton('Tester'),
                        Child, bt_mini := bouton('Mini'),
                        Child, bt_quit := bouton('Quitter'),
                    End,

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        MUIA_FrameTitle, 'Imprimante',
                        MUIA_Group_Columns, 2,
                        Child, bt_connect := bouton('Connect impr.'),
                        Child, bt_raz := bouton('RAZ'),
                    End,

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        MUIA_FrameTitle, 'Lecture',
                        MUIA_Group_Columns, 3,
                        Child, bt_status := bouton('Status'),
                        Child, bt_job := bouton('Job'),
                        Child, bt_m105 := bouton('M105'),
                    End,

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        MUIA_FrameTitle, 'Fichiers OctoPrint',
                        MUIA_Group_Columns, 3,
                        Child, bt_files := bouton('Files'),
                        Child, bt_printselected := bouton('Print choix'),
                        Child, bt_deletefile := bouton('Effacer'),
                    End,

                    Child, lv_files := ListviewObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        MUIA_Listview_Input, MUI_TRUE,
                        MUIA_Listview_List, li_files := ListObject,
                            MUIA_Frame, MUIV_Frame_InputList,
                            MUIA_List_ConstructHook, MUIV_List_ConstructHook_String,
                            MUIA_List_DestructHook, MUIV_List_DestructHook_String,
                        End,
                    End,

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        MUIA_FrameTitle, 'Envoyer un fichier G-code',
                        Child, GroupObject,
                            MUIA_Group_Columns, 3,
                            Child, PopaslObject,
                                /* 0 = selecteur de fichier ASL, compatible AmigaE 3.3. */
                                MUIA_Popasl_Type, 0,
                                MUIA_Popstring_String, st_upload := StringObject,
                                    StringFrame,
                                    MUIA_String_Contents, '',
                                    MUIA_String_MaxLen, 500,
                                End,
                                MUIA_Popstring_Button, PopButton(MUII_PopFile),
                            End,
                            Child, bt_upload := bouton('Envoyer'),
                            Child, bt_uploadprint := bouton('Envoyer+Print'),
                        End,
                        Child, ga_upload_progress := GaugeObject,
                            GaugeFrame,
                            MUIA_Gauge_Horiz, MUI_TRUE,
                            MUIA_Gauge_Max, 100,
                            MUIA_Gauge_Current, 0,
                        End,
                        Child, tx_upload_progress := TextObject,
                            MUIA_Text_Contents, 'Envoi: -- %',
                        End,
                    End,

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        MUIA_FrameTitle, 'Controle machine',
                        MUIA_Group_Columns, 4,
                        Child, bt_home := bouton('Home'),
                        Child, bt_motorsoff := bouton('Mot OFF'),
                        Child, bt_pla := bouton('PLA'),
                        Child, bt_heatoff := bouton('Heat OFF'),
                    End,

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        MUIA_FrameTitle, 'Impression',
                        MUIA_Group_Columns, 3,
                        Child, bt_pause := bouton('Pause'),
                        Child, bt_resume := bouton('Resume'),
                        Child, bt_cancel := bouton('Cancel'),
                    End,

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        MUIA_FrameTitle, 'Urgence',
                        Child, bt_emergency := bouton_urgence(),
                    End,

                    Child, HGroup,
                        Child, GroupObject,
                            MUIA_Frame, MUIV_Frame_Group,
                            MUIA_FrameTitle, 'Gestion Filament',
                            MUIA_Group_Columns, 3,
                            Child, bt_prechauffe := bouton('Chauffe Buse'),
                            Child, bt_insertion := bouton('Inserer Fil'),
                            Child, bt_retrait := bouton('Retirer Fil'),
                        End,

                        Child, GroupObject,
                            MUIA_Frame, MUIV_Frame_Group,
                            MUIA_FrameTitle, 'TINA2S',
                            Child, ImageObject,
                                MUIA_Image_Spec, IMAGE_TINA,
                                MUIA_Image_FreeVert, MUI_TRUE,
                                MUIA_Image_FreeHoriz, MUI_TRUE,
                                MUIA_FixWidth, 150,
                                MUIA_FixHeight, 150,
                            End,
                        End,
                    End,

                    Child, lv_result := ListviewObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        MUIA_Listview_Input, MUI_TRUE,
                        MUIA_Listview_List, li_result,
                    End,
                End,
            End,
        SubWindow,
            wi_monitor := WindowObject,
                MUIA_Window_Title, 'Moniteur imprimante',
                MUIA_Window_ID, "OCMO",
                MUIA_Width, 360,
                MUIA_Height, 160,
                WindowContents, VGroup,
                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        MUIA_FrameTitle, 'Temperatures',
                        Child, tx_monitor_state := TextObject,
                            MUIA_Text_Contents, 'Etat: --',
                        End,
                        Child, tx_monitor_tool := TextObject,
                            MUIA_Text_Contents, 'Buse: -- C / cible -- C',
                        End,
                        Child, tx_monitor_bed := TextObject,
                            MUIA_Text_Contents, 'Plateau: -- C / cible -- C',
                        End,
                        Child, tx_monitor_file := TextObject,
                            MUIA_Text_Contents, 'Fichier: --',
                        End,
                        Child, tx_monitor_job := TextObject,
                            MUIA_Text_Contents, 'Avancement: -- %',
                        End,
                        Child, tx_monitor_left := TextObject,
                            MUIA_Text_Contents, 'Temps restant: --',
                        End,
                        Child, bt_monitor_main := bouton('Principal'),
                    End,
                End,
            End,
        End

    IF ap_native = NIL THEN Raise(3)

    show_message('Pret. La configuration est dans S:octocontrol_native.cfg')

    doMethod(wi_native, [MUIM_Notify, MUIA_Window_CloseRequest, MUI_TRUE, ap_native, 2, MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])
    doMethod(wi_monitor, [MUIM_Notify, MUIA_Window_CloseRequest, MUI_TRUE, ap_native, 2, MUIM_Application_ReturnID, ID_MONITOR_CLOSE])
    doMethod(bt_save, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_SAVE])
    doMethod(bt_test, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_TEST])
    doMethod(bt_mini, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_MAIN_HIDE])
    doMethod(bt_connect, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_CONNECT])
    doMethod(bt_raz, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_RAZ])
    doMethod(mi_help, [MUIM_Notify, MUIA_Menuitem_Trigger, MUIV_EveryTime, ap_native, 2, MUIM_Application_ReturnID, ID_HELP])
    doMethod(mi_about, [MUIM_Notify, MUIA_Menuitem_Trigger, MUIV_EveryTime, ap_native, 2, MUIM_Application_ReturnID, ID_ABOUT])
    doMethod(bt_status, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_STATUS])
    doMethod(bt_job, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_JOB])
    doMethod(bt_m105, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_M105])
    doMethod(bt_files, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_FILES])
    doMethod(bt_printselected, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_PRINTSELECTED])
    doMethod(bt_deletefile, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_DELETEFILE])
    doMethod(bt_upload, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_UPLOAD])
    doMethod(bt_uploadprint, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_UPLOADPRINT])
    doMethod(bt_home, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_HOME])
    doMethod(bt_motorsoff, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_MOTORSOFF])
    doMethod(bt_pla, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_PLA])
    doMethod(bt_heatoff, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_HEATOFF])
    doMethod(bt_pause, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_PAUSE])
    doMethod(bt_resume, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_RESUME])
    doMethod(bt_cancel, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_CANCEL])
    doMethod(bt_emergency, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_EMERGENCY])
    doMethod(bt_prechauffe, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_PRECHAUFFE])
    doMethod(bt_insertion, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_INSERTION])
    doMethod(bt_retrait, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_RETRAIT])
    doMethod(bt_quit, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])
    doMethod(bt_monitor_main, [MUIM_Notify, MUIA_Pressed, FALSE, ap_native, 2, MUIM_Application_ReturnID, ID_MAIN_SHOW])

    set(wi_native, MUIA_Window_Open, MUI_TRUE)
    main_open := TRUE
    running := TRUE
    WHILE running
        result := doMethod(ap_native, [MUIM_Application_Input, {signal}])
        IF result <> MUIV_Application_ReturnID_Quit
            SELECT result
                CASE ID_SAVE
                    IF read_gui_config()
                        IF save_config()
                            show_message('Configuration sauvee dans S:octocontrol_native.cfg')
                        ELSE
                            show_message('Impossible d ecrire S:octocontrol_native.cfg')
                        ENDIF
                    ELSE
                        show_message('Indique une IP et une cle API OctoPrint.')
                    ENDIF
                CASE ID_TEST ; test_octoprint()
                CASE ID_CONNECT ; connect_printer()
                CASE ID_RAZ ; raz_printer()
                CASE ID_HELP ; show_help()
                CASE ID_ABOUT ; show_about()
                CASE ID_STATUS
                    monitor_open := TRUE
                    monitor_ticks := 0
                    set(wi_monitor, MUIA_Window_Open, MUI_TRUE)
                    read_printer_status()
                CASE ID_MAIN_HIDE
                    monitor_open := TRUE
                    monitor_ticks := 0
                    set(wi_monitor, MUIA_Window_Open, MUI_TRUE)
                    read_printer_status()
                    set(wi_native, MUIA_Window_Open, FALSE)
                    main_open := FALSE
                CASE ID_MAIN_SHOW
                    set(wi_native, MUIA_Window_Open, MUI_TRUE)
                    main_open := TRUE
                CASE ID_JOB ; read_job()
                CASE ID_M105 ; send_m105()
                CASE ID_FILES ; read_files()
                CASE ID_PRINTSELECTED ; print_selected()
                CASE ID_DELETEFILE ; delete_selected_file()
                CASE ID_UPLOAD ; upload_selected(FALSE)
                CASE ID_UPLOADPRINT ; upload_selected(TRUE)
                CASE ID_HOME ; home_printer()
                CASE ID_MOTORSOFF ; motors_off()
                CASE ID_PLA ; pla_heat()
                CASE ID_HEATOFF ; heat_off()
                CASE ID_PAUSE ; pause_print()
                CASE ID_RESUME ; resume_print()
                CASE ID_CANCEL ; cancel_print()
                CASE ID_EMERGENCY ; emergency_stop()
                CASE ID_PRECHAUFFE ; preheat_nozzle()
                CASE ID_INSERTION ; insert_filament()
                CASE ID_RETRAIT ; retract_filament()
                CASE ID_MONITOR_CLOSE
                    monitor_open := FALSE
                    set(wi_monitor, MUIA_Window_Open, FALSE)
                    IF main_open = FALSE
                        set(wi_native, MUIA_Window_Open, MUI_TRUE)
                        main_open := TRUE
                    ENDIF
            ENDSELECT
        ELSE
            running := FALSE
        ENDIF

        IF running AND monitor_open
            monitor_ticks++
            IF monitor_ticks >= 25
                monitor_ticks := 0
                refresh_monitor_status()
            ENDIF
        ENDIF

        IF running
            IF monitor_open
                Delay(10)
            ELSEIF signal <> 0
                Wait(signal)
            ELSE
                Delay(10)
            ENDIF
        ENDIF
    ENDWHILE

    IF wi_monitor THEN set(wi_monitor, MUIA_Window_Open, FALSE)
    set(wi_native, MUIA_Window_Open, FALSE)
    Mui_DisposeObject(ap_native)
    ap_native := NIL
    CloseLibrary(socketbase)
    socketbase := NIL
    CloseLibrary(muimasterbase)
    muimasterbase := NIL
    RETURN 0

EXCEPT
    IF ap_native THEN Mui_DisposeObject(ap_native)
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
