/*========================================================
  3DF.rexx
  --------
        Fonctions mathématiques en 3D.

    © NasGûl 1996  (nasgul@faws.org)
                    http://www.faws.org

    Libraries annexes:

        rexxmathlib.library

    Ce programme fait parti de la distibution de 3DView.
    il permet de contruire des objets 3D a partir de
    formules mathématiques.
    il peut fonctionner sans 3DView,sans aucune visualisation.
    L'objet 3D est sauvé au format Geo (VidéoScape) et en ASCII,
    les faces générées ont trois sommets.

    La routine la plus IMPORTANTE et CalcFct,toutes les autres
    ne sont que pour la gestion de toutes les fonctions.

        Si vous êtes étonné par la complexité des formules
    mathématiques du tore ou du ruban de Moebius,sachez que
    je n'ai rien inventé mais que j'ai lu le livre suivant:

        Graphisme 3D (Collection Micro-Systèmes)
        de Michel ROUSSELET
        Edition Techniques et Scientifiques Françaises
        2 à 12, Rue de Bellevue, 75940 Paris Cedex 19

    PS: Le Tore fourni dans le fichier 3DF.data et le même
        que celui de 3DView !.

 $VER: 3DF.rexx 0.9250 (17.07.96)
========================================================*/
Signal on error
Signal on syntax
options failat 21
_c0='[30m'
_c1='[31m'
_c2='[32m'
_c3='[33m'
_b=x2c(0d)
maxfct=-1
curfct=-1
pubname=getPubName()
x=Open(out,'Con:0/0/640/80/3DVRexxFct/Close/Auto/Screen 'pubname)
IF x=0 THEN EXIT 20
Call LoadData('3df.data')
Call SetFile('Ram:test.geo')
Call SetFct('Torus')
Signal Start:
DO Forever
    Call WriteCh out,_c2'3DF'_c3'>'_c1
    com=ReadLn(out)
    IF com~='' THEN Call TriCom(com)
END
EXIT
/*>TriCom */
TriCom:
    Parse arg tcom
    SELECT
        when Upper(Word(tcom,1))='EXIT' THEN Call Sortie()
        when Upper(Word(tcom,1))='LOADDATA' THEN Call LoadData(Word(tcom,2))
        when Upper(Word(tcom,1))='SAVEDATA' THEN Call SaveData(Word(tcom,2))
        when Upper(Word(tcom,1))='SETFCT' THEN Call SetFct(Word(tcom,2))
        when Upper(Word(tcom,1))='SETFILE' THEN Call SetFile(Word(tcom,2))
        when Upper(Word(tcom,1))='TYPEALLFCT' THEN Call TypeAllFct()
        when Upper(Word(tcom,1))='CURRENTFCT' THEN Call CurrentFct()
        when Upper(Word(tcom,1))='CURRENTCONFIG' THEN Call CurrentConfig()
        when Upper(Word(tcom,1))='SETFCTNAME' THEN Call SetFctName(Word(tcom,2))
        when Upper(Word(tcom,1))='SETFCTFX' THEN Call SetFctFx(Word(tcom,2))
        when Upper(Word(tcom,1))='SETFCTFY' THEN Call SetFctFy(Word(tcom,2))
        when Upper(Word(tcom,1))='SETFCTFZ' THEN Call SetFctFz(Word(tcom,2))
        when Upper(Word(tcom,1))='SETFCTMINX' THEN Call SetFctMinx(Word(tcom,2))
        when Upper(Word(tcom,1))='SETFCTMAXX' THEN Call SetFctMaxx(Word(tcom,2))
        when Upper(Word(tcom,1))='SETFCTMINY' THEN Call SetFctMiny(Word(tcom,2))
        when Upper(Word(tcom,1))='SETFCTMAXY' THEN Call SetFctMaxy(Word(tcom,2))
        when Upper(Word(tcom,1))='SETFCTSEPX' THEN Call SetFctSepx(Word(tcom,2))
        when Upper(Word(tcom,1))='SETFCTSEPY' THEN Call SetFctSepy(Word(tcom,2))
        when Upper(Word(tcom,1))='SETFCTF3D' THEN Call SetFctF3d(Word(tcom,2))
        when Upper(Word(tcom,1))='SETFCTFC' THEN Call SetFctFc(Word(tcom,2))
        when Upper(Word(tcom,1))='NEWFCT' THEN Call NewFct(tcom)
        when Upper(Word(tcom,1))='DELFCT' THEN Call DelFct(Word(tcom,2))
        when Upper(Word(tcom,1))='CALCFCT' THEN Call CalcFct()
        when Upper(Word(tcom,1))='3DV' THEN Call 3dv(tcom)
        when Upper(Word(tcom,1))='DOS' THEN Call Dos(tcom)
        when Upper(Word(tcom,1))='EXE' THEN Call Exe(Word(tcom,2))
        when Upper(Word(tcom,1))='HELP' THEN Call Help()
        OtherWise Call WriteLn(out,'Commande inconnu')
    END
