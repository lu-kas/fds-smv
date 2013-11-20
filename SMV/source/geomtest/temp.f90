! VVVVV placeholder modules - will not be moved to FDS VVVVV

! ------------ module PRECISION_PARAMETERS

MODULE PRECISION_PARAMETERS
 
! Set important parameters having to do with variable precision and array allocations
 
IMPLICIT NONE
 
! Precision of "Four Byte" and "Eight Byte" reals

INTEGER, PARAMETER :: FB = SELECTED_REAL_KIND(6)
INTEGER, PARAMETER :: EB = SELECTED_REAL_KIND(12)
END MODULE PRECISION_PARAMETERS

! ------------ module COMP_FUNCTIONS

MODULE COMP_FUNCTIONS
IMPLICIT NONE

CONTAINS

! ------------ SUBROUTINE SHUTDOWN

SUBROUTINE SHUTDOWN(MESSAGE)  
CHARACTER(*), INTENT(IN) :: MESSAGE

WRITE(6,'(/A)') TRIM(MESSAGE)

STOP

END SUBROUTINE SHUTDOWN

! ------------ SUBROUTINE CHECKREAD

SUBROUTINE CHECKREAD(NAME,LU,IOS)

! Look for the namelist variable NAME and then stop at that line.

INTEGER :: II
INTEGER, INTENT(OUT) :: IOS
INTEGER, INTENT(IN) :: LU
CHARACTER(4), INTENT(IN) :: NAME
CHARACTER(80) TEXT
IOS = 1

READLOOP: DO
   READ(LU,'(A)',END=10) TEXT
   TLOOP: DO II=1,72
      IF (TEXT(II:II)/='&' .AND. TEXT(II:II)/=' ') EXIT TLOOP
      IF (TEXT(II:II)=='&') THEN
         IF (TEXT(II+1:II+4)==NAME) THEN
            BACKSPACE(LU)
            IOS = 0
            EXIT READLOOP
         ELSE
            CYCLE READLOOP
         ENDIF
      ENDIF
   ENDDO TLOOP
ENDDO READLOOP
 
10 RETURN
END SUBROUTINE CHECKREAD

END MODULE COMP_FUNCTIONS

! ------------ MODULE MEMORY_FUNCTIONS

MODULE MEMORY_FUNCTIONS

USE COMP_FUNCTIONS, ONLY: SHUTDOWN
IMPLICIT NONE

CONTAINS

! ------------ SUBROUTINE ChkMemErr

SUBROUTINE ChkMemErr(CodeSect,VarName,IZERO)
 
! Memory checking routine
 
CHARACTER(*), INTENT(IN) :: CodeSect, VarName
INTEGER IZERO
CHARACTER(100) MESSAGE
 
IF (IZERO==0) RETURN
 
WRITE(MESSAGE,'(4A)') 'ERROR: Memory allocation failed for ', TRIM(VarName),' in the routine ',TRIM(CodeSect)
CALL SHUTDOWN(MESSAGE)

END SUBROUTINE ChkMemErr
END MODULE MEMORY_FUNCTIONS

! ^^^^ placeholder routines and modules ^^^^^^^

! ------------ module TYPES

MODULE TYPES
USE PRECISION_PARAMETERS

TYPE GEOMETRY_TYPE ! this TYPE definition will be moved to FDS
   LOGICAL :: COMPONENT_ONLY
   CHARACTER(30) :: ID='geom'
   CHARACTER(30) :: SURF_ID='null'
   INTEGER :: N_VERTS, N_FACES, N_GEOMS
   INTEGER, ALLOCATABLE, DIMENSION(:) :: FACES, GEOM_INDICES
   REAL(EB), ALLOCATABLE, DIMENSION(:) :: AZ, ELEV, VERTS, XYZ0, XYZ
END TYPE GEOMETRY_TYPE
INTEGER :: N_GEOM=0
TYPE(GEOMETRY_TYPE), ALLOCATABLE, TARGET, DIMENSION(:) :: GEOMETRY

TYPE MESH_TYPE
   INTEGER :: IBAR, JBAR, KBAR
   REAL(EB) :: XB(6)
END TYPE MESH_TYPE

