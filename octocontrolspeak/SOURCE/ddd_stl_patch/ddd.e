->> EDEVHEADER
/*= © NasGûl nasgul@faws.org ! http://www.faws.org)
 ESOURCE ddd.e
 EDIR    Workbench:AmigaE/Sources/3DView/3DLib
 ECOPT   ERRLINE
 EXENAME ddd.library
 MAKE    BUILD
 AUTHOR  NasGûl
 TYPE    EXELIB
=====================================*/
-><
->> ©/DISTRIBUTION/UTILISATION
/*=====================================

 - TOUTE UTILISATION COMMERCIALE DES CES SOURCES EST
   INTERDITE SANS MON AUTORISATION.

 - TOUTE DISTRIBUTION DOIT ETRE FAITES EN TOTALITE (EXECUTABLES/MODULES E/SOURCES E).

 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
 !! TOUTE INCLUSION SUR UN CD-ROM EST INTERDITE SANS MON AUTORISATION.!!
 !! SEULES LES DISTRIBUTIONS DE FRED FISH ET AMINET CDROM SONT AUTO-  !!
 !! RISES A DISTRIBUER CES PROGRAMMES/SOURCES.                        !!
 !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

=====================================*/
-><
->> HISTORY
/*= History ===========================
    v 0.8004 - premiere version de la librarie  
                (les routines faisait parti du programme 3DView).
    v 0.8010 - Le chargement des objets au format Vertex est plus fiable
               fixe du bug lors du chargement de fichiers Vertex contenant des
               objets ayant des points désélectionnés.
    v 0.8012 - ajout de la sauvegarde au format WaveFront/TTDDD/Imagine (TDDD).
               une seule fonction pour la sauvegarde (WriteFile3D) replace les fonctions Save<nom>File().
               la valeur défini dans base3d.saveformat défini le format de sauvegarde.
               la routine de sauvegarde sous GEO ne sauve plus des espaces en trop
               sur la description des points. (2 espaces entre les valeurs perturbe Vertex).
               ATTENTION !! LA SAUVEGARDE SOUS TTDDD ET TDDD CE FAIT AVEC DES ARETES DOUBLEES,VOUS
               DEVEZ DANS IMAGINE FAIRE UN MERGE POUR EFFACER LES ARETES DUPLIQUEES.
    v 0.8013 - Replacement de tous les * par des Mul() dans la fonction MakeObject().les * provoquaient des plantages
               sur le calcul de grosse primitives (genre 256 256).
             - Oubli d'un > dans la routine de sauvegarde sous POV2 (les fichiers sont directement exploitable sans retouche manuelle).
    v 0.8014 - Chargement des fichiers au format 3DStudio possible.
             - Plus de plantages sur un 'mémoire insufissante'.
    v 0.8016 - Sauvegarde au format 3DStudio ASCII.
             - Chargement au format GEO (les OBJECT doivent avoir que 3 points par faces).
             - La routine de centrage marche beaucoup mieux.
             - 'Netoyage' du Code source (unreferenced) et commentaires.
             - Ajout de la fonction DeleteObject3D().
    v 0.8017 - Ajout du format de sauvegarde Caligari Ascii.
    v 0.8018 - Ajout experimental du chargement STL ASCII par Denis Costils/Codex.
=====================================*/
-><
OPT PREPROCESS,LARGE
->> MODULE

->#define DEBUG
->MODULE 'tools/debug'

MODULE 'exec/nodes'  -> les objets sont chainés dans une liste Exec (lh).
MODULE 'mathieeesingbas','mathieeesingtrans'
MODULE 'exec/lists','exec/ports'
MODULE 'dos/dos','dos/rdargs'
MODULE 'other/plist'
MODULE 'mathffp','mathtrans'
MODULE 'intuition/intuition','intuition/screens'
MODULE 'graphics/modeid'

MODULE 'vector','libraries/vector'
MODULE 'tools/filledvector','tools/filledvdefs'
MODULE 'tools/file'

MODULE '*dddHeader','*dddobject'

RAISE ERR3D_MEM IF New()=NIL

-><
->> LIBRARY DEFINITIONS
LIBRARY PRG_NAME,PRG_VERSION,PRG_REVISION,PRG_VER IS
     init3DBase         ,
     checkIf3DFile      ,
     readFile3D         ,
     writeFile3D        ,
     rem3DBase          ,
     updateCenterBase3D     ,
     buildMinMax        ,
     formatBase3DWithScreen ,
     formatBase3DWithWindow ,
     drawBase3D         ,
     drawObject3D       ,
     drawObjectFace     ,
     clearDrawingArea       ,
     conv3DObj2Vect     ,
     conv3DObj2VectLib      ,
     renderVectorObject     ,
     getColor           ,
     makeObject         ,
     primCube           ,
     rotateBase3D       ,
     rotateBase         ,
     rotateObject3D     ,
     centreBase3D       ,
     centreObject3D     ,
     boundedObject3D        ,
     boundedAllObject3D     ,
     selectObject3D     ,
     selectAllObject3D  ,
     deleteObject3D
-><
PROC main() IS EMPTY
->> init3DBase() HANDLE
PROC init3DBase() HANDLE
/*== © NasGûl ==================================
Paramètres: NIL.
Retour   : NIL si erreur,sinon addresse de la base initialisée.
Action   : initialise un objet base3d.
===============================================*/
    DEF pb:PTR TO base3d
    #ifdef DEBUG
      kputfmt('init3DBase()\n',NIL)
    #endif
    IF (mathbase:=OpenLibrary('mathffp.library',34))=NIL THEN Raise(ERR3D_MATHLIB)
    IF (mathtransbase:=OpenLibrary('mathtrans.library',34))=NIL THEN Raise(ERR3D_MATHLIB)
    IF (mathieeesingbasbase:=OpenLibrary('mathieeesingbas.library',34))=NIL THEN Raise(ERR3D_MATHLIB)
    IF (mathieeesingtransbase:=OpenLibrary('mathieeesingtrans.library',34))=NIL THEN Raise(ERR3D_MATHLIB)
    pb:=New(SIZEOF base3d)
    pb.nbrsobjs:=0;pb.totalpts:=0;pb.totalfcs:=0
    pb.objlist:=initList()
    IF pb.objlist=NIL THEN Raise(ERR3D_MEM)
    pb.fctoldcyber:=1.0
    pb.fctnewcyber:=1.0
    pb.fct3dpro:=1.0
    pb.fctsculpt:=0.001
    pb.fctimagine:=1.0
    pb.fctvertex:=0.0001
    pb.vectorfactor:=0.1
    pb.minx:=1000000.0
    pb.maxx:=-1000000.0
    pb.miny:=1000000.0
    pb.maxy:=-1000000.0
    pb.minz:=1000000.0
    pb.maxz:=-1000000.0
    pb.echelle:=0.1
    pb.plan:=PLAN_XOY
    pb.basecx:=0.0;pb.basecy:=0.0;pb.basecz:=0.0
    pb.signex:=1.0;pb.signey:=1.0;pb.signez:=1.0
    pb.format:=0.0
    pb.centrex:=0;pb.centrey:=0
    pb.anglerotation:=10.0
    pb.palette:=[$689,$002,$DDD,$458,$B6C,$FB1,$F48,$CFA]:INT
    pb.rgbpts:=7      ->* couleur points *
    pb.rgbnormal:=1   ->* couleur faces  *
    pb.rgbselect:=6   ->* couleur select *
    pb.rgbbounding:=3       ->* couleur de l'encadrement *
    pb.drawmode:=DRAW_PTSFCS
    pb.saveformat:=SAVE_DXF
    pb.savewhat:=SAVEOBJ_ALL
    pb.freedata:=[DISP,22,DISP,26,DISE]
    pb.formatname:=['Imagine',
     'Cyber v1.0',
     'Cyber v2.0',
     'Sculpt',
     'Vertex<v1.62a',
     'Vertex>v1.73.f',
     '3Dpro',
     'STL ASCII',
     'Vertex v2.0',
     '3DStudio',
     'Geo',
     '',             -> pour le TYPE_UNKNOWN
     '3DPCTorus',
     '3DPCMoebius',
     '3DPCPlan',
     '3DPCTrbl',
     '3DPCSphere',
     '3DPCSpirale',
     '3DPCVagues',
     '3DPCCylindre',
     '3DPCConeD',
     '3DPCDome',
     '3DPDCube',
     '3DPDTetra',
     '3DPDOcta',
     '3DPDDodeca',
     '3DPDIcosa',
     '3DPDCubo',
     'UnKnown']
    pb.stopcode:=$21
    Raise(pb)
EXCEPT
    IF exception="MEM" 
        IF pb.objlist<>NIL THEN cleanList(pb.objlist,FALSE,0,LIST_REMOVE)
        IF pb<>NIL THEN Dispose(pb)
        RETURN ERR3D_MEM
    ENDIF
    RETURN exception
ENDPROC
-><
->> checkIf3DFile(fichier)
PROC checkIf3DFile(fichier)
/*== © NasGûl ==================================
Paramètres: nom d'un fichier amigados STRING.
Retour   : 2 valeur,1 valeur TRUE si ok sinon FALSE,2 valeur le type de l'objet.
Action   : verifie la validité de l'objet.
================================================*/
    DEF len,adr,buf,hdle,chunk,error=ERR3D_NONE,retype=TYPE_UNKNOWN
    #ifdef DEBUG
        kputfmt('checkIf3DFile(\s)\n',[fichier])
    #endif
    IF (FileLength(fichier))<>-1
        IF buf:=New(16)
            IF hdle:=Open(fichier,1005)
                IF len:=Read(hdle,buf,15)
                    Close(hdle)
                    adr:=buf
                    chunk:=Int(adr)
                    IF chunk=ID_3D2
                        Dispose(buf)
                        RETURN error,TYPE_NEWCYBER
                    ELSEIF chunk=ID_3D3D
                        Dispose(buf)
                        RETURN error,TYPE_OLDCYBER
                    ELSEIF chunk=ID_3DS
                        Dispose(buf)
                        RETURN error,TYPE_3DS
                    ENDIF
                    chunk:=Long(adr)
                    IF chunk=ID_VR3D
                        Dispose(buf)
                        RETURN error,TYPE_NEWVERTEX
                    ELSEIF chunk=ID_VE3D
                        Dispose(buf)
                        RETURN error,TYPE_OLDVERTEX
                    ELSEIF chunk=ID_3DPRO
                        Dispose(buf)
                        RETURN error,TYPE_3DPRO
                    ELSEIF chunk=ID_STL
                        Dispose(buf)
                        RETURN error,TYPE_STL
                    ELSEIF chunk=ID_GEO
                        Dispose(buf)
                        RETURN error,TYPE_GEO
                    ENDIF
                    chunk:=Long(adr+8)
                    SELECT chunk
                        CASE ID_TDDD
                            Dispose(buf)                            
                            RETURN error,TYPE_IMAGINE
                        CASE ID_SC3D
                            Dispose(buf)                            
                            RETURN error,TYPE_SCULPT
                        CASE ID_3DDD
                            Dispose(buf)                            
                            RETURN error,TYPE_VERTEX2
                            /*
                        CASE ID_LWOB
                            Dispose(buf)
                            RETURN error,TYPE_LIGHTWAVE
                            */
                    ENDSELECT
                ENDIF
            ELSE
                error:=ERR3D_NOFILE
            ENDIF
        ELSE
            error:=ERR3D_MEM
        ENDIF
        IF retype=TYPE_UNKNOWN THEN error:=ERR3D_UNKNOWNFILE
    ELSE
        error:=ERR3D_NOFILE
    ENDIF
ENDPROC error,retype
-><
->> readFile3D(base:PTR TO base3d,file)
PROC readFile3D(base:PTR TO base3d,file)
/*== © NasGûl ==================================
Paramètres: pointeur sur un objet base3d,nom d'un fichier amigados STRING.
Retour   : 2 valeur ,1 valeur TRUE siok sinon FALSE,2 valeur le type d'objet.
Action   : charge dans la base 3d un objet.
===============================================*/
    DEF n,er,ret=FALSE
    #ifdef DEBUG
      kputfmt('readFile3D($\h:PTR TO base3d,\s)\n',[base,file])
    #endif
    er,n:=checkIf3DFile(file)
    IF n<>TYPE_UNKNOWN
        SELECT n
            CASE TYPE_IMAGINE;    ret:=readImagineFile(base,file)
            CASE TYPE_OLDCYBER;   ret:=read3DFile(base,file)
            CASE TYPE_NEWCYBER;   ret:=read3D2File(base,file)
            CASE TYPE_OLDVERTEX;  ret:=readVertexFile(base,file,ID_VE3D)
            CASE TYPE_NEWVERTEX;  ret:=readVertexFile(base,file,ID_VR3D)
            CASE TYPE_3DPRO;    ret:=read3DProFile(base,file)
            CASE TYPE_STL;       ret:=readStlFile(base,file)
->            CASE TYPE_LIGHTWAVE; ret:=readLightWaveFile(base,file)
            CASE TYPE_SCULPT;   ret:=readSculptFile(base,file)
            CASE TYPE_VERTEX2;    ret:=readVertex2File(base,file)
            CASE TYPE_3DS;        ret:=read3DStudioFile(base,file)
            CASE TYPE_GEO;        ret:=readGeoFile(base,file)
        ENDSELECT
        er:=ret
    ENDIF
    base.nbrsobjs:=countNodes(base.objlist)
    updateCenterBase3D(base)
ENDPROC er,n
-><
->> writeFile3D(base:PTR TO base3d,dir)
PROC writeFile3D(base:PTR TO base3d,dir)
/*== © NasGûl ==================================
Paramètres: pointeur sur un objet base3d,nom d'un dossier amigados STRING.
Retour   : 1 valeur TRUE si ok sinon FALSE.
Action   : sauve dans le dossier la base de données suvant le format spécifié en <base.saveformat>.
===============================================*/
    DEF fr,t
    fr:=base.saveformat
    SELECT fr
        CASE SAVE_DXF;  t:=saveDxfFile(base,dir)
        CASE SAVE_GEO;  t:=saveGeoFile(base,dir)
        CASE SAVE_RAY;  t:=saveRayFile(base,dir)
        CASE SAVE_BIN;  t:=saveBinFile(base,dir,base.vectorfactor)
        CASE SAVE_POV1; t:=savePovFile(base,dir)
        CASE SAVE_POV2; t:=savePovFile(base,dir)
        CASE SAVE_WAVEFRONT;    t:=saveWaveFrontFile(base,dir)
        CASE SAVE_TTDDD; t:=saveTtdddFile(base,dir)
        CASE SAVE_TDDD; t:=saveTdddFile(base,dir)
        CASE SAVE_3DSASC; t:=save3dsAscFile(base,dir)
        CASE SAVE_CALIASC;  t:=saveCaliAscFile(base,dir)
    ENDSELECT
    RETURN t
ENDPROC
-><
->> rem3DBase(base:PTR TO base3d)
PROC rem3DBase(base:PTR TO base3d)
/*== © NasGûl ==================================
Paramètres: pointeur sur un objet base3d.
Retour   : NIL
Actlion   : libère la mémoire utilisé.
===============================================*/
    #ifdef DEBUG
      kputfmt('rem3DBase($\h:PTR TO base3d)\n',[base])
    #endif
    IF emptyList(base.objlist)<>-1
        cleanList(base.objlist,TRUE,base.freedata,LIST_REMOVE)
    ENDIF
    IF base THEN Dispose(base)
    IF mathieeesingtransbase THEN CloseLibrary(mathieeesingtransbase)
    IF mathieeesingbasbase THEN CloseLibrary(mathieeesingbasbase)
    IF mathtransbase THEN CloseLibrary(mathtransbase)
    IF mathbase THEN CloseLibrary(mathbase)
ENDPROC
-><
->> updateCenterBase3D(base:PTR TO base3d)
PROC updateCenterBase3D(base:PTR TO base3d)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet 3base3d
Retour   : NIL
Action   : remet a jour le centre de la base 3d,les mini/maxi
           des objets de la base doivent être juste.
================================================*/
    DEF ml:PTR TO lh
    DEF mo:PTR TO object3d
    
    DEF b_minx=1000000.0
    DEF b_maxx=-1000000.0
    DEF b_miny=1000000.0
    DEF b_maxy=-1000000.0
    DEF b_minz=1000000.0
    DEF b_maxz=-1000000.0

    #ifdef DEBUG
      kputfmt('updateCenterBase3D($\h:PTR TO base3d)\n',[base])
    #endif

    ml:=base.objlist
    mo:=ml.head
    WHILE mo
        IF mo.obj_node.succ<>0
            b_minx:=fMin(mo.objminx,b_minx)
            b_maxx:=fMax(mo.objmaxx,b_maxx)
            b_miny:=fMin(mo.objminy,b_miny)
            b_maxy:=fMax(mo.objmaxy,b_maxy)
            b_minz:=fMin(mo.objminz,b_minz)
            b_maxz:=fMax(mo.objmaxz,b_maxz)
        ENDIF
        mo:=mo.obj_node.succ
    ENDWHILE

    base.minx:=b_minx;base.maxx:=b_maxx
    base.miny:=b_miny;base.maxy:=b_maxy
    base.minz:=b_minz;base.maxz:=b_maxz

    base.basecx:=IeeeSPAdd(base.minx,IeeeSPMul(IeeeSPSub(base.maxx,base.minx),0.5))
    base.basecy:=IeeeSPAdd(base.miny,IeeeSPMul(IeeeSPSub(base.maxy,base.miny),0.5))
    base.basecz:=IeeeSPAdd(base.minz,IeeeSPMul(IeeeSPSub(base.maxz,base.minz),0.5))
ENDPROC
-><
->> buildMinMax(base:PTR TO base3d,obj:PTR TO object3d,update)
PROC buildMinMax(base:PTR TO base3d,obj:PTR TO object3d,update)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,pointeur sur un objet object3d,true ou false.
Retour   : NIL
Action   : cacule les mini/maxi d'un objet,si update en mis sur TRUE,les
       mini/maxi de la base sont remis a jour.
================================================*/
    DEF o_minx=1000000.0
    DEF o_maxx=-1000000.0
    DEF o_miny=1000000.0
    DEF o_maxy=-1000000.0
    DEF o_minz=1000000.0
    DEF o_maxz=-1000000.0


    DEF re_pts:PTR TO vertice,curs,b
    DEF nx,ny,nz
    #ifdef DEBUG
        kputfmt('buildMinMax($\h:PTR TO base3d,$\h:PTR TO object3d,\d)\n',[base,obj,update])
    #endif
    re_pts:=obj.datapts
    curs:=re_pts
    FOR b:=0 TO obj.nbrspts-1      -> read vertices
        re_pts:=curs
        nx:=re_pts.x
        ny:=re_pts.y
        nz:=re_pts.z
        o_minx:=fMin(nx,o_minx)
        o_maxx:=fMax(nx,o_maxx)
        o_miny:=fMin(ny,o_miny)
        o_maxy:=fMax(ny,o_maxy)
        o_minz:=fMin(nz,o_minz)
        o_maxz:=fMax(nz,o_maxz)
        curs:=curs+12
    ENDFOR
    obj.objminx:=o_minx;obj.objmaxx:=o_maxx
    obj.objminy:=o_miny;obj.objmaxy:=o_maxy
    obj.objminz:=o_minz;obj.objmaxz:=o_maxz


    obj.objcx:=fadd(o_minx,fdiv(fsub(o_maxx,o_minx),2.0))
    obj.objcy:=fadd(o_miny,fdiv(fsub(o_maxy,o_miny),2.0))
    obj.objcz:=fadd(o_minz,fdiv(fsub(o_maxz,o_minz),2.0))

    base.minx:=fMin(obj.objminx,base.minx)
    base.maxx:=fMax(obj.objmaxx,base.maxx)
    base.miny:=fMin(obj.objminy,base.miny)
    base.maxy:=fMax(obj.objmaxy,base.maxy)
    base.minz:=fMin(obj.objminz,base.minz)
    base.maxz:=fMax(obj.objmaxz,base.maxz)

    IF update=TRUE

        base.basecx:=fadd(base.minx,fdiv(fsub(base.maxx,base.minx),2.0))
        base.basecy:=fadd(base.miny,fdiv(fsub(base.maxy,base.miny),2.0))
        base.basecz:=fadd(base.minz,fdiv(fsub(base.maxz,base.minz),2.0))

    ENDIF
ENDPROC
-><
->> formatBase3DWithScreen(base:PTR TO base3d,s:PTR TO screen)
PROC formatBase3DWithScreen(base:PTR TO base3d,s:PTR TO screen)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,pointeur sur un écran.
Retour   : NIL
Action   : Calcule le rectangle de clipping,centre du rectangle de dessin.
================================================*/
    #ifdef DEBUG
        kputfmt('formatBase3DWithScreen($\h:PTR TO base3d,$\h:PTR TO screen)\n',[base,s])
    #endif
    base.draw_x:=s.leftedge
    base.draw_y:=s.topedge
    base.draw_w:=s.width
    base.draw_h:=s.height
    base.centrex:=Div(s.width,2)
    base.centrey:=Div(s.height,2)
    base.format:=IeeeSPDiv(SpTieee(SpFlt(s.width)),SpTieee(SpFlt(s.height)))
ENDPROC
-><
->> formatBase3DWithWindow(base:PTR TO base3d,w:PTR TO window)
PROC formatBase3DWithWindow(base:PTR TO base3d,w:PTR TO window)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,pointeur sur une fenêtre.
Retour   : NIL
Action   : Calcule le rectangle de clipping,centre du rectangle de dessin.
================================================*/
    DEF bl,bt,br,bb
    #ifdef DEBUG
        kputfmt('formatBase3DWithWindow($\h:PTR TO base3d,$\h:PTR TO window )\n',[base,w])
    #endif
    bl:=w.borderleft
    bt:=w.bordertop
    br:=w.borderright
    bb:=w.borderbottom
    base.draw_x:=bl
    base.draw_y:=bt
    base.draw_w:=w.width-(br-1)
    base.draw_h:=w.height-(bb-1)-(bt-1)
    base.centrex:=Div(w.width,2)
    base.centrey:=Div(w.height,2)
    base.format:=IeeeSPDiv(SpTieee(SpFlt(w.width)),SpTieee(SpFlt(w.height)))
ENDPROC
-><
->> drawBase3D(base:PTR TO base3d,win:PTR TO window)
PROC drawBase3D(base:PTR TO base3d,win:PTR TO window)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,pointeur sur un objet window
Retour   : TRUE si ok,FALSE si l'objet sort de rectangle,STOP_DRAWING si l'utilisateur
       a stopper le dessin.
Action   : Dessine labase 3D.
================================================*/
    DEF l:PTR TO lh
    DEF dob:PTR TO object3d
    DEF disinfo
    DEF oldrast
    #ifdef DEBUG
        kputfmt('drawBase3D( $\h:PTR TO base3d , $\h:PTR TO window )\n',[base,win])
    #endif
    clearDrawingArea(win,0)
    SetAPen(win.rport,0)
    oldrast:=SetStdRast(win.rport)
    l:=base.objlist
    dob:=l.head
    WHILE dob
        IF dob.obj_node.succ<>0
            disinfo:=drawObject3D(base,dob,win)
            IF ((disinfo<>TRUE) OR (disinfo=STOP_DRAWING))
                SetAPen(win.rport,0)
                SetStdRast(oldrast)
                RETURN FALSE
            ENDIF
        ENDIF
        dob:=dob.obj_node.succ
    ENDWHILE
    SetStdRast(oldrast)
