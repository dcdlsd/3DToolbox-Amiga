-> DDD2STLMUI.e
-> Simple MUI frontend for DDD2STL.
-> Converts 3D files readable by ddd.library to ASCII STL.

OPT PREPROCESS
OPT LARGE
OPT OSVERSION=39

MODULE 'muimaster','libraries/mui'
MODULE 'utility/tagitem','utility/hooks'
MODULE 'intuition/classes','intuition/classusr'
MODULE 'dos/dos','libraries/asl'
MODULE 'exec/lists','exec/nodes'
MODULE 'mathffp','mathtrans'
MODULE 'mathieeesingbas','mathieeesingtrans'
MODULE 'ddd','libraries/dddobject'

ENUM ID_CONVERT=1,
     ID_CLEAR

DEF ap_app, wi_main
DEF st_source, st_dest, st_scale
DEF bt_convert, bt_clear, bt_quit
DEF tx_status
DEF g_exported,g_skipped_invalid,g_skipped_degenerate
DEF g_nx,g_ny,g_nz

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

PROC make_stl_name(source:PTR TO CHAR, dest:PTR TO CHAR)
    DEF i=0,lastdot=-1

    StrCopy(dest, source, ALL)

    WHILE dest[i]
        IF (dest[i]=58) OR (dest[i]=47)
            lastdot:=-1
        ELSEIF dest[i]=46
            lastdot:=i
        ENDIF
        i++
    ENDWHILE

    IF lastdot<>-1 THEN dest[lastdot]:=0
    add_stl_extension(dest)
ENDPROC

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

PROC convert_from_gui()
    DEF srcptr,dstptr,scaleptr
    DEF source[256]:STRING,dest[256]:STRING,scale_text[64]:STRING
    DEF scale=0.1
    DEF base=NIL:PTR TO base3d,ret,typ,msg[256]:STRING

    get(st_source, MUIA_String_Contents, {srcptr})
    get(st_dest, MUIA_String_Contents, {dstptr})
    get(st_scale, MUIA_String_Contents, {scaleptr})

    IF srcptr=NIL
        set_status('Status: choose a source 3D file.')
        RETURN
    ENDIF
    IF dstptr=NIL
        set_status('Status: choose an STL destination file.')
        RETURN
    ENDIF

    StrCopy(source, srcptr, ALL)
    StrCopy(dest, dstptr, ALL)
    IF scaleptr THEN StrCopy(scale_text, scaleptr, ALL) ELSE StrCopy(scale_text, '0.1', ALL)

    IF StrLen(source)=0
        set_status('Status: choose a source 3D file.')
        RETURN
    ENDIF

    IF (StrLen(dest)=0) OR StrCmp(dest, 'RAM:object.stl', 14)
        make_stl_name(source, dest)
        set(st_dest, MUIA_String_Contents, dest)
    ELSE
        force_stl_extension(dest)
        set(st_dest, MUIA_String_Contents, dest)
    ENDIF

    scale:=string2Float(scale_text)

    set_status('Status: loading source file...')

    base:=Init3DBase()
    IF isValidBase(base)=FALSE
        set_status('Status: cannot initialise ddd 3D base.')
        RETURN
    ENDIF

    ret,typ:=ReadFile3D(base,source)
    IF ret<>ERR3D_NONE
        IF isValidBase(base) THEN Rem3DBase(base)
        set_status('Status: source file unsupported or unreadable.')
        RETURN
    ENDIF

    StringF(msg, 'Status: loaded. Objects \d, points \d, faces \d. Exporting...',
        base.nbrsobjs, base.totalpts, base.totalfcs)
    set_status(msg)

    IF exportSTL(base,dest,scale)=FALSE
        IF isValidBase(base) THEN Rem3DBase(base)
        set_status('Status: unable to write STL file.')
        RETURN
    ENDIF

    IF (g_skipped_invalid+g_skipped_degenerate)>0
        StringF(msg, 'Status: saved. WARNING: \d bad faces skipped. Repair/check in Cura.',
            g_skipped_invalid+g_skipped_degenerate)
    ELSE
        StringF(msg, 'Status: STL saved. Objects \d, faces \d.', base.nbrsobjs, g_exported)
    ENDIF
    IF isValidBase(base) THEN Rem3DBase(base)
    set_status(msg)
ENDPROC

PROC isValidBase(base)
    IF base=NIL THEN RETURN FALSE
    IF base=ERR3D_MEM THEN RETURN FALSE
    IF base=ERR3D_MATHLIB THEN RETURN FALSE