TYPE (MESH_TYPE), SAVE, DIMENSION(:), ALLOCATABLE, TARGET :: MESHES

END MODULE TYPES

! ------------ module GLOBAL_CONSTANTS

MODULE GLOBAL_CONSTANTS
USE PRECISION_PARAMETERS
IMPLICIT NONE

INTEGER :: LU_INPUT=5, LU_GEOM(1)=15, LU_SMV=4
CHARACTER(40) :: CHID
CHARACTER(250)                             :: FN_INPUT='null'
CHARACTER(80) :: FN_SMV,FN_GEOM(1)
END MODULE GLOBAL_CONSTANTS

! ------------ MODULE READ_INPUT

MODULE READ_INPUT

USE PRECISION_PARAMETERS
USE GLOBAL_CONSTANTS
USE COMP_FUNCTIONS, ONLY: CHECKREAD,SHUTDOWN
USE MEMORY_FUNCTIONS, ONLY: ChkMemErr
USE TYPES
IMPLICIT NONE
INTEGER :: NMESHES

PRIVATE
PUBLIC :: READ_HEAD,READ_MESH,NMESHES

CONTAINS

! ------------ SUBROUTINE READ_HEAD

SUBROUTINE READ_HEAD
INTEGER :: NAMELENGTH
INTEGER :: IOS, I

NAMELIST /HEAD/ CHID

CHID    = 'null'

REWIND(LU_INPUT)
HEAD_LOOP: DO
   CALL CHECKREAD('HEAD',LU_INPUT,IOS)
   IF (IOS==1) EXIT HEAD_LOOP
   READ(LU_INPUT,HEAD,END=13,ERR=14,IOSTAT=IOS)
   14 IF (IOS>0) CALL SHUTDOWN('ERROR: Problem with HEAD line')
ENDDO HEAD_LOOP
13 REWIND(LU_INPUT)

CLOOP: DO I=1,39
   IF (CHID(I:I)=='.') CALL SHUTDOWN('ERROR: No periods allowed in CHID')
   IF (CHID(I:I)==' ') EXIT CLOOP
ENDDO CLOOP

IF (TRIM(CHID)=='null') THEN
   NAMELENGTH = LEN_TRIM(FN_INPUT)
   ROOTNAME: DO I=NAMELENGTH,2,-1
      IF (FN_INPUT(I:I)=='.') THEN
         WRITE(CHID,'(A)') FN_INPUT(1:I-1)
         EXIT ROOTNAME
      ENDIF
   END DO ROOTNAME
ENDIF

FN_SMV=TRIM(CHID)//'.smv'
FN_GEOM(1)=TRIM(CHID)//'.ge'

END SUBROUTINE READ_HEAD

! ------------ SUBROUTINE CHECK_XB

SUBROUTINE CHECK_XB(XB)
! Reorder an input sextuple XB if needed
REAL(EB) :: DUMMY,XB(6)
INTEGER  :: I
DO I=1,5,2
   IF (XB(I)>XB(I+1)) THEN
      DUMMY   = XB(I)
      XB(I)   = XB(I+1)
      XB(I+1) = DUMMY
   ENDIF
ENDDO
END SUBROUTINE CHECK_XB

! ------------ SUBROUTINE READ_MESH

SUBROUTINE READ_MESH
INTEGER :: IBAR,JBAR,KBAR,J
INTEGER :: IOS, IZERO, N

REAL(EB) :: XB(6)
NAMELIST /MESH/ IBAR,JBAR,KBAR,XB

TYPE (MESH_TYPE), POINTER :: M=>NULL()

NMESHES = 0

REWIND(LU_INPUT)
COUNT_MESH_LOOP: DO
   CALL CHECKREAD('MESH',LU_INPUT,IOS)
   IF (IOS==1) EXIT COUNT_MESH_LOOP
   READ(LU_INPUT,MESH,END=15,ERR=16,IOSTAT=IOS)
   NMESHES      = NMESHES + 1
   16 IF (IOS>0) CALL SHUTDOWN('ERROR: Problem with MESH line.')
ENDDO COUNT_MESH_LOOP
15 CONTINUE