ENDPROC disinfo
-><
->> drawObject3D(base:PTR TO base3d,do:PTR TO object3d,win:PTR TO window)
PROC drawObject3D(base:PTR TO base3d,dob:PTR TO object3d,win:PTR TO window)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,pointeur sur un objetobject3d,pointeur sur objet window.
Retour   : TRUE si ok,sinon FALSE,sinon STOP_DRAWING
Action   : Dessin un objet de labase 3D.
================================================*/
    DEF list_vertices
    DEF data_boundedbox
    DEF t_faces,d_faces,list_datapts,curs,b
    DEF disinfo=TRUE
    DEF viewport:PTR TO mp,stop_mes:PTR TO intuimessage,class,code
    viewport:=win.userport
    #ifdef DEBUG
        kputfmt('drawObject3D( $\h:PTR TO base3d , $\h:PTR TO object3d , $\h:PTR TO window )\n',[base,dob,win])
    #endif
    IF dob.selected=TRUE THEN SetAPen(win.rport,base.rgbselect) ELSE SetAPen(win.rport,base.rgbnormal)
    IF dob.bounded=TRUE
        list_vertices:=[dob.objminx,dob.objminy,dob.objminz,
                dob.objminx,dob.objmaxy,dob.objminz,
                dob.objmaxx,dob.objmaxy,dob.objminz,
                dob.objmaxx,dob.objminy,dob.objminz,
                dob.objminx,dob.objminy,dob.objmaxz,
                dob.objminx,dob.objmaxy,dob.objmaxz,
                dob.objmaxx,dob.objmaxy,dob.objmaxz,
                dob.objmaxx,dob.objminy,dob.objmaxz]
        data_boundedbox:=[0,2,1,0,3,2,3,6,2,3,7,6,7,5,6,7,4,5,4,0,1,4,1,5,1,2,6,1,6,5,4,7,3,4,3,0]
        SetAPen(win.rport,2)
        t_faces:=12
        d_faces:=data_boundedbox
        list_datapts:=list_vertices
    ELSE
        t_faces:=dob.nbrsfcs
        d_faces:=dob.datafcs
        list_datapts:=d_faces
    ENDIF
    curs:=d_faces
    FOR b:=0 TO t_faces-1
        disinfo:=drawObjectFace(base,win,dob,Long(curs),Long(curs+4),Long(curs+8),list_datapts)
        IF (disinfo<>TRUE) THEN RETURN disinfo
        IF stop_mes:=GetMsg(viewport)
            class:=stop_mes.class
            code:=stop_mes.code
            IF (class=IDCMP_RAWKEY) AND (code=base.stopcode)
                DisplayBeep(0)
                WHILE stop_mes:=GetMsg(viewport) DO ReplyMsg(stop_mes)
                RETURN STOP_DRAWING
            ENDIF
            WHILE stop_mes:=GetMsg(viewport) DO ReplyMsg(stop_mes)
        ENDIF
        curs:=curs+12
    ENDFOR
ENDPROC disinfo
-><
->> drawObjectFace(base:PTR TO base3d,w:PTR TO window,do:PTR TO object3d,np1,np2,np3,list_datapts)
PROC drawObjectFace(base:PTR TO base3d,w:PTR TO window,dob:PTR TO object3d,np1,np2,np3,list_datapts)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,pointeur sur un objet window,
       pointeur sur un objet onject3d,1 sommet,2 sommet,3 sommet ,données des points.
Retour   : TRUE si ok,sinon FALSE.
Action   : Dessine une face d'un objet.
================================================*/
    DEF x1,y1,z1,x2,y2,z2,x3,y3,z3
    DEF fx_one,fx_two,fx_three
    DEF fy_one,fy_two,fy_three
    DEF plan,disinfo=TRUE
    IF dob.bounded=FALSE
        list_datapts:=dob.datapts
    ENDIF
    x1:=IeeeSPMul(base.signex,Long(list_datapts+(np1*12)))
    y1:=IeeeSPMul(base.signey,Long(list_datapts+(np1*12)+4))
    z1:=IeeeSPMul(base.signez,Long(list_datapts+(np1*12)+8))
    x2:=IeeeSPMul(base.signex,Long(list_datapts+(np2*12)))
    y2:=IeeeSPMul(base.signey,Long(list_datapts+(np2*12)+4))
    z2:=IeeeSPMul(base.signez,Long(list_datapts+(np2*12)+8))
    x3:=IeeeSPMul(base.signex,Long(list_datapts+(np3*12)))
    y3:=IeeeSPMul(base.signey,Long(list_datapts+(np3*12)+4))
    z3:=IeeeSPMul(base.signez,Long(list_datapts+(np3*12)+8))
    plan:=base.plan
    SELECT plan
        CASE PLAN_XOY
            fx_one:=  IeeeSPAdd(IeeeSPMul(IeeeSPMul(base.echelle,x1),base.format),SpTieee(SpFlt(base.centrex)))
            fx_two:=  IeeeSPAdd(IeeeSPMul(IeeeSPMul(base.echelle,x2),base.format),SpTieee(SpFlt(base.centrex)))
            fx_three:=IeeeSPAdd(IeeeSPMul(IeeeSPMul(base.echelle,x3),base.format),SpTieee(SpFlt(base.centrex)))
            fy_one:=  IeeeSPAdd(IeeeSPMul(base.echelle,y1),SpTieee(SpFlt(base.centrey)))
            fy_two:=  IeeeSPAdd(IeeeSPMul(base.echelle,y2),SpTieee(SpFlt(base.centrey)))
            fy_three:=IeeeSPAdd(IeeeSPMul(base.echelle,y3),SpTieee(SpFlt(base.centrey)))
        CASE PLAN_XOZ
            fx_one:=IeeeSPAdd(IeeeSPMul(IeeeSPMul(base.echelle,x1),base.format),SpTieee(SpFlt(base.centrex)))
            fx_two:=IeeeSPAdd(IeeeSPMul(IeeeSPMul(base.echelle,x2),base.format),SpTieee(SpFlt(base.centrex)))
            fx_three:=IeeeSPAdd(IeeeSPMul(IeeeSPMul(base.echelle,x3),base.format),SpTieee(SpFlt(base.centrex)))
            fy_one:=IeeeSPAdd(IeeeSPMul(base.echelle,z1),SpTieee(SpFlt(base.centrey)))
            fy_two:=IeeeSPAdd(IeeeSPMul(base.echelle,z2),SpTieee(SpFlt(base.centrey)))
            fy_three:=IeeeSPAdd(IeeeSPMul(base.echelle,z3),SpTieee(SpFlt(base.centrey)))
        CASE PLAN_YOZ
            fx_one:=IeeeSPAdd(IeeeSPMul(IeeeSPMul(base.echelle,y1),base.format),SpTieee(SpFlt(base.centrex)))
            fx_two:=IeeeSPAdd(IeeeSPMul(IeeeSPMul(base.echelle,y2),base.format),SpTieee(SpFlt(base.centrex)))
            fx_three:=IeeeSPAdd(IeeeSPMul(IeeeSPMul(base.echelle,y3),base.format),SpTieee(SpFlt(base.centrex)))
            fy_one:=IeeeSPAdd(IeeeSPMul(base.echelle,z1),SpTieee(SpFlt(base.centrey)))
            fy_two:=IeeeSPAdd(IeeeSPMul(base.echelle,z2),SpTieee(SpFlt(base.centrey)))
            fy_three:=IeeeSPAdd(IeeeSPMul(base.echelle,z3),SpTieee(SpFlt(base.centrey)))
    ENDSELECT
    x1:=IeeeSPFix(fx_one)
    x2:=IeeeSPFix(fx_two)
    x3:=IeeeSPFix(fx_three)
    y1:=IeeeSPFix(fy_one)
    y2:=IeeeSPFix(fy_two)
    y3:=IeeeSPFix(fy_three)
    IF (((x1<=(base.draw_x+base.draw_w)) AND (x1>=base.draw_x)) AND
        ((x2<=(base.draw_x+base.draw_w)) AND (x2>=base.draw_x)) AND
        ((x3<=(base.draw_x+base.draw_w)) AND (x3>=base.draw_x)) AND
        ((y1<=(base.draw_y+base.draw_h)) AND (y1>=base.draw_y)) AND
        ((y2<=(base.draw_y+base.draw_h)) AND (y2>=base.draw_y)) AND
        ((y3<=(base.draw_y+base.draw_h)) AND (y3>=base.draw_y)))
        IF ((base.drawmode=DRAW_PTS) OR (base.drawmode=DRAW_PTSFCS))
            SetAPen(w.rport,base.rgbpts)
            RectFill(w.rport,x1-1,y1-1,x1+1,y1+1)
            RectFill(w.rport,x2-1,y2-1,x2+1,y2+1)
            RectFill(w.rport,x3-1,y3-1,x3+1,y3+1)
            SetAPen(w.rport,base.rgbnormal)
        ENDIF
        IF ((base.drawmode=DRAW_FCS) OR (base.drawmode=DRAW_PTSFCS))
            IF dob.selected=TRUE
                SetAPen(w.rport,base.rgbselect)
            ELSEIF dob.bounded=TRUE
                SetAPen(w.rport,base.rgbbounding)
            ELSE
                SetAPen(w.rport,base.rgbnormal)
            ENDIF
            Move(w.rport,x1,y1)
            Draw(w.rport,x2,y2)
            Move(w.rport,x2,y2)
            Draw(w.rport,x3,y3)
            Move(w.rport,x3,y3)
            Draw(w.rport,x1,y1)
        ENDIF
    ELSE
        disinfo:=FALSE
    ENDIF
ENDPROC disinfo
-><
->> clearDrawingArea(win:PTR TO window,color)
PROC clearDrawingArea(win:PTR TO window,color)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet window,couleur.
Retour   : NIL
Action   : Efface la surface du dessin avec la couleur <color>.
================================================*/
    SetAPen(win.rport,color)
    RectFill(win.rport,  win.borderleft,
     win.bordertop,
     win.width-win.borderright-1,
     win.height-win.borderbottom-1)
ENDPROC
-><
->> conv3DObj2Vect(mybase:PTR TO base3d,numobj,v_face,nbrscolors=16,center=FALSE)
PROC conv3DObj2Vect(mybase:PTR TO base3d,numobj,v_face,nbrscolors=16,center=FALSE)
/*== © NasGûl ===================================
Paramètres: pointeur sur une structure base3d,numéro d'objet,flags des faces,nombres de couleurs,
       centre l'objet destination en 0,0,0
Retour   : succes (TRUE si OK,sinon FALSE),addresse des points,addresse des faces
Action   : converti un objet de la base 3D en un format exploitable par le module
       FilledVector.m de Frank Zucchi.
================================================*/
    DEF bo:PTR TO object3d
    DEF intpts:PTR TO INT,adrpts,p,b
    DEF intfcs,nfcs,datafcs,pivface:PTR TO face,color,curintfcs
    DEF ix,iy,iz,icx,icy,icz
    #ifdef DEBUG
        kputfmt('conv3DObj2Vect()\n',NIL)
    #endif
    bo:=getInfoNode(mybase.objlist,numobj,GETWITH_NUM,RETURN_ADR)
    IF bo<>-1
        IF center=TRUE
            icx:=IeeeSPFix(IeeeSPMul(bo.objcx,mybase.vectorfactor))
            icy:=IeeeSPFix(IeeeSPMul(bo.objcy,mybase.vectorfactor))
            icz:=IeeeSPFix(IeeeSPMul(bo.objcz,mybase.vectorfactor))
        ELSE
            icx:=0;icy:=0;icz:=0
        ENDIF
        adrpts:=bo.datapts
        IF intpts:=New(bo.nbrspts*6)
            p:=intpts
            FOR b:=0 TO bo.nbrspts-1
                ix:=IeeeSPFix(IeeeSPMul(Long(adrpts),mybase.vectorfactor))-icx
                iy:=IeeeSPFix(IeeeSPMul(Long(adrpts+4),mybase.vectorfactor))-icy
                iz:=IeeeSPFix(IeeeSPMul(Long(adrpts+8),mybase.vectorfactor))-icz
                CopyMem([ix,iy,iz]:INT,p,6)
                p:=p+6
                adrpts:=adrpts+12
            ENDFOR
        ELSE
            RETURN NIL,NIL
        ENDIF
        IF v_face=FV_DOUBLE THEN nfcs:=bo.nbrsfcs*2 ELSE nfcs:=bo.nbrsfcs
        IF intfcs:=New(SIZEOF face*nfcs)
            curintfcs:=intfcs
            datafcs:=bo.datafcs
            FOR b:=0 TO bo.nbrsfcs-1
                IF pivface:=New(SIZEOF face)
                    IF ((v_face=FV_INDIRECT) OR (v_face=FV_DOUBLE))
                        pivface.cross0:=Int(datafcs+10)
                        pivface.cross1:=Int(datafcs+6)
                        pivface.cross2:=Int(datafcs+2)
                    ELSE
                        pivface.cross0:=Int(datafcs+2)
                        pivface.cross1:=Int(datafcs+6)
                        pivface.cross2:=Int(datafcs+10)
                    ENDIF
                    color:=getColor(nbrscolors,bo,Long(datafcs),Long(datafcs+4),Long(datafcs+8))
                    pivface.colour:=color
                    IF p:=New(14)
                        pivface.facelist:=p
                        CopyMem([3,pivface.cross0,pivface.cross1,pivface.cross1,pivface.cross2,pivface.cross2,pivface.cross0]:INT,pivface.facelist,14)
                    ENDIF
                    pivface.pad00:=NIL
                    CopyMem(pivface,curintfcs,SIZEOF face)
                    curintfcs:=curintfcs+SIZEOF face
                    IF v_face=FV_DOUBLE
                        pivface.cross0:=Int(datafcs+2)
                        pivface.cross1:=Int(datafcs+6)
                        pivface.cross2:=Int(datafcs+10)
                        CopyMem(pivface,curintfcs,SIZEOF face)
                        curintfcs:=curintfcs+SIZEOF face
                    ENDIF
                    IF pivface THEN Dispose(pivface)
                ENDIF
                datafcs:=datafcs+12
            ENDFOR
        ELSE
            RETURN intpts,NIL
        ENDIF
    ELSE
        RETURN NIL,NIL
    ENDIF
ENDPROC intpts,intfcs
-><
->> conv3DObj2VectLib(mybase:PTR TO base3d,numobj,v_face,nbrscolors=16,center=FALSE)
PROC conv3DObj2VectLib(mybase:PTR TO base3d,numobj,v_face,nbrscolors=16,center=FALSE)
/*== © NasGûl ===================================
Paramètres: pointeur sur une structure base3d,numéro d'objet,flags des faces,nombres de couleurs
       centre l'objet destination en 0,0,0
Retour   : succes (TRUE si OK,sinon FALSE),addresse des points,addresse des faces
Action   : converti un objet de la base 3D en un format exploitable par la
       vector.library de A. Lippert
================================================*/
    DEF bo:PTR TO object3d
    DEF intpts,ix,iy,iz,f_datapts,icx,icy,icz
    DEF intfcs,pivpts,pivfcs,b,color,p
    DEF nfcs,npts
    #ifdef DEBUG
        kputfmt('conv3DObj2VectLib()\n',NIL)
    #endif
    bo:=getInfoNode(mybase.objlist,numobj,GETWITH_NUM,RETURN_ADR)
    IF bo<>-1
        IF center=TRUE
            icx:=IeeeSPFix(IeeeSPMul(bo.objcx,mybase.vectorfactor))
            icy:=IeeeSPFix(IeeeSPMul(bo.objcy,mybase.vectorfactor))
            icz:=IeeeSPFix(IeeeSPMul(bo.objcz,mybase.vectorfactor))
        ELSE
            icx:=0;icy:=0;icz:=0
        ENDIF
        f_datapts:=bo.datapts
        npts:=bo.nbrspts
        IF intpts:=New((bo.nbrspts*8)+2)
            pivpts:=intpts
            FOR b:=0 TO bo.nbrspts-1
                ix:=IeeeSPFix(IeeeSPMul(Long(f_datapts),mybase.vectorfactor))-icx
                iy:=IeeeSPFix(IeeeSPMul(Long(f_datapts+4),mybase.vectorfactor))-icy
                iz:=IeeeSPFix(IeeeSPMul(Long(f_datapts+8),mybase.vectorfactor))-icz
                f_datapts:=f_datapts+12
                IF b=0
                    CopyMem([npts,ix,iy,iz,0]:INT,pivpts,10)
                    pivpts:=pivpts+10
                ELSE
                    CopyMem([ix,iy,iz,0]:INT,pivpts,8)
                    pivpts:=pivpts+8
                ENDIF
            ENDFOR
        ELSE
            RETURN 0,0
        ENDIF
        pivfcs:=bo.datafcs
        IF ((v_face=FV_INDIRECT) OR (v_face=FV_DIRECT)) THEN nfcs:=bo.nbrsfcs ELSE nfcs:=bo.nbrsfcs*2
        IF intfcs:=New((nfcs*22)+2)
            p:=intfcs
            FOR b:=0 TO bo.nbrsfcs-1
                color:=getColor(nbrscolors,bo,Long(pivfcs),Long(pivfcs+4),Long(pivfcs+8))
                IF b=0
                    SELECT v_face
                        CASE FV_INDIRECT
                            CopyMem([nfcs,3,color,Long(pivfcs+8)*4,Long(pivfcs+4)*4,Long(pivfcs)*4,Long(pivfcs+8)*4,0,0,0,0,0]:INT,p,24)
                            p:=p+24
                        CASE FV_DIRECT
                            CopyMem([nfcs,3,color,Long(pivfcs)*4,Long(pivfcs+4)*4,Long(pivfcs+8)*4,Long(pivfcs)*4,0,0,0,0,0]:INT,p,24)
                            p:=p+24
                        CASE FV_DOUBLE
                            CopyMem([nfcs,3,color,Long(pivfcs+8)*4,Long(pivfcs+4)*4,Long(pivfcs)*4,Long(pivfcs+8)*4,0,0,0,0,0]:INT,p,24)
                            p:=p+24
                            CopyMem([3,color,Long(pivfcs)*4,Long(pivfcs+4)*4,Long(pivfcs+8)*4,Long(pivfcs)*4,0,0,0,0,0]:INT,p,22)
                            p:=p+22
                    ENDSELECT
                ELSE
                    SELECT v_face
                        CASE FV_INDIRECT
                            CopyMem([3,color,Long(pivfcs+8)*4,Long(pivfcs+4)*4,Long(pivfcs)*4,Long(pivfcs+8)*4,0,0,0,0,0]:INT,p,22)
                            p:=p+22
                        CASE FV_DIRECT
                            CopyMem([3,color,Long(pivfcs)*4,Long(pivfcs+4)*4,Long(pivfcs+8)*4,Long(pivfcs)*4,0,0,0,0,0]:INT,p,22)
                            p:=p+22
                        CASE FV_DOUBLE
                            CopyMem([3,color,Long(pivfcs+8)*4,Long(pivfcs+4)*4,Long(pivfcs)*4,Long(pivfcs+8)*4,0,0,0,0,0]:INT,p,22)
                            p:=p+22
                            CopyMem([3,color,Long(pivfcs)*4,Long(pivfcs+4)*4,Long(pivfcs+8)*4,Long(pivfcs)*4,0,0,0,0,0]:INT,p,22)
                            p:=p+22
                    ENDSELECT
                ENDIF
                pivfcs:=pivfcs+12
            ENDFOR
        ELSE
            RETURN intpts,NIL
        ENDIF
    ELSE
        RETURN NIL,NIL
    ENDIF
ENDPROC intpts,intfcs
-><
->> renderVectorObject(b:PTR TO base3d,no,vsup,vsens,vtime,vrotx,vroty,vrotz,center=FALSE)
PROC renderVectorObject(b:PTR TO base3d,no,vsup,vsens,vtime,vrotx,vroty,vrotz,center=FALSE)
/*== © NasGûl ===================================
Paramètres: pointeur sur une structure base3d,numéro d'objet,vector support,sens des faces,
       temps (tick),rotation x,rotation y,rotation z,centre l'objet destination en 0,0,0.
Retour   : NIL
Action   : dessine un objet en utilisant soit la vector.library soit le module E FilledVector.m.
================================================*/
    -> All vector.library def <<<<
    DEF myvscreen:PTR TO newvscreen
    DEF colort:PTR TO INT
    DEF objworld:PTR TO world
    DEF view,vobj=NIL:PTR TO object
    -> All FilledVector def <<<<
    DEF s0:PTR TO screen,s1:PTR TO screen,scr:PTR TO screen
    DEF pc,fobj:PTR TO vobject
    DEF mypal:PTR TO INT,allok=FALSE

    DEF adrpts=NIL,adrfcs=NIL,npts,nfcs,o:PTR TO object3d,plandraw
    DEF ret=ERR3D_NONE

    #ifdef DEBUG
        kputfmt('renderVectorObject()\n',NIL)
    #endif
    SELECT vsup
        CASE VECTOR_LIB
            IF vecbase:=OpenLibrary('vector.library',1)
                adrpts,adrfcs:=conv3DObj2VectLib(b,no,vsens,16,center)
                IF ((adrpts<>NIL) AND (adrfcs<>NIL))
                    -> Vector screen (16 colors)
                    myvscreen:=[0,0,640,512,4,0,0,HIRESLACE_KEY,NIL,'vector.library  ©1991 by A.Lippert',0,0,0,640,512,4]:newvscreen
                    -> Palette (just grayscale).
                    colort:=[0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,6,6,6,6,7,7,7,7,8,8,8,8,9,9,9,9,10,10,10,10,11,11,11,11,12,12,12,12,13,13,13,13,14,14,14,14,15,15,15,15,-1]:INT
                    -> Init Vector OBJECT
                    IF vobj:=New(SIZEOF object)
                        vobj.point_data:=adrpts
                        vobj.area_data:=adrfcs
                        vobj.move_table:=[vtime,0,0,0,vrotx,vroty,vrotz,END_1]:INT
                        vobj.flags:=0
                        vobj.pos_x:=0
                        vobj.pos_y:=0
                        vobj.pos_z:=-1000
                        plandraw:=b.plan
                        SELECT plandraw
                            CASE PLAN_XOY
                                vobj.rot_x:=180
                                vobj.rot_y:=0
                                vobj.rot_z:=0
                            CASE PLAN_XOZ
                                vobj.rot_x:=90
                                vobj.rot_y:=0
                                vobj.rot_z:=0
                            CASE PLAN_YOZ
                                vobj.rot_x:=0
                                vobj.rot_y:=90
                                vobj.rot_z:=-90
                        ENDSELECT
                        objworld:=[0,1,vobj]:world
                        IF view:=OpenVScreen(myvscreen)
                            SetColors(view,colort)
                            AutoScaleOn(myvscreen.viewmodes)
                            DoAnim(objworld)
                            IF view THEN CloseVScreen()
                            allok:=TRUE
                        ELSE
                            IF adrpts<>NIL THEN Dispose(adrpts)
                            IF adrfcs<>NIL THEN Dispose(adrfcs)
                            IF vobj<>NIL THEN Dispose(vobj)
                        ENDIF
                    ELSE
                        IF allok=FALSE
                            IF adrpts<>NIL THEN Dispose(adrpts)
                            IF adrfcs<>NIL THEN Dispose(adrfcs)
                        ENDIF
                    ENDIF
                ELSE
                    IF allok=FALSE
                        IF adrpts<>NIL THEN Dispose(adrpts)
                        IF adrfcs<>NIL THEN Dispose(adrfcs)
                        ret:=ERR3D_CONVVECTOR
                    ENDIF
                ENDIF
                IF vecbase THEN CloseLibrary(vecbase)
            ELSE
                ret:=ERR3D_NOVECTORLIB
            ENDIF
    CASE VECTOR_MOD
        adrpts,adrfcs:=conv3DObj2Vect(b,no,vsens,16,center)
        IF ((adrpts<>NIL) AND (adrfcs<>NIL))
            mypal:=[$000,$111,$222,$333,$444,$555,$666,$777,$888,$999,$aaa,$bbb,$ccc,$ddd,$eee,$fff]:INT
            o:=getInfoNode(b.objlist,no,GETWITH_NUM,RETURN_ADR)
            npts:=o.nbrspts
            IF vsens=FV_DOUBLE THEN nfcs:=o.nbrsfcs*2 ELSE nfcs:=o.nbrsfcs
            IF s0:=OpenS(320,256,4,0,'FilledVector © Frank Zucchi')
                LoadRGB4(s0.viewport,mypal,16)
                IF s1:=OpenS(320,256,4,0,'FilledVector © Frank Zucchi')
                    LoadRGB4(s1.viewport,mypal,16)
                    IF pc:=newPolyContext(s0.bitmap,npts+16)
                        setPolyFlags(pc,1,1)
                        IF fobj:=newVectorObject(0,npts,nfcs,adrpts,adrfcs)
                            scr:=s0
                            fobj.pz:=5000
                            SetRast(scr.rastport,0)
                            setPolyBitMap(pc,scr.bitmap)
                            drawVObject(pc,fobj)
                            ScreenToFront(scr)
                            WHILE Mouse()<>3
                                SetRast(scr.rastport,0);
                                setPolyBitMap(pc, scr.bitmap)
                                drawVObject(pc,fobj)
                                ScreenToFront(scr)
                                fobj.ax:=fobj.ax+vrotx
                                fobj.ay:=fobj.ay+vroty
                                fobj.az:=fobj.az+vrotz
                                IF scr=s0 THEN scr:=s1 ELSE scr:=s0
                            ENDWHILE
                            freeVectorObject(fobj)
                        ENDIF
                    ENDIF
                    CloseS(s1)
                ENDIF
                CloseS(s0)
            ENDIF
        ELSE
            IF adrpts<>NIL THEN Dispose(adrpts)
            IF adrfcs<>NIL THEN Dispose(adrfcs)
            ret:=ERR3D_CONVVECTOR
        ENDIF
    ENDSELECT