RETURN
/*<*/
/*>Help*/
Help:
    x=Exists('Libs:amigaguide.library')
    IF x=1 THEN
        DO
            x=Show('L','amigaguide.library')
            IF x=0 THEN Call AddLib('amigaguide.library',0,-30)
            x=Show('L','amigaguide.library')
            IF x=1 THEN
                Call ShowNode(pubname,'3DView.Guide','BT_vrexx',0,0)
            ELSE
                Call WriteLn(out,"cette fonction a besion de l'amigaguide.library")
        END
    ELSE
        Call WriteLn(out,"cette fonction a besion de l'amigaguide.library")
RETURN 0
/*<*/
/*>Exe*/
Exe:
    Parse Arg f
    x=Open('sc',f,'R')
    IF x~=0 THEN
        DO
            DO forever
                IF eof('sc')=1 THEN leave
                data=Readln('sc')
                IF data~='' THEN
                    DO
                        tcom=data
                        SELECT
                            when Upper(Word(tcom,1))='EXIT' THEN Call Sortie()
                            when Upper(Word(tcom,1))='LOADDATA' THEN Call LoadData(Word(tcom,2))
                            when Upper(Word(tcom,1))='SAVEDATA' THEN Call SaveData(Word(tcom,2))
                            when Upper(Word(tcom,1))='SETFCT' THEN Call SetFct(Word(tcom,2))
                            when Upper(Word(tcom,1))='SETFILE' THEN Call SetFile(Word(tcom,2))
                            when Upper(Word(tcom,1))='TYPEALLFCT' THEN Call TypeAllFct()
                            when Upper(Word(tcom,1))='CURRENTFCT' THEN Call CurrentFct()
                            when Upper(Word(tcom,1))='CURRENTCONFIG' THEN Call CurrentConfig()
                            when Upper(Word(tcom,1))='SETFCTNAME' THEN Call SetFctName(Word(tcom,2))
                            when Upper(Word(tcom,1))='SETFCTFX' THEN Call SetFctFx(Word(tcom,2))
                            when Upper(Word(tcom,1))='SETFCTFY' THEN Call SetFctFy(Word(tcom,2))
                            when Upper(Word(tcom,1))='SETFCTFZ' THEN Call SetFctFz(Word(tcom,2))
                            when Upper(Word(tcom,1))='SETFCTMINX' THEN Call SetFctMinx(Word(tcom,2))
                            when Upper(Word(tcom,1))='SETFCTMAXX' THEN Call SetFctMaxx(Word(tcom,2))
                            when Upper(Word(tcom,1))='SETFCTMINY' THEN Call SetFctMiny(Word(tcom,2))
                            when Upper(Word(tcom,1))='SETFCTMAXY' THEN Call SetFctMaxy(Word(tcom,2))
                            when Upper(Word(tcom,1))='SETFCTSEPX' THEN Call SetFctSepx(Word(tcom,2))
                            when Upper(Word(tcom,1))='SETFCTSEPY' THEN Call SetFctSepy(Word(tcom,2))
                            when Upper(Word(tcom,1))='SETFCTF3D' THEN Call SetFctF3d(Word(tcom,2))
                            when Upper(Word(tcom,1))='SETFCTFC' THEN Call SetFctFc(Word(tcom,2))
                            when Upper(Word(tcom,1))='NEWFCT' THEN Call NewFct(tcom)
                            when Upper(Word(tcom,1))='DELFCT' THEN Call DelFct(Word(tcom,2))
                            when Upper(Word(tcom,1))='CALCFCT' THEN Call CalcFct()
                            when Upper(Word(tcom,1))='3DV' THEN Call 3dv(tcom)
                            when Upper(Word(tcom,1))='DOS' THEN Call Dos(tcom)
                            when Upper(Word(tcom,1))='EXE' THEN Call Exe(Word(tcom,2))
                            OtherWise Call WriteLn(out,'Commande inconnu')
                        END
                    END
            END
            Call Close('sc')
        END
    ELSE
        Call WriteLn(out,"Impossible d'executer "f)
