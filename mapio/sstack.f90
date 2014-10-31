program hastack_prog
  use coop_wrapper_utils
  use coop_fitswrap_mod
  use coop_sphere_mod
  use coop_healpix_mod
  use head_fits
  use fitstools
  use pix_tools
  use alm_tools
  implicit none
#include "constants.h"
  COOP_INT, parameter::n_sim = 100
  COOP_UNKNOWN_STRING, parameter::color_table = "Rainbow"
  COOP_SHORT_STRING::spot_type, stack_type
  COOP_REAL, parameter::patch_size = 2.d0*coop_SI_degree
  COOP_UNKNOWN_STRING, parameter::cs_method = "commander"
  COOP_UNKNOWN_STRING, parameter::pol_case = "case3"
  
  COOP_UNKNOWN_STRING, parameter::prefix = "sst_"//cs_method//"_"//pol_case//"/"
  COOP_INT, parameter::mmax = 4
  COOP_REAL, parameter::fwhm_arcmin = 10.d0
  COOP_REAL, parameter::fwhm_in = 10.d0
  COOP_UNKNOWN_STRING, parameter::input_resolution =   "_010a_1024"
  COOP_UNKNOWN_STRING, parameter::postfix =  input_resolution//".fits"

  COOP_STRING::allprefix
  COOP_UNKNOWN_STRING, parameter::mapdir = "/mnt/scratch-lustre/zqhuang/scratch-3month/zqhuang/"
  COOP_REAL,parameter::fwhm = coop_SI_arcmin * sqrt(fwhm_arcmin**2-fwhm_in**2)
  COOP_REAL, parameter::threshold = 0
  COOP_REAL, parameter::dr = coop_SI_arcmin * max(fwhm_arcmin/4.d0, 5.d0)
  COOP_INT, parameter::n = nint(patch_size/dr)

  COOP_UNKNOWN_STRING, parameter::imap_file  = "planck14/dx11_v2_"//cs_method//"_int_cmb"//postfix
  COOP_UNKNOWN_STRING, parameter::polmap_file  = "planck14/dx11_v2_"//cs_method//"_pol_"//pol_case//"_cmb"//postfix
  COOP_UNKNOWN_STRING, parameter::imask_file  = "planck14/dx11_v2_common_int_mask"//postfix
  COOP_UNKNOWN_STRING, parameter::polmask_file  ="planck14/dx11_v2_common_pol_mask"//postfix

  type(coop_healpix_maps)::polmask, imask, noise, imap, polmap, tmpmap
  type(coop_healpix_patch)::patch
  COOP_INT i, j, ind, nmaps_temp
  COOP_STRING::fr_file
  type(coop_list_integer)::listpix
  type(coop_list_real)::listangle
  type(coop_file) fp
  call coop_MPI_init()
  spot_type = trim(coop_InputArgs(1))
  stack_type = trim(coop_InputArgs(2))
  if(trim(spot_type) .eq. "" .or. trim(stack_type).eq."")then
     print*, "Syntax:"
     print*, "./SST Tmax  T"
     print*, "./SST Tmax  QrUr"
     print*, "./SST Tmax  QU"     
     print*, "./SST Tmax_QTUTOrient QU"
     print*, "./SST PTmax QU"
  endif
  call imask%read(imask_file, nmaps_wanted = 1, spin = (/ 0 /) )
  if(trim(stack_type) .ne. "T")then
     call polmask%read(polmask_file, nmaps_wanted = 1, spin = (/ 0 /) )
  endif
  
  call patch%init(trim(stack_type), n, dr, mmax = mmax)
  if(fwhm .gt. coop_SI_arcmin)then
     allprefix = prefix//trim(stack_type)//"_on_"//trim(spot_type)//"_fr_"//COOP_STR_OF(nint(patch_size/coop_SI_degree))//"deg"//input_resolution//"_smooth"//COOP_STR_OF(nint(fwhm_arcmin))
  else
     allprefix = prefix//trim(stack_type)//"_on_"//trim(spot_type)//"_fr_"//COOP_STR_OF(nint(patch_size/coop_SI_degree))//"deg"//input_resolution//"_nosmooth"
  endif

  call fp%open(trim(allprefix)//"_info.txt", "w")
  write(fp%unit,*) n, patch%nmaps, dr/coop_SI_arcmin
  call fp%close()

  fr_file = trim(allprefix)//".dat"
  ind = -1
  if(.not. coop_file_exists(trim(fr_file)))goto 200
  call fp%open(trim(fr_file), "ru")
  do
     read(fp%unit, ERR=100, END=100) i
     read(fp%unit, ERR=100, END=100) patch%fr
     if(i.ne.ind+1) call cooP_MPI_Abort("fr file broken")
     ind = i
     if(ind .ge. n_sim) exit
  enddo
100 write(*,*) "Loaded "//trim(coop_num2str(ind+1))//" maps from checkpoint"
  call fp%close()
200 call fp%open(trim(fr_file), "u")
  do i=0, ind
     read(fp%unit, ERR=100, END=100) j
     read(fp%unit, ERR=100, END=100) patch%fr
     if(j.ne.i)call cooP_MPI_Abort("fr file broken")
  enddo
  do while(ind .lt. n_sim)
     ind = ind + 1
     call load_imap(ind)
     select case(trim(stack_type))
     case("T")
        noise%map = imap%map
        call noise%get_listpix(listpix, listangle, trim(spot_type), threshold, imask)
        call imap%stack_with_listpix(patch, listpix, listangle, imask)
     case default
        call imap%get_listpix(listpix, listangle, trim(spot_type), threshold, imask)
        call load_polmap(ind)
        call polmap%stack_with_listpix(patch, listpix, listangle, polmask)
     end select
     call patch%get_all_radial_profiles()
     write(fp%unit) ind
     write(fp%unit) patch%fr
     flush(fp%unit)
  enddo
  call fp%close()
  call coop_MPI_Finalize()

contains

  subroutine load_imap(i)
    COOP_INT i, nm
    COOP_INT,dimension(:),allocatable::spin
    if(trim(spot_type) .eq. "PTmax" .or. trim(spot_type) .eq. "Tmax_QTUTOrient")then
       nm = 3
    else
       nm = 1
    endif
    allocate(spin(nm))
    spin(1) = 0
    if(nm.gt.1) spin(2:3) = 2
    if(i.eq.0)then
       call imap%read(filename = trim(imap_file), nmaps_wanted = nm , spin = spin , nmaps_to_read = 1 )
       imap%map(:, 1) = imap%map(:, 1)*imask%map(:, 1)
       if(fwhm.ge.coop_SI_arcmin)    call imap%smooth(fwhm)
       noise = imap
    else
       call imap%read(trim(sim_file_name_cmb_imap(i)), nmaps_wanted = nm , spin = spin , nmaps_to_read = 1 )
       call noise%read(trim(sim_file_name_noise_imap(i)), nmaps_wanted = nm , spin = spin, nmaps_to_read = 1 )
       imap%map(:, 1) = (imap%map(:, 1) + noise%map(:, 1))*imask%map(:, 1)
       if(fwhm.ge.coop_SI_arcmin)    call imap%smooth(fwhm)
    endif
    deallocate(spin)
    if(nm.gt.1)call imap%iqu2TQTUT()
  end subroutine load_imap


  subroutine load_polmap(i)
    COOP_INT i
    if(i.eq.0)then
       call polmap%read(trim(polmap_file), spin = (/2 , 2 /) , nmaps_wanted = 2  )
       polmap%map(:, 1) = polmap%map(:, 1)*polmask%map(:, 1)
       polmap%map(:, 2) = polmap%map(:, 2)*polmask%map(:, 1)
       if(fwhm.ge.coop_SI_arcmin)call polmap%smooth(fwhm)
    else
       call polmap%read(trim(sim_file_name_cmb_polmap(i)), spin = (/2 , 2 /) , nmaps_wanted = 2  )
       call noise%read(trim(sim_file_name_noise_polmap(i)), spin = (/2 , 2 /) , nmaps_wanted = 2 )
       polmap%map(:, 1) = (polmap%map(:, 1) + noise%map(:, 1))*polmask%map(:, 1)
       polmap%map(:, 2) = (polmap%map(:, 2) + noise%map(:, 2))*polmask%map(:, 1)
       if(fwhm.ge.coop_SI_arcmin)call polmap%smooth(fwhm)
    endif
  end subroutine load_polmap


  function sim_file_name_cmb_imap(i)
    COOP_INT i
    COOP_STRING sim_file_name_cmb_imap
    sim_file_name_cmb_imap = mapdir//"cmb/int/dx11_v2_"//cs_method//"_int_cmb_mc_"//trim(coop_Ndigits(i-1, 5))//postfix
  end function sim_file_name_cmb_imap

  function sim_file_name_noise_imap(i)
    COOP_INT i
    COOP_STRING sim_file_name_noise_imap
    sim_file_name_noise_imap = mapdir//"noise/int/dx11_v2_"//cs_method//"_int_noise_mc_"//trim(coop_Ndigits(i-1, 5))//postfix
  end function sim_file_name_noise_imap


  function sim_file_name_cmb_polmap(i)
    COOP_INT i
    COOP_STRING sim_file_name_cmb_polmap
    sim_file_name_cmb_polmap = mapdir//"cmb/pol/dx11_v2_"//cs_method//"_pol_"//pol_case//"_cmb_mc_"//trim(coop_Ndigits(i-1, 5))//postfix
  end function sim_file_name_cmb_polmap

  function sim_file_name_noise_polmap(i)
    COOP_INT i
    COOP_STRING sim_file_name_noise_polmap
    sim_file_name_noise_polmap = mapdir//"noise/pol/dx11_v2_"//cs_method//"_pol_"//pol_case//"_noise_mc_"//trim(coop_Ndigits(i-1, 5))//postfix
  end function sim_file_name_noise_polmap

end program hastack_prog