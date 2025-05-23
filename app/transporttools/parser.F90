!--------------------------------------------------------------------------------------------------!
!  DFTB+: general package for performing fast atomistic simulations                                !
!  Copyright (C) 2006 - 2025  DFTB+ developers group                                               !
!                                                                                                  !
!  See the LICENSE file for terms of usage and distribution.                                       !
!--------------------------------------------------------------------------------------------------!

#:include 'common.fypp'

!> Fills the derived type with the input parameters from an HSD or an XML file.
module transporttools_parser
  use transporttools_helpsetupgeom, only : setupGeometry
  use transporttools_inputdata, only : TInputData
  use dftbp_common_accuracy, only : distFudge, distFudgeOld, dp, lc, mc
  use dftbp_common_constants, only : Bohr__AA
  use dftbp_common_globalenv, only : stdOut, tIoProc
  use dftbp_common_unitconversion, only : lengthUnits
  use dftbp_dftb_slakoeqgrid, only : skEqGridNew, skEqGridOld
  use dftbp_dftbplus_oldcompat, only : convertOldHsd
  use dftbp_extlibs_xmlf90, only : assignment(=), char, destroyNode, destroyNodeList, fnode,&
      & fNodeList, getItem1, getLength, getNodeName, string
  use dftbp_io_charmanip, only : i2c, newline, tolower, unquote
  use dftbp_io_hsdparser, only : dumpHSD, getNodeHSDName, parseHSD
  use dftbp_io_hsdutils, only : detailedError, detailedWarning, getChild, getChildren,&
      & getChildValue, getSelectedAtomIndices
  use dftbp_io_hsdutils2, only : convertUnitHsd, setUnprocessed, warnUnprocessedNodes
  use dftbp_io_message, only : error, warning
  use dftbp_transport_negfvars, only : ContactInfo, TTransPar
  use dftbp_type_linkedlist, only : append, asArray, destruct, get, init, len, TListCharLc,&
      & TListReal, TListString
  use dftbp_type_oldskdata, only : readFromFile, TOldSKData
  use dftbp_type_typegeometryhsd, only : readTGeometryGen, readTGeometryHsd, TGeometry
  use dftbp_type_wrappedintr, only : TWrappedInt1
  implicit none

  private
  public :: parseHsdInput, parserVersion


  ! Default file names

  !> Main HSD input file
  character(len=*), parameter :: hsdInputName = "setup_in.hsd"

  !> XML input file
  character(len=*), parameter :: xmlInputName = "setup_in.xml"

  !> Processed HSD input
  character(len=*), parameter :: hsdProcInputName = "setup_pin.hsd"

  !> Processed  XML input
  character(len=*), parameter :: xmlProcInputName = "setup_pin.xml"

  !> Tag at the head of the input document tree
  character(len=*), parameter :: rootTag = "setup_in"


  !> Version of the current parser
  integer, parameter :: parserVersion = 6


  !> Version of the oldest parser for which compatibility is still maintained
  integer, parameter :: minVersion = 1


  !> Container type for parser related flags.
  type TParserFlags

    !> stop after parsing?
    logical :: tStop

    !> Continue despite unprocessed nodes
    logical :: tIgnoreUnprocessed

    !> XML output?
    logical :: tWriteXML

    !> HSD output?
    logical :: tWriteHSD
  end type TParserFlags


