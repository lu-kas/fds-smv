
! ------------ module COMPLEX_GEOMETRY

MODULE COMPLEX_GEOMETRY ! this module will be moved to FDS

USE PRECISION_PARAMETERS
USE COMP_FUNCTIONS, ONLY: CHECKREAD,SHUTDOWN
USE MEMORY_FUNCTIONS, ONLY: ChkMemErr
USE GLOBAL_CONSTANTS
USE TYPES

IMPLICIT NONE

PRIVATE
PUBLIC :: READ_GEOM,WRITE_GEOM
 
CONTAINS

! ------------ SUBROUTINE GET_GEOM_ID

SUBROUTINE GET_GEOM_ID(ID,GEOM_INDEX, N_LAST)
   CHARACTER(30), INTENT(IN) :: ID
   INTEGER, INTENT(IN) :: N_LAST
   INTEGER, INTENT(OUT) :: GEOM_INDEX
   INTEGER :: N
   TYPE(GEOMETRY_TYPE), POINTER :: G=>NULL()
   
   GEOM_INDEX=0
   DO N=1,N_LAST
      G=>GEOMETRY(N)
      IF(TRIM(G%ID)==TRIM(ID))THEN
         GEOM_INDEX=N
         RETURN
      ENDIF
   END DO
END SUBROUTINE GET_GEOM_ID

! ------------ SUBROUTINE READ_GEOM

SUBROUTINE READ_GEOM

INTEGER, PARAMETER :: MAX_VERTS=10000000 ! at some point we may decide to use dynmaic memory allocation
INTEGER, PARAMETER :: MAX_FACES=MAX_VERTS
INTEGER, PARAMETER :: MAX_IDS=100000
CHARACTER(30) :: ID,SURF_ID, GEOM_IDS(MAX_IDS)
REAL(EB) :: AZ(MAX_IDS), ELEV(MAX_IDS), XYZ0(3*MAX_IDS), XYZ(3*MAX_IDS)
REAL(EB), PARAMETER :: MAX_COORD=1.0E20_EB
REAL(EB) :: VERTS(3*MAX_VERTS)
INTEGER :: FACES(3*MAX_FACES)
INTEGER :: N_VERTS, N_FACES
INTEGER :: IOS,IZERO,N, I, J, N_GEOMS, GEOM_INDEX
LOGICAL COMPONENT_ONLY
TYPE(GEOMETRY_TYPE), POINTER :: G=>NULL()
NAMELIST /GEOM/ AZ, COMPONENT_ONLY, ELEV, FACES, GEOM_IDS, ID, SURF_ID, VERTS, XYZ0, XYZ

N_GEOM=0
REWIND(LU_INPUT)
COUNT_GEOM_LOOP: DO
   CALL CHECKREAD('GEOM',LU_INPUT,IOS)
   IF (IOS==1) EXIT COUNT_GEOM_LOOP
   READ(LU_INPUT,NML=GEOM,END=11,ERR=12,IOSTAT=IOS)
   N_GEOM=N_GEOM+1
   12 IF (IOS>0) CALL SHUTDOWN('ERROR: problem with GEOM line')
ENDDO COUNT_GEOM_LOOP
11 REWIND(LU_INPUT)

IF (N_GEOM==0) RETURN

! Allocate GEOMETRY array

ALLOCATE(GEOMETRY(N_GEOM),STAT=IZERO)
CALL ChkMemErr('READ','GEOMETRY',IZERO)

! read GEOM data

