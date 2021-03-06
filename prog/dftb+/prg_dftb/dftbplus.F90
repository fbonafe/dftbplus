!--------------------------------------------------------------------------------------------------!
!  DFTB+: general package for performing fast atomistic simulations                                !
!  Copyright (C) 2006 - 2020  DFTB+ developers group                                               !
!                                                                                                  !
!  See the LICENSE file for terms of usage and distribution.                                       !
!--------------------------------------------------------------------------------------------------!

#:include 'common.fypp'

program dftbplus
  use dftbp_globalenv
  use dftbp_environment, only : TEnvironment, TEnvironment_init
  use dftbp_main, only : runDftbPlus
  use dftbp_inputdata, only : TInputData
  use dftbp_formatout, only : printDftbHeader
  use dftbp_hsdhelpers, only : parseHsdInput
  use dftbp_initprogram, only : TDftbPlusMain
  implicit none

  character(len=*), parameter :: releaseName = '${RELEASE}$'
  integer, parameter :: releaseYear = 2020

  type(TEnvironment) :: env
  type(TInputData), allocatable :: input
  type(TDftbPlusMain) :: main

  call initGlobalEnv()
  call printDftbHeader(releaseName, releaseYear)
  allocate(input)
  call parseHsdInput(input)
  call TEnvironment_init(env)
  call main%initProgramVariables(input, env)
  deallocate(input)
  call runDftbPlus(main, env)
  call main%destructProgramVariables()
#:if WITH_GPU
  call magmaf_finalize()
#:endif
  call env%destruct()
  call destructGlobalEnv()

end program dftbplus