ENDPROC TRUE

PROC openLibraries()
    IF (mathbase:=OpenLibrary('mathffp.library',34))=NIL THEN RETURN FALSE
    IF (mathtransbase:=OpenLibrary('mathtrans.library',34))=NIL THEN RETURN FALSE
    IF (mathieeesingbasbase:=OpenLibrary('mathieeesingbas.library',34))=NIL THEN RETURN FALSE
    IF (mathieeesingtransbase:=OpenLibrary('mathieeesingtrans.library',34))=NIL THEN RETURN FALSE
    IF (dddbase:=OpenLibrary('ddd.library',0))=NIL THEN RETURN FALSE
ENDPROC TRUE

PROC closeLibraries()
    IF dddbase THEN CloseLibrary(dddbase)
    IF mathieeesingtransbase THEN CloseLibrary(mathieeesingtransbase)
    IF mathieeesingbasbase THEN CloseLibrary(mathieeesingbasbase)
    IF mathtransbase THEN CloseLibrary(mathtransbase)
    IF mathbase THEN CloseLibrary(mathbase)
ENDPROC

PROC exportSTL(base:PTR TO base3d,outfile,scale)
    DEF h=NIL,oldout,ret=FALSE
    DEF mylist:PTR TO lh,mynode:PTR TO ln
    DEF obj:PTR TO object3d
    DEF faces,pts,n
    DEF v1,v2,v3

    g_exported:=0
    g_skipped_invalid:=0
    g_skipped_degenerate:=0

    IF h:=Open(outfile,1006)
        oldout:=stdout
        stdout:=h

        WriteF('solid ddd2stl\n')

        mylist:=base.objlist
        mynode:=mylist.head
        WHILE mynode
            IF mynode.succ<>0
                obj:=mynode
                pts:=obj.datapts
                faces:=obj.datafcs

                FOR n:=0 TO obj.nbrsfcs-1
                    v1:=Long(faces)
                    v2:=Long(faces+4)
                    v3:=Long(faces+8)

                    IF (v1>=0) AND (v2>=0) AND (v3>=0) AND (v1<obj.nbrspts) AND (v2<obj.nbrspts) AND (v3<obj.nbrspts)
                        IF (v1<>v2) AND (v1<>v3) AND (v2<>v3) AND calcNormal(pts,v1,v2,v3,scale)
                            WriteF('  facet normal ')
                            writeSTLFloat(g_nx)
                            WriteF(' ')
                            writeSTLFloat(g_ny)
                            WriteF(' ')
                            writeSTLFloat(g_nz)
                            WriteF('\n')
                            WriteF('    outer loop\n')
                            writeSTLVertex(pts,v1,scale)
                            writeSTLVertex(pts,v2,scale)
                            writeSTLVertex(pts,v3,scale)
                            WriteF('    endloop\n')
                            WriteF('  endfacet\n')
                            g_exported++
                        ELSE
                            g_skipped_degenerate++
                        ENDIF
                    ELSE
                        g_skipped_invalid++
                    ENDIF

                    faces:=faces+12
                ENDFOR
            ENDIF
            mynode:=mynode.succ
        ENDWHILE

        WriteF('endsolid ddd2stl\n')

        stdout:=oldout
        Close(h)
        ret:=TRUE
    ENDIF
ENDPROC ret

PROC calcNormal(pts,v1,v2,v3,scale)
    DEF p1,p2,p3
    DEF x1,y1,z1,x2,y2,z2,x3,y3,z3
    DEF ux,uy,uz,vx,vy,vz

    p1:=pts+(v1*12)
    p2:=pts+(v2*12)
    p3:=pts+(v3*12)

    x1:=IeeeSPMul(Long(p1),scale)
    y1:=IeeeSPMul(Long(p1+4),scale)
    z1:=IeeeSPMul(Long(p1+8),scale)
    x2:=IeeeSPMul(Long(p2),scale)
    y2:=IeeeSPMul(Long(p2+4),scale)
    z2:=IeeeSPMul(Long(p2+8),scale)
    x3:=IeeeSPMul(Long(p3),scale)
    y3:=IeeeSPMul(Long(p3+4),scale)
    z3:=IeeeSPMul(Long(p3+8),scale)

    ux:=IeeeSPSub(x2,x1)
    uy:=IeeeSPSub(y2,y1)
    uz:=IeeeSPSub(z2,z1)
    vx:=IeeeSPSub(x3,x1)
    vy:=IeeeSPSub(y3,y1)
    vz:=IeeeSPSub(z3,z1)

    g_nx:=IeeeSPSub(IeeeSPMul(uy,vz),IeeeSPMul(uz,vy))
    g_ny:=IeeeSPSub(IeeeSPMul(uz,vx),IeeeSPMul(ux,vz))
    g_nz:=IeeeSPSub(IeeeSPMul(ux,vy),IeeeSPMul(uy,vx))

    IF (IeeeSPCmp(g_nx,0.0)=0) AND (IeeeSPCmp(g_ny,0.0)=0) AND (IeeeSPCmp(g_nz,0.0)=0) THEN RETURN FALSE