ENDPROC ret
-><
->> getColor(nbrscolor,o:PTR TO object3d,v1,v2,v3)
PROC getColor(nbrscolor,o:PTR TO object3d,v1,v2,v3)
/*== © NasGûl ===================================
Paramètres: nombres de couleurs,pointeur sur un objetc3d,1 sommet de la face,2 sommet,3 sommet
Retour   : valeur de la couleur de la face courante.
Action   : calcule la couleur d'une face avec une lumière en 4500,-4500,4500.
================================================*/
    DEF lx=4500.0,ly=-4500.0,lz=4500.0,vlx,vly,vlz
    DEF norm_vl,vlx_1,vly_1,vlz_1
    DEF x0,y0,z0,x1,y1,z1,x2,y2,z2
    DEF norm_vn,vnx,vny,vnz,vnx_1,vny_1,vnz_1
    DEF p,px,py,pz,color

    vlx:=fsub(0.0,lx)
    vly:=fsub(0.0,ly)
    vlz:=fsub(0.0,lz)

    norm_vl:=fsqr(fadd(fmul(vlx,vlx),fadd(fmul(vly,vly),fmul(vlz,vlz))))

    vlx_1:=fdiv(vlx,norm_vl)
    vly_1:=fdiv(vly,norm_vl)
    vlz_1:=fdiv(vlz,norm_vl)

    x0:=Long(o.datapts+(v1*12))
    y0:=Long(o.datapts+(v1*12)+4)
    z0:=Long(o.datapts+(v1*12)+8)

    x1:=Long(o.datapts+(v2*12))
    y1:=Long(o.datapts+(v2*12)+4)
    z1:=Long(o.datapts+(v2*12)+8)

    x2:=Long(o.datapts+(v3*12))
    y2:=Long(o.datapts+(v3*12)+4)
    z2:=Long(o.datapts+(v3*12)+8)

    vnx:=fsub(fmul(fsub(y1,y0),fsub(z2,z1)),fmul(fsub(y2,y1),fsub(z1,z0)))
    vny:=fsub(fmul(fsub(z1,z0),fsub(x2,x1)),fmul(fsub(z2,z1),fsub(x1,x0)))
    vnz:=fsub(fmul(fsub(x1,x0),fsub(y2,y1)),fmul(fsub(x2,x1),fsub(y1,y0)))
    norm_vn:=fsqr(fadd(fmul(vnx,vnx),fadd(fmul(vny,vny),fmul(vnz,vnz))))

    IF norm_vn<>0
   vnx_1:=fdiv(vnx,norm_vn)
   vny_1:=fdiv(vny,norm_vn)
   vnz_1:=fdiv(vnz,norm_vn)
    ENDIF

    px:=fmul(vnx_1,vlx_1)
    py:=fmul(vny_1,vly_1)
    pz:=fmul(vnz_1,vlz_1)
    p:=fadd(px,py)

    color:=IeeeSPAbs(fadd(p,pz))
    p:=!color*(nbrscolor-1)