RETURN 0
/*<*/
/*>Dos */
Dos:
    Parse Arg f
    thecom=DelWord(f,1,1)
    Address Command thecom '>T:DosTemp'
    x=Open('s','T:DosTemp','R')
    DO Forever
        IF eof('s')=1 THEN leave
        data=ReadLn('s')
        Call WriteLn(out,data)
    END
    Call Close('s')
RETURN 0
/*<*/

/*>3dv */
3dv:
    Parse Arg f
    thecom=Upper(DelWord(f,1,1))
    Address '3DVIEW'
    thecom
RETURN 0
/*<*/
/*> LoadData */
LoadData:
    Arg file
    x=Open('s',file,'R')
    i=0
    maxfct=0
    IF x~=0 THEN
        DO
            DO forever
                IF Eof('s')=1 THEN leave
                data=ReadLn('s')
                IF data~='' THEN
                    DO
                        fctname.i=Word(data,1)
                        fctfx.i=Word(data,2)
                        fctfy.i=Word(data,3)
                        fctfz.i=Word(data,4)
                        fctminx.i=Word(data,5)
                        fctmaxx.i=Word(data,6)
                        fctminy.i=Word(data,7)
                        fctmaxy.i=Word(data,8)
                        fctpt.i=Word(data,9)
                        fctgt.i=Word(data,10)
                        fctf3d.i=Word(data,11)
                        fctfc.i=Word(data,12)
                        i=i+1
                    END
            END
            maxfct=i-1
            Call Close('s')
        END
    ELSE
        Call WriteLn(out,'Impossible de charger le fichier 'file)
RETURN 0
/*<*/
/*>SaveData */
SaveData:
    Parse Arg f
    IF f~='' THEN 
        file=f 
    ELSE 
        file='3DF.Data'
    x=Open('s',file,'W')
    IF x~=0 THEN
        DO
            DO i=0 TO maxfct
                Call WriteLn('s',fctname.i' 'fctfx.i' 'fctfy.i' 'fctfz.i' 'fctminx.i' 'fctmaxx.i' 'fctminy.i' 'fctmaxy.i' 'fctpt.i' 'fctgt.i' 'fctf3d.i' 'fctfc.i)
            END
            Call Close('s')
        END
    ELSE
        Call WriteLn(out,'Impossible de créer le fichier 'file)
RETURN 0
/*<*/
/*>SetFct */
SetFct:
    Parse Arg f
    found=0
    DO i=0 TO maxfct
        IF Upper(f)=Upper(fctname.i) THEN
            DO
                found=1
                Call SetClip('FCT_NAME',fctname.i)
                Call SetClip('FCT_FX',fctfx.i)
                Call SetClip('FCT_FY',fctfy.i)
                Call SetClip('FCT_FZ',fctfz.i)
                Call SetClip('FCT_MINX',fctminx.i)
                Call SetClip('FCT_MAXX',fctmaxx.i)
                Call SetClip('FCT_MINY',fctminy.i)
                Call SetClip('FCT_MAXY',fctmaxy.i)
                Call SetClip('FCT_PT',fctpt.i)
                Call SetClip('FCT_GT',fctgt.i)
                Call SetClip('FCT_F3D',fctf3d.i)
                Call SetClip('FCT_FC',fctfc.i)
                Call CurrentFct()
                curfct=i
            END
    END
    IF found=0 THEN Call WriteLn(out,"La fonction n'existe pas.")