READ_GEOM_LOOP: DO N=1,N_GEOM
   G=>GEOMETRY(N)
   
   CALL CHECKREAD('GEOM',LU_INPUT,IOS)
   IF (IOS==1) EXIT READ_GEOM_LOOP
   
   ! Set defaults
   
   COMPONENT_ONLY=.FALSE.
   ID = 'geom'
   SURF_ID = 'INERT'
   VERTS=1.001_EB*MAX_COORD
   FACES=0
   GEOM_IDS = ''
   AZ = 0.0
   ELEV = 0.0
   XYZ0 = 0.0
   XYZ = 0.0

   ! Read the GEOM line
   
   READ(LU_INPUT,GEOM,END=35)
   
   N_VERTS=0
   DO I = 1, MAX_VERTS
      IF(VERTS(3*I-2).GE.MAX_COORD.OR.VERTS(3*I-1).GE.MAX_COORD.OR.VERTS(3*I).GE.MAX_COORD)EXIT
      N_VERTS=N_VERTS+1
   END DO
   
   N_FACES=0
   DO I = 1, MAX_FACES
      IF(FACES(3*I-2).EQ.0.OR.FACES(3*I-1).EQ.0.OR.FACES(3*I).EQ.0)EXIT
      N_FACES=N_FACES+1
   END DO

   G%COMPONENT_ONLY=COMPONENT_ONLY
   G%ID = ID
   G%N_FACES = N_FACES
   G%N_VERTS = N_VERTS
   G%SURF_ID = SURF_ID

   IF (N_FACES.GT.0) THEN
      ALLOCATE(G%FACES(3*N_FACES),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','FACES',IZERO)
      G%VERTS(1:3*N_VERTS) = VERTS(1:3*N_VERTS)
   ENDIF
   
   DO I = 1, 3*N_FACES
      IF(FACES(I).LT.1.OR.FACES(I).GT.N_VERTS)THEN
         CALL SHUTDOWN('ERROR: problem with GEOM, vertex index out of bounds')
      ENDIF
   END DO

   IF (N_VERTS.GT.0) THEN
      ALLOCATE(G%VERTS(3*N_VERTS),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','VERTS',IZERO)
      G%FACES(1:3*N_FACES) = FACES(1:3*N_FACES)
   ENDIF
   
   N_GEOMS=0
   DO I = 1, MAX_IDS
      IF(GEOM_IDS(I)=='')EXIT
      N_GEOMS=N_GEOMS+1
   END DO
   IF (N_GEOMS.GT.0) THEN
      ALLOCATE(G%GEOM_INDICES(N_GEOMS),STAT=IZERO)
      CALL ChkMemErr('READ_GEOM','GEOM_INDICES',IZERO)
   ENDIF
   ALLOCATE(G%AZ(N_GEOMS+1),STAT=IZERO)
   CALL ChkMemErr('READ_GEOM','AZ',IZERO)
   ALLOCATE(G%ELEV(N_GEOMS+1),STAT=IZERO)
   CALL ChkMemErr('READ_GEOM','ELEV',IZERO)
   ALLOCATE(G%XYZ0(3*(N_GEOMS+1)),STAT=IZERO)
   CALL ChkMemErr('READ_GEOM','XYZ0',IZERO)
   ALLOCATE(G%XYZ(3*(N_GEOMS+1)),STAT=IZERO)
   CALL ChkMemErr('READ_GEOM','XYZ',IZERO)
   G%N_GEOMS=N_GEOMS

   DO I = 1, N_GEOMS
      IF(GEOM_IDS(I)=='')EXIT
      N_GEOMS=N_GEOMS+1
      CALL GET_GEOM_ID(GEOM_IDS(I),GEOM_INDEX, N-1)
      IF(GEOM_INDEX.GE.1.and.GEOM_INDEX.LE.N-1)THEN
         G%GEOM_INDICES(I)=GEOM_INDEX
      ELSE
         CALL SHUTDOWN('ERROR: problem with GEOM '//TRIM(G%ID)//' line, '//TRIM(GEOM_IDS(I))//' not yet defined.')
      ENDIF
   END DO
   
   DO I = 1, N_GEOMS+1
      G%AZ(I) = AZ(I)
      G%ELEV(I) = ELEV(I)
      G%XYZ0(3*I-2) = XYZ0(3*I-2)
      G%XYZ0(3*I-1) = XYZ0(3*I-1)
      G%XYZ0(3-2) = XYZ0(3*I)
      G%XYZ(3*I-2) = XYZ(3*I-2)
      G%XYZ(3*I-1) = XYZ(3*I-1)
      G%XYZ(3-2) = XYZ(3*I)
   END DO
ENDDO READ_GEOM_LOOP
35 REWIND(LU_INPUT)

END SUBROUTINE READ_GEOM

! ------------ SUBROUTINE MREGE_GEOMS

SUBROUTINE MERGE_GEOMS(VERTS,N_VERTS,FACES,N_FACES)
   INTEGER N_VERTS, N_FACES, I, J
   INTEGER, DIMENSION(:) :: FACES(3*N_FACES)
   INTEGER, DIMENSION(:) :: OFFSETS(0:N_GEOM)
   REAL(EB), DIMENSION(:) :: VERTS(3*N_VERTS)
   TYPE(GEOMETRY_TYPE), POINTER :: G=>NULL()
   INTEGER :: IZERO
   
   OFFSETS(0)=0
   DO I = 1, N_GEOM
      G=>GEOMETRY(I)
      
      OFFSETS(I) = OFFSETS(I-1) + G%N_VERTS
   END DO
   DO I = 0, N_GEOM-1
      G=>GEOMETRY(I+1)
      DO J = 0, G%N_VERTS-1
         VERTS(3*I+3*J+1) = G%VERTS(3*J+1)
         VERTS(3*I+3*J+2) = G%VERTS(3*J+2)
         VERTS(3*I+3*J+3) = G%VERTS(3*J+3)
      END DO
      DO J = 0, G%N_FACES-1
         FACES(3*I+3*J+1) = G%FACES(3*J+1)+OFFSETS(I)
         FACES(3*I+3*J+2) = G%FACES(3*J+2)+OFFSETS(I)
         FACES(3*I+3*J+3) = G%FACES(3*J+3)+OFFSETS(I)
      END DO
   END DO
END SUBROUTINE MERGE_GEOMS

! ------------ SUBROUTINE WRITE_GEOM

SUBROUTINE WRITE_GEOM
INTEGER :: I
TYPE(GEOMETRY_TYPE), POINTER :: G=>NULL()
INTEGER :: N_VERTS, N_FACES
INTEGER, ALLOCATABLE, DIMENSION(:) :: FACES
REAL(EB), ALLOCATABLE, DIMENSION(:) :: VERTS
INTEGER :: IZERO
INTEGER :: ONE=1, ZERO=0, VERSION=0
REAL(FB) :: STIME=0.0
INTEGER :: N_VERT_S_VALS, N_VERT_D_VALS
INTEGER :: N_FACE_S_VALS, N_FACE_D_VALS

IF (N_GEOM.LE.0) RETURN
N_VERTS=0
N_FACES=0
DO I = 1, N_GEOM
   G=>GEOMETRY(I)
      
   N_VERTS = N_VERTS + G%N_VERTS
   N_FACES = N_FACES + G%N_FACES
END DO
IF(N_VERTS.LE.0.OR.N_VERTS.LE.0)RETURN

ALLOCATE(VERTS(3*N_VERTS),STAT=IZERO)
CALL ChkMemErr('WRITE_GEOM_TO_SMV','VERTS',IZERO)
   
ALLOCATE(FACES(3*N_FACES),STAT=IZERO)
CALL ChkMemErr('WRITE_GEOM_TO_SMV','FACES',IZERO)

CALL MERGE_GEOMS(VERTS,N_VERTS,FACES,N_FACES)

OPEN(LU_GEOM(1),FILE=FN_GEOM(1),FORM='UNFORMATTED',STATUS='REPLACE')

N_VERT_S_VALS=N_VERTS
N_VERT_D_VALS=0
N_FACE_S_VALS = N_FACES
N_FACE_D_VALS=0

WRITE(LU_GEOM(1)) ONE
WRITE(LU_GEOM(1)) VERSION
WRITE(LU_GEOM(1)) ZERO ! floating point header
WRITE(LU_GEOM(1)) ZERO ! integer header
WRITE(LU_GEOM(1)) N_VERT_S_VALS,N_FACE_S_VALS
IF (N_VERT_S_VALS>0) WRITE(LU_GEOM(1)) (REAL(VERTS(I),FB), I=1,3*N_VERT_S_VALS)
IF (N_FACE_S_VALS>0) THEN
   WRITE(LU_GEOM(1)) (FACES(I), I=1,3*N_FACE_S_VALS)
   WRITE(LU_GEOM(1)) (ZERO, I=1,N_FACE_S_VALS)
ENDIF
WRITE(LU_GEOM(1)) STIME,ZERO
WRITE(LU_GEOM(1)) ZERO,ZERO

END SUBROUTINE WRITE_GEOM

END MODULE COMPLEX_GEOMETRY