ENDPROC p
-><
->> makeObject(base:PTR TO base3d,type,name:PTR TO CHAR,p_t,g_t,factor,fc) HANDLE
PROC makeObject(base:PTR TO base3d,type,name:PTR TO CHAR,p_t,g_t,factor,fc) HANDLE
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,type=const (TYPE_<nonm>,name=nom de l'objet,
       valeur en x,valeur en y,facteur 3D (flottant),fc=génération des faces (0/1/2).
Retour   : TRUE si ok,sinon FALSE.
Action   : Ajoute un primitive a la base 3D déjà existante.
================================================*/
    DEF i,j,fi,fj,fp_t,fg_t,p1,p2,p3,p4
    DEF fnx,fny,fnz,x,y,ba=0
    DEF ret=ERR3D_NONE
    DEF xmin,xmax,ymin,ymax
    DEF newobj:PTR TO object3d
    DEF rname[256]:STRING
    DEF nbrspts,nbrsfcs,piv_pts
    #ifdef DEBUG
      kputfmt('MakeObject()\n',NIL)
    #endif

    StringF(rname,'\s',name)
    SELECT type
        CASE PRIM_TORUS
            xmin:=-3.14159265
            xmax:=3.14159265
            ymin:=-3.14159265
            ymax:=3.14159265
        CASE PRIM_MOEBIUS
            xmin:=0.0
            xmax:=6.28318512
            ymin:=-1.0
            ymax:=1.0
        CASE PRIM_PLAN
            xmin:=-1.0
            xmax:=1.0
            ymin:=-1.0
            ymax:=1.0
        CASE PRIM_TRBL
            xmin:=0.1
            xmax:=5.0
            ymin:=-3.14159265
            ymax:=3.14159265
        CASE PRIM_SPHERE
            xmin:=-3.14159265
            xmax:=3.14159265
            ymin:=0.0
            ymax:=3.14159265
        CASE PRIM_SPIRALE
            xmin:=1.0
            xmax:=4.0
            ymin:=0.0
            ymax:=fmul(3.14159265,2.0)
        CASE PRIM_VAGUES
            xmin:=-5.0
            xmax:=5.0
            ymin:=-5.0
            ymax:=5.0
        CASE PRIM_CYLINDRE
            xmin:=0.0
            xmax:=fmul(3.14159265,2.0)
            ymin:=-4.0
            ymax:=4.0
        CASE PRIM_CONED
           xmin:=0.0
           xmax:=3.14159265
           ymin:=-3.14159265
           ymax:=3.14159265
        CASE PRIM_DOME
           xmin:=0.001
           xmax:=3.14159265
           ymin:=-3.14159265
           ymax:=3.14159265
        DEFAULT
            RETURN ERR3D_WRONGPRIMTYPE
    ENDSELECT
    fp_t:=p_t!
    fg_t:=g_t!
    newobj:=New(SIZEOF object3d)
    newobj.typeobj:=type
    newobj.selected:=FALSE
    newobj.bounded:=FALSE
    nbrspts:=Mul((p_t+1),(g_t+1))
    newobj.nbrspts:=nbrspts
    newobj.datapts:=New(Mul(nbrspts,12))
    
    #ifdef DEBUG
      kputfmt('MakeObject() nbrspts \d Mem \d\n',[nbrspts,Mul(nbrspts,12)])
    #endif

    IF ((fc=FV_INDIRECT) OR (fc=FV_DIRECT)) THEN nbrsfcs:=Mul(Mul(p_t,g_t),2) ELSE nbrsfcs:=Mul(Mul(p_t,g_t),4)
    newobj.nbrsfcs:=nbrsfcs
    newobj.datafcs:=New(Mul(nbrsfcs,12))

    #ifdef DEBUG
      kputfmt('MakeObject() nbrsfcs \d Mem \d\n',[nbrsfcs,Mul(nbrsfcs,12)])
    #endif

    piv_pts:=newobj.datapts

    #ifdef DEBUG
      kputfmt('MakeObject() Calculate points\n',NIL)
    #endif

    FOR i:=1 TO p_t+1
        FOR j:=1 TO g_t+1

            fi:=i!
            fj:=j!
            x:=fadd(xmin,fmul(fsub(fi,1.0),fdiv(fsub(xmax,xmin),fp_t)))
            y:=fadd(ymin,fmul(fsub(fj,1.0),fdiv(fsub(ymax,ymin),fg_t)))
            SELECT type
                CASE PRIM_TORUS
                     fnx:=fmul(fctTorusX(x,y),factor)
                     fny:=fmul(fctTorusY(x,y),factor)
                     fnz:=fmul(fctTorusZ(x,y),factor)
                 CASE PRIM_MOEBIUS
                     fnx:=fmul(fctMoebiusX(x,y),factor)
                     fny:=fmul(fctMoebiusY(x,y),factor)
                     fnz:=fmul(fctMoebiusZ(x,y),factor)
                 CASE PRIM_PLAN
                     fnx:=fmul(fctPlanX(x,y),factor)
                     fny:=fmul(fctPlanY(x,y),factor)
                     fnz:=fmul(fctPlanZ(x,y),factor)
                 CASE PRIM_TRBL
                     fnx:=fmul(fctTrblX(x,y),factor)
                     fny:=fmul(fctTrblY(x,y),factor)
                     fnz:=fmul(fctTrblZ(x,y),factor)
                 CASE PRIM_SPHERE
                     fnx:=fmul(fctSphereX(x,y),factor)
                     fny:=fmul(fctSphereY(x,y),factor)
                     fnz:=fmul(fctSphereZ(x,y),factor)
                 CASE PRIM_SPIRALE
                     fnx:=fmul(fctSpiraleX(x,y),factor)
                     fny:=fmul(fctSpiraleY(x,y),factor)
                     fnz:=fmul(fctSpiraleZ(x,y),factor)
                 CASE PRIM_VAGUES
                     fnx:=fmul(fctVaguesX(x,y),factor)
                     fny:=fmul(fctVaguesY(x,y),factor)
                     fnz:=fmul(fctVaguesZ(x,y),factor)
                 CASE PRIM_CYLINDRE
                     fnx:=fmul(fctCylindreX(x,y),factor)
                     fny:=fmul(fctCylindreY(x,y),factor)
                     fnz:=fmul(fctCylindreZ(x,y),factor)
                 CASE PRIM_CONED
                     fnx:=fmul(fctConedX(x,y),factor)
                     fny:=fmul(fctConedY(x,y),factor)
                     fnz:=fmul(fctConedZ(x,y),factor)
                 CASE PRIM_DOME
                     fnx:=fmul(fctDomeX(x,y),factor)
                     fny:=fmul(fctDomeY(x,y),factor)
                     fnz:=fmul(fctDomeZ(x,y),factor)
            ENDSELECT
            ^piv_pts:=fnx
            piv_pts:=piv_pts+4
            ^piv_pts:=fny
            piv_pts:=piv_pts+4
            ^piv_pts:=fnz
            piv_pts:=piv_pts+4


        ENDFOR
    ENDFOR

    #ifdef DEBUG
      kputfmt('MakeObject() Calculate faces\n',NIL)
    #endif

    piv_pts:=newobj.datafcs
    FOR i:=0 TO p_t-1
        FOR j:=0 TO g_t-1


            p1:=ba
            p2:=ba+1
            p3:=g_t+ba+2
            p4:=g_t+ba+1
            IF ((fc=FV_INDIRECT) OR (fc=FV_DOUBLE))
                ^piv_pts:=p1
                piv_pts:=piv_pts+4
                ^piv_pts:=p2
                piv_pts:=piv_pts+4
                ^piv_pts:=p3
                piv_pts:=piv_pts+4
                ^piv_pts:=p1
                piv_pts:=piv_pts+4
                ^piv_pts:=p3
                piv_pts:=piv_pts+4
                ^piv_pts:=p4
                piv_pts:=piv_pts+4
            ENDIF
            IF ((fc=FV_DIRECT) OR (fc=FV_DOUBLE))
                ^piv_pts:=p1
                piv_pts:=piv_pts+4
                ^piv_pts:=p3
                piv_pts:=piv_pts+4
                ^piv_pts:=p2
                piv_pts:=piv_pts+4
                ^piv_pts:=p1
                piv_pts:=piv_pts+4
                ^piv_pts:=p4
                piv_pts:=piv_pts+4
                ^piv_pts:=p3
                piv_pts:=piv_pts+4
            ENDIF


            ba:=ba+1
        ENDFOR
        ba:=ba+1
    ENDFOR


    newobj.objminx:=1000000.0
    newobj.objmaxx:=-1000000.0
    newobj.objminy:=1000000.0
    newobj.objmaxy:=-1000000.0
    newobj.objminz:=1000000.0
    newobj.objmaxz:=-1000000.0
    addNode(base.objlist,rname,newobj)
    buildMinMax(base,newobj,TRUE)
    base.nbrsobjs:=countNodes(base.objlist)
    base.totalpts:=base.totalpts+newobj.nbrspts
    base.totalfcs:=base.totalfcs+newobj.nbrsfcs
    Raise(ret)
EXCEPT
    IF exception="MEM" THEN RETURN ERR3D_MEM
ENDPROC ret
-><
->> primCube(base:PTR TO base3d,name,type)
PROC primCube(base:PTR TO base3d,name,type)
/*== © NasGûl ===================================
Paramètres: pointeur sur unobjet base3d,nom STRING,type=const
Retour   : TRUE si ok,sinon FALSE.
Action   : Ajoute une primitive a la base 3D.
================================================*/
    DEF no:PTR TO object3d,ret=ERR3D_NONE
    no:=New(SIZEOF object3d)
    no.typeobj:=type
    no.selected:=FALSE
    no.bounded:=FALSE
    SELECT type
   CASE PRIMD_CUBE
       no.nbrspts:=8
       no.datapts:=[-1.0,-1.0,-1.0,
     1.0,-1.0,-1.0,
     1.0,1.0,-1.0,
     -1.0,1.0,-1.0,
     -1.0,-1.0,1.0,
     1.0,-1.0,1.0,
     1.0,1.0,1.0,
     -1.0,1.0,1.0]:LONG
       no.nbrsfcs:=12
       no.datafcs:=[0,1,5,0,5,4,
    1,2,6,1,6,5,
    0,3,2,0,2,1,
    0,4,7,0,7,3,
    7,6,2,7,2,3,
    7,4,5,7,5,6]:LONG
       ret:=TRUE
   CASE PRIMD_TETRA
       no.nbrspts:=4
       no.datapts:=[1.0,-1.73205080,0.0,
    1.0,1.73205080,0.0,
    -2.0,0.0,0.0,
    0.0,0.0,2.82842712]:LONG
       no.nbrsfcs:=4
       no.datafcs:=[0,2,1,
    0,3,2,
    0,1,3,
    1,2,3]:LONG
       ret:=TRUE
   CASE PRIMD_OCTA
       no.nbrspts:=6
       no.datapts:=[0.0,0.0,-1.0,
    0.0,-1.0,0.0,
    1.0,0.0,0.0,
    0.0,1.0,0.0,
    -1.0,0.0,0.0,
    0.0,0.0,1.0]:LONG
       no.nbrsfcs:=8
       no.datafcs:=[0,2,1,
    0,3,2,
    0,1,4,
    0,4,3,
    1,2,5,
    1,5,4,
    2,3,5,
    4,5,3]:LONG
       ret:=TRUE
   CASE PRIMD_DODECA
       no.nbrspts:=20
       no.datapts:=[1.6180, -1.6180,-1.6180,
    1.6180,  1.6180,-1.6180,
       -1.6180,  1.6180,-1.6180,
       -1.6180, -1.6180,-1.6180,
    1.6180, -1.6180, 1.6180,
    1.6180,  1.6180, 1.6180,
       -1.6180,  1.6180, 1.6180,
       -1.6180, -1.6180, 1.6180,
    2.6180,  1.0 , 0.0 ,
    2.6180, -1.0 , 0.0 ,
    0.0   ,  2.6180, 1.0 ,
    0.0   ,  2.6180,-1.0 ,
       -2.6180,  1.0 , 0.0 ,
       -2.6180, -1.0 , 0.0 ,
    0.0   , -2.6180, 1.0 ,
    0.0   , -2.6180,-1.0 ,
    1.0   ,  0.0 ,-2.6180,
       -1.0   ,  0.0 ,-2.6180,
    1.0   ,  0.0 , 2.6180,
       -1.0   ,  0.0 , 2.6180]:LONG
       no.nbrsfcs:=12*3
       no.datafcs:=[10,5,8,
       10,8,1,
       10,1,11,

       18,4,9,
       18,9,8,
       18,8, 5,

       18,5,10,
       18,10,6,
       18,6,19,

       7,14,4,
       7,4,18,
       7,18,19,

       3,15,14,
       3,14,7,
       3,7,13,

       15,0,9,
       15,9,4,
       15,4,14,

       15,3,17,
       15,17,16,
       15,16,0,

       11,1,16,
       11,16,17,
       11,17,2,

       16,1,8,
       16,8,9,
       16,9,0,

       19,6,12,
       19,12,13,
       19,13,7,

       13,12,2,
       13,2,17,
       13,17,3,

       10,11,2,
       10,2,12,
       10,12,6]:LONG
       ret:=TRUE
   CASE PRIMD_ICOSA
       no.nbrspts:=12
       no.datapts:=[1.0   , 0.0   ,-1.6180,
    1.0   , 0.0   , 1.6180,
       -1.0   , 0.0   , 1.6180,
       -1.0   , 0.0   ,-1.6180,
    1.6180,-1.0   , 0.0   ,
    1.6180, 1.0   , 0.0   ,
       -1.6180, 1.0   , 0.0   ,
       -1.6180,-1.0   , 0.0   ,
    0.0   ,-1.6180, 1.0   ,
    0.0   , 1.6180, 1.0   ,
    0.0   , 1.6180,-1.0   ,
    0.0   ,-1.6180,-1.0   ]:LONG
       no.nbrsfcs:=20
       no.datafcs:=[1,9,2,
    9,1,5,
    9,5,10,
    6,9,10,
    6,2,9,
    7,8,2,
    1,2,8,
    1,8,4,
    5,1,4,
    5,4,0,
    5,0,10,
    10,0,3,
    6,10,3,
    7,6,3,
    7,2,6,
    11,4,8,
    0,4,11,
    0,11,3,
    3,11,7,
    7,11,8]:LONG
       ret:=TRUE
   CASE PRIMD_OCTATRONQUE
       no.nbrspts:=24
       no.datapts:=[ 3.0  , -1.0  ,  0.0  ,
     2.0  , -2.0  ,  1.4142 ,
     1.0  , -3.0  ,  0.0  ,
     2.0  , -2.0  , -1.4142 ,
     3.0  ,  1.0  ,  0.0  ,
     2.0  ,  2.0  , -1.4142 ,
     1.0  ,  3.0  ,  0.0  ,
     2.0  ,  2.0  ,  1.4142 ,
    -1.0  ,  3.0  ,  0.0  ,
    -2.0  ,  2.0  , -1.4142 ,
    -3.0  ,  1.0  ,  0.0  ,
    -2.0  ,  2.0  ,  1.4142 ,
    -3.0  , -1.0  ,  0.0  ,
    -2.0  , -2.0  , -1.4142 ,
    -1.0  , -3.0  ,  0.0  ,
    -2.0  , -2.0  ,  1.4142 ,
     1.0  , -1.0  , -2.8284 ,
     1.0  ,  1.0  , -2.8284 ,
    -1.0  ,  1.0  , -2.8284 ,
    -1.0  , -1.0  , -2.8284 ,
     1.0  , -1.0  ,  2.8284 ,
     1.0  ,  1.0  ,  2.8284 ,
    -1.0  ,  1.0  ,  2.8284 ,
    -1.0  , -1.0  ,  2.8284 ]:LONG
       no.nbrsfcs:=44
     no.datafcs:=[ 0 ,1 ,2 ,
     0 ,2 ,3 ,

     4 ,5 ,6 ,
     4 ,6 ,7 ,

     8 ,9 ,10,
     8 ,10,11,

     12,13,14,
     12,14,15,

     16,19,18,
     16,18,17,

     20,21,22,
     20,22,23,

     0 ,4 ,7 ,
     0 ,7 ,21,
     0 ,21,20,
     0 ,20,1 ,

     0 ,3 ,16,
     0 ,16,17,
     0 ,17,5 ,
     0 ,5 ,4 ,

     15,14,2 ,
     15,2 ,1 ,
     15,1 ,20,
     15,20,23,

     14,13,19,
     14,19,16,
     14,16,3 ,
     14,3 ,2 ,

     12,15,23,
     12,23,22,
     12,22,11,
     12,11,10,

     10,9 ,18,
     10,18,19,
     10,19,13,
     10,13,12,

     8 ,6 ,5 ,
     8 ,5 ,17,
     8 ,17,18,
     8 ,18,9 ,

     22,21,7 ,
     22,7 ,6 ,
     22,6 ,8 ,
     22,8 ,11]:LONG
       ret:=TRUE
   CASE PRIMD_CUBO
       no.nbrspts:=12
       no.datapts:=[0.0 ,-1.0,-1.0,
    1.0 , 0.0,-1.0,
    0.0 , 1.0,-1.0,
       -1.0 , 0.0,-1.0,
       -1.0 ,-1.0, 0.0,
    1.0 ,-1.0, 0.0,
    1.0 , 1.0, 0.0,
       -1.0 , 1.0, 0.0,
       -1.0 , 0.0, 1.0,
    0.0 ,-1.0, 1.0,
    1.0 , 0.0, 1.0,
    0.0 , 1.0, 1.0]:LONG
       no.nbrsfcs:=20
       no.datafcs:=[8 ,9 ,10,8 ,10,11,
    0 ,3 ,2 ,0 ,2 ,1 ,
    1 ,6 ,10,1 ,10,5 ,
    4 ,8 ,7 ,4 ,7 ,3 ,
    0 ,5 ,9 ,0 ,9 ,4 ,
    11,6 ,2 ,11,2 ,7 ,
    9,8,4,
    9,5,10,
    10,6,11,
    8,11,7,
    0,4,3,
    0,1,5,
    2,6,1,
    3,7,2]:LONG
       ret:=TRUE
    DEFAULT
    RETURN ERR3D_WRONGPRIMTYPE
    ENDSELECT
    no.objminx:=1000000.0
    no.objmaxx:=-1000000.0
    no.objminy:=1000000.0
    no.objmaxy:=-1000000.0
    no.objminz:=1000000.0
    no.objmaxz:=-1000000.0
    addNode(base.objlist,name,no)
    buildMinMax(base,no,TRUE)
    base.nbrsobjs:=countNodes(base.objlist)
    base.totalpts:=base.totalpts+no.nbrspts
    base.totalfcs:=base.totalfcs+no.nbrsfcs
ENDPROC ret
-><
->> rotateBase3D(base:PTR TO base3d,key)
PROC rotateBase3D(base:PTR TO base3d,key)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,key=const (CURSORUP/CURSORDOWN/CURSORRIGHT/CURSORLEFT).
Retour   : NIL.
Action   : Tourne les objets d'un angle de base3d.rotationangle,suivant le plan
       de vue et la touche du curseur enfoncée.
================================================*/
    DEF p=NIL,pl=NIL
    #ifdef DEBUG
    kputfmt('rotateBase3D( $\h:PTR TO base3d , \d )\n',[base,key])
    #endif
    SELECT key
    CASE CURSORUP
   p:=IeeeSPDiv(IeeeSPMul(base.anglerotation,3.14159),180.0)
    CASE CURSORLEFT
   p:=IeeeSPDiv(IeeeSPMul(base.anglerotation,3.14159),180.0)
    CASE CURSORDOWN
   p:=IeeeSPDiv(IeeeSPMul(base.anglerotation,3.14159),-180.0)
    CASE CURSORRIGHT
   p:=IeeeSPDiv(IeeeSPMul(base.anglerotation,3.14159),-180.0)
    ENDSELECT
    pl:=base.plan
    IF ((key=CURSORUP) OR (key=CURSORDOWN))
    SELECT pl
   CASE PLAN_XOY; rotateBase(base,AXE_X,p)
   CASE PLAN_YOZ; rotateBase(base,AXE_Y,p)
   CASE PLAN_XOZ; rotateBase(base,AXE_X,p)
    ENDSELECT
    ENDIF
    IF ((key=CURSORLEFT) OR (key=CURSORRIGHT))
    SELECT pl
   CASE PLAN_XOY; rotateBase(base,AXE_Y,p)
   CASE PLAN_YOZ; rotateBase(base,AXE_Z,p)
   CASE PLAN_XOZ; rotateBase(base,AXE_Z,p)
    ENDSELECT
    ENDIF
ENDPROC
-><
->> rotateBase(base:PTR TO base3d,axe,angle)
PROC rotateBase(base:PTR TO base3d,axe,angle)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,axe de rotation (AXE_X/AXE_Y/AXE_Z),
       angle de rotation (EN RADIANS).
Retour   : NIL
Action   : Effectue la rotation objet par objet.
================================================*/
    DEF l:PTR TO lh
    DEF n:PTR TO ln
    #ifdef DEBUG
        kputfmt('rotateBase( $\h:PTR TO base3d, \d , float\n',[base,axe])
    #endif
    l:=base.objlist
    n:=l.head
    WHILE n
        IF n.succ<>0
            rotateObject3D(base,n,axe,angle)
        ENDIF
        n:=n.succ
    ENDWHILE
ENDPROC
-><
->> rotateObject3D(base:PTR TO base3d,do:PTR TO object3d,axe,angle=NIL)
PROC rotateObject3D(base:PTR TO base3d,do:PTR TO object3d,axe,angle=NIL)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,pointeur sur un objet objetc3d,
       axe (AXE_X/AXE_Y/AXE_Z),angle (EN RADIANS).
Retour   : NIL
Action   : tourne un objet suivant les paramètres.
================================================*/
    DEF b
    DEF old_x=NIL,old_y=NIL,old_z=NIL
    DEF new_x=NIL,new_y=NIL,new_z=NIL
    DEF adrx,adry,adrz
    DEF r_point
    #ifdef DEBUG
        kputfmt('rotateObject3D( $\h:PTR TO base3d , $\h:PTR TO object3d , \d ,float)\n',[base,do,axe])
    #endif
    r_point:=do.datapts
    FOR b:=0 TO do.nbrspts-1
        adrx:=r_point
        adry:=r_point+4
        adrz:=r_point+8
        old_x:=Long(adrx)
        old_y:=Long(adry)
        old_z:=Long(adrz)
        SELECT axe
            CASE AXE_X
                new_x:=old_x
                new_y:=IeeeSPSub(IeeeSPMul(old_y,IeeeSPCos(angle)),IeeeSPMul(old_z,IeeeSPSin(angle)))
                new_z:=IeeeSPAdd(IeeeSPMul(old_y,IeeeSPSin(angle)),IeeeSPMul(old_z,IeeeSPCos(angle)))
            CASE AXE_Y
               new_x:=IeeeSPSub(IeeeSPMul(old_x,IeeeSPCos(angle)),IeeeSPMul(old_z,IeeeSPSin(angle)))
               new_y:=old_y
               new_z:=IeeeSPAdd(IeeeSPMul(old_x,IeeeSPSin(angle)),IeeeSPMul(old_z,IeeeSPCos(angle)))
            CASE AXE_Z
               new_x:=IeeeSPSub(IeeeSPMul(old_x,IeeeSPCos(angle)),IeeeSPMul(old_y,IeeeSPSin(angle)))
               new_y:=IeeeSPAdd(IeeeSPMul(old_x,IeeeSPSin(angle)),IeeeSPMul(old_y,IeeeSPCos(angle)))
               new_z:=old_z
        ENDSELECT
        ^adrx:=new_x
        ^adry:=new_y
        ^adrz:=new_z
        r_point:=r_point+12
    ENDFOR
    buildMinMax(base,do,FALSE)
ENDPROC
-><
->> centreBase3D(base:PTR TO base3d)
PROC centreBase3D(base:PTR TO base3d)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d.
Retour   : NIL
Action   : recentre toute la base 3D.
================================================*/
    DEF l:PTR TO lh
    DEF n:PTR TO ln
    l:=base.objlist
    n:=l.head
    WHILE n
        IF n.succ<>0
            centreObject3D(base,n)
        ENDIF
        n:=n.succ
    ENDWHILE
    l:=base.objlist
    n:=l.head
    WHILE n
        IF n.succ<>0
            buildMinMax(base,n,FALSE)
        ENDIF
        n:=n.succ
    ENDWHILE
    updateCenterBase3D(base)
ENDPROC
-><
->> centreObject3D(base:PTR TO base3d,do:PTR TO object3d)
PROC centreObject3D(base:PTR TO base3d,do:PTR TO object3d)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,pointeur sur un objet object3d.
Retour   : NIL
Action   : Centre un objet.
================================================*/
    DEF b,curs
    DEF cp:PTR TO vertice
    do.objcx:=IeeeSPSub(do.objcx,base.basecx)
    do.objcy:=IeeeSPSub(do.objcy,base.basecy)
    do.objcz:=IeeeSPSub(do.objcz,base.basecz)
    curs:=do.datapts
    FOR b:=0 TO do.nbrspts-1
        cp:=curs
        cp.x:=IeeeSPSub(cp.x,base.basecx)
        cp.y:=IeeeSPSub(cp.y,base.basecy)
        cp.z:=IeeeSPSub(cp.z,base.basecz)
        curs:=curs+12
    ENDFOR
    buildMinMax(base,do,FALSE)
ENDPROC
-><
->> boundedObject3D(base:PTR TO base3d,data,getwith,action)
PROC boundedObject3D(base:PTR TO base3d,data,getwith,action)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,
       data,getwith (VOIR Plist.m),
       action TRUE ou FALSE.
Retour   : NIL
Action   : met le champ o.bounded sur <action>.
================================================*/
    DEF o:PTR TO object3d
    o:=getInfoNode(base.objlist,data,getwith,RETURN_ADR)
    o.bounded:=action
ENDPROC
-><
->> boundedAllObject3D(base:PTR TO base3d,action)
PROC boundedAllObject3D(base:PTR TO base3d,action)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,action (TRUE/FALSE)
Retour   : NIL
Action   : Met o.bounded de tous les objets sur <action>.
================================================*/
    DEF l:PTR TO lh
    DEF o:PTR TO object3d
    l:=base.objlist
    o:=l.head
    WHILE o
        IF o.obj_node.succ<>0
            o.bounded:=action
        ENDIF
        o:=o.obj_node.succ
    ENDWHILE
ENDPROC
-><
->> selectObject3D(base:PTR TO base3d,data,getwith,action)
PROC selectObject3D(base:PTR TO base3d,data,getwith,action)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,
       data,getwith (VOIR Plist.m),
       action TRUE ou FALSE.
Retour   : NIL
Action   : met le champ o.selected sur <action>.
================================================*/
    DEF o:PTR TO object3d
    o:=getInfoNode(base.objlist,data,getwith,RETURN_ADR)
    IF o<>-1 THEN o.selected:=action
ENDPROC

-><
->> selectAllObject3D(base:PTR TO base3d,action)
PROC selectAllObject3D(base:PTR TO base3d,action)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,action (TRUE/FALSE)
Retour   : NIL
Action   : Met o.selected de tous les objets sur <action>.
================================================*/
    DEF l:PTR TO lh
    DEF o:PTR TO object3d
    l:=base.objlist
    o:=l.head
    WHILE o
        IF o.obj_node.succ<>0
            o.selected:=action
        ENDIF
        o:=o.obj_node.succ
    ENDWHILE
ENDPROC

-><
->> deleteObject3D(base:PTR TO base3d,numobj)
PROC deleteObject3D(base:PTR TO base3d,numobj)
/*= © NasGûl ===================================================================
 = Para         : base pointeur sur une structure base3d,numéro de l'OBJECT
 = RETURN       : Rien
 = Description  : Efface un objet 3D de la base de données.
 ==============================================================================*/
    DEF pivobj:PTR TO object3d
    pivobj:=getInfoNode(base.objlist,numobj,GETWITH_NUM,RETURN_ADR)
    IF pivobj<>-1
        base.nbrsobjs:=base.nbrsobjs-1
        base.totalpts:=base.totalpts-pivobj.nbrspts
        base.totalfcs:=base.totalfcs-pivobj.nbrsfcs
        remNode(base.objlist,numobj,TRUE,base.freedata)
    ENDIF
ENDPROC
-><
->> ========== Fonctions Privées ==========

->> Fonctions mathématiques des primitives calculées



PROC fctTorusX(px,py) IS fmul(fadd(2.0,fcos(px)),fcos(py))
PROC fctTorusY(px,py) IS fmul(fadd(2.0,fcos(px)),fsin(py))
PROC fctTorusZ(px,py) 
    VOID py
ENDPROC fsin(px)

PROC fctMoebiusX(px,py) IS fmul(fadd(5.0,fmul(py,fcos(fdiv(px,2.0)))),fcos(px))
PROC fctMoebiusY(px,py) IS fmul(fadd(5.0,fmul(py,fcos(fdiv(px,2.0)))),fsin(px))
PROC fctMoebiusZ(px,py) IS fmul(py,fsin(fdiv(px,2.0)))


PROC fctPlanX(px,py) 
    VOID py
ENDPROC px
PROC fctPlanY(px,py) 
    VOID px
ENDPROC py
PROC fctPlanZ(px,py) 
    VOID px
    VOID py
ENDPROC 0.0


PROC fctTrblX(px,py) IS fmul(px,fcos(py))
PROC fctTrblY(px,py) IS fmul(px,fsin(py))
PROC fctTrblZ(px,py) 
    VOID py
ENDPROC fdiv(1.0,px)


PROC fctSphereX(px,py) IS fmul(fcos(px),fcos(py))
PROC fctSphereY(px,py) IS fmul(fcos(px),fsin(py))
PROC fctSphereZ(px,py) 
    VOID py
ENDPROC fsin(px)


PROC fctSpiraleX(px,py) IS fmul(px,fcos(py))
PROC fctSpiraleY(px,py) IS fmul(px,fsin(py))
PROC fctSpiraleZ(px,py) IS fdiv(py,px)


PROC fctVaguesX(px,py) 
    VOID py
ENDPROC px
PROC fctVaguesY(px,py) 
    VOID px
ENDPROC py
PROC fctVaguesZ(px,py) IS fmul(fcos(px),fcos(py))


PROC fctCylindreX(px,py) 
    VOID py
ENDPROC fcos(px)
PROC fctCylindreY(px,py) 
    VOID py
ENDPROC fsin(px)
PROC fctCylindreZ(px,py) 
    VOID px
ENDPROC py


PROC fctConedX(px,py) IS fmul(px,fcos(py))
PROC fctConedY(px,py) IS fmul(px,fsin(py))
PROC fctConedZ(px,py) 
    VOID py
ENDPROC px


PROC fctDomeX(px,py) IS fmul(px,fcos(py))
PROC fctDomeY(px,py) IS fmul(px,fsin(py))
PROC fctDomeZ(px,py) 
    VOID py
ENDPROC fmul(px,px)
-><

->> Fonctions mathématiques

PROC fsub(a,b) IS IeeeSPSub(a,b)
PROC fdiv(a,b) IS IeeeSPDiv(a,b)
PROC fmul(a,b) IS IeeeSPMul(a,b)
PROC fadd(a,b) IS IeeeSPAdd(a,b)
PROC fsqr(a)   IS IeeeSPSqrt(a)
PROC fcos(a)   IS IeeeSPCos(a)
PROC fsin(a)   IS IeeeSPSin(a)
PROC ffix(a)   IS IeeeSPFix(a)

-><

->> Fonctions de lecture des fichiers 3D

->> read3D2File(base:PTR TO base3d,file) HANDLE
PROC read3D2File(base:PTR TO base3d,file) HANDLE
/*== © NasGûl ==================================
Paramètres: pointeur sur un objet base3d,nom d'un fichier amigados STRING.
Retour   : TRUE si ok sinon FALSE
Action   : charge dans la base 3d un objet au format .3D2.
================================================*/
    DEF len,adr,buf=NIL,handle,flen=TRUE
    DEF nbrs_obj,obj_name[20]:STRING,i,myobj=NIL:PTR TO object3d,piv_pts
    DEF a,x,y,z,p1,p2,p3

    #ifdef DEBUG
        kputfmt('read3D2File($\h:PTR TO base3d,\s)\n',[base,file])
    #endif

    flen:=FileLength(file)
    buf:=New(flen+1)
    IF handle:=Open(file,1005)
        len:=Read(handle,buf,len)
        Close(handle)
        adr:=buf
        nbrs_obj:=Int(adr+2)
        base.nbrsobjs:=base.nbrsobjs+nbrs_obj
        adr:=buf+256
        FOR i:=0 TO nbrs_obj-1
            StringF(obj_name,'\s',adr)
            myobj:=New(SIZEOF object3d)                                /*==== Allocate new structure ====*/
            myobj.typeobj:=TYPE_NEWCYBER         /*==== Type object      ====*/
            myobj.selected:=FALSE          /*==== Object selected      ====*/
            myobj.bounded:=FALSE           /*==== Object bounded       ====*/
            myobj.nbrspts:=Int(adr+9)                                  /*==== Number of vertices     ====*/
            base.totalpts:=base.totalpts+myobj.nbrspts       /*==== Update database (pts)  ====*/
            adr:=adr+11          /*==== Jump to datapts      ====*/
            myobj.datapts:=New(myobj.nbrspts*12)                       /*==== Allocate Mem for pts   ====*/
            piv_pts:=myobj.datapts       /*==== Pointer to ObjDataPts  ====*/
            FOR a:=0 TO myobj.nbrspts-1
                x:=Int(adr)                                            /*==== Read x ====*/
                y:=Int(adr+2)                                          /*==== Read y ====*/
                z:=Int(adr+4)                                          /*==== Read z ====*/
                IF x>32767 THEN x:=x-65535
                IF y>32767 THEN y:=y-65535
                IF z>32767 THEN z:=z-65535
                adr:=adr+6
                ^piv_pts:=IeeeSPMul(SpTieee(SpFlt(x)),base.fctnewcyber)  /*==== Stock x ====*/
                piv_pts:=piv_pts+4
                ^piv_pts:=IeeeSPMul(SpTieee(SpFlt(y)),base.fctnewcyber)  /*==== Stock y ====*/
                piv_pts:=piv_pts+4
                ^piv_pts:=IeeeSPMul(SpTieee(SpFlt(z)),base.fctnewcyber)  /*==== Stock z ====*/
                piv_pts:=piv_pts+4
           ENDFOR
           myobj.nbrsfcs:=Int(adr)                                    /*==== Number of faces       ====*/
           base.totalfcs:=base.totalfcs+myobj.nbrsfcs       /*==== Update database (fcs) ====*/
           myobj.datafcs:=New(myobj.nbrsfcs*12)                       /*==== Allocate Mem for fcs  ====*/
           piv_pts:=myobj.datafcs       /*==== Pointer to ObjDataFcs ====*/
           adr:=adr+2           /*==== Jump to datafcs     ====*/
           FOR a:=0 TO myobj.nbrsfcs-1
                p1:=Int(adr)                                           /*==== Read 1 vertice ====*/
                p2:=Int(adr+2)                                         /*==== Read 2 vertice ====*/
                p3:=Int(adr+4)                                         /*==== Read 3 vertice ====*/
                ^piv_pts:=p1             /*==== Stock 1 vertice ====*/
                piv_pts:=piv_pts+4
                ^piv_pts:=p2             /*==== Stock 2 vertice ====*/
                piv_pts:=piv_pts+4
                ^piv_pts:=p3             /*==== Stock 3 vertice ====*/
                piv_pts:=piv_pts+4
                adr:=adr+8
            ENDFOR
            myobj.objminx:=1000000.0
            myobj.objmaxx:=-1000000.0
            myobj.objminy:=1000000.0
            myobj.objmaxy:=-1000000.0
            myobj.objminz:=1000000.0
            myobj.objmaxz:=-1000000.0
            addNode(base.objlist,obj_name,myobj)
            buildMinMax(base,myobj,TRUE)
        ENDFOR
    ENDIF
    Raise(ERR3D_NONE)
EXCEPT
    IF exception=ERR3D_MEM
        IF buf<>NIL THEN Dispose(buf)
        IF myobj.datafcs<>NIL THEN Dispose(myobj.datafcs)
        IF myobj.datapts<>NIL THEN Dispose(myobj.datapts)
        IF myobj<>NIL THEN Dispose(myobj)
        RETURN ERR3D_MEM
    ENDIF
    RETURN exception
ENDPROC
-><
->> read3DFile(base:PTR TO base3d,file) HANDLE
PROC read3DFile(base:PTR TO base3d,file) HANDLE
/*== © NasGûl ==================================
Paramètres: pointeur sur un objet base3d,nom d'un fichier amigados STRING.
Retour   : TRUE si ok sinon FALSE
Action   : charge dans la base 3d un objet au format .3D.
===============================================*/
    DEF len,a,adr,buf=NIL,handle,flen=TRUE,i
    DEF nbrs_obj,obj_name[80]:STRING,x,y,z
    DEF myobj=NIL:PTR TO object3d,piv_pts
    #ifdef DEBUG
    kputfmt('read3DFile($\h:PTR TO base3d,\s)\n',[base,file])
    #endif
    flen:=FileLength(file)
    buf:=New(flen+1)
    handle:=Open(file,1005)
    len:=Read(handle,buf,flen)
    Close(handle)
    adr:=buf
    nbrs_obj:=Int(adr+2)
    base.nbrsobjs:=base.nbrsobjs+nbrs_obj
    adr:=buf+34
    FOR i:=0 TO nbrs_obj-1
   StringF(obj_name,'\s',adr)                                 /*==== name of object         ====*/
   myobj:=New(SIZEOF object3d)                                /*==== Allocate new structure ====*/
   myobj.typeobj:=TYPE_OLDCYBER       /*==== Type object    ====*/
   myobj.selected:=FALSE        /*==== Object selected  ====*/
   myobj.bounded:=FALSE         /*==== Object bounded   ====*/
   myobj.nbrspts:=Int(adr+9)                                  /*==== Number of vertices     ====*/
   base.totalpts:=base.totalpts+myobj.nbrspts       /*==== Update database (pts)  ====*/
   adr:=adr+11          /*==== Jump to datapts  ====*/
   myobj.datapts:=New(myobj.nbrspts*12)                       /*==== Allocate Mem for pts   ====*/
   piv_pts:=myobj.datapts         /*==== Pointer to ObjDataPts  ====*/
   FOR a:=0 TO myobj.nbrspts-1
       x:=Long(adr)                                           /*==== Read x ====*/
       y:=Long(adr+(myobj.nbrspts*4))                         /*==== Read y ====*/
       z:=Long(adr+(myobj.nbrspts*8))                         /*==== Read z ====*/
       ^piv_pts:=IeeeSPMul(SpTieee(x),base.fctoldcyber)       /*==== Stock x ====*/
       piv_pts:=piv_pts+4
       ^piv_pts:=IeeeSPMul(SpTieee(y),base.fctoldcyber)       /*==== Stock y ====*/
       piv_pts:=piv_pts+4
       ^piv_pts:=IeeeSPMul(SpTieee(z),base.fctoldcyber)       /*==== Stock z ====*/
       piv_pts:=piv_pts+4
       adr:=adr+4
   ENDFOR
   adr:=adr+(myobj.nbrspts*8)                                 /*==== Jump to faces          ====*/
   myobj.nbrsfcs:=Int(adr)                                    /*==== Number of faces        ====*/
   base.totalfcs:=base.totalfcs+myobj.nbrsfcs       /*==== Update DataBase (fcs)  ====*/
   myobj.datafcs:=New(myobj.nbrsfcs*12)                       /*==== Allocate Mem for faces ====*/
   piv_pts:=myobj.datafcs         /*==== Pointer to datafaces   ====*/
   adr:=adr+2           /*==== Jump to datafcs  ====*/
   FOR a:=0 TO myobj.nbrsfcs-1
       x:=Int(adr)                                            /*==== Number 1 (vertive) ====*/
       y:=Int(adr+2)                                          /*==== Number 2 (vertive) ====*/
       z:=Int(adr+4)                                          /*==== Number 3 (vertice) ====*/
       ^piv_pts:=x      /*==== Stock vertice 1 ====*/
       piv_pts:=piv_pts+4
       ^piv_pts:=y      /*==== Stock vertice 2 ====*/
       piv_pts:=piv_pts+4
       ^piv_pts:=z      /*==== Stock vertice 3 ====*/
       piv_pts:=piv_pts+4
       adr:=adr+8
   ENDFOR
   myobj.objminx:=1000000.0
   myobj.objmaxx:=-1000000.0
   myobj.objminy:=1000000.0
   myobj.objmaxy:=-1000000.0
   myobj.objminz:=1000000.0
   myobj.objmaxz:=-1000000.0
   addNode(base.objlist,obj_name,myobj)
   buildMinMax(base,myobj,TRUE)
    ENDFOR
    Raise(ERR3D_NONE)
EXCEPT
    IF exception=ERR3D_MEM
        IF buf<>NIL THEN Dispose(buf)
        IF myobj.datafcs<>NIL THEN Dispose(myobj.datafcs)
        IF myobj.datapts<>NIL THEN Dispose(myobj.datapts)
        IF myobj<>NIL THEN Dispose(myobj)
        RETURN ERR3D_MEM
    ENDIF
    RETURN exception
ENDPROC
-><
->> read3DProFile(base:PTR TO base3d,file) HANDLE
PROC read3DProFile(base:PTR TO base3d,file) HANDLE
/*== © NasGûl ==================================
Paramètres: pointeur sur un objet base3d,nom d'un fichier amigados STRING.
Retour   : TRUE si ok sinon FALSE
Action   : charge dans la base 3d un objet au format 3DPro.
================================================*/
    DEF len,adr,buf=NIL,handle,flen=TRUE
    DEF count=NIL,piv_pts,pf
    DEF x,y,z
    DEF myobj=NIL:PTR TO object3d,adr_face=NIL,pts_size=NIL
    DEF reel_nbrs_faces=0,max_pts_face=0,badr,obj_name[80]:STRING
    DEF numobj,oldnumface
    #ifdef DEBUG
    kputfmt('read3DProFile($\h:PTR TO base3d,\s)\n',[base,file])
    #endif
    flen:=FileLength(file)
    buf:=New(flen+1)
    handle:=Open(file,1005)
    len:=Read(handle,buf,flen)
    Close(handle)
    adr:=buf
    numobj:=countNodes(base.objlist)
    StringF(obj_name,'Object_\d',numobj+1)
    myobj:=New(SIZEOF object3d)                       /*==== Allocate Mem for structure ====*/
    myobj.typeobj:=TYPE_3DPRO        /*==== Type object    ====*/
    myobj.selected:=FALSE        /*==== Object selected    ====*/
    myobj.bounded:=FALSE       /*==== Object bounded   ====*/
    myobj.nbrspts:=(Int(adr+13)-Int(adr+11))          /*==== Number of pts              ====*/
    myobj.nbrsfcs:=(Int(adr+9)-Int(adr+7))            /*==== Number of faces            ====*/ /*==== WARNING !!, with 3dpro faces can have more than 3 vertice ====*/
    oldnumface:=myobj.nbrsfcs
    base.totalpts:=base.totalpts+myobj.nbrspts       /*==== Update database (pts)      ====*/
    myobj.datapts:=New(myobj.nbrspts*12)              /*==== Allocate mem for pts       ====*/
    piv_pts:=myobj.datapts       /*==== Pointer to objdatapts  ====*/
    adr:=adr+76+7          /*==== Jump to datapts    ====*/
    FOR count:=0 TO myobj.nbrspts-1
   x:=IeeeSPMul(SpTieee(SpFlt(Long(adr))),base.fct3dpro)     -> read x
   y:=IeeeSPMul(SpTieee(SpFlt(Long(adr+4))),base.fct3dpro)   -> read y
   z:=IeeeSPMul(SpTieee(SpFlt(Long(adr+8))),base.fct3dpro)   -> read z
   ^piv_pts:=x         /*==== Stock x ====*/
   piv_pts:=piv_pts+4
   ^piv_pts:=y         /*==== Stock y ====*/
   piv_pts:=piv_pts+4
   ^piv_pts:=z         /*==== Stock z ====*/
   piv_pts:=piv_pts+4
   adr:=adr+12
    ENDFOR
    adr_face:=adr          /*==== 3DPro can have some faces with more than 3 vertices ====*/
    FOR count:=0 TO myobj.nbrsfcs-1
   pts_size:=Char(adr)
   IF pts_size>max_pts_face THEN max_pts_face:=pts_size
   reel_nbrs_faces:=reel_nbrs_faces+(pts_size-2)
   adr:=adr+22+(2*pts_size)
    ENDFOR
    myobj.nbrsfcs:=reel_nbrs_faces      /*==== The reel number of faces (convert to faces with 3 vertice ====*/
    base.totalfcs:=base.totalfcs+reel_nbrs_faces      /*==== Update databse (fcs) ====*/
    myobj.datafcs:=New(reel_nbrs_faces*12)                             /*==== Allocate Mem for faces ====*/
    adr:=adr_face           /*==== Jump to datafaces ====*/
    piv_pts:=myobj.datafcs        /*==== Pointer to objdatafcs ====*/
    FOR count:=0 TO oldnumface-1
   pts_size:=Char(adr)
   badr:=adr+22
   adr:=adr+22
   FOR pf:=1 TO pts_size-2
       x:=Int(badr)                  /*==== Read x ====*/
       y:=Int(adr+2)                 /*==== Read y ====*/
       z:=Int(adr+4)                 /*==== Read z ====*/
       ^piv_pts:=x   /*==== Stock x ====*/
       piv_pts:=piv_pts+4
       ^piv_pts:=y   /*==== Stock y ====*/
       piv_pts:=piv_pts+4
       ^piv_pts:=z   /*==== Stock z ====*/
       piv_pts:=piv_pts+4
       adr:=adr+2
   ENDFOR
   adr:=adr+4
    ENDFOR
    myobj.objminx:=1000000.0
    myobj.objmaxx:=-1000000.0
    myobj.objminy:=1000000.0
    myobj.objmaxy:=-1000000.0
    myobj.objminz:=1000000.0
    myobj.objmaxz:=-1000000.0
    addNode(base.objlist,obj_name,myobj)
    buildMinMax(base,myobj,TRUE)
    Raise(ERR3D_NONE)
EXCEPT
    IF exception=ERR3D_MEM
        IF buf<>NIL THEN Dispose(buf)
        IF myobj.datafcs<>NIL THEN Dispose(myobj.datafcs)
        IF myobj.datapts<>NIL THEN Dispose(myobj.datapts)
        IF myobj<>NIL THEN Dispose(myobj)
        RETURN ERR3D_MEM
    ENDIF
    RETURN exception
ENDPROC
-><
->> readImagineFile(base:PTR TO base3d,file) HANDLE
PROC readImagineFile(base:PTR TO base3d,file) HANDLE
/*== © NasGûl ==================================
Paramètres: pointeur sur un objet base3d,nom d'un fichier amigados STRING.
Retour   : TRUE si ok sinon FALSE
Action   : charge dans la base 3d un objet au format Imagine.
===============================================*/
    DEF len,a,adr,buf=NIL,handle,flen=TRUE,pos,chunk
    DEF count=NIL,nbrs_edges,piv
    DEF obj_name[80]:STRING
    DEF adr_edges,pivfcs
    DEF myobj=NIL:PTR TO object3d,piv_pts,x,y,z
    DEF x_size,y_size,z_size
    DEF p1,d1,inobj=FALSE
    flen:=FileLength(file)
    buf:=New(flen+1)
    handle:=Open(file,1005)
    len:=Read(handle,buf,flen)
    Close(handle)

    adr:=buf

    FOR a:=0 TO len-1
    pos:=adr++
    IF Even(pos)
        chunk:=Long(pos)
        SELECT chunk
        CASE ID_FORM
        CASE ID_TDDD
        CASE ID_SIZE
            x_size:=Int(pos+8)
            y_size:=Int(pos+12)
            z_size:=Int(pos+16)
        CASE ID_NAME
            StringF(obj_name,pos+8,ALL)
            IF StrLen(obj_name)=0 THEN StringF(obj_name,'Object_\d',countNodes(base.objlist))
        CASE ID_PNTS
            inobj:=TRUE
            myobj:=New(SIZEOF object3d)                     /*==== Allocate Mem for structure ====*/
            myobj.typeobj:=TYPE_IMAGINE     /*==== Type object      ====*/
            myobj.selected:=FALSE   /*==== Object selected      ====*/
            myobj.bounded:=FALSE    /*==== Object bounded     ====*/
            myobj.nbrspts:=Int(pos+8)                       /*==== Number of pts              ====*/
            base.totalpts:=base.totalpts+myobj.nbrspts  /*==== Update database (pts)      ====*/
            myobj.datapts:=New(myobj.nbrspts*12)            /*==== Allocate mem for pts       ====*/
            piv_pts:=myobj.datapts    /*==== Pointer to objdatapts    ====*/
            piv:=pos+10     /*==== Jump to datapts      ====*/
            FOR count:=0 TO myobj.nbrspts-1
            x:=IeeeSPMul(IeeeSPDiv(SpTieee(SpFlt(Long(piv))),SpTieee(SpFlt(65536))),base.fctimagine)
            y:=IeeeSPMul(IeeeSPDiv(SpTieee(SpFlt(Long(piv+4))),SpTieee(SpFlt(65536))),base.fctimagine)
            z:=IeeeSPMul(IeeeSPDiv(SpTieee(SpFlt(Long(piv+8))),SpTieee(SpFlt(65536))),base.fctimagine)
            ->     WriteF('\d ',count);wF(x);wF(y);wF(z);WriteF('\n')
            ^piv_pts:=x     /*==== Stock x ====*/
            piv_pts:=piv_pts+4
            ^piv_pts:=y     /*==== Stock y ====*/
            piv_pts:=piv_pts+4
            ^piv_pts:=z     /*==== Stock z ====*/
            piv_pts:=piv_pts+4
            piv:=piv+12
            ENDFOR
        CASE ID_EDGE
            nbrs_edges:=Int(pos+8)                          /*==== Number of edges ====*/
            piv:=pos+10     /*==== just remember   ====*/
            adr_edges:=piv      /*==== the address     ====*/
        CASE ID_FACE
            pivfcs:=Int(pos+8)                              /*==== Number of fcs         ====*/
            IF ((pivfcs<>0) AND (inobj=TRUE))
            myobj.nbrsfcs:=pivfcs
            base.totalfcs:=base.totalfcs+myobj.nbrsfcs      /*==== Update database   ====*/
            myobj.datafcs:=New(myobj.nbrsfcs*12)                            /*==== Allocate mem for fcs  ====*/
            piv_pts:=myobj.datafcs          /*==== Pointer to objdatafcs ====*/
            piv:=pos+10         /*==== Jump to datafcs   ====*/
            FOR count:=0 TO myobj.nbrsfcs-1
                x:=Int(adr_edges+(Int(piv)*4))                              /*==== Read 1 vertice ====*/
                y:=Int(adr_edges+(Int(piv)*4+2))                            /*==== Read 2 vertice ====*/
                p1:=Int(adr_edges+(Int(piv+2)*4))                           /*==== select 3 vertice ====*/
                d1:=Int(adr_edges+(Int(piv+2)*4+2))                         /*==== to build the face ====*/
                IF (p1<>x) AND (p1<>y) THEN z:=p1
                IF (d1<>x) AND (d1<>y) THEN z:=d1
                ^piv_pts:=x           /*==== Stock 1 vertice ====*/
                piv_pts:=piv_pts+4
               ^piv_pts:=y           /*==== Stock 2 vertice ====*/
               piv_pts:=piv_pts+4
               ^piv_pts:=z           /*==== Stock 3 vertice ====*/
               piv_pts:=piv_pts+4
               piv:=piv+6
            ENDFOR
            myobj.objminx:=1000000.0
            myobj.objmaxx:=-1000000.0
            myobj.objminy:=1000000.0
            myobj.objmaxy:=-1000000.0
            myobj.objminz:=1000000.0
            myobj.objmaxz:=-1000000.0
            addNode(base.objlist,obj_name,myobj)
            buildMinMax(base,myobj,TRUE)
            inobj:=FALSE
            ENDIF
        DEFAULT
            NOP
        ENDSELECT
    ENDIF
    ENDFOR
    Raise(ERR3D_NONE)
EXCEPT
    IF exception=ERR3D_MEM
        IF buf<>NIL THEN Dispose(buf)
        IF myobj.datafcs<>NIL THEN Dispose(myobj.datafcs)
        IF myobj.datapts<>NIL THEN Dispose(myobj.datapts)
        IF myobj<>NIL THEN Dispose(myobj)
        RETURN ERR3D_MEM
    ENDIF
    RETURN exception
ENDPROC
-><
->> readSculptFile(base:PTR TO base3d,file) HANDLE
PROC readSculptFile(base:PTR TO base3d,file) HANDLE
/*== © NasGûl ==================================
Paramètres: pointeur sur un objet base3d,nom d'un fichier amigados STRING.
Retour   : TRUE si ok sinon FALSE
Action   : charge dans la base 3d un objet au format Sculpt.
================================================*/
  DEF len,a,adr,buf=NIL,handle,flen=TRUE,pos,chunk,i,piv
  DEF x,y,z
  DEF myobj=NIL:PTR TO object3d,piv_pts,obj_name[80]:STRING
  DEF numobj
    #ifdef DEBUG
    kputfmt('readSculptFile($\h:PTR TO base3d,\s)\n',[base,file])
    #endif
  flen:=FileLength(file)
  buf:=New(flen+1)
  handle:=Open(file,1005)
  len:=Read(handle,buf,flen)
  Close(handle)
  adr:=buf
  FOR a:=0 TO len-1
    pos:=adr++
    IF Even(pos)
   chunk:=Long(pos)
   SELECT chunk
       CASE ID_FORM
       CASE ID_SC3D
       CASE ID_VERT
     numobj:=countNodes(base.objlist)
     StringF(obj_name,'Object_\d',numobj+1)
     myobj:=New(SIZEOF object3d)                        /*==== Allocate mem for structure ====*/
     myobj.typeobj:=TYPE_SCULPT     /*==== Type object    ====*/
     myobj.selected:=FALSE      /*==== Object selected  ====*/
     myobj.bounded:=FALSE       /*==== Object bounded   ====*/
     myobj.nbrspts:=Long(pos+4)/12                      /*==== Number of pts              ====*/
     base.totalpts:=base.totalpts+myobj.nbrspts     /*==== Update database (pts)      ====*/
     myobj.datapts:=New(myobj.nbrspts*12)               /*==== Allocate mem for pts       ====*/
     piv_pts:=myobj.datapts       /*==== Pointer to objdatapts  ====*/
     piv:=pos+8         /*==== Jump to datapts  ====*/
     FOR i:=0 TO myobj.nbrspts-1
     x:=IeeeSPMul(SpTieee(SpFlt(Long(piv))),base.fctsculpt)
     y:=IeeeSPMul(SpTieee(SpFlt(Long(piv+4))),base.fctsculpt)
     z:=IeeeSPMul(SpTieee(SpFlt(Long(piv+8))),base.fctsculpt)
     ^piv_pts:=x        /*==== Stock x ====*/
     piv_pts:=piv_pts+4
     ^piv_pts:=y        /*==== Stock y ====*/
     piv_pts:=piv_pts+4
     ^piv_pts:=z        /*==== Stock z ====*/
     piv_pts:=piv_pts+4
     piv:=piv+12
     ENDFOR
       CASE ID_EDGE
       CASE ID_FACE
     myobj.nbrsfcs:=Long(pos+4)/16                                 /*==== Number of fcs         ====*/
     myobj.datafcs:=New(myobj.nbrsfcs*12)                          /*==== Allocate mem for fcs  ====*/
     base.totalfcs:=base.totalfcs+myobj.nbrsfcs      /*==== Update database (fcs) ====*/
     piv_pts:=myobj.datafcs        /*==== Pointer to objdatafcs ====*/
     piv:=pos+8          /*==== Jump to datafcs     ====*/
     FOR i:=0 TO myobj.nbrsfcs-1
     x:=Long(piv)                          /*==== Read 1 vertice ====*/
     y:=Long(piv+4)                        /*==== Read 2 vertice ====*/
     z:=Long(piv+8)                        /*==== Read 3 vertice ====*/
     ^piv_pts:=x         /*==== Stock 1 vertice ====*/
     piv_pts:=piv_pts+4
     ^piv_pts:=y         /*==== Stock 2 vertice ====*/
     piv_pts:=piv_pts+4
     ^piv_pts:=z         /*==== Stock 3 vertice ====*/
     piv_pts:=piv_pts+4
     piv:=piv+16
     ENDFOR
     myobj.objminx:=1000000.0
     myobj.objmaxx:=-1000000.0
     myobj.objminy:=1000000.0
     myobj.objmaxy:=-1000000.0
     myobj.objminz:=1000000.0
     myobj.objmaxz:=-1000000.0
     addNode(base.objlist,obj_name,myobj)
     buildMinMax(base,myobj,TRUE)
       DEFAULT
     NOP
   ENDSELECT
    ENDIF
  ENDFOR
  Raise(ERR3D_NONE)
EXCEPT
    IF exception=ERR3D_MEM
        IF buf<>NIL THEN Dispose(buf)
        IF myobj.datafcs<>NIL THEN Dispose(myobj.datafcs)
        IF myobj.datapts<>NIL THEN Dispose(myobj.datapts)
        IF myobj<>NIL THEN Dispose(myobj)
        RETURN ERR3D_MEM
    ENDIF
    RETURN exception
ENDPROC
-><
->> readVertexFile(base:PTR TO base3d,file,chunk) HANDLE
PROC readVertexFile(base:PTR TO base3d,file,chunk) HANDLE
/*== © NasGûl ==================================
Paramètres: pointeur sur un objet base3d,nom d'un fichier amigados STRING.
Retour   : TRUE si ok sinon FALSE
Action   : charge dans la base 3d un objet au format Vertex.
================================================*/
    DEF len,a,adr,buf=NIL,handle,flen=TRUE
    DEF piv
    DEF nbrs_edges,x,y,z
    DEF myobj=NIL:PTR TO object3d,piv_pts,obj_name[80]:STRING
    DEF numobj,objsel
    #ifdef DEBUG
        kputfmt('readVertexFile($\h:PTR TO base3d,\s)\n',[base,file])
    #endif
    flen:=FileLength(file)
    buf:=New(flen+1)
    handle:=Open(file,1005)
    len:=Read(handle,buf,flen)
    Close(handle)
    adr:=buf
    numobj:=countNodes(base.objlist)
    StringF(obj_name,'Object_\d',numobj+1)
    myobj:=New(SIZEOF object3d)                          /*==== Allocate mem for structure ====*/
    IF chunk=ID_VE3D THEN myobj.typeobj:=TYPE_OLDVERTEX ELSE myobj.typeobj:=TYPE_NEWVERTEX    /*==== Object type ====*/
    myobj.selected:=FALSE     /*==== Object selected ====*/
    myobj.bounded:=FALSE    /*==== Object bounded  ====*/
    myobj.nbrspts:=Long(adr+4)                           /*==== Number of pts   ====*/
    base.totalpts:=base.totalpts+myobj.nbrspts    /*==== Update database (pts) ====*/
    myobj.datapts:=New(myobj.nbrspts*12)                 /*==== Allocate mem for pts ====*/
    piv_pts:=myobj.datapts    /*==== Pointer to objdatapts ====*/
    piv:=adr+8        /*==== Jump to datapts ====*/
    FOR a:=0 TO myobj.nbrspts-1
        x:=IeeeSPMul(SpTieee(SpFlt(Long(piv))),base.fctvertex)
        y:=IeeeSPMul(SpTieee(SpFlt(Long(piv+4))),base.fctvertex)
        z:=IeeeSPMul(SpTieee(SpFlt(Long(piv+8))),base.fctvertex)
        ^piv_pts:=x      /*==== Stock x ====*/
        piv_pts:=piv_pts+4
        ^piv_pts:=y      /*==== Stock y ====*/
        piv_pts:=piv_pts+4
        ^piv_pts:=z      /*==== Stock z ====*/
        piv_pts:=piv_pts+4
        SELECT chunk
            CASE ID_VE3D
                objsel:=Char(piv+13)
                IF objsel=$2D THEN piv:=piv+16 ELSE piv:=piv+15
            CASE ID_VR3D
                objsel:=Char(piv+14)
                IF objsel=$2D THEN piv:=piv+17 ELSE piv:=piv+16
->    #ifdef DEBUG
->        kputfmt('readVertexFile() $\h \h\n',[objsel,chunk])
->    #endif

        ENDSELECT
    ENDFOR
    nbrs_edges:=Long(piv)
    piv:=piv+4+Mul(nbrs_edges,8)
->    piv:=piv+4+(nbrs_edges*8)
    myobj.nbrsfcs:=Long(piv)                             /*==== Number of fcs ====*/
    base.totalfcs:=base.totalfcs+myobj.nbrsfcs    /*==== Update database fcs ====*/
    myobj.datafcs:=New(myobj.nbrsfcs*12)                 /*==== Allocate mem for fcs ====*/
    piv_pts:=myobj.datafcs    /*==== Pointer to objdatafcs ====*/
    piv:=piv+4        /*==== Jump to datafcs ====*/
    FOR a:=0 TO myobj.nbrsfcs-1
   x:=Long(piv)-1                                   /*==== Read 1 vertice ====*/
   y:=Long(piv+4)-1                                 /*==== Read 2 vertice ====*/
   z:=Long(piv+8)-1                                 /*==== Read 3 vertice ====*/
   ^piv_pts:=x      /*==== Stock 1 vertice ====*/
   piv_pts:=piv_pts+4
   ^piv_pts:=y      /*==== Stock 2 vertice ====*/
   piv_pts:=piv_pts+4
   ^piv_pts:=z      /*==== Stock 3 vertice ====*/
   piv_pts:=piv_pts+4
   piv:=piv+12
    ENDFOR
    myobj.objminx:=1000000.0
    myobj.objmaxx:=-1000000.0
    myobj.objminy:=1000000.0
    myobj.objmaxy:=-1000000.0
    myobj.objminz:=1000000.0
    myobj.objmaxz:=-1000000.0
    addNode(base.objlist,obj_name,myobj)
    buildMinMax(base,myobj,TRUE)
    Raise(ERR3D_NONE)
EXCEPT
    IF exception=ERR3D_MEM
        IF buf<>NIL THEN Dispose(buf)
        IF myobj.datafcs<>NIL THEN Dispose(myobj.datafcs)
        IF myobj.datapts<>NIL THEN Dispose(myobj.datapts)
        IF myobj<>NIL THEN Dispose(myobj)
        RETURN ERR3D_MEM
    ENDIF
    RETURN exception
ENDPROC
-><
->> readVertex2File(base:PTR TO base3d,file) HANDLE
PROC readVertex2File(base:PTR TO base3d,file) HANDLE
/*== © NasGûl ==================================
Paramètres: pointeur sur un objet base3d,nom d'un fichier amigados STRING.
Retour   : TRUE si ok sinon FALSE
Action   : charge dans la base 3d un objet au format Vertex2.
================================================*/
  DEF len,a,adr,buf=NIL,handle,flen=TRUE,pos,chunk,i,piv
  DEF x,y,z
  DEF myobj=NIL:PTR TO object3d,piv_pts,obj_name[80]:STRING
  DEF numobj
  DEF longf,longe,adr_edges,nbrs_edges
    #ifdef DEBUG
    kputfmt('readVertex2File($\h:PTR TO base3d,\s)\n',[base,file])
    #endif
  flen:=FileLength(file)
  buf:=New(flen+1)
  handle:=Open(file,1005)
  len:=Read(handle,buf,flen)
  Close(handle)
  adr:=buf
  FOR a:=0 TO len-1
    pos:=adr++
    IF Even(pos)
   chunk:=Long(pos)
   SELECT chunk
       CASE ID_NAME
     StringF(obj_name,pos+8,ALL)
     IF StrLen(obj_name)=0 THEN StringF(obj_name,'Object_\d',countNodes(base.objlist))
       CASE ID_VERT
     numobj:=countNodes(base.objlist)
     myobj:=New(SIZEOF object3d)
     myobj.typeobj:=TYPE_VERTEX2    /*==== Type object    ====*/
     myobj.selected:=FALSE      /*==== Object selected  ====*/
     myobj.bounded:=FALSE       /*==== Object bounded   ====*/
     myobj.nbrspts:=Long(pos+4)/12                      /*==== Number of pts              ====*/
     base.totalpts:=base.totalpts+myobj.nbrspts     /*==== Update database (pts)      ====*/
     myobj.datapts:=New(myobj.nbrspts*12)               /*==== Allocate mem for pts       ====*/
     piv_pts:=myobj.datapts       /*==== Pointer to objdatapts  ====*/
     piv:=pos+8         /*==== Jump to datapts  ====*/
     FOR i:=0 TO myobj.nbrspts-1
     x:=IeeeSPMul(SpTieee(SpFlt(Long(piv))),base.fctvertex)                        /*==== Read x ====*/
     y:=IeeeSPMul(SpTieee(SpFlt(Long(piv+4))),base.fctvertex)                      /*==== Read y ====*/
     z:=IeeeSPMul(SpTieee(SpFlt(Long(piv+8))),base.fctvertex)                      /*==== Read z ====*/
     ^piv_pts:=x        /*==== Stock x ====*/
     piv_pts:=piv_pts+4
     ^piv_pts:=y        /*==== Stock y ====*/
     piv_pts:=piv_pts+4
     ^piv_pts:=z        /*==== Stock z ====*/
     piv_pts:=piv_pts+4
     piv:=piv+12
     ENDFOR
       CASE ID_EDGE
     longe:=Long(pos+4)
     IF longe<765
     nbrs_edges:=longe/3
     ELSE
     nbrs_edges:=longe/6
     ENDIF
     adr_edges:=pos+8
       CASE ID_FACE
     longf:=Long(pos+4)
     IF longf<765
     myobj.nbrsfcs:=Long(pos+4)/3                                 /*==== Number of fcs         ====*/
     ELSE
     myobj.nbrsfcs:=Long(pos+4)/6                                 /*==== Number of fcs         ====*/
     ENDIF
     myobj.datafcs:=New(myobj.nbrsfcs*12)                          /*==== Allocate mem for fcs  ====*/
     base.totalfcs:=base.totalfcs+myobj.nbrsfcs      /*==== Update database (fcs) ====*/
     piv_pts:=myobj.datafcs        /*==== Pointer to objdatafcs ====*/
     piv:=pos+8          /*==== Jump to datafcs     ====*/
     FOR i:=0 TO myobj.nbrsfcs-1
     IF longf<765
       x:=Char(piv)-1
       y:=Char(piv+1)-1
       z:=Char(piv+2)-1
       ^piv_pts:=x       /*==== Stock 1 vertice ====*/
       piv_pts:=piv_pts+4
       ^piv_pts:=y       /*==== Stock 2 vertice ====*/
       piv_pts:=piv_pts+4
       ^piv_pts:=z       /*==== Stock 3 vertice ====*/
       piv_pts:=piv_pts+4
       piv:=piv+3
     ELSE
       x:=Int(piv)-1                          /*==== Read 1 vertice ====*/
       y:=Int(piv+2)-1                        /*==== Read 2 vertice ====*/
       z:=Int(piv+4)-1                        /*==== Read 3 vertice ====*/
       ^piv_pts:=x       /*==== Stock 1 vertice ====*/
       piv_pts:=piv_pts+4
       ^piv_pts:=y       /*==== Stock 2 vertice ====*/
       piv_pts:=piv_pts+4
       ^piv_pts:=z       /*==== Stock 3 vertice ====*/
       piv_pts:=piv_pts+4
       piv:=piv+6
     ENDIF
     ENDFOR
     myobj.objminx:=1000000.0
     myobj.objmaxx:=-1000000.0
     myobj.objminy:=1000000.0
     myobj.objmaxy:=-1000000.0
     myobj.objminz:=1000000.0
     myobj.objmaxz:=-1000000.0
     addNode(base.objlist,obj_name,myobj)
     buildMinMax(base,myobj,TRUE)
       DEFAULT
     NOP
   ENDSELECT
    ENDIF
  ENDFOR
  Raise(ERR3D_NONE)
EXCEPT
    IF exception=ERR3D_MEM
        IF buf<>NIL THEN Dispose(buf)
        IF myobj.datafcs<>NIL THEN Dispose(myobj.datafcs)
        IF myobj.datapts<>NIL THEN Dispose(myobj.datapts)
        IF myobj<>NIL THEN Dispose(myobj)
        RETURN ERR3D_MEM
    ENDIF
    RETURN exception
ENDPROC
-><
->> read3DStudioFile(base:PTR TO base3d,file) HANDLE
PROC read3DStudioFile(base:PTR TO base3d,file) HANDLE
/*== © NasGûl ==================================
Paramètres: pointeur sur un objet base3d,nom d'un fichier amigados STRING.
Retour   : TRUE si ok sinon FALSE
Action   : charge dans la base 3d un objet au format 3DStudio.
================================================*/
    DEF flen,buf=NIL,adr:PTR TO CHAR,hld=NIL,len
    DEF pos:PTR TO CHAR,chunk
    DEF mc:PTR TO studiochunk,inobj=FALSE,lookpoint=FALSE,offset,b,npts,nfcs,lookface=FALSE
    DEF x,y,z,s1,s2,s3
    /*==============================*/
    DEF objname[256]:STRING,robjname[256]:STRING
    DEF skip=FALSE
    /*===============================*/
    DEF myobj=NIL:PTR TO object3d,piv_pts
    #ifdef DEBUG
        kputfmt('readVertex2File($\h:PTR TO base3d,\s)\n',[base,file])
    #endif
    flen:=FileLength(file)
    buf:=New(flen+1)
    hld:=Open(file,1005)
    len:=Read(hld,buf,flen)
    Close(hld)
    adr:=buf
    pos:=adr
    REPEAT
        chunk:=Int(pos)
        offset:=pos-adr
        SELECT chunk
            CASE $40
                StrCopy(objname,pos+6,ALL)
                IF EstrLen(objname)>1
                    pos:=pos+6+EstrLen(objname)+1
                    chunk:=Int(pos)
                    IF chunk=$41
                        StrCopy(robjname,objname,ALL) -> the name OF OBJECT.
                        inobj:=TRUE
                    ENDIF
                ENDIF
            CASE $1041
                IF inobj=TRUE
                    myobj:=New(SIZEOF object3d)    -> allocate mem FOR NEW OBJECT.
                    myobj.typeobj:=TYPE_3DS         -> type OF OBJECT.
                    myobj.selected:=FALSE           -> OBJECT not selected
                    myobj.bounded:=FALSE            -> OBJECT not bounded
                    npts:=getInt(Int(pos+6))        -> get number OF vertices
                    myobj.nbrspts:=npts             -> Number OF pts
                    base.totalpts:=base.totalpts+myobj.nbrspts     -> Update database (pts)
                    myobj.datapts:=New(myobj.nbrspts*12)           -> Allocate mem FOR pts
                    piv_pts:=myobj.datapts                         -> Pointer TO objdatapts
                    mc:=pos                                        -> get current chunk
                    pos:=pos+8                                     -> skip it AND go TO data.
                    FOR b:=0 TO npts-1
                        x:=getLong(Long(pos))                      -> get coord x.
                        y:=getLong(Long(pos+4))                    -> get coord y.
                        z:=getLong(Long(pos+8))                    -> get coord z.
                        ^piv_pts:=x                                -> stock x
                        piv_pts:=piv_pts+4
                        ^piv_pts:=y                                -> stock y
                        piv_pts:=piv_pts+4
                        ^piv_pts:=z                                -> stock z
                        piv_pts:=piv_pts+4
                        pos:=pos+12
                    ENDFOR
                    pos:=pos+((getLong(mc.chunksize)-8)-Mul(12,npts))  -> got END OF point chunk
                    lookpoint:=FALSE                                   -> d'ont look FOR point
                    lookface:=TRUE                                     -> BUT search faces....
                    REPEAT                                             -> so skip ALL other chunk.
                        chunk:=Int(pos)
                        SELECT chunk
                            CASE $7041
                                pos:=pos+skipChunk(pos)
                            CASE $4041
                                pos:=pos+skipChunk(pos)
                            CASE $1141
                                pos:=pos+skipChunk(pos)
                            CASE $6041
                                pos:=pos+skipChunk(pos)
                            CASE $6541
                                pos:=pos+skipChunk(pos)
                            DEFAULT
                                skip:=TRUE
                        ENDSELECT
                    UNTIL (skip=TRUE)
                    skip:=FALSE
                    pos:=pos-2             -> RETURN 2 bytes TO get the chunkid
                ENDIF
            CASE $2041
                IF inobj=TRUE
                    IF lookface=TRUE
                        mc:=pos
                        nfcs:=getInt(Int(pos+6))                  -> get num faces
                        myobj.nbrsfcs:=nfcs                        -> update them in OBJECT structure
                        myobj.datafcs:=New(Mul(myobj.nbrsfcs,12))  -> allocate mem FOR faces
                        base.totalfcs:=base.totalfcs+nfcs         -> update total base faces.
                        pos:=pos+8                                -> point TO data.
                        piv_pts:=myobj.datafcs                    -> OBJECT faces
                        FOR b:=0 TO nfcs-1
                            s1:=getInt(Int(pos))
                            s2:=getInt(Int(pos+2))
                            s3:=getInt(Int(pos+4))
                            ^piv_pts:=s1
                            piv_pts:=piv_pts+4
                            ^piv_pts:=s2
                            piv_pts:=piv_pts+4                            
                            ^piv_pts:=s3
                            piv_pts:=piv_pts+4
                            pos:=pos+8
                        ENDFOR
                        pos:=pos+((getLong(mc.chunksize)-8)-Mul(8,nfcs))
                        lookface:=FALSE
                        inobj:=FALSE
                        pos:=pos-2
                        myobj.objminx:=1000000.0
                        myobj.objmaxx:=-1000000.0
                        myobj.objminy:=1000000.0
                        myobj.objmaxy:=-1000000.0
                        myobj.objminz:=1000000.0
                        myobj.objmaxz:=-1000000.0
                        addNode(base.objlist,robjname,myobj)
                        buildMinMax(base,myobj,TRUE)
                    ENDIF
                ENDIF
        ENDSELECT
        pos++
    UNTIL (pos=(adr+len))
    Raise(ERR3D_NONE)
EXCEPT
    IF exception=ERR3D_MEM
        IF buf<>NIL THEN Dispose(buf)
        IF myobj.datafcs<>NIL THEN Dispose(myobj.datafcs)
        IF myobj.datapts<>NIL THEN Dispose(myobj.datapts)
        IF myobj<>NIL THEN Dispose(myobj)
        RETURN ERR3D_MEM
    ENDIF
    RETURN exception
ENDPROC
-><
->>
->> Fonctions de chargement STL ASCII.

PROC stlCharUpper(c)
    IF (c>=97) AND (c<=122) THEN c:=c-32
ENDPROC c

PROC stlSkipSpaces(line:PTR TO CHAR,pos)
    WHILE (line[pos]=32) OR (line[pos]=9)
        pos++
    ENDWHILE
ENDPROC pos

PROC stlNextToken(line:PTR TO CHAR,pos,dest:PTR TO CHAR)
    DEF i=0

    pos:=stlSkipSpaces(line,pos)

    WHILE (line[pos]<>0) AND (line[pos]<>32) AND (line[pos]<>9) AND (line[pos]<>10) AND (line[pos]<>13)
        IF i<63
            dest[i]:=line[pos]
            i++
        ENDIF
        pos++
    ENDWHILE

    dest[i]:=0
ENDPROC pos

PROC stlReadLine(h,line,maxlen)
    DEF c[1]:ARRAY OF CHAR
    DEF len=0,r

    WHILE len<maxlen-1
        r:=Read(h,c,1)
        IF r<>1
            line[len]:=0
            IF len=0 THEN RETURN -1
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

PROC stlParseVertex(line:PTR TO CHAR,xptr:PTR TO LONG,yptr:PTR TO LONG,zptr:PTR TO LONG)
    DEF pos,t,rx,ry,rz
    DEF tok[64]:STRING

    pos:=stlSkipSpaces(line,0)

    IF stlCharUpper(line[pos])<>86 THEN RETURN FALSE
    pos++
    IF stlCharUpper(line[pos])<>69 THEN RETURN FALSE
    pos++
    IF stlCharUpper(line[pos])<>82 THEN RETURN FALSE
    pos++
    IF stlCharUpper(line[pos])<>84 THEN RETURN FALSE
    pos++
    IF stlCharUpper(line[pos])<>69 THEN RETURN FALSE
    pos++
    IF stlCharUpper(line[pos])<>88 THEN RETURN FALSE
    pos++

    pos:=stlNextToken(line,pos,tok)
    rx,t:=RealVal(tok)
    pos:=stlNextToken(line,pos,tok)
    ry,t:=RealVal(tok)
    pos:=stlNextToken(line,pos,tok)
    rz,t:=RealVal(tok)

    ^xptr:=rx
    ^yptr:=ry
    ^zptr:=rz
ENDPROC TRUE

PROC stlCountVertices(file)
    DEF h=NIL,line[256]:ARRAY OF CHAR,len
    DEF count=0,x,y,z

    h:=Open(file,1005)
    IF h=NIL THEN RETURN -1

    WHILE (len:=stlReadLine(h,line,256))<>-1
        IF stlParseVertex(line,{x},{y},{z}) THEN count++
    ENDWHILE

    Close(h)
ENDPROC count

PROC readStlFile(base:PTR TO base3d,file) HANDLE
/*== Denis Costils / Codex ==================================
Parametres: pointeur sur un objet base3d, nom d'un fichier amigados STRING.
Retour   : TRUE si ok sinon FALSE.
Action   : charge dans la base 3d un objet au format STL ASCII.
Note     : STL binaire non supporte.
================================================*/
    DEF nverts,nfaces,h=NIL,line[256]:ARRAY OF CHAR,len
    DEF myobj=NIL:PTR TO object3d,piv_pts
    DEF obj_name[256]:STRING
    DEF i,x,y,z
    DEF ret=ERR3D_NONE

    nverts:=stlCountVertices(file)
    IF nverts<0 THEN RETURN ERR3D_NOFILE
    IF nverts=0 THEN RETURN ERR3D_UNKNOWNFILE
    IF (nverts/3)*3<>nverts THEN RETURN ERR3D_UNKNOWNFILE

    nfaces:=nverts/3

    myobj:=New(SIZEOF object3d)
    StringF(obj_name,'STL_Object_\d',countNodes(base.objlist))
    myobj.typeobj:=TYPE_STL
    myobj.selected:=FALSE
    myobj.bounded:=FALSE
    myobj.nbrspts:=nverts
    myobj.nbrsfcs:=nfaces

    base.totalpts:=base.totalpts+myobj.nbrspts
    base.totalfcs:=base.totalfcs+myobj.nbrsfcs

    myobj.datapts:=New(myobj.nbrspts*12)
    piv_pts:=myobj.datapts

    h:=Open(file,1005)
    IF h=NIL THEN Raise(ERR3D_NOFILE)

    WHILE (len:=stlReadLine(h,line,256))<>-1
        IF stlParseVertex(line,{x},{y},{z})
            ^piv_pts:=x
            piv_pts:=piv_pts+4
            ^piv_pts:=y
            piv_pts:=piv_pts+4
            ^piv_pts:=z
            piv_pts:=piv_pts+4
        ENDIF
    ENDWHILE

    Close(h)
    h:=NIL

    myobj.datafcs:=New(myobj.nbrsfcs*12)
    piv_pts:=myobj.datafcs

    FOR i:=0 TO nfaces-1
        ^piv_pts:=i*3
        piv_pts:=piv_pts+4
        ^piv_pts:=(i*3)+1
        piv_pts:=piv_pts+4
        ^piv_pts:=(i*3)+2
        piv_pts:=piv_pts+4
    ENDFOR

    myobj.objminx:=1000000.0
    myobj.objmaxx:=-1000000.0
    myobj.objminy:=1000000.0
    myobj.objmaxy:=-1000000.0
    myobj.objminz:=1000000.0
    myobj.objmaxz:=-1000000.0

    addNode(base.objlist,obj_name,myobj)
    buildMinMax(base,myobj,TRUE)

    Raise(ret)

EXCEPT
    IF h THEN Close(h)
    IF exception<>ERR3D_NONE
        IF myobj<>NIL
            IF myobj.datafcs<>NIL THEN Dispose(myobj.datafcs)
            IF myobj.datapts<>NIL THEN Dispose(myobj.datapts)
            Dispose(myobj)
        ENDIF
    ENDIF
    RETURN exception
ENDPROC
-><

->> readGeoFile(base:PTR TO base3d,file) HANDLE
PROC readGeoFile(base:PTR TO base3d,file) HANDLE
/*== © NasGûl ==================================
Paramètres: pointeur sur un objet base3d,nom d'un fichier amigados STRING.
Retour   : TRUE si ok sinon FALSE
Action   : charge dans la base 3d un objet au format GEO (3DG1).
================================================*/
    DEF textmem=NIL,len=-1,l=NIL:PTR TO LONG,numline=NIL,i

    DEF nbrspts,nbrsfcs,piv_pts,x,y,z
    DEF myobj:PTR TO object3d,obj_name[256]:STRING
    DEF v1,v2,v3

    DEF ret=ERR3D_NONE

    textmem,len:=readfile(file)
    numline:=countstrings(textmem,len)
    l:=stringsinfile(textmem,len,numline)

    myobj:=New(SIZEOF object3d)              -> alloc me FOR OBJECT
     StringF(obj_name,'Object_\d',countNodes(base.objlist))
->    StrCopy(obj_name,'Object_1',ALL)         -> one OBJECT in geo file
    myobj.typeobj:=TYPE_GEO                  ->Type OBJECT
    myobj.selected:=FALSE                    -> OBJECT (not) selected
    myobj.bounded:=FALSE                     -> OBJECT (not) bounded
    nbrspts:=Val(l[1],NIL)
    myobj.nbrspts:=nbrspts                   -> nbrspts OF OBJECT

    base.totalpts:=base.totalpts+myobj.nbrspts  /*==== Update database (pts)      ====*/
    myobj.datapts:=New(myobj.nbrspts*12)        /*==== Allocate mem FOR pts       ====*/
    piv_pts:=myobj.datapts                      /*==== Pointer TO objdatapts    ====*/
    FOR i:=0 TO nbrspts-1
        x:=getCoord(COORD_X,l[i+2])             -> read x
        y:=getCoord(COORD_Y,l[i+2])             -> read y
        z:=getCoord(COORD_Z,l[i+2])             -> read z
        ^piv_pts:=x                             /*==== Stock x ====*/
        piv_pts:=piv_pts+4
        ^piv_pts:=y                             /*==== Stock y ====*/
        piv_pts:=piv_pts+4
        ^piv_pts:=z                             /*==== Stock z ====*/
        piv_pts:=piv_pts+4
    ENDFOR

    nbrsfcs:=((numline)-2)-nbrspts                   -> nbrs faces OF OBJECT
    myobj.nbrsfcs:=nbrsfcs                           -> update data in OBJECT
    base.totalfcs:=base.totalfcs+myobj.nbrsfcs       /*==== Update database   ====*/
    myobj.datafcs:=New(myobj.nbrsfcs*12)             /*==== Allocate mem FOR fcs  ====*/
    piv_pts:=myobj.datafcs                           /*==== Pointer TO objdatafcs ====*/

    FOR i:=0 TO nbrsfcs-1
        v1:=getVertice(VERTICE_1,l[i+nbrspts+2])     -> read 1 vertice
        v2:=getVertice(VERTICE_2,l[i+nbrspts+2])     -> read 2 vertice
        v3:=getVertice(VERTICE_3,l[i+nbrspts+2])     -> read 3 vertice
        IF (v1=-1) OR (v2=-1) OR (v3=-1) THEN Raise(ERR3D_3VERT4GEO)  -> ONLY 3 VERTICE FOR ONE FACE !!! (MORE VERTICES NOT SUPPORTTED)
        ^piv_pts:=v1                                  /*==== Stock 1 vertice ====*/
        piv_pts:=piv_pts+4
        ^piv_pts:=v2                                  /*==== Stock 2 vertice ====*/
        piv_pts:=piv_pts+4
        ^piv_pts:=v3                                  /*==== Stock 3 vertice ====*/
        piv_pts:=piv_pts+4
    ENDFOR

    myobj.objminx:=1000000.0
    myobj.objmaxx:=-1000000.0
    myobj.objminy:=1000000.0
    myobj.objmaxy:=-1000000.0
    myobj.objminz:=1000000.0
    myobj.objmaxz:=-1000000.0
    addNode(base.objlist,obj_name,myobj)
    buildMinMax(base,myobj,TRUE)

    freefile(textmem)

    Raise(ret)

EXCEPT
    IF exception<>ERR3D_NONE
        IF exception="MEM"
            IF textmem<>NIL THEN freefile(textmem)
        ENDIF
        IF exception="IN"
            IF textmem<>NIL THEN freefile(textmem)
        ENDIF
        IF exception=ERR3D_MEM
            IF myobj.datafcs<>NIL THEN Dispose(myobj.datafcs)
            IF myobj.datapts<>NIL THEN Dispose(myobj.datapts)
            IF myobj<>NIL THEN Dispose(myobj)
            RETURN ERR3D_MEM
        ENDIF
    ENDIF
    RETURN exception
ENDPROC
-><

-><

->> Fonctions d'écriture des fichiers 3D

->> saveGeoFile(base:PTR TO base3d,dir)
PROC saveGeoFile(base:PTR TO base3d,dir)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,dossier amigados (STRING)
Retour   : TRUE si ok,sinon FALSE
Action   : Sauve la base 3d au format GEO.
================================================*/
    DEF b_pts,b_faces
    DEF n_pts,n_faces
    DEF mobj:PTR TO object3d
    DEF p_pts,p_faces
    DEF s_handle,fichier_out[256]:STRING,v:PTR TO vertice
    DEF mylist:PTR TO lh,mynode:PTR TO ln,saveit=FALSE
    DEF oldout,ret=ERR3D_NONE
    DEF l
    DEF info:fileinfoblock
    AddPart(dir,'',256)
    IF l:=Lock(dir,-2)
        IF Examine(l,info)
            IF info.direntrytype>0
                UnLock(l)
            ELSE
                UnLock(l)
                RETURN ERR3D_NODIR
            ENDIF
        ELSE
            RETURN ERR3D_NODIR
        ENDIF
    ELSE
        RETURN ERR3D_NODIR
    ENDIF
    mylist:=base.objlist
    mynode:=mylist.head
    WHILE mynode
        IF mynode.succ<>0
            mobj:=mynode
            IF (base.savewhat=SAVEOBJ_ALL)
                saveit:=TRUE
            ELSEIF ((mobj.selected=TRUE) AND (base.savewhat=SAVEOBJ_SEL))
                saveit:=TRUE
            ELSEIF ((mobj.selected=FALSE) AND (base.savewhat=SAVEOBJ_DES))
                saveit:=TRUE
            ENDIF
            IF saveit=TRUE
                StringF(fichier_out,'\s\s.geo',dir,mynode.name)
                IF s_handle:=Open(fichier_out,1006)
                    oldout:=stdout
                    stdout:=s_handle
                    WriteF('3DG1\n')
                    n_pts:=mobj.nbrspts
                    WriteF('\d\n',n_pts)
                    p_pts:=mobj.datapts
                    FOR b_pts:=0 TO n_pts-1
                        v:=p_pts
                        writeFGeoVertice(v)
                        p_pts:=p_pts+12
                    ENDFOR
                    n_faces:=mobj.nbrsfcs
                    p_faces:=mobj.datafcs
                    FOR b_faces:=0 TO n_faces-1
                        WriteF('3 \d \d \d 141\n',Long(p_faces),Long(p_faces+4),Long(p_faces+8))
                        p_faces:=p_faces+12
                    ENDFOR
                    ret:=TRUE
                    stdout:=oldout
                    IF s_handle THEN Close(s_handle)
                ELSE
                    RETURN ERR3D_OPEN
                ENDIF
                saveit:=FALSE
            ENDIF
        ENDIF
        mynode:=mynode.succ
    ENDWHILE
ENDPROC ret
-><
->> saveDxfFile(base:PTR TO base3d,dir)
PROC saveDxfFile(base:PTR TO base3d,dir)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,dossier amigados (STRING)
Retour   : TRUE si ok,sinon FALSE
Action   : Sauve la base au  format DXF.
================================================*/
    DEF b_faces
    DEF n_faces
    DEF mobj:PTR TO object3d
    DEF p_pts,p_faces
    DEF s_handle=NIL,fichier_out[256]:STRING,oldout,ret=ERR3D_NONE
    DEF mylist:PTR TO lh,mynode:PTR TO ln,saveit=FALSE
    DEF l
    DEF info:fileinfoblock
    AddPart(dir,'',256)
    IF l:=Lock(dir,-2)
        IF Examine(l,info)
            IF info.direntrytype>0
                UnLock(l)
            ELSE
                UnLock(l)
                RETURN ERR3D_NODIR
            ENDIF
        ELSE
            RETURN ERR3D_NODIR
        ENDIF
    ELSE
        RETURN ERR3D_NODIR
    ENDIF
    mylist:=base.objlist
    mynode:=mylist.head
    WHILE mynode
        IF mynode.succ<>0
            mobj:=mynode
            IF (base.savewhat=SAVEOBJ_ALL)
                saveit:=TRUE
            ELSEIF ((mobj.selected=TRUE) AND (base.savewhat=SAVEOBJ_SEL))
                saveit:=TRUE
            ELSEIF ((mobj.selected=FALSE) AND (base.savewhat=SAVEOBJ_DES))
                saveit:=TRUE
            ENDIF
            IF saveit=TRUE
                StringF(fichier_out,'\s\s.dxf',dir,mynode.name)
                IF s_handle:=Open(fichier_out,1006)
                    oldout:=stdout
                    stdout:=s_handle
                    WriteF('0\nSECTION\n2\nENTITIES\n0\n')
                    p_pts:=mobj.datapts
                    n_faces:=mobj.nbrsfcs
                    p_faces:=mobj.datafcs
                    FOR b_faces:=0 TO n_faces-1
                        WriteF('3DFACE\n')
                        WriteF('8\n')
                        WriteF('\s\n',mynode.name)
                        writeFDxfVertice(10,Long(p_pts+(Long(p_faces)*12)))
                        writeFDxfVertice(20,Long(p_pts+(Long(p_faces)*12)+4))
                        writeFDxfVertice(30,Long(p_pts+(Long(p_faces)*12)+8))
                        /**/
                        writeFDxfVertice(11,Long(p_pts+(Long(p_faces+4)*12)))
                        writeFDxfVertice(21,Long(p_pts+(Long(p_faces+4)*12)+4))
                        writeFDxfVertice(31,Long(p_pts+(Long(p_faces+4)*12)+8))
                        /**/
                        writeFDxfVertice(12,Long(p_pts+(Long(p_faces+8)*12)))
                        writeFDxfVertice(22,Long(p_pts+(Long(p_faces+8)*12)+4))
                        writeFDxfVertice(32,Long(p_pts+(Long(p_faces+8)*12)+8))
                        /**/
                        writeFDxfVertice(13,Long(p_pts+(Long(p_faces+8)*12)))
                        writeFDxfVertice(23,Long(p_pts+(Long(p_faces+8)*12)+4))
                        writeFDxfVertice(33,Long(p_pts+(Long(p_faces+8)*12)+8))
                        WriteF('0\n')
                        p_faces:=p_faces+12
                    ENDFOR
                    WriteF('ENDSEC\n0\nEOF\n')
                    ret:=TRUE
                    stdout:=oldout
                    IF s_handle THEN Close(s_handle)
                ELSE
                    RETURN ERR3D_OPEN
                ENDIF
            ENDIF
            saveit:=FALSE
        ENDIF
        mynode:=mynode.succ
    ENDWHILE
ENDPROC ret
-><
->> saveRayFile(base:PTR TO base3d,dir)
PROC saveRayFile(base:PTR TO base3d,dir)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,dossier Amigados (STRING)
Retour   : TRUE si ok,sinon FALSE.
Action   : Sauve la base3d au format RAY.
================================================*/
    DEF b_faces
    DEF n_faces
    DEF mobj:PTR TO object3d
    DEF p_pts,p_faces
    DEF s_handle,fichier_out[256]:STRING
    DEF mylist:PTR TO lh,mynode:PTR TO ln,saveit=FALSE,oldout,ret=ERR3D_NONE
    DEF l
    DEF info:fileinfoblock
    AddPart(dir,'',256)
    IF l:=Lock(dir,-2)
        IF Examine(l,info)
            IF info.direntrytype>0
                UnLock(l)
            ELSE
                UnLock(l)
                RETURN ERR3D_NODIR
            ENDIF
        ELSE
            RETURN ERR3D_NODIR
        ENDIF
    ELSE
        RETURN ERR3D_NODIR
    ENDIF
    mylist:=base.objlist
    mynode:=mylist.head
    WHILE mynode
        IF mynode.succ<>0
            mobj:=mynode
            IF (base.savewhat=SAVEOBJ_ALL)
                saveit:=TRUE
            ELSEIF ((mobj.selected=TRUE) AND (base.savewhat=SAVEOBJ_SEL))
                saveit:=TRUE
            ELSEIF ((mobj.selected=FALSE) AND (base.savewhat=SAVEOBJ_DES))
                saveit:=TRUE
            ENDIF
            IF saveit=TRUE
                StringF(fichier_out,'\s\s.ray',dir,mynode.name)
                IF s_handle:=Open(fichier_out,1006)
                    oldout:=stdout
                    stdout:=s_handle
                    p_pts:=mobj.datapts
                    n_faces:=mobj.nbrsfcs
                    p_faces:=mobj.datafcs
                    FOR b_faces:=0 TO n_faces-1
                        WriteF('triangle\n')
                        writeFFloat(Long(p_pts+(Long(p_faces)*12)))
                        WriteF(' ')
                        writeFFloat(Long(p_pts+(Long(p_faces)*12)+4))
                        WriteF(' ')
                        writeFFloat(Long(p_pts+(Long(p_faces)*12)+8))
                        WriteF('\n')
                        writeFFloat(Long(p_pts+(Long(p_faces+4)*12)))
                        WriteF(' ')
                        writeFFloat(Long(p_pts+(Long(p_faces+4)*12)+4))
                        WriteF(' ')
                        writeFFloat(Long(p_pts+(Long(p_faces+4)*12)+8))
                        WriteF('\n')
                        writeFFloat(Long(p_pts+(Long(p_faces+8)*12)))
                        WriteF(' ')
                        writeFFloat(Long(p_pts+(Long(p_faces+8)*12)+4))
                        WriteF(' ')
                        writeFFloat(Long(p_pts+(Long(p_faces+8)*12)+8))
                        WriteF('\n')
                        /**********************************/
                        p_faces:=p_faces+12
                    ENDFOR
                    ret:=TRUE
                    stdout:=oldout
                    IF s_handle THEN Close(s_handle)
                ELSE
                    RETURN ERR3D_OPEN
                ENDIF
            ENDIF
        ENDIF
        mynode:=mynode.succ
    ENDWHILE
ENDPROC ret
-><
->> savePovFile(base:PTR TO base3d,dir)
PROC savePovFile(base:PTR TO base3d,dir)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,dossier AmigaDos (STRING)
Retour   : TRUE si ok,sinon FALSE.
Action   : Sauve la base3d au format POV.
================================================*/
    DEF b_faces
    DEF n_faces
    DEF mobj:PTR TO object3d
    DEF p_pts,p_faces
    DEF s_handle,fichier_out[256]:STRING
    DEF mylist:PTR TO lh,mynode:PTR TO ln,saveit=FALSE,oldout,ret=ERR3D_NONE
    DEF l
    DEF info:fileinfoblock
    AddPart(dir,'',256)
    IF l:=Lock(dir,-2)
        IF Examine(l,info)
            IF info.direntrytype>0
                UnLock(l)
            ELSE
                UnLock(l)
                RETURN ERR3D_NODIR
            ENDIF
        ELSE
            RETURN ERR3D_NODIR
        ENDIF
    ELSE
        RETURN ERR3D_NODIR
    ENDIF
    mylist:=base.objlist
    mynode:=mylist.head
    WHILE mynode
        IF mynode.succ<>0
            mobj:=mynode
            IF (base.savewhat=SAVEOBJ_ALL)
                saveit:=TRUE
            ELSEIF ((mobj.selected=TRUE) AND (base.savewhat=SAVEOBJ_SEL))
                saveit:=TRUE
            ELSEIF ((mobj.selected=FALSE) AND (base.savewhat=SAVEOBJ_DES))
                saveit:=TRUE
            ENDIF
            IF saveit=TRUE
                StringF(fichier_out,'\s\s.pov',dir,mynode.name)
                IF s_handle:=Open(fichier_out,1006)
                    oldout:=stdout
                    stdout:=s_handle
                    p_pts:=mobj.datapts
                    n_faces:=mobj.nbrsfcs
                    p_faces:=mobj.datafcs
                    WriteF('/* Object :\s */\n',mobj.obj_node.name)
                    WriteF('#declare \s =\n',mobj.obj_node.name)
                    WriteF('object {\n')
                    WriteF('    union {\n')
                    FOR b_faces:=0 TO n_faces-1
                        WriteF('        triangle {<')
                        writeFFloat(Long(p_pts+(Long(p_faces)*12)))
                        IF base.saveformat=SAVE_POV2 THEN WriteF(',') ELSE WriteF(' ')
                        writeFFloat(Long(p_pts+(Long(p_faces)*12)+4))
                        IF base.saveformat=SAVE_POV2 THEN WriteF(',') ELSE WriteF(' ')
                        writeFFloat(Long(p_pts+(Long(p_faces)*12)+8))
                        IF base.saveformat=SAVE_POV2 THEN WriteF('>,<') ELSE WriteF('> <')
                        writeFFloat(Long(p_pts+(Long(p_faces+4)*12)))
                        IF base.saveformat=SAVE_POV2 THEN WriteF(',') ELSE WriteF(' ')
                        writeFFloat(Long(p_pts+(Long(p_faces+4)*12)+4))
                        IF base.saveformat=SAVE_POV2 THEN WriteF(',') ELSE WriteF(' ')
                        writeFFloat(Long(p_pts+(Long(p_faces+4)*12)+8))
                        IF base.saveformat=SAVE_POV2 THEN WriteF('>,<') ELSE WriteF('> <')
                        writeFFloat(Long(p_pts+(Long(p_faces+8)*12)))
                        IF base.saveformat=SAVE_POV2 THEN WriteF(',') ELSE WriteF(' ')
                        writeFFloat(Long(p_pts+(Long(p_faces+8)*12)+4))
                        IF base.saveformat=SAVE_POV2 THEN WriteF(',') ELSE WriteF(' ')
                        writeFFloat(Long(p_pts+(Long(p_faces+8)*12)+8))
                        WriteF('>}\n')
                        /**********************************/
                        p_faces:=p_faces+12
                    ENDFOR
                    WriteF('    }\n')
                    WriteF('    texture { Text_\s }\n',mobj.obj_node.name)
                    IF base.saveformat=SAVE_POV2
                        WriteF('    clipped_by { box {<')
                        writeFFloat(mobj.objminx)
                        WriteF(',')
                        writeFFloat(mobj.objminy)
                        WriteF(',')
                        writeFFloat(mobj.objminz)
                        WriteF('>,<')
                        writeFFloat(mobj.objmaxx)
                        WriteF(',')
                        writeFFloat(mobj.objmaxy)
                        WriteF(',')
                        writeFFloat(mobj.objmaxz)
                        WriteF('>}}\n')
                        WriteF('    bounded_by{clipped_by}\n')
                    ENDIF
                    WriteF('}\n')
                    ret:=TRUE
                    stdout:=oldout
                    IF s_handle THEN Close(s_handle)
                ELSE
                    RETURN ERR3D_OPEN
                ENDIF
            ENDIF
        ENDIF
        mynode:=mynode.succ
    ENDWHILE
ENDPROC ret
-><
->> saveWaveFrontFile(base:PTR TO base3d,dir)
PROC saveWaveFrontFile(base:PTR TO base3d,dir)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,dossier amigados (STRING)
Retour   : TRUE si ok,sinon FALSE
Action   : Sauve la base 3d au format WaveFront.
================================================*/
    DEF b_pts,b_faces
    DEF n_pts,n_faces
    DEF mobj:PTR TO object3d
    DEF p_pts,p_faces
    DEF s_handle,fichier_out[256]:STRING,v:PTR TO vertice
    DEF mylist:PTR TO lh,mynode:PTR TO ln,saveit=FALSE
    DEF oldout,ret=ERR3D_NONE
    DEF l
    DEF info:fileinfoblock
    AddPart(dir,'',256)
    IF l:=Lock(dir,-2)
        IF Examine(l,info)
            IF info.direntrytype>0
                UnLock(l)
            ELSE
                UnLock(l)
                RETURN ERR3D_NODIR
            ENDIF
        ELSE
            RETURN ERR3D_NODIR
        ENDIF
    ELSE
        RETURN ERR3D_NODIR
    ENDIF
    mylist:=base.objlist
    mynode:=mylist.head
    WHILE mynode
        IF mynode.succ<>0
            mobj:=mynode
            IF (base.savewhat=SAVEOBJ_ALL)
                saveit:=TRUE
            ELSEIF ((mobj.selected=TRUE) AND (base.savewhat=SAVEOBJ_SEL))
                saveit:=TRUE
            ELSEIF ((mobj.selected=FALSE) AND (base.savewhat=SAVEOBJ_DES))
                saveit:=TRUE
            ENDIF
            IF saveit=TRUE
                StringF(fichier_out,'\s\s.obj',dir,mynode.name)
                IF s_handle:=Open(fichier_out,1006)
                    oldout:=stdout
                    stdout:=s_handle
                    WriteF('# Fichier Sauvegardé avec la ddd.library © NasGûl\n')
                    n_pts:=mobj.nbrspts
                    p_pts:=mobj.datapts
                    FOR b_pts:=0 TO n_pts-1
                        v:=p_pts
                        WriteF('v ')
                        writeFGeoVertice(v)
                        p_pts:=p_pts+12
                    ENDFOR
                    n_faces:=mobj.nbrsfcs
                    p_faces:=mobj.datafcs
                    FOR b_faces:=0 TO n_faces-1
                        WriteF('f \d/\d/\d \d/\d/\d \d/\d/\d\n',Long(p_faces)+1,Long(p_faces)+1,Long(p_faces)+1,Long(p_faces+4)+1,Long(p_faces+4)+1,Long(p_faces+4)+1,Long(p_faces+8)+1,Long(p_faces+8)+1,Long(p_faces+8)+1)
                        p_faces:=p_faces+12
                    ENDFOR
                    ret:=TRUE
                    stdout:=oldout
                    IF s_handle THEN Close(s_handle)
                ELSE
                    RETURN ERR3D_OPEN
                ENDIF
                saveit:=FALSE
            ENDIF
        ENDIF
        mynode:=mynode.succ
    ENDWHILE
ENDPROC
-><
->> saveBinFile(base:PTR TO base3d,dir,factor)
PROC saveBinFile(base:PTR TO base3d,dir,factor)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,dossier AmigaDos,facteur 3d (flottant).
Retour   : TRUE si ok,sinon FALSE.
Action   : Sauve la base 3D dans un  format exploitable par la vertor.library
================================================*/
    DEF b_pts,b_faces
    DEF n_pts,n_faces
    DEF mobj:PTR TO object3d
    DEF p_pts,p_faces
    DEF s_handle,fichier_out[256]:STRING
    DEF mylist:PTR TO lh,mynode:PTR TO ln,saveit=FALSE
    DEF fx,fy,fz,ret=ERR3D_NONE
    DEF l
    AddPart(dir,'',256)
    IF l:=Lock(dir,-2)
        UnLock(l)
    ELSE
        RETURN ERR3D_NODIR
    ENDIF
    mylist:=base.objlist
    mynode:=mylist.head
    WHILE mynode
        IF mynode.succ<>0
            mobj:=mynode
            IF (base.savewhat=SAVEOBJ_ALL)
                saveit:=TRUE
            ELSEIF ((mobj.selected=TRUE) AND (base.savewhat=SAVEOBJ_SEL))
                saveit:=TRUE
            ELSEIF ((mobj.selected=FALSE) AND (base.savewhat=SAVEOBJ_DES))
                saveit:=TRUE
            ENDIF
            IF saveit=TRUE
                StringF(fichier_out,'\s\s_pts.bin',dir,mynode.name)
                IF s_handle:=Open(fichier_out,1006)
                    n_pts:=mobj.nbrspts
                    Write(s_handle,[n_pts]:INT,2)
                    StringF(fichier_out,'\d\n',n_pts)
                    p_pts:=mobj.datapts
                    FOR b_pts:=0 TO n_pts-1
                        fx:=IeeeSPFix(IeeeSPMul(Long(p_pts),factor))
                        fy:=IeeeSPFix(IeeeSPMul(Long(p_pts+4),factor))
                        fz:=IeeeSPFix(IeeeSPMul(Long(p_pts+8),factor))
                        Write(s_handle,[fx,fy,fz,0]:INT,8)
                        p_pts:=p_pts+12
                    ENDFOR
                    ret:=TRUE
                    IF s_handle THEN Close(s_handle)
                ELSE
                    RETURN ERR3D_OPEN
                ENDIF
                StringF(fichier_out,'\s\s_fcs.bin',dir,mynode.name)
                IF s_handle:=Open(fichier_out,1006)
                    n_faces:=mobj.nbrsfcs
                    p_faces:=mobj.datafcs
                    Write(s_handle,[n_faces]:INT,2)
                    FOR b_faces:=0 TO n_faces-1
                        Write(s_handle,[3,5,Long(p_faces)*4,Long(p_faces+4)*4,Long(p_faces+8)*4,Long(p_faces)*4,0,0,0,0,0]:INT,22)
                        p_faces:=p_faces+12
                    ENDFOR
                    ret:=TRUE
                    IF s_handle THEN Close(s_handle)
                ELSE
                    RETURN ERR3D_OPEN
                ENDIF
                saveit:=FALSE
            ENDIF
        ENDIF
        mynode:=mynode.succ
    ENDWHILE
ENDPROC ret
-><
->> saveTtdddFile(base:PTR TO base3d,dir)
PROC saveTtdddFile(base:PTR TO base3d,dir)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,dossier amigados (STRING)
Retour   : TRUE si ok,sinon FALSE
Action   : Sauve la base 3d au format TDDD.
================================================*/
    DEF b_pts,b_faces
    DEF n_pts,n_faces
    DEF mobj:PTR TO object3d
    DEF p_pts,p_faces
    DEF s_handle,fichier_out[256]:STRING,v:PTR TO vertice
    DEF mylist:PTR TO lh,mynode:PTR TO ln,saveit=FALSE
    DEF oldout,ret=ERR3D_NONE
    DEF l
    DEF info: fileinfoblock
    AddPart(dir,'',256)
    IF l:=Lock(dir,-2)
        IF Examine(l,info)
            IF info.direntrytype>0
                UnLock(l)
            ELSE
                UnLock(l)
                RETURN ERR3D_NODIR
            ENDIF
        ELSE
            RETURN ERR3D_NODIR
        ENDIF
    ELSE
        RETURN ERR3D_NODIR
    ENDIF
    mylist:=base.objlist
    mynode:=mylist.head
    WHILE mynode
        IF mynode.succ<>0
            mobj:=mynode
            IF (base.savewhat=SAVEOBJ_ALL)
                saveit:=TRUE
            ELSEIF ((mobj.selected=TRUE) AND (base.savewhat=SAVEOBJ_SEL))
                saveit:=TRUE
            ELSEIF ((mobj.selected=FALSE) AND (base.savewhat=SAVEOBJ_DES))
                saveit:=TRUE
            ENDIF
            IF saveit=TRUE
                StringF(fichier_out,'\s\s.ttddd',dir,mynode.name)
                IF s_handle:=Open(fichier_out,1006)
                    oldout:=stdout
                    stdout:=s_handle
                    WriteF('% TTDDD version OF \s\n',mynode.name)
                    WriteF('% Sauvergardé par la  ddd.library © NasGûl (d''après le code de Glenn M. Lewis)\n\n')
                    WriteF('OBJ Begin "Hierarchy 1"\n')
                    WriteF('    DESC Begin "OBJECT 1 at level 1 OF hierarchy 1"\n')
                    WriteF('        NAME "\s"\n\n',mynode.name)
                    WriteF('        POSI X=');writeFFloat(mobj.objcx);WriteF(' Y=');writeFFloat(mobj.objcy);WriteF(' Z=');writeFFloat(mobj.objcz);WriteF('\n\n')
                    WriteF('        AXIS XAxis X=1.000 Y=0.000 Z=0.000\n')
                    WriteF('        AXIS YAxis X=0.000 Y=1.000 Z=0.000\n')
                    WriteF('        AXIS ZAxis X=0.000 Y=0.000 Z=1.000\n\n')
                    WriteF('        SIZE X=50.000 Y=32.000 Z=50.000\n\n')
                    n_pts:=mobj.nbrspts
                    WriteF('        PNTS PCount \d\n',n_pts)
                    p_pts:=mobj.datapts
                    FOR b_pts:=0 TO n_pts-1
                        v:=p_pts
                        WriteF('        PNTS Point[\d] X=',b_pts);writeFFloat(v.x);WriteF(' Y=');writeFFloat(v.y);WriteF(' Z=');writeFFloat(v.z);WriteF('\n')
                        p_pts:=p_pts+12
                    ENDFOR
                    WriteF('\n')
                    n_faces:=mobj.nbrsfcs
                    p_faces:=mobj.datafcs
                    WriteF('        EDGE Ecount \d\n',n_faces*3)
                    FOR b_faces:=0 TO n_faces-1
                        WriteF('        EDGE Edge[\d] \d \d\n',b_faces*3,Long(p_faces),Long(p_faces+4))
                        WriteF('        EDGE Edge[\d] \d \d\n',(b_faces*3)+1,Long(p_faces+4),Long(p_faces+8))
                        WriteF('        EDGE Edge[\d] \d \d\n',(b_faces*3)+2,Long(p_faces+8),Long(p_faces))
                        p_faces:=p_faces+12
                    ENDFOR                    
                    WriteF('\n')
                    n_faces:=mobj.nbrsfcs
                    p_faces:=mobj.datafcs
                    WriteF('        FACE TCount \d\n',n_faces)
                    FOR b_faces:=0 TO n_faces-1
->                        WriteF('        FACE Connect[\d] \d \d \d\n',b_faces,Long(p_faces),Long(p_faces+4),Long(p_faces+8))
                        WriteF('        FACE Connect[\d] \d \d \d\n',b_faces,b_faces*3,(b_faces*3)+1,(b_faces*3)+2)
                        p_faces:=p_faces+12
                    ENDFOR
                    WriteF('\n\n')
                    WriteF('        COLR R=255 G=255 B=255\n\n')
                    WriteF('        REFL R=0 G=0 B=0\n\n')
                    WriteF('        TRAN R=0 G=0 B=0\n\n')
                    
                    WriteF('        CLST Count \d\n',n_faces)
                    n_faces:=mobj.nbrsfcs
                    p_faces:=mobj.datafcs
                    FOR b_faces:=0 TO n_faces-1
                        WriteF('        CLST Color[\d] R=255 G=255 B=255\n',b_faces)
->                        p_faces:=p_faces+12
                    ENDFOR
                    WriteF('\n')

                    WriteF('        RLST Count \d\n',n_faces)
                    n_faces:=mobj.nbrsfcs
                    p_faces:=mobj.datafcs
                    FOR b_faces:=0 TO n_faces-1
                        WriteF('        RLST Color[\d] R=0 G=0 B=0\n',b_faces)
->                        p_faces:=p_faces+12
                    ENDFOR
                    WriteF('\n')

                    WriteF('        TLST Count \d\n',n_faces)
                    n_faces:=mobj.nbrsfcs
                    p_faces:=mobj.datafcs
                    FOR b_faces:=0 TO n_faces-1
                        WriteF('        TLST Color[\d] R=0 G=0 B=0\n',b_faces)
->                        p_faces:=p_faces+12
                    ENDFOR
                    WriteF('\n')
                    WriteF('    END DESC "OBJECT 1 at level 1 OF hierarchy 1"\n')
                    WriteF('TOBJ         "OBJECT 1 at level 1 OF hierarchy 1"\n')
                    WriteF('END OBJ  "Hierarchy 1"\n')
                    ret:=TRUE
                    stdout:=oldout
                    IF s_handle THEN Close(s_handle)
                ELSE
                    RETURN ERR3D_OPEN
                ENDIF
                saveit:=FALSE
            ENDIF
        ENDIF
        mynode:=mynode.succ
    ENDWHILE
ENDPROC ret
-><
->> saveTdddFile(base:PTR TO base3d,dir)
PROC saveTdddFile(base:PTR TO base3d,dir)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,dossier amigados (STRING)
Retour   : TRUE si ok,sinon FALSE
Action   : Sauve la base 3d au format TDDD (Imagine).
================================================*/
    DEF b_pts,b_faces
    DEF n_pts,n_faces
    DEF mobj:PTR TO object3d
    DEF p_pts,p_faces
    DEF s_handle,fichier_out[256]:STRING,v:PTR TO vertice
    DEF mylist:PTR TO lh,mynode:PTR TO ln,saveit=FALSE
    DEF ret=ERR3D_NONE
    DEF l
    DEF info:fileinfoblock
    AddPart(dir,'',256)
    IF l:=Lock(dir,-2)
        IF Examine(l,info)
            IF info.direntrytype>0
                UnLock(l)
            ELSE
                UnLock(l)
                RETURN ERR3D_NODIR
            ENDIF
        ELSE
            RETURN ERR3D_NODIR
        ENDIF
    ELSE
        RETURN ERR3D_NODIR
    ENDIF
    mylist:=base.objlist
    mynode:=mylist.head
    WHILE mynode
        IF mynode.succ<>0
            mobj:=mynode
            IF (base.savewhat=SAVEOBJ_ALL)
                saveit:=TRUE
            ELSEIF ((mobj.selected=TRUE) AND (base.savewhat=SAVEOBJ_SEL))
                saveit:=TRUE
            ELSEIF ((mobj.selected=FALSE) AND (base.savewhat=SAVEOBJ_DES))
                saveit:=TRUE
            ENDIF
            IF saveit=TRUE
                StringF(fichier_out,'\s\s.tddd',dir,mynode.name)
                IF s_handle:=Open(fichier_out,1006)
                    Write(s_handle,["FORM"],4)
                    Write(s_handle,[0],4)
                    Write(s_handle,["TDDD"],4)
                    Write(s_handle,["OBJ "],4)
                    Write(s_handle,[0],4)
                    Write(s_handle,["DESC"],4)
                    Write(s_handle,[0],4)
                    Write(s_handle,["NAME"],4)
                    Write(s_handle,[$12],4)
                    Write(s_handle,mynode.name,EstrLen(mynode.name))
                    FOR l:=0 TO 17-EstrLen(mynode.name)
                        Out(s_handle,0)
                    ENDFOR
                    Write(s_handle,["SHAP",$4,$00020000]:LONG,12)
                    Write(s_handle,["POSI"],4)
                    Write(s_handle,[$C],4)
                    l:=Mul(ffix(mobj.objcx),65536)
                    Write(s_handle,[l],4)
                    l:=Mul(ffix(mobj.objcy),65536)
                    Write(s_handle,[l],4)
                    l:=Mul(ffix(mobj.objcz),65536)
                    Write(s_handle,[l],4)
                    Write(s_handle,["AXIS"],4)
                    Write(s_handle,[$24],4)
                    Write(s_handle,[65536,$00000000,$00000000]:LONG,12)
                    Write(s_handle,[$00000000,65536,$00000000]:LONG,12)
                    Write(s_handle,[$00000000,$00000000,65536]:LONG,12)
                    Write(s_handle,["SIZE",12],8)
                    Write(s_handle,[Mul(50,65536),Mul(32,65536),Mul(50,65536)]:LONG,12)
                    Write(s_handle,["PNTS"],4)
                    /*
                    IF Odd((mobj.nbrspts*12)+2)
                        Write(s_handle,[(mobj.nbrspts*12)+3],4)
                    ELSE
                    */
                    Write(s_handle,[(mobj.nbrspts*12)+2],4)
->                    ENDIF
                    Write(s_handle,[mobj.nbrspts]:INT,2)
                    n_pts:=mobj.nbrspts
                    p_pts:=mobj.datapts
                    FOR b_pts:=0 TO n_pts-1
                        v:=p_pts
                        l:=ffix(fmul(v.x,65536.0))
                        Write(s_handle,[l],4)
                        l:=ffix(fmul(v.y,65536.0))
                        Write(s_handle,[l],4)
                        l:=ffix(fmul(v.z,65536.0))
                        Write(s_handle,[l],4)
                        p_pts:=p_pts+12
                    ENDFOR
                    IF Odd((mobj.nbrspts*12)+2) THEN Out(s_handle,0)

                    n_faces:=mobj.nbrsfcs
                    p_faces:=mobj.datafcs
                    Write(s_handle,["EDGE"],4)
->                    IF Odd((n_faces*3)*4+2)
->                        Write(s_handle,[(n_faces*3)*4+3],4)
->                    ELSE
                        Write(s_handle,[(n_faces*3)*4+2],4)
->                    ENDIF
                    Write(s_handle,[n_faces*3]:INT,2)
                    FOR b_faces:=0 TO n_faces-1
                        Write(s_handle,[Long(p_faces),Long(p_faces+4)]:INT,4)
                        Write(s_handle,[Long(p_faces+4),Long(p_faces+8)]:INT,4)
                        Write(s_handle,[Long(p_faces+8),Long(p_faces)]:INT,4)
                        p_faces:=p_faces+12
                    ENDFOR
                    IF Odd((n_faces*3)*4+2) THEN Out(s_handle,0)

                    n_faces:=mobj.nbrsfcs
                    p_faces:=mobj.datafcs
                    Write(s_handle,["FACE"],4)
->                    IF Odd((n_faces*6)+2)
->                        Write(s_handle,[(n_faces*6)+3],4)
->                    ELSE
                        Write(s_handle,[(n_faces*6)+2],4)
->                    ENDIF

                    Write(s_handle,[n_faces]:INT,2)
                    FOR b_faces:=0 TO n_faces-1
                        Write(s_handle,[b_faces*3,(b_faces*3)+1,(b_faces*3)+2]:INT,6)
                        p_faces:=p_faces+12
                    ENDFOR
                    IF Odd((n_faces*6)+2) THEN Out(s_handle,0)

                    Write(s_handle,["COLR",4]:LONG,8)
                    Write(s_handle,[0,$FF,$FF,$FF]:CHAR,4)
                    Write(s_handle,["REFL",4]:LONG,8)
                    Write(s_handle,[0,0,0,0]:CHAR,4)
                    Write(s_handle,["TRAN",4]:LONG,8)
                    Write(s_handle,[0,0,0,0]:CHAR,4)
                    n_faces:=mobj.nbrsfcs
                    p_faces:=mobj.datafcs
                    Write(s_handle,["CLST"],4)

                    Write(s_handle,[(n_faces*3)+2],4)
                    Write(s_handle,[n_faces]:INT,2)
                    FOR b_faces:=0 TO n_faces-1
                        Write(s_handle,[$FF,$FF,$FF]:CHAR,3)
                    ENDFOR
                    IF Odd((n_faces*3)+2) THEN Out(s_handle,0)

                    Write(s_handle,["RLST"],4)
                    Write(s_handle,[(n_faces*3)+2],4)
                    Write(s_handle,[n_faces]:INT,2)
                    FOR b_faces:=0 TO n_faces-1
                        Write(s_handle,[$0,$0,$0]:CHAR,3)
                    ENDFOR
                    IF Odd((n_faces*3)+2) THEN Out(s_handle,0)

                    Write(s_handle,["TLST"],4)
                    Write(s_handle,[(n_faces*3)+2],4)
                    Write(s_handle,[n_faces]:INT,2)
                    FOR b_faces:=0 TO n_faces-1
                        Write(s_handle,[$0,$0,$0]:CHAR,3)
                    ENDFOR
                    IF Odd((n_faces*3)+2) THEN Out(s_handle,0)
                    
                    Write(s_handle,["TOBJ",0],8)
                    IF s_handle THEN Close(s_handle)
                    l:=FileLength(fichier_out)
                    IF s_handle:=Open(fichier_out,1005)
                        Seek(s_handle,4,-1)
                        Write(s_handle,[l-8],4)
                        Seek(s_handle,16,-1)
                        Write(s_handle,[l-20],4)
                        Seek(s_handle,24,-1)
                        Write(s_handle,[l-36],4)
                        Close(s_handle)
                        ret:=TRUE
                    ENDIF
                ELSE
                    RETURN ERR3D_OPEN
                ENDIF
                saveit:=FALSE
            ENDIF
        ENDIF
        mynode:=mynode.succ
    ENDWHILE
ENDPROC ret
-><
->> save3dsAscFile(base:PTR TO base3d,dir)
PROC save3dsAscFile(base:PTR TO base3d,dir)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,dossier amigados (STRING)
Retour   : TRUE si ok,sinon FALSE
Action   : Sauve la base 3d au format 3DStudio Ascii.
================================================*/
    DEF b_pts,b_faces
    DEF n_pts,n_faces
    DEF mobj:PTR TO object3d
    DEF p_pts,p_faces
    DEF s_handle,fichier_out[256]:STRING
    DEF v:PTR TO vertice
    DEF mylist:PTR TO lh,mynode:PTR TO ln,saveit=FALSE
    DEF oldout,ret=ERR3D_NONE
    DEF l
    DEF info: fileinfoblock
    AddPart(dir,'',256)
    IF l:=Lock(dir,-2)
        IF Examine(l,info)
            IF info.direntrytype>0
                UnLock(l)
            ELSE
                UnLock(l)
                RETURN ERR3D_NODIR
            ENDIF
        ELSE
            RETURN ERR3D_NODIR
        ENDIF
    ELSE
        RETURN ERR3D_NODIR
    ENDIF
    mylist:=base.objlist
    mynode:=mylist.head
    WHILE mynode
        IF mynode.succ<>0
            mobj:=mynode
            IF (base.savewhat=SAVEOBJ_ALL)
                saveit:=TRUE
            ELSEIF ((mobj.selected=TRUE) AND (base.savewhat=SAVEOBJ_SEL))
                saveit:=TRUE
            ELSEIF ((mobj.selected=FALSE) AND (base.savewhat=SAVEOBJ_DES))
                saveit:=TRUE
            ENDIF
            IF saveit=TRUE
                StringF(fichier_out,'\s\s.asc',dir,mynode.name)
                IF s_handle:=Open(fichier_out,1006)
                    oldout:=stdout
                    stdout:=s_handle
                    WriteF('Ambient light color: Red=0.039216 Green=0.039216 Blue=0.039216\n\n')
                    WriteF('Named object: "\s"\n',mynode.name)
                    WriteF('Tri-mesh, Vertices: \d Faces: \d\n',mobj.nbrspts,mobj.nbrsfcs)
                    WriteF('Vertex list:\n')
                    n_pts:=mobj.nbrspts
                    p_pts:=mobj.datapts
                    FOR b_pts:=0 TO n_pts-1
                        v:=p_pts
                        WriteF('Vertex \d: X: ',b_pts);writeFFloat(v.x);WriteF(' Y: ');writeFFloat(v.y);WriteF(' Z: ');writeFFloat(v.z);WriteF('\n')
                        p_pts:=p_pts+12
                    ENDFOR
                    n_faces:=mobj.nbrsfcs
                    p_faces:=mobj.datafcs
                    WriteF('Faces list:\n')
                    FOR b_faces:=0 TO n_faces-1
                        WriteF('Faces \d:    A:\d B:\d C:\d AB:1 BC:1 CA:1\n',b_faces,Long(p_faces),Long(p_faces+4),Long(p_faces+8))
                        p_faces:=p_faces+12
                    ENDFOR
                    ret:=TRUE
                    stdout:=oldout
                    IF s_handle THEN Close(s_handle)
                ELSE
                    RETURN ERR3D_OPEN
                ENDIF
                saveit:=FALSE
            ENDIF
        ENDIF
        mynode:=mynode.succ
    ENDWHILE
ENDPROC ret
-><

->> saveCaliAscFile(base:PTR TO base3d,dir)
PROC saveCaliAscFile(base:PTR TO base3d,dir)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet base3d,dossier amigados (STRING)
Retour   : TRUE si ok,sinon FALSE
Action   : Sauve la base 3d au format GEO.
================================================*/
    DEF b_pts,b_faces
    DEF n_pts,n_faces
    DEF mobj:PTR TO object3d
    DEF p_pts,p_faces
    DEF s_handle,fichier_out[256]:STRING,v:PTR TO vertice
    DEF mylist:PTR TO lh,mynode:PTR TO ln,saveit=FALSE
    DEF oldout,ret=ERR3D_NONE
    DEF l
    DEF info:fileinfoblock
    AddPart(dir,'',256)
    IF l:=Lock(dir,-2)
        IF Examine(l,info)
            IF info.direntrytype>0
                UnLock(l)
            ELSE
                UnLock(l)
                RETURN ERR3D_NODIR
            ENDIF
        ELSE
            RETURN ERR3D_NODIR
        ENDIF
    ELSE
        RETURN ERR3D_NODIR
    ENDIF
    mylist:=base.objlist
    mynode:=mylist.head
    WHILE mynode
        IF mynode.succ<>0
            mobj:=mynode
            IF (base.savewhat=SAVEOBJ_ALL)
                saveit:=TRUE
            ELSEIF ((mobj.selected=TRUE) AND (base.savewhat=SAVEOBJ_SEL))
                saveit:=TRUE
            ELSEIF ((mobj.selected=FALSE) AND (base.savewhat=SAVEOBJ_DES))
                saveit:=TRUE
            ENDIF
            IF saveit=TRUE
                StringF(fichier_out,'\s\s.cob',dir,mynode.name)
                IF s_handle:=Open(fichier_out,1006)
                    oldout:=stdout
                    stdout:=s_handle
                    WriteF('Caligari V00.01ALH             \n')
                    WriteF('PolH V0.02 Id 0 Parent 0 Size 0\n')
                    WriteF('Name \s\n',mynode.name)
                    WriteF('center 0 0 1\n')
                    WriteF('x axis 1 0 0\n')
                    WriteF('y axis 0 1 0\n')
                    WriteF('z axis 0 0 1\n')
                    WriteF('Transform\n')
                    WriteF('1 0 0 0\n')
                    WriteF('0 1 0 0\n')
                    WriteF('0 0 1 1\n')
                    WriteF('0 0 0 1\n')
                    n_pts:=mobj.nbrspts
                    WriteF('World Vertices \d\n',n_pts)
                    p_pts:=mobj.datapts
                    FOR b_pts:=0 TO n_pts-1
                        v:=p_pts
                        writeFGeoVertice(v)
                        p_pts:=p_pts+12
                    ENDFOR
                    n_faces:=mobj.nbrsfcs
                    p_faces:=mobj.datafcs
                    WriteF('Faces \d\n',n_faces)
                    FOR b_faces:=0 TO n_faces-1
                        WriteF('Face verts 3 flags 32 mat 0\n')
                        WriteF('<\d,0> <\d,0> <\d,0>\n',Long(p_faces),Long(p_faces+4),Long(p_faces+8))
                        p_faces:=p_faces+12
                    ENDFOR
                    WriteF('END  V1.00 Id 0 Parent 0 Size        0\n')
                    ret:=TRUE
                    stdout:=oldout
                    IF s_handle THEN Close(s_handle)
                ELSE
                    RETURN ERR3D_OPEN
                ENDIF
                saveit:=FALSE
            ENDIF
        ENDIF
        mynode:=mynode.succ
    ENDWHILE
ENDPROC ret
-><


->> writeFGeoVertice(v:PTR TO vertice)
PROC writeFGeoVertice(v:PTR TO vertice)
/*== © NasGûl ===================================
Paramètres: pointeur sur un objet vertice.
Retour   : NIL
Action   : Ecrit un sommet au format GEO.
================================================*/
    writeFFloat(v.x);WriteF(' ');writeFFloat(v.y);WriteF(' ');writeFFloat(v.z);WriteF('\n')
ENDPROC
-><
->> writeFDxfVertice(ent,float)
PROC writeFDxfVertice(ent,float)
/*== © NasGûl ===================================
Paramètres: entête dxf,flottant.
Retour   : NIL
Action   : Ecrit un sommet au format DXF.
================================================*/
    WriteF('\d\n',ent)
    WriteF('\d.\z\d[4]\n',IeeeSPFix(float),IeeeSPFix(IeeeSPAbs(IeeeSPMul(IeeeSPSub(IeeeSPFlt(IeeeSPFix(float)),float ),10000.0))))
ENDPROC
-><
->> writeFFloat(float)
PROC writeFFloat(float)
/*== © NasGûl ===================================
Paramètres: flottant.
Retour   : NIL
Action   : Ecrit un nombre flottant en stdout.
================================================*/
    WriteF('\d.\z\d[4]',IeeeSPFix(float),IeeeSPFix(IeeeSPAbs(IeeeSPMul(IeeeSPSub(IeeeSPFlt(IeeeSPFix(float)),float ),10000.0))))
ENDPROC
-><

-><

->> Fonctions annexes a la lecture des fichiers 3DStudio.

->> skipChunk(c:PTR TO studiochunk)
PROC skipChunk(c:PTR TO studiochunk)
    DEF tempo
    tempo:=getLong(c.chunksize)
    RETURN  tempo
ENDPROC
-><
->> getInt(valeur)
PROC getInt(valeur:PTR TO INT)
    DEF fr:PTR TO INT,fa:PTR TO INT,rn:PTR TO INT
    DEF str[10]:STRING
    DEF ret
    rn:=Shl(valeur,16)
    fa:=Shr(rn,24) AND $FF
    fr:=Shr(Shl(valeur,24),24) AND $FF
    StringF(str,'$\z\h[2]\z\h[2]',fr,fa)
    ret:=Val(str,NIL)
->    WriteF('\h \h \h \s\n',ret,fr,fa,str)
    RETURN ret
    /*
    DEF v1
    DEF v2
    DEF v3
    DEF v4
    DEF v
    DEF str[80]:STRING
    v1:=Shr(valeur,8)
    v2:=Shl(valeur,12)
    /*
    v3:=Shr(Shl(Long({valeur}),16),24)
    v4:=Shl(Int({valeur}),24)
    */
    StringF(str,'$\z\h[2]\z\h[2]',v2,v1)
    WriteF('Valeur :\h v1:\h v2:\h v3:\h v4:\h str:\s\n',valeur,v1,v2,v3,v4,str)
    RETURN Val(str,NIL)
    */
ENDPROC
-><
->> getLong(valeur)
PROC getLong(valeur)
    DEF v1,v2,v3,v4,str[20]:STRING
    DEF ret
    v1:=Shr(valeur,24) AND $FF
    v2:=Shr(Shl(valeur,8),24) AND $FF
    v3:=Shr(Shl(valeur,16),24) AND $FF
    v4:=Shr(Shl(valeur,24),24) AND $FF
->    WriteF('\h \h \h \h\n',v1,v2,v3,v4)
    StringF(str,'$\z\h[2]\z\h[2]\z\h[2]\z\h[2]',v4,v3,v2,v1)
->    StringF(str,'$\h\h\h\h',v4,v3,v2,v1)
    ret:=Val(str,NIL)
    RETURN ret
ENDPROC
-><

-><

->> fonctions annexes a la lecture des fichiers Geo (3DG1)

->> getCoord(type,data)
PROC getCoord(type,data)
    DEF m:PTR TO LONG
    DEF valx,valy,valz,t
    m:=[0,0,0]
    IF getArg(data,'X,Y,Z',m)
        valx,t:=RealVal(m[0])
        valy,t:=RealVal(m[1])
        valz,t:=RealVal(m[2])
        m[0]:=0;m[1]:=0;m[2]:=0
    ENDIF
    SELECT type
        CASE COORD_X;   RETURN valx
        CASE COORD_Y;   RETURN valy
        CASE COORD_Z;   RETURN valz
    ENDSELECT
ENDPROC
-><
->> getArg(argu,temp,a:PTR TO LONG)
PROC getArg(argu,temp,a:PTR TO LONG)
    DEF myc:PTR TO csource
    DEF ma:PTR TO rdargs
    DEF rdarg=NIL
    DEF argstr[256]:STRING
    DEF ret=NIL

    StrCopy(argstr,argu,ALL)
    StrAdd(argstr,'\n',1)
    IF ma:=AllocDosObject(DOS_RDARGS,NIL)

        myc:=New(SIZEOF csource)
        myc.buffer:=argstr
        myc.length:=EstrLen(argstr)
        ma.flags:=4
        CopyMem(myc,ma.source,SIZEOF csource)

        IF rdarg:=ReadArgs(temp,a,ma)
            ret:=a
            IF rdarg THEN FreeArgs(rdarg)
        ELSE
        ENDIF
        IF myc THEN Dispose(myc)
        FreeDosObject(DOS_RDARGS,ma)
    ELSE
->        WriteF('AllocDosObject failed !!\n')
    ENDIF

    RETURN ret
ENDPROC
-><
->> getVertice(type,data)
PROC getVertice(type,data)
    DEF m:PTR TO LONG
    DEF ver1,ver2,ver3,numver
    m:=[0,0,0,0,0]
    IF getArg(data,'NV,V1,V2,V3,CV',m)
        numver:=Val(m[0],NIL)
        IF numver=3
            ver1:=Val(m[1],NIL)
            ver2:=Val(m[2],NIL)
            ver3:=Val(m[3],NIL)
        ELSE
            ver1:=-1
            ver2:=-1
            ver3:=-1
        ENDIF
        m[0]:=0;m[1]:=0;m[2]:=0;m[3]:=0
    ENDIF
    SELECT type
        CASE VERTICE_1; RETURN ver1
        CASE VERTICE_2; RETURN ver2
        CASE VERTICE_3; RETURN ver3
    ENDSELECT
ENDPROC
-><

-><

->> fMin(a,b)
PROC fMin(a,b)
/*== © NasGûl ===================================
Paramètres: 2 flottants.
Retour   : 1 flottant
Action   : retour le minimum entre aet b
================================================*/
    DEF t
    t:=IeeeSPCmp(a,b)
    IF t=$1 THEN RETURN b
    IF t=$0 THEN RETURN a
    IF t=$FFFFFFFF THEN RETURN a
ENDPROC
-><
->> fMax(a,b)
PROC fMax(a,b)
/*== © NasGûl ===================================
Paramètres: 2 flottants.
Retour   : 1 flottant.
Action   : retourne le maximum entre a et b
================================================*/
    DEF t
    t:=IeeeSPCmp(a,b)
    IF t=$1 THEN RETURN a
    IF t=$0 THEN RETURN b
    IF t=$FFFFFFFF THEN RETURN b
ENDPROC
-><

-><
