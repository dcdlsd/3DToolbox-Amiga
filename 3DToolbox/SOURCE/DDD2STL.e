-> DDD2STL.e
-> First test: convert a 3D object readable by ddd.library to ASCII STL.
-> Usage:
->   DDD2STL source.3d ram:objet.stl SCALE 1.0

OPT PREPROCESS
OPT LARGE

MODULE 'dos/dos'
MODULE 'exec/lists','exec/nodes'
MODULE 'mathffp','mathtrans'
MODULE 'mathieeesingbas','mathieeesingtrans'
MODULE 'ddd','libraries/dddobject'

ENUM ER_NONE,ER_ARGS,ER_LIB,ER_BASE,ER_READ,ER_WRITE

DEF g_exported,g_skipped_invalid,g_skipped_degenerate
DEF g_nx,g_ny,g_nz

PROC main() HANDLE
    DEF args:PTR TO LONG,rdargs=NIL
    DEF source,dest,scale=1.0
    DEF base=NIL:PTR TO base3d,ret,typ

    args:=[0,0,0]:LONG

    IF openLibraries()=FALSE THEN Raise(ER_LIB)

    IF rdargs:=ReadArgs('SOURCE/A,DEST/A,SCALE/K',args,NIL)
        source:=args[0]
        dest:=args[1]
        IF args[2] THEN scale:=string2Float(args[2])

        WriteF('DDD2STL: loading \s\n',source)
        base:=Init3DBase()
        IF base=NIL THEN Raise(ER_BASE)
        IF base=ERR3D_MEM THEN Raise(ER_BASE)
        IF base=ERR3D_MATHLIB THEN Raise(ER_BASE)

        ret,typ:=ReadFile3D(base,source)
        IF ret<>ERR3D_NONE THEN Raise(ER_READ)

        WriteF('DDD2STL: objects=\d points=\d faces=\d\n',base.nbrsobjs,base.totalpts,base.totalfcs)
        IF exportSTL(base,dest,scale)=FALSE THEN Raise(ER_WRITE)

        WriteF('DDD2STL: saved \s\n',dest)
        WriteF('DDD2STL: exported faces=\d skipped bad faces=\d\n',
            g_exported,g_skipped_invalid+g_skipped_degenerate)
        IF (g_skipped_invalid+g_skipped_degenerate)>0
            WriteF('DDD2STL: warning, model may need repair before Cura.\n')
        ENDIF
    ELSE
        Raise(ER_ARGS)
    ENDIF

    Raise(ER_NONE)

EXCEPT DO
    SELECT exception
        CASE ER_ARGS
            WriteF('Usage: DDD2STL SOURCE DEST SCALE/K\n')
            WriteF('Example: DDD2STL work:object.3d ram:object.stl SCALE 1.0\n')
        CASE ER_LIB
            WriteF('Error: missing library. Need ddd.library and math libraries.\n')
        CASE ER_BASE
            WriteF('Error: cannot initialise ddd 3D base.\n')
        CASE ER_READ
            WriteF('Error: source file not readable or unsupported by ddd.library.\n')
        CASE ER_WRITE
            WriteF('Error: cannot write STL output file.\n')
    ENDSELECT

    IF isValidBase(base) THEN Rem3DBase(base)
    IF rdargs THEN FreeArgs(rdargs)
    closeLibraries()
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

    IF s=NIL THEN RETURN 1.0
    len:=EstrLen(s)
    IF len=0 THEN RETURN 1.0

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
