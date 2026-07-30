-> Print3DToolboxMUI.e
-> Small launcher for the Amiga 3D printing toolbox.

OPT PREPROCESS
OPT OSVERSION=39

MODULE 'muimaster','libraries/mui'
MODULE 'utility/tagitem','utility/hooks'
MODULE 'intuition/classes','intuition/classusr'
MODULE 'dos/dos'

#define CFG_FILE 'S:print3dtoolbox.cfg'
#define IMG_OCTO '5:3dtoolbox:icons/octocontrolspeak.iff'
#define IMG_PITEMP '5:3dtoolbox:icons/pitempmui.iff'
#define IMG_DDD '5:3dtoolbox:icons/ddd2stlmui.iff'
#define IMG_COLOR '5:3dtoolbox:icons/gcodecolorpausemui.iff'
#define IMG_ZSETUP '5:3dtoolbox:icons/zsetupmui.iff'

ENUM ID_OCTO=1,
     ID_PITEMP,
     ID_DDD2STL,
     ID_COLOR,
     ID_ZSETUP,
     ID_SAVE,
     ID_ABOUT

DEF ap_app, wi_main
DEF st_path
DEF bt_save, bt_about, bt_quit
DEF im_octo, im_pitemp, im_ddd, im_color, im_zsetup
DEF tx_status
DEF g_tool_path[256]:STRING

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

PROC etiquette(label)
    DEF obj
    obj := TextObject,
        MUIA_Text_Contents, label,
        MUIA_Text_PreParse, '\ec',
    End
ENDPROC obj

PROC set_status(text)
    set(tx_status, MUIA_Text_Contents, text)
ENDPROC

PROC about_pause()
    DEF signal

    doMethod(ap_app, [MUIM_Application_Input, {signal}])
    Delay(80)
ENDPROC

PROC show_about()
    set_status('Print 3D Toolbox for Amiga')
    about_pause()
    set_status('Author: Denis Costils')
    about_pause()
    set_status('With help from ChatGPT Codex')
    about_pause()
    set_status('OctoControlSpeak: OctoPrint control')
    about_pause()
    set_status('PiTempMUI: Raspberry Pi temperature')
    about_pause()
    set_status('DDD2STLMUI: Imagine 3D to STL')
    about_pause()
    set_status('GCodeColorPauseMUI: color pause helper')
    about_pause()
    set_status('ZSetupMUI: Z offset adjustment')
    about_pause()
    set_status('Amiga + OctoPrint + 3D printing toolbox')
ENDPROC

PROC begins(texte:PTR TO CHAR, debut:PTR TO CHAR)
    WHILE debut[]
        IF texte[] <> debut[] THEN RETURN FALSE
        texte++
        debut++
    ENDWHILE
ENDPROC TRUE

PROC trim_line(text:PTR TO CHAR)
    DEF i=0

    WHILE text[i]
        IF (text[i]=10) OR (text[i]=13)
            text[i]:=0
            RETURN
        ENDIF
        i++
    ENDWHILE
ENDPROC

PROC copy_value(destination:PTR TO CHAR, source:PTR TO CHAR, max)
    DEF i=0

    WHILE source[] AND (i < max-1)
        destination[i++] := source[]
        source++
    ENDWHILE
    destination[i] := 0
ENDPROC

PROC load_config()
    DEF h=NIL,buffer[512]:STRING,len

    StrCopy(g_tool_path,'3dtoolbox:',ALL)

    IF (h:=Open(CFG_FILE,MODE_OLDFILE))=NIL THEN RETURN FALSE
    len:=Read(h,buffer,511)
    Close(h)
    IF len<=0 THEN RETURN FALSE
    buffer[len]:=0
    trim_line(buffer)

    IF begins(buffer,'TOOLPATH=')
        copy_value(g_tool_path,buffer+9,256)
    ENDIF
ENDPROC TRUE