! Allocate parameters associated with the mesh.

ALLOCATE(MESHES(NMESHES),STAT=IZERO)
CALL ChkMemErr('READ','MESHES',IZERO)

! Read in the Mesh lines from Input file

REWIND(LU_INPUT)

IF (NMESHES<1) CALL SHUTDOWN('ERROR: No MESH line(s) defined.')

MESH_LOOP: DO N=1,NMESHES

   ! Set MESH defaults

   IBAR = 10
   JBAR = 10
   KBAR = 10
   XB(1) = 0._EB
   XB(2) = 1._EB
   XB(3) = 0._EB
   XB(4) = 1._EB
   XB(5) = 0._EB
   XB(6) = 1._EB

   CALL CHECKREAD('MESH',LU_INPUT,IOS)
   IF (IOS==1) EXIT MESH_LOOP
   READ(LU_INPUT,MESH)

   ! Reorder XB coordinates if necessary

   CALL CHECK_XB(XB)

   M => MESHES(N)
   DO J = 1, 6
      M%XB(J) = XB(J)
   END DO
   M%IBAR = IBAR
   M%JBAR = JBAR
   M%KBAR = KBAR

ENDDO MESH_LOOP

END SUBROUTINE READ_MESH

END MODULE READ_INPUT


! ------------ SUBROUTINE WRITE_SMV

SUBROUTINE WRITE_SMV
USE GLOBAL_CONSTANTS
USE TYPES
USE READ_INPUT
IMPLICIT NONE

INTEGER :: N,I
TYPE (MESH_TYPE), POINTER :: M=>NULL()

OPEN(LU_SMV,FILE=FN_SMV)

WRITE(LU_SMV,'(/A)') 'CHID'
WRITE(LU_SMV,'(1X,A)') TRIM(CHID)

DO N = 1, NMESHES
   M=>MESHES(N)
   
   WRITE(LU_SMV,'(/A)') 'PDIM'
   WRITE(LU_SMV,'(6F14.5)') (M%XB(I),I=1,6)
   
   WRITE(LU_SMV,'(/A,3X,A,1X,I10)') 'GRID','MESH',N
   WRITE(LU_SMV,'(3I5)') M%IBAR,M%JBAR,M%KBAR
   
   WRITE(LU_SMV,'(/A)') 'TRNX'
   WRITE(LU_SMV,'(I5)') 0
   DO I=0,M%IBAR
      WRITE(LU_SMV,'(I5,F14.5)') I,((M%IBAR-I)*M%XB(1)+I*M%XB(2))/REAL(M%IBAR,EB)
   ENDDO
   
   WRITE(LU_SMV,'(/A)') 'TRNY'
   WRITE(LU_SMV,'(I5)') 0
   DO I=0,M%JBAR
      WRITE(LU_SMV,'(I5,F14.5)') I,((M%JBAR-I)*M%XB(3)+I*M%XB(4))/REAL(M%JBAR,EB)
   ENDDO

   WRITE(LU_SMV,'(/A)') 'TRNZ'
   WRITE(LU_SMV,'(I5)') 0
   DO I=0,M%KBAR
      WRITE(LU_SMV,'(I5,F14.5)') I,((M%KBAR-I)*M%XB(5)+I*M%XB(6))/REAL(M%KBAR,EB)
   ENDDO
   
   WRITE(LU_SMV,'(/A)') 'VENT'
   WRITE(LU_SMV,'(2I5)') 0,0

   WRITE(LU_SMV,'(/A)') 'OBST'
   WRITE(LU_SMV,'(I5)') 0

END DO


WRITE(LU_SMV,'(/A)')'SURFACE'
WRITE(LU_SMV,'(1x,A)')'INERT'
WRITE(LU_SMV,'(1x,A)')'5000.00    1.00'
WRITE(LU_SMV,'(1x,A)')'0      1.00000      1.00000      1.00000      0.80000      0.40000      1.00000'
WRITE(LU_SMV,'(1x,A)')'null'

WRITE(LU_SMV,'(/A)') 'GEOM'
WRITE(LU_SMV,'(1X,A)') FN_GEOM(1)

END SUBROUTINE WRITE_SMV
