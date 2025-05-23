!--------------------------------------------------------------------------------------------------!
!  DFTB+: general package for performing fast atomistic simulations                                !
!  Copyright (C) 2006 - 2025  DFTB+ developers group                                               !
!                                                                                                  !
!  See the LICENSE file for terms of usage and distribution.                                       !
!--------------------------------------------------------------------------------------------------!

#:include 'common.fypp'

!> MAGMA GPU interface library
module dftbp_extlibs_magma
  use, intrinsic :: iso_c_binding, only : c_int
#:if WITH_MAGMA
  use magma, only : magmaf_cheevd_m, magmaf_chegvd_m, magmaf_dsyevd_m, magmaf_dsygvd_m,&
      & magmaf_ssyevd_m, magmaf_ssygvd_m, magmaf_zheevd_m, magmaf_zhegvd_m
#:endif
  implicit none

  private
  public :: withGpu
#:if WITH_MAGMA
  public :: getGpusAvailable, getGpusRequested, gpusInit
  public :: magmaf_ssygvd_m, magmaf_dsygvd_m, magmaf_chegvd_m, magmaf_zhegvd_m
  public :: magmaf_ssyevd_m, magmaf_dsyevd_m, magmaf_cheevd_m, magmaf_zheevd_m
#:endif

  !> Whether code was built with GPU support
  logical, parameter :: withGpu = ${FORTRAN_LOGICAL(WITH_MAGMA)}$

#:if WITH_MAGMA

  interface

    !> Initialises magma.
    subroutine  gpusInit() bind(C, name='magma_init')

      implicit none

    end subroutine gpusInit


    !> Initialises magma and queries the nr. of available GPUs.
    subroutine  getGpusAvailable(nGpu) bind(C, name='dftbp_extlibs_magma_get_gpus_available')

      import :: c_int
      implicit none

      !> Nr. of GPUs found
      integer(c_int), intent(out) :: nGpu

    end subroutine getGpusAvailable


    !> Returns the nr. of GPUs requested by MAGMA.
    subroutine getGpusRequested(nGpuReq) bind(C, name='dftbp_extlibs_magma_get_gpus_requested')

      import :: c_int
      implicit none

      !> Nr. of requested GPUs.
      integer(c_int), intent(out) :: nGpuReq

    end subroutine getGpusRequested

  end interface

#:endif

end module dftbp_extlibs_magma