PROC save_config()
    DEF h=NIL,pathptr,oldout

    get(st_path,MUIA_String_Contents,{pathptr})
    IF pathptr THEN copy_value(g_tool_path,pathptr,256)
    IF StrLen(g_tool_path)=0 THEN StrCopy(g_tool_path,'3dtoolbox:',ALL)

    h:=Open(CFG_FILE,MODE_NEWFILE)
    IF h=NIL
        set_status('Status: unable to save S:print3dtoolbox.cfg.')
        RETURN FALSE
    ENDIF

    oldout:=stdout
    stdout:=h
    WriteF('TOOLPATH=\s\n',g_tool_path)
    stdout:=oldout
    Close(h)
    set_status('Status: path saved in S:print3dtoolbox.cfg.')
ENDPROC TRUE

PROC append_text(dest:PTR TO CHAR,source:PTR TO CHAR)
    DEF len=0

    WHILE dest[len]
        len++
    ENDWHILE

    WHILE source[]
        dest[len++] := source[]
        source++
    ENDWHILE
    dest[len] := 0
ENDPROC

PROC make_program_path(dest:PTR TO CHAR,program:PTR TO CHAR)
    DEF len

    IF StrLen(g_tool_path)=0 THEN StrCopy(g_tool_path,'3dtoolbox:',ALL)
    StrCopy(dest,g_tool_path,ALL)
    len:=StrLen(dest)

    IF len>0
        IF (dest[len-1]<>58) AND (dest[len-1]<>47)
            dest[len]:=47
            dest[len+1]:=0
        ENDIF
    ENDIF

    append_text(dest,program)
ENDPROC

PROC launch_tool(program:PTR TO CHAR,label:PTR TO CHAR)
    DEF cmd[256]:STRING
    DEF fullpath[256]:STRING
    DEF entree=NIL,sortie=NIL,ok

    make_program_path(fullpath,program)
    StringF(cmd,'Run >NIL: "\s"',fullpath)
    entree:=Open('NIL:',MODE_OLDFILE)
    sortie:=Open('NIL:',MODE_NEWFILE)
    ok:=Execute(cmd,entree,sortie)
    IF entree THEN Close(entree)
    IF sortie THEN Close(sortie)

    IF ok
        StringF(cmd,'Status: launched \s.',label)
    ELSE
        StringF(cmd,'Status: unable to launch \s.',label)
    ENDIF
    set_status(cmd)
ENDPROC