ENDPROC TRUE

PROC writeSTLVertex(pts,index,scale)
    DEF p,x,y,z
    p:=pts+(index*12)
    x:=IeeeSPMul(Long(p),scale)
    y:=IeeeSPMul(Long(p+4),scale)
    z:=IeeeSPMul(Long(p+8),scale)

    WriteF('      vertex ')
    writeSTLFloat(x)
    WriteF(' ')
    writeSTLFloat(y)
    WriteF(' ')
    writeSTLFloat(z)
    WriteF('\n')
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

PROC string2Float(s)
    DEF entier[80]:STRING,decimal[80]:STRING
    DEF pos,len,i,p,ei,di,res

    IF s=NIL THEN RETURN 0.1
    len:=EstrLen(s)
    IF len=0 THEN RETURN 0.1

    pos:=InStr(s,'.',0)
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

PROC main() HANDLE
    DEF signal,result,running

    IF (muimasterbase:=OpenLibrary(MUIMASTER_NAME,MUIMASTER_VMIN))=NIL THEN Raise(1)
    IF openLibraries()=FALSE THEN Raise(2)

    ap_app := ApplicationObject,
        MUIA_Application_Title, 'DDD2STL',
        MUIA_Application_Version, '0.1',
        MUIA_Application_Author, 'Denis Costils',
        MUIA_Application_Description, 'Amiga 3D to STL converter',
        MUIA_Application_Base, 'DDD2STL',

        SubWindow,
            wi_main := WindowObject,
                MUIA_Window_Title, 'DDD2STL',
                MUIA_Window_ID, "D2SL",
                MUIA_Width, 520,
                MUIA_Height, 180,
                WindowContents, VGroup,

                    Child, GroupObject,
                        MUIA_Frame, MUIV_Frame_Group,
                        MUIA_FrameTitle, '3D object',
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
                        Child, TextObject, MUIA_Text_Contents, 'STL file', End,
                        Child, PopaslObject,
                            MUIA_Popasl_Type, 0,
                            MUIA_Popstring_String, st_dest := StringObject,
                                StringFrame,
                                MUIA_String_Contents, 'RAM:object.stl',
                                MUIA_String_MaxLen, 255,
                            End,
                            MUIA_Popstring_Button, PopButton(MUII_PopFile),
                        End,
                        Child, TextObject, MUIA_Text_Contents, 'Scale', End,
                        Child, st_scale := StringObject,
                            StringFrame,
                            MUIA_String_Contents, '0.1',
                            MUIA_String_MaxLen, 63,
                        End,
                    End,

                    Child, HGroup,
                        Child, bt_convert := bouton('Convert'),
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

    IF ap_app=NIL THEN Raise(3)

    doMethod(wi_main, [MUIM_Notify, MUIA_Window_CloseRequest, MUI_TRUE, ap_app, 2, MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])
    doMethod(bt_convert, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_CONVERT])
    doMethod(bt_clear, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, ID_CLEAR])
    doMethod(bt_quit, [MUIM_Notify, MUIA_Pressed, FALSE, ap_app, 2, MUIM_Application_ReturnID, MUIV_Application_ReturnID_Quit])

    set(wi_main, MUIA_Window_Open, MUI_TRUE)

    running:=TRUE
    WHILE running
        result:=doMethod(ap_app, [MUIM_Application_Input, {signal}])
        IF result<>MUIV_Application_ReturnID_Quit
            SELECT result
                CASE ID_CONVERT
                    convert_from_gui()
                CASE ID_CLEAR
                    set(st_source, MUIA_String_Contents, '')
                    set(st_dest, MUIA_String_Contents, 'RAM:object.stl')
                    set(st_scale, MUIA_String_Contents, '0.1')
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
        CASE 2 ; WriteF('Cannot open ddd.library or math libraries.\n')
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