RETURN 0
/*<*/
/*>CurrentFct */
CurrentFct:
    Call WriteLn(out,'Nom :'GetClip('FCT_NAME'))
    Call WriteLn(out,'Fx  :'GetClip('FCT_FX'))
    Call WriteLn(out,'Fy  :'GetClip('FCT_FY'))
    Call WriteLn(out,'Fz  :'GetClip('FCT_FZ'))
    Call WriteLn(out,'Minx:'GetClip('FCT_MINX') 'Maxx:'GetClip('FCT_MAXX'))
    Call WriteLn(out,'Miny:'GetClip('FCT_MINY') 'Maxy:'GetClip('FCT_MAXY'))
    Call WriteLn(out,'Sepx:'GetClip('FCT_PT')   'Sepy:'GetClip('FCT_GT'))
    Call WriteLn(out,'Facteur 3D:'GetClip('FCT_F3D'))
    Call WriteLn(out,'Générations des faces:'GetClip('FCT_FC'))
RETURN 0
/*<*/
/*>TypeAllFct */
TypeAllFct:
    DO i=0 TO maxfct
        Call WriteLn(out,fctname.i fctfx.i fctfy.i fctfz.i fctminx.i fctmaxx.i fctminy.i fctmaxy.i fctpt.i fctgt.i fctf3d.i fctfc.i)
    END
RETURN 0
/*<*/
/*>SetFctName */
SetFctName:
    Parse arg f
    Call SetClip('FCT_NAME',f)
    fctname.curfct=f
RETURN 0
/*<*/
/*>SetFctFx */
SetFctFx:
    Parse arg f
    Call SetClip('FCT_FX',f)
    fctfx.curfct=f
RETURN 0
/*<*/
/*>SetFctFy */
SetFctFy:
    Parse arg f
    Call SetClip('FCT_FY',f)
    fctfy.curfct=f
RETURN 0
/*<*/
/*>SetFctFz */
SetFctFz:
    Parse arg f
    Call SetClip('FCT_FZ',f)
    fctfz.curfct=f
RETURN 0
/*<*/
/*>SetFctMinx */
SetFctMinx:
    Parse arg f
    Call SetClip('FCT_MINX',f)
    fctminx.curfct=f
RETURN 0
/*<*/
/*>SetFctMaxx */
SetFctMaxx:
    Parse arg f
    Call SetClip('FCT_MAXX',f)
    fctmaxx.curfct=f
RETURN 0
/*<*/
/*>SetFctMiny */
SetFctMiny:
    Parse arg f
    Call SetClip('FCT_MINY',f)
    fctminy.curfct=f
RETURN 0
/*<*/
/*>SetFctMaxy */
SetFctMaxy:
    Parse arg f
    Call SetClip('FCT_MAXY',f)
    fctmaxy.curfct=f
RETURN 0
/*<*/
/*>SetFctSepx */
SetFctSepx:
    Parse arg f
    Call SetClip('FCT_PT',f)
    fctpt.curfct=f
RETURN 0
/*<*/
/*>SetFctSepy */
SetFctSepy:
    Parse arg f
    Call SetClip('FCT_GT',f)
    fctgt.curfct=f
RETURN 0
/*<*/
/*>SetFctF3d */
SetFctF3d:
    Parse arg f
    Call SetClip('FCT_F3D',f)
    fctf3d.curfct=f
RETURN 0
/*<*/
/*>SetFctFc */
SetFctFc:
    Parse arg f
    Call SetClip('FCT_FC',f)
    fctfc.curfct=f
