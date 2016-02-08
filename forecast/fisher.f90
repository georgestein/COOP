module coop_fisher_mod
  use coop_halofit_mod
  use coop_wrapper_firstorder
  implicit none
#include "constants.h"

  COOP_REAL,parameter::coop_fisher_tolerance = 1.d-6
  COOP_INT,parameter::coop_parameter_type_slow = 0
  COOP_INT,parameter::coop_parameter_type_fast = 1
  COOP_INT,parameter::coop_parameter_type_nuis = 2

  type coop_observation
     COOP_STRING::filename = ""
     type(coop_dictionary)::settings
     COOP_STRING::name = ""
     COOP_STRING::genre = ""
     COOP_INT::n_obs = 0
     COOP_INT::dim_obs = 0
     COOP_INT::dim_nuis = 0
     type(coop_int_table)::paramnames
     COOP_REAL,dimension(:,:),allocatable::obs !!(dim_obs, n_obs)
     COOP_REAL,dimension(:,:,:),allocatable::dobs !!(dim_obs, n_obs, paramnames%n)
     COOP_REAL,dimension(:,:),allocatable::nuis  !!(dim_nuis, n_obs)
     COOP_REAL,dimension(:,:,:),allocatable::invcov !!(dim, dim, n_obs)
   contains
     procedure::free => coop_observation_free
     procedure::init => coop_observation_init
     procedure::get_dobs => coop_observation_get_dobs
     procedure::get_invcov => coop_observation_get_invcov
  end type coop_observation
  
  type coop_fisher
     type(coop_cosmology_firstorder)::cosmology
     type(coop_dictionary)::settings
     type(coop_real_table)::paramtable
     COOP_INT::n_params = 0
     COOP_INT::n_params_used = 0
     COOP_INT::n_slow
     COOP_INT::n_fast
     COOP_INT::n_nuis
     COOP_INT::n_observations = 0
     COOP_REAL,dimension(:),allocatable::params
     COOP_REAL,dimension(:),allocatable::step1
     COOP_REAL,dimension(:),allocatable::step2
     COOP_REAL,dimension(:),allocatable::priors
     COOP_INT,dimension(:),allocatable::ind_slow, ind_fast, ind_nuis, param_types
     COOP_REAL,dimension(:,:),allocatable::fisher
     COOP_REAL,dimension(:,:),allocatable::Cov
     COOP_INT,dimension(:),allocatable::ind_used
     logical,dimension(:),allocatable::is_used
     type(coop_observation),dimension(:),allocatable::observations
   contains
     procedure::init => coop_fisher_init
     procedure::free => coop_fisher_free
     procedure::get_fisher => coop_fisher_get_fisher
  end type coop_fisher