contains


  !> Parse input from an HSD/XML file
  subroutine parseHsdInput(input)

    !> Returns initialised input variables on exit
    type(TInputData), intent(out) :: input

    type(fnode), pointer :: hsdTree
    type(fnode), pointer :: root, tmp, child, dummy
    type(TParserflags) :: parserFlags

    write(stdOut, "(/, A, /)") "***  Parsing and initializing"

    ! Read in the input
    call parseHSD(rootTag, hsdInputName, hsdTree)
    call getChild(hsdTree, rootTag, root)

    write(stdout, '(A,1X,I0,/)') 'Parser version:', parserVersion
    write(stdout, "(A)") "Interpreting input file '" // hsdInputName // "'"
    write(stdout, "(A)") repeat("-", 80)

    ! Handle parser options
    call getChildValue(root, "ParserOptions", dummy, "", child=child, &
        &list=.true., allowEmptyValue=.true., dummyValue=.true.)
    call readParserOptions(child, root, parserFlags)

    ! Read in the different blocks

    ! Atomic geometry and boundary conditions
    call getChild(root, "Geometry", tmp)
    call readGeometry(tmp, input)

    call getChild(root, "Transport", child, requested=.false.)

    ! Read in transport and modify geometry if it is only a contact calculation
    if (associated(child)) then
      call readTransportGeometry(child, input%geom, input%transpar)
    else
      input%transpar%ncont=0
      allocate(input%transpar%contacts(0))
      ! set range of atoms in the 'device', as there are no contacts
      input%transpar%idxdevice(1) = 1
      input%transpar%idxdevice(2) = input%geom%nAtom
    end if
    ! input data strucutre has been initialised
    input%tInitialized = .true.

    ! Issue warning about unprocessed nodes
    call warnUnprocessedNodes(root, parserFlags%tIgnoreUnprocessed)

    ! Dump processed tree in HSD and XML format
    if (tIoProc .and. parserFlags%tWriteHSD) then
      call dumpHSD(hsdTree, hsdProcInputName)
      write(stdout, '(/,/,A)') "Processed input in HSD format written to '" &
          &// hsdProcInputName // "'"
    end if

    ! Stop, if only parsing is required
    if (parserFlags%tStop) then
      call error("Keyword 'StopAfterParsing' is set to Yes. Stopping.")
    end if

    call destroyNode(hsdTree)

    write(stdout,*) 'Geometry processed. Job finished'

  end subroutine parseHsdInput


  !> Read in parser options (options not passed to the main code)
  subroutine readParserOptions(node, root, flags)

    !> Node to get the information from
    type(fnode), pointer :: node

    !> Root of the entire tree (in case it needs to be converted, for example because dftbp_of
    !> compatibility options)
    type(fnode), pointer :: root

    !> Contains parser flags on exit.
    type(TParserFlags), intent(out) :: flags

    integer :: inputVersion
    type(fnode), pointer :: child

    ! Check if input needs compatibility conversion.
    call getChildValue(node, "ParserVersion", inputVersion, parserVersion, &
        &child=child)
    if (inputVersion < 1 .or. inputVersion > parserVersion) then
      call detailedError(child, "Invalid parser version (" // i2c(inputVersion)&
          &// ")")
    elseif (inputVersion < minVersion) then
      call detailedError(child, &
          &"Sorry, no compatibility mode for parser version " &
          &// i2c(inputVersion) // " (too old)")
    elseif (inputVersion /= parserVersion) then
      write(stdout, "(A,I2,A,I2,A)") "***  Converting input from version ", &
          &inputVersion, " to version ", parserVersion, " ..."
      call convertOldHSD(root, inputVersion, parserVersion)
      write(stdout, "(A,/)") "***  Done."
    end if

    call getChildValue(node, "WriteHSDInput", flags%tWriteHSD, .true.)
    call getChildValue(node, "WriteXMLInput", flags%tWriteXML, .false.)
    if (.not. (flags%tWriteHSD .or. flags%tWriteXML)) then
      call detailedWarning(node, &
          &"WriteHSDInput and WriteXMLInput both turned off. You are not&
          & guaranteed" &
          &// newline // &
          &" to able to obtain the same results with a later version of the&
          & code!")
    end if
    call getChildValue(node, "StopAfterParsing", flags%tStop, .false.)

    call getChildValue(node, "IgnoreUnprocessedNodes", &
        &flags%tIgnoreUnprocessed, .false.)

  end subroutine readParserOptions


  !> Read in Geometry
  subroutine readGeometry(node, input)

    !> Node to get the information from
    type(fnode), pointer :: node

    !> Input structure to be filled
    type(TInputData), intent(inout) :: input

    type(fnode), pointer :: value1, child
    type(string) :: buffer

    call getChildValue(node, "", value1, child=child)
    call getNodeName(value1, buffer)
    select case (char(buffer))
    case ("genformat")
      call readTGeometryGen(value1, input%geom)
    case default
      call setUnprocessed(value1)
      call readTGeometryHSD(child, input%geom)
    end select

  end subroutine readGeometry


  !> Read geometry information for transport calculation
  subroutine readTransportGeometry(root, geom, transpar)

    !> Root node containing the current block
    type(fnode), pointer :: root

    !> geometry of the system, which may be modified for some types of calculation
    type(TGeometry), intent(inout) :: geom

    !> Parameters of the transport calculation
    type(TTransPar), intent(inout) :: transpar

    type(fnode), pointer :: pDevice, pTask, pTaskType
    type(string) :: buffer
    type(fnodeList), pointer :: pNodeList
    real(dp) :: skCutoff
    type(TWrappedInt1), allocatable :: iAtInRegion(:)
    integer, allocatable :: nPLs(:)
    logical :: printDebug

    transpar%defined = .true.
    transpar%tPeriodic1D = .not. geom%tPeriodic

    !! Note: we parse first the task because dftbp_we need to know it to define the
    !! mandatory contact entries. On the other hand we need to wait that
    !! contacts are parsed to resolve the name of the contact for task =
    !! contacthamiltonian
    call getChildValue(root, "Task", pTask, child=pTaskType, default='uploadcontacts')
    call getNodeName(pTask, buffer)

    if (char(buffer).ne."setupgeometry") then
      call getChild(root, "Device", pDevice)
      call getChildValue(pDevice, "AtomRange", transpar%idxdevice)
    end if

    call getChildren(root, "Contact", pNodeList)
    transpar%ncont = getLength(pNodeList)
    if (transpar%ncont < 2) then
      call detailedError(root, "At least two contacts must be defined")
    end if
    allocate(transpar%contacts(transpar%ncont))

    select case (char(buffer))
    case ("setupgeometry")

      call readContacts(pNodeList, transpar%contacts, geom, char(buffer), iAtInRegion, nPLs)
      call getSKcutoff(pTask, geom, skCutoff)
      write(stdOut,*) 'Maximum SK cutoff:', SKcutoff*Bohr__AA,'(A)'
      call getChildValue(pTask, "printInfo", printDebug, .false.)
      call setupGeometry(geom, iAtInRegion, transpar%contacts, skCutoff, nPLs, printDebug)

    case default

      call getNodeHSDName(pTask, buffer)
      call detailedError(pTaskType, "Invalid task '" // char(buffer) // "'")

   end select

   call destroyNodeList(pNodeList)

  end subroutine readTransportGeometry


  !> Read bias information, used in Analysis and Green's function eigensolver
  subroutine readContacts(pNodeList, contacts, geom, task, iAtInRegion, nPLs)
    type(fnodeList), pointer :: pNodeList
    type(ContactInfo), allocatable, dimension(:), intent(inout) :: contacts
    type(TGeometry), intent(in) :: geom
    character(*), intent(in) :: task
    type(TWrappedInt1), allocatable, intent(out) :: iAtInRegion(:)
    integer, intent(out), allocatable :: nPLs(:)

    real(dp) :: contactLayerTol, vec(3)
    integer :: selectionRange(2)
    integer :: ii, ishift
    type(fnode), pointer :: field, pNode, pTmp
    type(string) :: buffer, modif
    type(TListReal) :: vecBuffer

    allocate(iAtInRegion(size(contacts)+1))
    allocate(nPLs(size(contacts)))

    do ii = 1, size(contacts)

      contacts(ii)%wideBand = .false.
      contacts(ii)%wideBandDos = 0.0_dp

      call getItem1(pNodeList, ii, pNode)
      call getChildValue(pNode, "Id", buffer, child=pTmp)
      buffer = tolower(trim(unquote(char(buffer))))
      if (len(buffer) > mc) then
        call detailedError(pTmp, "Contact id may not be longer than " // i2c(mc) // " characters.")
      end if
      contacts(ii)%name = char(buffer)
      if (any(contacts(1:ii-1)%name == contacts(ii)%name)) then
        call detailedError(pTmp, "Contact id '" // trim(contacts(ii)%name) &
            &//  "' already in use")
      end if

      call getChildValue(pNode, "PLShiftTolerance", contactLayerTol, 1e-5_dp, modifier=modif,&
          & child=field)
      call convertUnitHsd(char(modif), lengthUnits, field, contactLayerTol)

      if (task .eq. "setupgeometry") then
        call getChildValue(pNode, "PLsDefined", nPLs(ii))
        call getChildValue(pNode, "Atoms", buffer, child=pTmp, modifier=modif, multiple=.true.)
        if (isZeroBased(char(modif))) then
          selectionRange(:) = [0, size(geom%species) - 1]
          ishift = 1
        else
          selectionRange(:) = [1, size(geom%species)]
          ishift = 0
        end if
        call getSelectedAtomIndices(pTmp, char(buffer), geom%speciesNames, geom%species, &
            & iAtInRegion(ii)%data, selectionRange=selectionRange)
        iAtInRegion(ii)%data = iAtInRegion(ii)%data + ishift
        call init(vecBuffer)
        call getChildValue(pNode, "ContactVector", vecBuffer, modifier=modif)
        if (len(vecBuffer).eq.3) then
           call asArray(vecBuffer, vec)
           call convertUnitHsd(char(modif), lengthUnits, pNode, vec)
           ! check vector is along x y or z
           if (count(vec == 0.0_dp) < 2 ) then
             call error("ContactVector must be along either x, y or z")
           end if
           contacts(ii)%lattice = vec
           contacts(ii)%shiftAccuracy = contactLayerTol
           call destruct(vecBuffer)
        else
           call error("ContactVector must define three entries")
        end if
      else
        call error("Invalid task for setpugeometry tool")
      end if

    end do

    contains

      function isZeroBased(chr)
        character(*), intent(in) :: chr
        logical :: isZeroBased

        if (trim(chr) == "" .or. tolower(trim(chr)) == "onebased") then
          isZeroBased = .false.
        else if (tolower(trim(chr)) .eq. "zerobased") then
          isZeroBased = .true.
        else
          call error("Modifier in Atoms " // trim(chr) // " not recongnized")
        end if

      end function isZeroBased

  end subroutine readContacts


  subroutine getSKcutoff(node, geo, mSKCutoff)
    !> Node to get the information from
    type(fnode), pointer :: node

    !> Geometry structure to be filled
    type(TGeometry), intent(in) :: geo

    !> Maximum cutoff distance from sk files
    real(dp), intent(out) :: mSKCutoff

    ! Locals
    type(fnode), pointer :: child
    integer :: skInterMeth
    logical :: oldSKInter

    call getChildValue(node, "OldSKInterpolation", oldSKInter, .false.)
    if (oldSKInter) then
      skInterMeth = skEqGridOld
    else
      skInterMeth = skEqGridNew
    end if

    call getChild(node, "TruncateSKRange", child, requested=.false.)
    if (associated(child)) then
      call warning("Artificially truncating the SK table, this is normally a bad idea!")
      call SKTruncations(child, mSKCutOff, skInterMeth)
    else
      call readSKFiles(node, geo%nSpecies, geo%speciesNames, mSKCutOff)
    end if
    ! The fudge distance is added to get complete cutoff
    select case(skInterMeth)
    case(skEqGridOld)
      mSKCutOff = mSKCutOff + distFudgeOld
    case(skEqGridNew)
      mSKCutOff = mSKCutOff + distFudge
    end select

  end subroutine getSKcutoff

  !> Reads Slater-Koster files
  !> Should be replaced with a more sophisticated routine, once the new SK-format has been
  !> established
  subroutine readSKFiles(node, nSpecies, speciesNames, maxSKcutoff)
    !> Node to get the information from
    type(fnode), pointer :: node

    !> Nr. of species in the system
    integer, intent(in) :: nSpecies

    !> Array with specie names
    character(mc), intent(in) :: speciesNames(:)

    !> Maximum SK cutoff distance obtained from SK files
    real(dp), intent(out) :: maxSKcutoff

    type(fnode), pointer :: value1, child, child2
    type(string) :: buffer, buffer2
    type(TListString) :: lStr
    type(TListCharLc), allocatable :: skFiles(:,:)
    type(TOldSKData) :: skData
    integer :: iSp1, iSp2, ii
    character(lc) :: prefix, suffix, separator, elem1, elem2, strTmp
    character(lc) :: fileName
    logical :: tLower, tExist

    ! Slater-Koster files
    allocate(skFiles(nSpecies, nSpecies))
    do iSp1 = 1, nSpecies
      do iSp2 = 1, nSpecies
        call init(skFiles(iSp2, iSp1))
      end do
    end do
    call getChildValue(node, "SlaterKosterFiles", value1, child=child)
    call getNodeName(value1, buffer)
    select case(char(buffer))
    case ("type2filenames")
      call getChildValue(value1, "Prefix", buffer2, "")
      prefix = unquote(char(buffer2))
      call getChildValue(value1, "Suffix", buffer2, "")
      suffix = unquote(char(buffer2))
      call getChildValue(value1, "Separator", buffer2, "")
      separator = unquote(char(buffer2))
      call getChildValue(value1, "LowerCaseTypeName", tLower, .false.)
      do iSp1 = 1, nSpecies
        if (tLower) then
          elem1 = tolower(speciesNames(iSp1))
        else
          elem1 = speciesNames(iSp1)
        end if
        do iSp2 = 1, nSpecies
          if (tLower) then
            elem2 = tolower(speciesNames(iSp2))
          else
            elem2 = speciesNames(iSp2)
          end if
          strTmp = trim(prefix) // trim(elem1) // trim(separator) &
              &// trim(elem2) // trim(suffix)
          call append(skFiles(iSp2, iSp1), strTmp)
          inquire(file=strTmp, exist=tExist)
          if (.not. tExist) then
            call detailedError(value1, "SK file with generated name '" &
                &// trim(strTmp) // "' does not exist.")
          end if
        end do
      end do
    case default
      call setUnprocessed(value1)
      do iSp1 = 1, nSpecies
        do iSp2 = 1, nSpecies
          strTmp = trim(speciesNames(iSp1)) // "-" &
              &// trim(speciesNames(iSp2))
          call init(lStr)
          call getChildValue(child, trim(strTmp), lStr, child=child2)
          !if (len(lStr) /= len(angShells(iSp1)) * len(angShells(iSp2))) then
          !  call detailedError(child2, "Incorrect number of Slater-Koster &
          !      &files")
          !end if
          do ii = 1, len(lStr)
            call get(lStr, strTmp, ii)
            inquire(file=strTmp, exist=tExist)
            if (.not. tExist) then
              call detailedError(child2, "SK file '" // trim(strTmp) &
                  &// "' does not exist'")
            end if
            call append(skFiles(iSp2, iSp1), strTmp)
          end do
          call destruct(lStr)
        end do
      end do
    end select

    write(stdout, "(A)") "Reading SK-files:"
    do iSp1 = 1, nSpecies
      do iSp2 = iSp1, nSpecies
        call get(skFiles(iSp2, iSp1), fileName, 1)
        write(stdout,*) trim(fileName)
        call readFromFile(skData, fileName, (iSp1 == iSp2))
        maxSKcutoff = max(maxSKcutoff, skData%dist * size(skData%skHam,1))
      end do
    end do
    write(stdout, "(A)") "Done."
    write(stdout, *)

    do iSp1 = 1, nSpecies
      do iSp2 = 1, nSpecies
        call destruct(skFiles(iSp2, iSp1))
      end do
    end do
    deallocate(skFiles)

  end subroutine readSKFiles


  !> Options for truncation of the SK data sets at a fixed distance
  subroutine SKTruncations(node, truncationCutOff, skInterMeth)

    !> Relevant node in input tree
    type(fnode), pointer :: node

    !> This is the resulting cutoff distance
    real(dp), intent(out) :: truncationCutOff

    !> Method of the sk interpolation
    integer, intent(in) :: skInterMeth

    logical :: tHardCutOff
    type(fnode), pointer :: field
    type(string) :: modifier

    ! Artificially truncate the SK table
    call getChildValue(node, "SKMaxDistance", truncationCutOff, modifier=modifier, child=field)
    call convertUnitHsd(char(modifier), lengthUnits, field, truncationCutOff)

    call getChildValue(node, "HardCutOff", tHardCutOff, .true.)
    if (tHardCutOff) then
      ! Adjust by the length of the tail appended to the cutoff
      select case(skInterMeth)
      case(skEqGridOld)
        truncationCutOff = truncationCutOff - distFudgeOld
      case(skEqGridNew)
        truncationCutOff = truncationCutOff - distFudge
      end select
    end if
    if (truncationCutOff < epsilon(0.0_dp)) then
      call detailedError(field, "Truncation is shorter than the minimum distance over which SK data&
          & goes to 0")
    end if

  end subroutine SKTruncations

end module transporttools_parser