RETURN 0
/*<*/
/*>NewFct */
NewFct:
    Parse Arg f 
    Parse Var f p' 'name' 'fx' 'fy' 'fz' 'minx' 'maxx' 'miny' 'maxy' 'pt' 'gt' 'f3d' 'fc
    Say 'NewFct 'name
    IF FindFctName(name)=0 THEN
        DO
            maxfct=maxfct+1
            curfct=maxfct
            fctname.curfct=name
            fctfx.curfct=fx
            fctfy.curfct=fy
            fctfz.curfct=fz
            fctminx.curfct=minx
            fctmaxx.curfct=maxx
            fctminy.curfct=miny
            fctmaxy.curfct=maxy
            fctpt.curfct=pt
            fctgt.curfct=gt
            fctf3d.curfct=f3d
            fctfc.curfct=fc
            Call SetClip('FCT_NAME',fctname.curfct)
            Call SetClip('FCT_FX',fctfx.curfct)
            Call SetClip('FCT_FY',fctfy.curfct)
            Call SetClip('FCT_FZ',fctfz.curfct)
            Call SetClip('FCT_MINX',fctminx.curfct)
            Call SetClip('FCT_MAXX',fctmaxx.curfct)
            Call SetClip('FCT_MINY',fctminy.curfct)
            Call SetClip('FCT_MAXY',fctmaxy.curfct)
            Call SetClip('FCT_PT',fctpt.curfct)
            Call SetClip('FCT_GT',fctgt.curfct)
            Call SetClip('FCT_F3D',fctf3d.curfct)
            Call SetClip('FCT_FC',fctfc.curfct)
            Call CurrentFct()
        END
    ELSE
        Call WriteLn(out,'La fonction 'name' existe dèjà')
RETURN 0
/*<*/
/*>DelFct */
DelFct:
    Parse Arg f
    found=-1
    DO i=0 TO maxfct
        IF Upper(f)=Upper(fctname.i) THEN
            DO
                found=i
            END
    END
    IF found=-1 THEN 
        DO
            Call WriteLn(out,"La fonction n'existe pas.")
            RETURN 0
        END
    ELSE
        DO
            x=Open('s','T:3DVTemp','W')
            DO i=0 TO maxfct
                IF i~=found THEN
                    Call WriteLn('s',fctname.i' 'fctfx.i' 'fctfy.i' 'fctfz.i' 'fctminx.i' 'fctmaxx.i' 'fctminy.i' 'fctmaxy.i' 'fctpt.i' 'fctgt.i' 'fctf3d.i' 'fctfc.i)
                ELSE
                    NOP
            END
            Call Close('s')
            Call LoadData('T:3DVTemp')
        END
RETURN 0
/*<*/
/*>FindFctName */
FindFctName:
    Parse Arg f
    ret=0
    DO i=0 TO maxfct
        IF Upper(f)=Upper(fctname.i) THEN 
            DO
                ret=1
                Leave
            END
    END
RETURN ret
/*<*/
/*>Sortie */
Sortie:
    Call SetClip('FCT_NAME','')
    Call SetClip('FCT_FX','')
    Call SetClip('FCT_FY','')
    Call SetClip('FCT_FZ','')
    Call SetClip('FCT_MINX','')
    Call SetClip('FCT_MAXX','')
    Call SetClip('FCT_MINY','')
    Call SetClip('FCT_MAXY','')
    Call SetClip('FCT_PT','')
    Call SetClip('FCT_GT','')
    Call SetClip('FCT_F3D','')
    Call SetClip('FCT_FC','')
    Call SetClip('FCT_FILE','')
    EXIT 0
RETURN 0
/*<*/
/*>CurrentConfig */
CurrentConfig:
    Call WriteLn(out,'Nbrs Fcts:'maxfct)
    Call WriteLn(out,'Fichier  :'GetClip('FCT_FILE'))
RETURN 0
/*<*/
/*>SetFile */
SetFile:
    Parse Arg f
    Call SetClip('FCT_FILE',f)