PROC main() HANDLE
    DEF signal,result,running

    IF (muimasterbase:=OpenLibrary(MUIMASTER_NAME,MUIMASTER_VMIN))=NIL THEN Raise(1)
    load_config()

    ap_app := ApplicationObject,
        MUIA_Application_Title, 'Print3DToolbox',
        MUIA_Application_Version, '0.1',
        MUIA_Application_Author, 'Denis Costils',
        MUIA_Application_Description, 'Amiga 3D printing toolbox launcher',
        MUIA_Application_Base, 'P3TB',

        SubWindow,
            wi_main := WindowObject,
                MUIA_Window_Title, 'Print 3D Toolbox',
                MUIA_Window_ID, "P3TB",
                MUIA_Width, 360,
                MUIA_Height, 230,
                WindowContents, VGroup,

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        MUIA_FrameTitle, 'Settings',
                        MUIA_Group_Columns, 2,
                        Child, TextObject, MUIA_Text_Contents, 'Tools drawer', End,
                        Child, st_path := StringObject,
                            StringFrame,
                            MUIA_String_Contents, g_tool_path,
                            MUIA_String_MaxLen, 255,
                        End,
                    End,

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        MUIA_FrameTitle, 'Tools',
                        MUIA_Group_Columns, 3,

                        Child, VGroup,
                            Child, im_octo := ImageObject,
                                ButtonFrame,
                                MUIA_Image_Spec, IMG_OCTO,
                                MUIA_Image_FreeVert, MUI_TRUE,
                                MUIA_Image_FreeHoriz, MUI_TRUE,
                                MUIA_FixWidth, 46,
                                MUIA_FixHeight, 46,
                                MUIA_InputMode, MUIV_InputMode_RelVerify,
                                MUIA_Background, MUII_ButtonBack,
                            End,
                            Child, etiquette('OctoControlSpeak'),
                        End,

                        Child, VGroup,
                            Child, im_pitemp := ImageObject,
                                ButtonFrame,
                                MUIA_Image_Spec, IMG_PITEMP,
                                MUIA_Image_FreeVert, MUI_TRUE,
                                MUIA_Image_FreeHoriz, MUI_TRUE,
                                MUIA_FixWidth, 46,
                                MUIA_FixHeight, 46,
                                MUIA_InputMode, MUIV_InputMode_RelVerify,
                                MUIA_Background, MUII_ButtonBack,
                            End,
                            Child, etiquette('PiTemp'),
                        End,

                        Child, VGroup,
                            Child, im_ddd := ImageObject,
                                ButtonFrame,
                                MUIA_Image_Spec, IMG_DDD,
                                MUIA_Image_FreeVert, MUI_TRUE,
                                MUIA_Image_FreeHoriz, MUI_TRUE,
                                MUIA_FixWidth, 46,
                                MUIA_FixHeight, 46,
                                MUIA_InputMode, MUIV_InputMode_RelVerify,
                                MUIA_Background, MUII_ButtonBack,
                            End,
                            Child, etiquette('DDD2STLMUI'),
                        End,

                        Child, VGroup,
                            Child, im_color := ImageObject,
                                ButtonFrame,
                                MUIA_Image_Spec, IMG_COLOR,
                                MUIA_Image_FreeVert, MUI_TRUE,
                                MUIA_Image_FreeHoriz, MUI_TRUE,
                                MUIA_FixWidth, 46,
                                MUIA_FixHeight, 46,
                                MUIA_InputMode, MUIV_InputMode_RelVerify,
                                MUIA_Background, MUII_ButtonBack,
                            End,
                            Child, etiquette('GCodeColorPauseMUI'),
                        End,

                        Child, VGroup,
                            Child, im_zsetup := ImageObject,
                                ButtonFrame,
                                MUIA_Image_Spec, IMG_ZSETUP,
                                MUIA_Image_FreeVert, MUI_TRUE,
                                MUIA_Image_FreeHoriz, MUI_TRUE,
                                MUIA_FixWidth, 46,
                                MUIA_FixHeight, 46,
                                MUIA_InputMode, MUIV_InputMode_RelVerify,
                                MUIA_Background, MUII_ButtonBack,
                            End,
                            Child, etiquette('ZSetupMUI'),
                        End,
                    End,

                    Child, HGroup,
                        Child, bt_save := bouton('Save path'),
                        Child, bt_about := bouton('About'),
                        Child, bt_quit := bouton('Quit'),
                    End,

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        Child, tx_status := TextObject,
                            MUIA_Text_Contents, 'Status: ready. Default drawer is 3dtoolbox:.',
                        End,
                    End,
                End,
            End,
        End

    IF ap_app=NIL THEN Raise(2)

    doMethod(wi_main, [MUIM_Notify, MUIA_Window_CloseRequest, MUI_TRUE, ap_app, 2, MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])
    doMethod(im_octo, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_OCTO])
    doMethod(im_pitemp, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_PITEMP])
    doMethod(im_ddd, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_DDD2STL])
    doMethod(im_color, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_COLOR])
    doMethod(im_zsetup, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_ZSETUP])
    doMethod(bt_save, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_SAVE])
    doMethod(bt_about, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_ABOUT])
    doMethod(bt_quit, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])

    set(wi_main, MUIA_Window_Open, MUI_TRUE)

    running:=TRUE
    WHILE running
        result:=doMethod(ap_app, [MUIM_Application_Input, {signal}])
        IF result<>MUIV_Application_ReturnID_Quit
            SELECT result
                CASE ID_OCTO
                    launch_tool('OctoControlSpeak','OctoControlSpeak')
                CASE ID_PITEMP
                    launch_tool('PiTempMUI','PiTemp')
                CASE ID_DDD2STL
                    launch_tool('DDD2STLMUI','DDD2STLMUI')
                CASE ID_COLOR
                    launch_tool('GCodeColorPauseMUI','GCodeColorPauseMUI')
                CASE ID_ZSETUP
                    launch_tool('ZSetupMUI','ZSetupMUI')
                CASE ID_SAVE
                    save_config()
                CASE ID_ABOUT
                    show_about()
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