contains

  subroutine coop_observation_get_dobs(this, dobs, paramtable, cosmology)
    class(coop_observation)::this
    COOP_REAL::dobs(this%dim_obs, this%n_obs), MStar
    type(coop_real_table)::paramtable
    type(coop_cosmology_firstorder)::cosmology
    COOP_INT::i, idata
    select case(trim(this%genre))
    case("SN")
       call paramtable%lookup("sn_absolute_m", Mstar)
       !$omp parallel do
       do idata = 1, this%n_obs
          dobs(1, idata) = 5.d0*log10(cosmology%luminosity_distance(1.d0/(1.d0+this%nuis(1, idata)))/cosmology%H0Mpc()) + Mstar  - this%obs(1, idata) 
       enddo
       !$omp end parallel do
    case("MPK")
    case("CMB_TE")
    case("CMB_T")
    case("CMB_E")
    case("CMB_B")
    case default
       write(*,*) trim(this%genre)
       stop "unknown observation genre"
    end select
  end subroutine coop_observation_get_dobs

  subroutine coop_observation_get_invcov(this, paramtable, cosmology)
    COOP_REAL,parameter::sn_intrinsic_delta_mu = 0.1d0
    COOP_REAL,parameter::sn_peculiar_velocity = 4.d5/coop_SI_c
    class(coop_observation)::this
    type(coop_real_table)::paramtable
    type(coop_cosmology_firstorder)::cosmology
    COOP_INT idata
    COOP_REAL::Mstar
    select case(trim(this%genre))
    case("SN")
       call paramtable%lookup("sn_absolute_m", Mstar)
       !$omp parallel do
       do idata = 1, this%n_obs
          this%obs(1, idata) =  5.d0*log10(cosmology%luminosity_distance(1.d0/(1.d0+this%nuis(1, idata)))/cosmology%H0Mpc()) + Mstar
          this%invcov(1, 1, idata) = this%nuis(2, idata)/(sn_intrinsic_delta_mu**2 + (sn_peculiar_velocity/this%nuis(1, idata))**2)
       enddo
       !$omp end parallel do
    case("MPK")
    case("CMB_TE")
    case("CMB_T")
    case("CMB_E")
    case("CMB_B")
    case default
       write(*,*) trim(this%genre)
       stop "unknown observation genre"
    end select
  end subroutine coop_observation_get_invcov

  subroutine coop_observation_init(this, filename)
    class(coop_observation)::this
    COOP_UNKNOWN_STRING,optional::filename
    type(coop_list_string)::ls
    type(coop_list_real)::lr
    COOP_INT::i
    if(present(filename))this%filename = trim(adjustl(filename))
    if(trim(this%filename) .eq. "") stop "observation_init: empty file name"
    call coop_load_dictionary(this%filename, this%settings)
    call coop_dictionary_lookup(this%settings, "genre", this%genre)
    call coop_dictionary_lookup(this%settings, "name", this%name, "COOP_OBSERVATION_"//trim(this%genre))
    call coop_dictionary_lookup(this%settings, "n_obs", this%n_obs)
    this%genre = COOP_UPPER_STR(this%genre)
    select case(trim(this%genre))
    case("SN")
       this%dim_obs = 1  !!distance moduli
       this%dim_nuis = 2  !!z, n_samples
    case("MPK")
       this%dim_obs = 1 !!matter power spectrum
       this%dim_nuis = 4   !!z, k, n, bias
    case("CMB_TE")
       this%dim_obs = 3 !!TT, TE, EE
       this%dim_nuis = 2 !! l, fsky
    case("CMB_T", "CMB_E", "CMB_B")
       this%dim_obs = 1
       this%dim_nuis = 2 !!l, fsky
    case default
       write(*,*) trim(this%genre)
       stop "Error: unknown observation genre"
    end select
    call coop_dictionary_lookup(this%settings, "params", ls)
    do i=1, ls%n
       call this%paramnames%insert(ls%element(i), i)  
    enddo
    allocate(this%obs(this%dim_obs, this%n_obs), this%nuis(this%dim_nuis, this%n_obs), this%invcov(this%dim_obs, this%dim_obs, this%n_obs), this%dobs(this%dim_obs, this%n_obs, this%paramnames%n))
    call ls%free()

    select case(trim(this%genre))
    case("SN")
       call coop_dictionary_lookup(this%settings, "z", lr)
       if(lr%n .ne. this%n_obs)then
          write(*,*) "Error in "//trim(this%filename)
          write(*,*) "Number of redshift bins does not equal to n_obs"
          stop
       endif
       !$omp parallel do
       do i = 1, this%n_obs
          this%nuis(1, i) = lr%element(i)
       enddo
       !$omp end parallel do
       call lr%free()

       call coop_dictionary_lookup(this%settings, "n_samples", lr)
       if(lr%n .ne. this%n_obs)then
          write(*,*) "Error in "//trim(this%filename)
          write(*,*) "Length of n_samples list does not equal to n_obs"
          stop
       endif
       !$omp parallel do
       do i = 1, this%n_obs
          this%nuis(2, i) = lr%element(i)
       enddo
       !$omp end parallel do
       call lr%free()
    case("MPK")
    case("CMB_TE")
    case("CMB_T", "CMB_E", "CMB_B")
    case default
       write(*,*) trim(this%genre)
       stop "Error: unknown observation genre"
    end select


  end subroutine coop_observation_init

  subroutine coop_observation_free(this)
    class(coop_observation)::this
    call this%settings%free()
    call this%paramnames%free()
    COOP_DEALLOC(this%obs)
    COOP_DEALLOC(this%dobs)
    COOP_DEALLOC(this%invcov)
    COOP_DEALLOC(this%nuis)
    this%n_obs = 0
    this%dim_obs = 0
    this%dim_nuis = 0
    this%genre = ""
    this%name = ""
    this%filename = ""
  end subroutine coop_observation_free


  subroutine coop_fisher_free(this)
    class(coop_fisher)::this
    COOP_INT::i, j
    call this%settings%free()
    call this%cosmology%free()
    call this%paramtable%free()
    COOP_DEALLOC(this%params)
    COOP_DEALLOC(this%step1)
    COOP_DEALLOC(this%step2)
    COOP_DEALLOC(this%priors)
    COOP_DEALLOC(this%param_types)
    COOP_DEALLOC(this%ind_slow)
    COOP_DEALLOC(this%ind_fast)
    COOP_DEALLOC(this%ind_nuis)
    COOP_DEALLOC(this%fisher)
    COOP_DEALLOC(this%cov)
    COOP_DEALLOC(this%ind_used)
    COOP_DEALLOC(this%is_used)
    if(allocated(this%observations))then
       do i=1, this%n_observations
          call this%observations(i)%free()
       enddo
       deallocate(this%observations)
    endif
    this%n_params = 0
    this%n_params_used = 0
    this%n_observations = 0
  end subroutine coop_fisher_free

  subroutine coop_fisher_init(this, filename)
    class(coop_fisher)::this
    COOP_UNKNOWN_STRING::filename  
    type(coop_list_string)::ls
    type(coop_list_real)::lr
    logical::success
    COOP_INT::i, j, ip
    call this%free()
    call coop_load_dictionary(filename, this%settings)
    call coop_dictionary_lookup(dict = this%settings, key="n_params", val = this%n_params)
    allocate(this%params(this%n_params), this%step1(this%n_params), this%step2(this%n_params), this%priors(this%n_params), this%fisher(this%n_params, this%n_params), this%cov(this%n_params, this%n_params), this%is_used(this%n_params), this%param_types(this%n_params))
    this%fisher = 0.d0
    this%cov = 0.d0
    this%is_used = .false.
    call coop_dictionary_lookup(this%settings, "param_names", ls)
    if(ls%n .ne. this%n_params) stop "Error in fisher_init: size of param_names does not equal to n_params"

    do i = 1, this%n_params
       call coop_dictionary_lookup(this%settings,  "param["//trim(ls%element(i))//"]", lr)
       select case(lr%n)
       case(1)
          this%params(i) = lr%element(1)
          this%step1(i) = 0.d0
          this%step2(i) = 0.d0
          this%priors(i) = 0.d0
       case(2)
          this%params(i) = lr%element(1)
          this%step1(i) = lr%element(2)
          this%step2(i) = -this%step1(i)
          this%priors(i) = abs(this%step1(i))*1.d5 !! making this finite rather than infinity helps to beat down the numeric instability from round-off errors.
       case(3)
          this%params(i) = lr%element(1)
          this%step1(i) = lr%element(2)
          this%step2(i) = lr%element(3)
          this%priors(i) = max(abs(this%step1(i)), abs(this%step2(i)))*1.d5 !! making this finite rather than infinity helps to beat down the numeric instability from round-off errors.
       case(4)
          this%params(i) = lr%element(1)
          this%step1(i) = lr%element(2)
          this%step2(i) = lr%element(3)
          this%priors(i) = lr%element(4)
       case default
          write(*,*)  "param["//trim(ls%element(i))//"] seems to be not right, the format is:"
          write(*,*)  "param["//trim(ls%element(i))//"] = fiducial step1 step2 prior"
          stop
       end select
       if(this%priors(i).ne.0.d0 .and. (this%step1(i).eq.0.d0 .or. this%step2(i).eq.0.d0))then
          write(*,*)  "param["//trim(ls%element(i))//"] seems to be not right, the format is:"
          write(*,*)  "param["//trim(ls%element(i))//"] = fiducial step1 step2 prior"
          stop
       endif
       call this%paramtable%insert(trim(ls%element(i)), this%params(i))
    enddo
    call ls%free()
    call lr%free()

    this%param_types = coop_parameter_type_nuis
    !!the parameters that require recomputing cosmological perturbations
    call coop_dictionary_lookup(this%settings,"params_slow", ls) !!
    this%n_slow = ls%n
    allocate(this%ind_slow(ls%n))
    do i = 1, ls%n
       j = this%paramtable%index(trim(ls%element(i)))
       if(j.eq.0)then
          write(*,*) trim(ls%element(i))//" appears in param_slow but not in params"
          stop
       endif
       if(this%param_types(j).ne. coop_parameter_type_nuis)then
          write(*,*) "Error: "//trim(ls%element(i))//" duplicated in params_slow"
          stop
       endif
       this%ind_slow(i) = j
       this%param_types(j) = coop_parameter_type_slow
    enddo
    call ls%free()

    !!the parameters that require updating primordial power spectrum
    call coop_dictionary_lookup(this%settings,"params_fast", ls)
    this%n_fast = ls%n
    allocate(this%ind_fast(ls%n))
    do i = 1, ls%n
       j = this%paramtable%index(trim(ls%element(i)))
       if(j.eq.0)then
          write(*,*) trim(ls%element(i))//" appears in param_fast but not in params"
          stop
       endif
       if(this%param_types(j).ne. coop_parameter_type_nuis)then
          write(*,*) "Error: "//trim(ls%element(i))//" duplicated in params_fast"
          stop
       endif
       this%ind_fast(i) = j
       this%param_types(j) = coop_parameter_type_fast
    enddo
    call ls%free()

    j = 0
    this%n_nuis = this%n_params - this%n_slow - this%n_fast
    allocate(this%ind_nuis(this%n_nuis))
    do i=1, this%n_params
       if(this%param_types(i).eq.coop_parameter_type_nuis)then
          j = j + 1
          this%ind_nuis(j) = i
       endif
    enddo

    call coop_dictionary_lookup(dict = this%settings, key="n_observations", val = this%n_observations)
    if(this%n_observations .gt. 0)then
       allocate(this%observations(this%n_observations))
       do i=1, this%n_observations
          call coop_dictionary_lookup(this%settings, "observation"//COOP_STR_OF(i), this%observations(i)%filename)
          call this%observations(i)%init()
          do j=1, this%observations(i)%paramnames%n
              this%observations(i)%paramnames%val(j) = this%paramtable%index( this%observations(i)%paramnames%key(j) )
             if( this%observations(i)%paramnames%val(j) .eq. 0)then
                write(*,*) "Error in fisher_init:"
                write(*,*) "parameter "//trim(this%observations(i)%paramnames%key(j))//" (required by dataset "//trim(this%observations(i)%name)//") is not found."
             endif
          enddo
       enddo
    endif

    !!compute the fiducial cosmology
    call this%cosmology%set_up(this%paramtable, success)
    if(.not. success)then
       write(*,*) "cannot set up the cosmology, check the parameter range:"
       call this%paramtable%print()
       stop
    endif
    do i = 1, this%n_observations
       call this%observations(i)%get_invcov(this%paramtable, this%cosmology)
    enddo
  end subroutine coop_fisher_init

  subroutine coop_fisher_get_dobs_slow(this, i)
    class(coop_fisher)::this
    COOP_INT::i, iobs, j
    logical::success
    type(coop_real_table)::paramtable_tmp
    type(coop_cosmology_firstorder)::cosmology_tmp
    COOP_REAL,dimension(:,:),allocatable::dobs_tmp
    if(this%priors(i).eq. 0.d0)then
       do iobs = 1, this%n_observations
          j = this%observations(iobs)%paramnames%index(this%paramtable%key(i))
          if(j.ne.0)this%observations(iobs)%dobs(:,:,j) = 0.d0
       enddo
       return
    endif

    paramtable_tmp = this%paramtable
    paramtable_tmp%val(i) = this%paramtable%val(i) + this%step1(i)
    call  cosmology_tmp%set_up(paramtable_tmp, success)
    if(.not. success)then
       write(*,*) "cannot set up the cosmology, check the parameter range:"
       call paramtable_tmp%print()
       stop
    endif
    do iobs = 1, this%n_observations
       j = this%observations(iobs)%paramnames%index(this%paramtable%key(i)) 
       if(j.ne.0)then
          call this%observations(iobs)%get_dobs( this%observations(iobs)%dobs(:,:,j), paramtable_tmp, cosmology_tmp)
       endif
    enddo

    paramtable_tmp%val(i) = this%paramtable%val(i) + this%step2(i)
    call  cosmology_tmp%set_up(paramtable_tmp, success)
    if(.not. success)then
       write(*,*) "cannot set up the cosmology, check the parameter range:"
       call paramtable_tmp%print()
       stop
    endif
    do iobs = 1, this%n_observations
       j = this%observations(iobs)%paramnames%index(this%paramtable%key(i)) 
       if(j.ne.0)then
          allocate(dobs_tmp(this%observations(iobs)%dim_obs, this%observations(iobs)%n_obs))
          call this%observations(iobs)%get_dobs(dobs_tmp, paramtable_tmp, cosmology_tmp)
          this%observations(iobs)%dobs(:,:,j) = (this%observations(iobs)%dobs(:,:,j) - dobs_tmp * (this%step1(i)/this%step2(i))**2)/(1.d0- this%step1(i)/this%step2(i))
          deallocate(dobs_tmp)
       endif
    enddo
    call cosmology_tmp%free()
    call paramtable_tmp%free()
  end subroutine coop_fisher_get_dobs_slow

  subroutine coop_fisher_get_dobs_fast(this, i)
    class(coop_fisher)::this
    COOP_INT::i, iobs, j
    type(coop_real_table)::paramtable_tmp
    type(coop_cosmology_firstorder)::cosmology_tmp
    COOP_REAL,dimension(:,:),allocatable::dobs_tmp
    if(this%priors(i).eq. 0.d0)then
       do iobs = 1, this%n_observations
          j = this%observations(iobs)%paramnames%index(this%paramtable%key(i))
          if(j.ne.0)this%observations(iobs)%dobs(:,:,j) = 0.d0
       enddo
       return
    endif
    paramtable_tmp = this%paramtable
    cosmology_tmp = this%cosmology

    paramtable_tmp%val(i) = this%paramtable%val(i) + this%step1(i)
    call cosmology_tmp%set_primordial_power(paramtable_tmp)


    do iobs = 1, this%n_observations
       j = this%observations(iobs)%paramnames%index(this%paramtable%key(i)) 
       if(j.ne.0)then
          call this%observations(iobs)%get_dobs( this%observations(iobs)%dobs(:,:,j), paramtable_tmp, cosmology_tmp)
       endif
    enddo

    paramtable_tmp%val(i) = this%paramtable%val(i) + this%step2(i)
    call cosmology_tmp%set_primordial_power(paramtable_tmp)
    do iobs = 1, this%n_observations
       j = this%observations(iobs)%paramnames%index(this%paramtable%key(i)) 
       if(j.ne.0)then
          allocate(dobs_tmp(this%observations(iobs)%dim_obs, this%observations(iobs)%n_obs))
          call this%observations(iobs)%get_dobs(dobs_tmp, paramtable_tmp, cosmology_tmp)
          this%observations(iobs)%dobs(:,:,j) = (this%observations(iobs)%dobs(:,:,j) - dobs_tmp * (this%step1(i)/this%step2(i))**2)/(1.d0- this%step1(i)/this%step2(i))
          deallocate(dobs_tmp)
       endif
    enddo
    call cosmology_tmp%free()
    call paramtable_tmp%free()

  end subroutine coop_fisher_get_dobs_fast

  subroutine coop_fisher_get_dobs_nuis(this, i)
    class(coop_fisher)::this
    COOP_INT::i, iobs, j
    type(coop_real_table)::paramtable_tmp
    COOP_REAL,dimension(:,:),allocatable::dobs_tmp
    if(this%priors(i).eq. 0.d0)then
       do iobs = 1, this%n_observations
          j = this%observations(iobs)%paramnames%index(this%paramtable%key(i))
          if(j.ne.0)this%observations(iobs)%dobs(:,:,j) = 0.d0
       enddo
       return
    endif




    paramtable_tmp = this%paramtable

    paramtable_tmp%val(i) = this%paramtable%val(i) + this%step1(i)
    do iobs = 1, this%n_observations
       j = this%observations(iobs)%paramnames%index(this%paramtable%key(i)) 
       if(j.ne.0)then
          call this%observations(iobs)%get_dobs( this%observations(iobs)%dobs(:,:,j), paramtable_tmp, this%cosmology)
       endif
    enddo

    paramtable_tmp%val(i) = this%paramtable%val(i) + this%step2(i)
    do iobs = 1, this%n_observations
       j = this%observations(iobs)%paramnames%index(this%paramtable%key(i)) 
       if(j.ne.0)then
          allocate(dobs_tmp(this%observations(iobs)%dim_obs, this%observations(iobs)%n_obs))
          call this%observations(iobs)%get_dobs(dobs_tmp, paramtable_tmp, this%cosmology)
          this%observations(iobs)%dobs(:,:,j) = (this%observations(iobs)%dobs(:,:,j) - dobs_tmp * (this%step1(i)/this%step2(i))**2)/(1.d0- this%step1(i)/this%step2(i))
          deallocate(dobs_tmp)
       endif
    enddo
    call paramtable_tmp%free()
  end subroutine coop_fisher_get_dobs_nuis

  subroutine coop_fisher_get_fisher(this)
    class(coop_fisher)::this
    COOP_INT::i, idata, j
    COOP_REAL, dimension(:,:),allocatable::cov
    this%fisher = 0.d0
    !$omp parallel do
    do i = 1, this%n_slow
       call coop_fisher_get_dobs_slow(this, this%ind_slow(i))
    enddo
    !$omp end parallel do
    !$omp parallel do
    do i = 1, this%n_fast
       call coop_fisher_get_dobs_fast(this, this%ind_fast(i))
    enddo
    !$omp end parallel do
    !$omp parallel do
    do i = 1, this%n_nuis
       call coop_fisher_get_dobs_nuis(this, this%ind_nuis(i))
    enddo
    !$omp end parallel do

    do i = 1, this%n_observations
       do idata = 1, this%observations(i)%n_obs
          this%fisher(this%observations(i)%paramnames%val(1:this%observations(i)%paramnames%n), this%observations(i)%paramnames%val(1:this%observations(i)%paramnames%n)) &
               = this%fisher(this%observations(i)%paramnames%val(1:this%observations(i)%paramnames%n), this%observations(i)%paramnames%val(1:this%observations(i)%paramnames%n)) &
               + matmul(transpose(this%observations(i)%dobs(:,idata,:)), matmul(this%observations(i)%invcov(:, :, idata), this%observations(i)%dobs(:, idata, :)))
       enddo
    enddo


    !!compute the covariance matrix
    this%n_params_used = 0
    do i=1, this%n_params
       if(this%fisher(i, i) .gt. coop_fisher_tolerance)then
          this%is_used(i) = .true.
          this%n_params_used = this%n_params_used + 1
       else
          this%is_used(i) = .false.
       endif
    enddo


    do i=1, this%n_params
       if(this%is_used(i))this%fisher(i,i) = this%fisher(i,i) + (this%step1(i)/this%priors(i))**2
    enddo

    COOP_DEALLOC(this%ind_used)
    allocate(this%ind_used(this%n_params_used), cov(this%n_params_used, this%n_params_used))
    j = 0
    do i = 1, this%n_params
       if(this%is_used(i))then
          j = j + 1
          this%ind_used(j) = i
       endif
    enddo
    cov = this%fisher(this%ind_used, this%ind_used)
    call coop_sympos_inverse(this%n_params_used, this%n_params_used, cov)
    this%cov(this%ind_used, this%ind_used) = cov
    do i = 1, this%n_params
       if(this%is_used(i))then
          this%fisher(i,:) = this%fisher(i,:) /this%step1(i)
          this%fisher(:,i) = this%fisher(:,i) /this%step1(i)
          this%cov(i,:) = this%cov(i,:) *this%step1(i)
          this%cov(:,i) = this%cov(:,i) *this%step1(i)
       endif
    enddo
    deallocate(cov)
  end subroutine coop_fisher_get_fisher


end module coop_fisher_mod