RETURN 0
/*<*/
/*>CalcFct*/
CalcFct:
    test=Exists('Libs:rexxmathlib.library')
    IF test=0 THEN
        DO
            Call WriteLn(out,'ce script a besoin de la rexxmathlib.library !')
            Signal Start
        END
    test=Show('L','rexxmathlib.library')
    IF test=0 THEN Call AddLib('rexxmathlib.library',0,-30,0)

    fx=GetClip('FCT_FX')
    gy=GetClip('FCT_FY')
    hz=GetClip('FCT_FZ')

    xmin=GetClip('FCT_MINX')
    xmax=GetClip('FCT_MAXX')
    ymin=GetClip('FCT_MINY')
    ymax=GetClip('FCT_MAXY')

    pt=GetClip('FCT_PT')
    gt=GetClip('FCT_GT')
    f3d=GetClip('FCT_F3D')
    fc=GetClip('FCT_FC')

    f=Open('fct',GetClip('FCT_FILE'),'W')
    IF f=0 THEN
        DO
            Call WriteLn(out,'impossible de créer 'GetClip('FCT_FILE'))
            Signal Start
        END
    nbrspts=1
    totalpts=(pt+1)*(gt+1)
    nbrsfcs=0
    totalfcs=0
    Call WriteLn('fct','3DG1')
    Call WriteLn('fct',(pt+1)*(gt+1))
    DO i=1 TO pt+1
        DO j=1 TO gt+1
            x=(xmin+(i-1)*(xmax-xmin)/pt)
            y=(ymin+(j-1)*(ymax-ymin)/gt)
            r=SQRT(x**2+y**2)
            INTERPRET 'nx=' fx
            INTERPRET 'ny=' gy
            INTERPRET 'nz=' hz
            nx=(nx*f3d)
            ny=(ny*f3d)
            nz=(nz*f3d)
            Call WriteLn('fct',nx' 'ny' 'nz)
            Call WriteCh(out,_b'Calcul des Points :'nbrspts' ('totalpts')')
            nbrspts=nbrspts+1
        END
    END
    Call WriteLn(out,'')
    IF fc=2 THEN
        totalfcs=(pt)*(gt)*4
    ELSE 
        totalfcs=(pt)*(gt)*2
    base=0
    DO i=0 TO pt-1
        DO j=0 TO gt-1
            p1=base
            p2=base+1
            p3=gt+base+2
            p4=gt+base+1
            if fc=0 | fc=2 then do
                Call WriteLn('fct','3 'p1' 'p2' 'p3' 140')
                Call WriteLn('fct','3 'p1' 'p3' 'p4' 140')
                nbrsfcs=nbrsfcs+2
                Call WriteCh(out,_b'Calcul des Faces :'nbrsfcs' ('totalfcs')')
            end
            if fc=1 | fc=2 then do
                Call WriteLn('fct','3 'p1' 'p3' 'p2' 140')
                Call WriteLn('fct','3 'p1' 'p4' 'p3' 140')
                nbrsfcs=nbrsfcs+2
                Call WriteCh(out,_b'Calcul des Faces :'nbrsfcs' ('totalfcs')')
            end
            base=base+1
        END
        base=base+1
    END
    Call WriteLn(out,'')
    Call Close('fct')

    x=Show('P','3DVIEW')
    IF x=1 THEN
        DO
            Call WriteLn(out,'Transfert des données dans 3DView')
            Address '3DVIEW'
            'LOCKGUI'
            'DELBASE'
            'LOADBASE 'GetClip('FCT_FILE')
            'DRAWBASE3D'
            'UNLOCKGUI'
        END

RETURN 0
/*<*/
/*>getPubName*/
getPubName:
    h=Open('pn','Env:3DVPUBSCREEN','R')
    IF h=1 THEN
        DO
            data=ReadLn('pn')
            Call Close('pn')
        END
RETURN data
/*<*/

/*>error*/
error:
    IF rc<=48 THEN
        Call WriteLn(out,'Error ('rc') 'ErrorText(rc)' Ligne 'sigl)
    ELSE
        DO
            SELECT
                when rc=49 THEN Call WriteLn(out,"Les commandes arexx ne sont valables que si 3DView n'est pas iconifier !")
                when rc=50 THEN Call WriteLn(out,"Format de fichier inconnu !")
                when rc=51 THEN Call WriteLn(out,"fichier inexistant !")
                otherwise nop
            END
        END
    Call Close('fct')
RETURN 0
/*<*/
/*>syntax*/
syntax:
    Call WriteLn(out,'Syntax ('rc') 'ErrorText(rc)' Ligne 'sigl)
    Call Close('fct')
RETURN 0
/*<*/
