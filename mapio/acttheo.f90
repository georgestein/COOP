program stackth
  use coop_wrapper_utils
  use coop_fitswrap_mod
  use coop_sphere_mod  
  use coop_healpix_mod
#ifdef HAS_HEALPIX  
  use head_fits
  use fitstools
  use pix_tools
  use alm_tools
#endif  
  implicit none
#include "constants.h"

#ifdef HAS_HEALPIX
  logical::normalize_sigma0 = .false.
  COOP_REAL::sigma0_norm = 59.141857614604476d0
  integer, parameter::lmin = 2, lmax=2500, index_TT = 1, index_TE = 4, index_EE=2
  COOP_REAL, parameter:: r_degree = 2.d0
  COOP_REAL, parameter:: width = 2.d0*sin(r_degree*coop_SI_degree/2.d0)
  COOP_INT,parameter:: n=36
  COOP_REAL, parameter:: dr = width/n
  logical,parameter::flat = .false. !!use nonflat is actually faster
  !!settings
  COOP_INT,parameter::hp_lowl = 230
  COOP_INT,parameter::hp_highl = 270
  integer::index_corr = index_TT 
  integer::index_auto = index_TT
  COOP_STRING::clfile ="planck14best_lensedCls.dat"
  COOP_STRING::spot_type, stack_field
  COOP_REAL::nu !! threshold
  COOP_REAL::fwhm !!fwhm in arcmin
  COOP_INT::head_level
  COOP_STRING::prefix, line
  type(coop_file)::fp, fpfr
  type(coop_asy)::figCr, fpI(0:2), fpQU(0:2)
  integer l, il, i, j, iomega, m
  type(coop_arguments)::args
  type(coop_healpix_patch)::patchI, patchQU, patchQrUr
  COOP_REAL::Pl0(0:lmax), Pl2(0:lmax), Pl4(0:lmax)
  COOP_REAL::cls(4, 2:lmax), ell(2:lmax), sigma, l2cls(4,2:lmax), sigma2, sigma0, sigma1, cosbeta, j2, j4, j0, omega, weights(4), cr(0:1, 0:2, 0:n*3/2), frI(0:2, 0:n*3/2), frQU(0:2, 0:n*3/2), pomega, phi, romega, r(0:n*3/2), kr, norm
  norm = (COOP_DEFAULT_TCMB*1.e6)**2/coop_2pi
  line = coop_InputArgs(5)
  if(trim(line).eq."")then
     write(*,*) "Syntax:"
     write(*,*) "./ACTTheo clfile spot_type stack_field nu fwhm_arcmin [output_prefix] [head_level]"
     stop
  endif
  coop_healpix_patch_default_want_caption = .true.
  coop_healpix_patch_default_want_label  = .true.
  coop_healpix_patch_default_want_arrow  = .true.
  coop_healpix_patch_default_figure_width = 3.5
  coop_healpix_patch_default_figure_height = 3.1
  
  
  read(line, *) fwhm

  if(trim(coop_InputArgs(1)) .ne. trim(clfile))then
     clfile = trim(coop_InputArgs(1))
     normalize_sigma0 = .true.
     write(*,*) "warning: normalizing sigma_0"
  endif
  spot_type =  trim(coop_InputArgs(2))
  stack_field = trim(coop_InputArgs(3))
  line = coop_InputArgs(4)
  read(line, *) nu
  if(trim(coop_InputArgs(6)).ne."")then
     prefix = "rprof/"//trim(coop_InputArgs(6))//"_"
  else
     prefix = "rprof/"
  endif
  if(trim(coop_InputArgs(7)).ne."")then
     line = coop_InputArgs(7)
     read(line,*) head_level
  else
     head_level = 0
  endif

  select case(trim(spot_type))
  case("Pmax", "Emax")
     index_auto = index_EE
  case default
     index_auto = index_TT
  end select
  select case(trim(stack_field))
  case("T")
     if(index_auto .eq. index_TT)then
        index_corr = index_TT
     else
        index_corr = index_TE
     endif
  case("QU")
     if(index_auto .eq. index_TT)then
        index_corr = index_TE
     else
        index_corr = index_EE
     endif
  case default
     stop "ACTTheo so far only support stacking T or QU"
  end select
  call coop_random_init()
  sigma = fwhm*coop_sigma_by_fwhm*coop_SI_arcmin
  write(*,*) "filter l1, l2 = ", hp_lowl, hp_highl  
  call fp%open(clfile, "r")
  do l=2, lmax
     read(fp%unit, *) il, l2cls(:, l)
     ell(l)  = l
     l2cls(:,l) = l2cls(:, l)*(coop_2pi*exp(-l*(l+1.d0)*sigma**2))
     l2cls(:,l) = l2cls(:,l)*(coop_highpass_filter(hp_lowl, hp_highl, l))**2
     cls(:,l) = l2cls(:,l)/(l*(l+1.d0))
     if(il.ne.l) stop "cl file broken"

  enddo

  call fp%close()
  sigma0 = sqrt(sum(Cls(index_auto,:)*(ell+0.5d0))/coop_2pi)
  if(normalize_sigma0)then
     write(*,*) "***********Warning: Normalizing sigma0!!!!**********"
     Cls = Cls*(sigma0_norm/sigma0)**2
     l2Cls = L2Cls*(sigma0_norm/sigma0)**2
     sigma0 = sigma0_norm
  endif
  sigma1 = sqrt(sum(l2Cls(index_auto,:)*(ell+0.5d0))/coop_2pi)
  sigma2 = sqrt(sum(l2Cls(index_auto,:)*(ell+0.5d0)*(ell*(ell+1.d0)))/coop_2pi)
  cosbeta = sigma1**2/sigma0/sigma2
  print*, "gamma = ", cosbeta
  print*, "sigma_0 = ", sigma0
  print*, "sigma_2 = ", sigma2  
  call coop_gaussian_npeak_set_args(args, 2, sigma0, sigma1, sigma2)
  print*, "nmax = ", coop_gaussian_nmax(nu, args)
  select case(trim(spot_type))
  case("Tmax_QTUTOrient", "Tmin_QTUTOrient")
     call coop_gaussian_get_oriented_stacking_weights(nu, args, weights)
  case("Tmax", "Emax", "Bmax", "Tmin", "Emin", "Bmin")
     call coop_gaussian_get_nonoriented_stacking_weights(nu, args, weights)
  case("PTmax", "Pmax")
     call coop_gaussian_get_pmax_stacking_weights(nu, args, weights)
  case("RANDOMmax", "RANDOMmin")
     call coop_gaussian_get_fieldpoints_nonoriented_stacking_weights(nu, args, weights)
  case("RANDOMmax_QTUTOrient", "RANDOMmin_QTUTOrient")
     call coop_gaussian_get_fieldpoints_oriented_stacking_weights(nu, args, weights)
  case default
     write(*,*) trim(spot_type)
     stop "Unknown spot type"
  end select
  
  write(*,*) "Weights = ", weights(1)*sigma0, weights(2)*sigma2, weights(3)*sigma0, weights(4)*sigma2

  do m=0,2
     call fpI(m)%open(trim(prefix)//"I_fwhm"//COOP_STR_OF(nint(fwhm))//"_m"//COOP_STR_OF(m*2)//".txt")
     call fpQU(m)%open(trim(prefix)//"QU_fwhm"//COOP_STR_OF(nint(fwhm))//"_m"//COOP_STR_OF(m*2)//".txt")
     if(head_level .ge. 1)then
        if(head_level.ge.2)then
           call fpI(m)%init(xlabel="$\varpi$", ylabel="$T_"//COOP_STR_OF(m*2)//"$")
           call fpQU(m)%init(xlabel="$\varpi$", ylabel="$P_"//COOP_STR_OF(m*2)//"$")
        endif
        write(fpI(m)%unit, "(A)") "CURVE"
        write(fpQU(m)%unit, "(A)") "CURVE"
        write(fpI(m)%unit, "(I6)") n+1
        write(fpQU(m)%unit, "(I6)") n+1
        write(fpI(m)%unit, "(A)") "Theory"
        write(fpQU(m)%unit, "(A)") "Theory"
        write(fpI(m)%unit, "(A)") "blue_dashed"
        write(fpQU(m)%unit, "(A)") "blue_dashed"
        write(fpI(m)%unit, "(A)") "0"
        write(fpQU(m)%unit, "(A)") "0"
     endif
  enddo
  cr = 0.d0       
  do i = 0, n*3/2
     omega = dr*i
     r(i) = omega
     if(.not.flat)then  !!get Plms
        call coop_get_normalized_Plm_array(m=0, lmax=lmax, x = 1.d0-omega**2/2.d0, Plms = Pl0)
        call coop_get_normalized_Plm_array(m=2, lmax=lmax, x = 1.d0-omega**2/2.d0, Plms = Pl2)
        call coop_get_normalized_Plm_array(m=4, lmax=lmax, x = 1.d0-omega**2/2.d0, Plms = Pl4)
     endif
     do l = lmin, lmax
        if(flat)then
           kr = sqrt(l*(l+1.d0))*omega
           j0 = coop_bessj(0, kr)
           j2 = coop_bessj(2, kr)
           j4 = coop_bessj(4, kr)
        else
           j0 = Pl0(l)
           j2 = Pl2(l)
           j4 = Pl4(l)
        endif
        cr(0, 0, i) = cr(0, 0, i) + (l+0.5d0)*j0*cls(index_corr, l)
        cr(1, 0, i) = cr(1, 0, i) - (l+0.5d0)*j0*l2cls(index_corr, l)
        cr(0, 1, i) = cr(0, 1, i) + (l+0.5d0)*j2*cls(index_corr, l)
        cr(1, 1, i) = cr(1, 1, i) - (l+0.5d0)*j2*l2cls(index_corr, l)
        cr(0, 2, i) = cr(0, 2, i) + (l+0.5d0)*j4*cls(index_corr, l)
        cr(1, 2, i) = cr(1, 2, i) - (l+0.5d0)*j4*l2cls(index_corr, l)        
     enddo
     cr(:,:,i) = cr(:,:,i)/coop_2pi
     call coop_gaussian_radial_modes_I(weights, cr(:,:,i), frI(:, i))
     call coop_gaussian_radial_modes_QU(weights, cr(:,:,i), frQU(:, i))
  enddo
  if(trim(spot_type) .eq. "Tmin_QTUTOrient" .or. trim(spot_type).eq. "Tmin" .or. trim(spot_type).eq. "RANDOMmin" .or. trim(spot_type).eq. "RANDOMmin_QTUTOrient")then
     frI(0,:) = -frI(0,:)
     frQU(1,:) = -frQU(1,:)
  endif
  call patchI%init("T", n, dr)
  call patchQU%init("QU", n, dr)
  call patchQrUr%init("QrUr", n, dr)
  patchI%nstack = 1.d0
  patchQU%nstack = 1.d0
  patchQrUr%nstack = 1.d0
  patchI%nstack_raw = 1.d0
  patchQU%nstack_raw = 1.d0
  patchQrUr%nstack_raw = 1.d0  
  do i=-n, n
     do j=-n, n
        if(i.eq.0.and.j.eq.0)then
           patchI%image(i,j,1) = frI(0,0)
           patchQU%image(i,j,1) = frQU(0, 0)
           patchQU%image(i,j,2) = 0.d0
           patchQrUr%image(i,j,1) = frQU(0, 0)
           patchQrUr%image(i,j,2) = 0.d0
        else
           phi = atan2(dble(j), dble(i))
           omega = sqrt(dble(i)**2+dble(j)**2)
           iomega = floor(omega)
           romega = omega - iomega
           patchI%image(i,j,1) = (frI(0, iomega)+ frI(1, iomega)*cos(2*phi) + frI(2, iomega)*cos(4*phi) ) *(1.d0-romega)+(frI(0, iomega+1)+ frI(1, iomega+1)*cos(2*phi) + frI(2, iomega+1)*cos(4*phi) ) * romega
           patchQU%image(i, j,1) = (frQU(0, iomega)+ frQU(1, iomega)*cos(2*phi) + frQU(2, iomega)*cos(4*phi) ) *(1.d0-romega)+(frQU(0, iomega+1)+ frQU(1, iomega+1)*cos(2*phi) + frQU(2, iomega+1)*cos(4*phi) ) * romega
           patchQU%image(i, j, 2) = (frQU(1, iomega)*sin(2*phi) + frQU(2, iomega)*sin(4*phi) ) *(1.d0-romega)+(frQU(0, iomega+1)+ frQU(1, iomega+1)*sin(2*phi) + frQU(2, iomega+1)*sin(4*phi) ) * romega
           patchQrUr%image(i, j, 1) = -patchQU%image(i, j,1)*cos(2*phi) - patchQU%image(i, j, 2)*sin(2*phi)  !!urgh, the stupid minus sign...
           patchQrUr%image(i, j, 2) = patchQU%image(i, j,1)*sin(2*phi) - patchQU%image(i, j, 2)*cos(2*phi)
        endif
     enddo
  enddo
  patchI%caption = "best-fit $\Lambda$CDM theory, $\nu="//COOP_STR_OF(nint(nu))//"$"
  patchQU%caption = "best-fit $\Lambda$CDM theory, $\nu="//COOP_STR_OF(nint(nu))//"$"
  patchQrUr%caption = "best-fit $\Lambda$CDM theory, $\nu="//COOP_STR_OF(nint(nu))//"$"
  call patchI%plot(1, trim(prefix)//"I_stack.txt")
  call patchQU%plot(1, trim(prefix)//"Q_stack.txt")
  call patchQU%plot(2, trim(prefix)//"U_stack.txt")
  call patchQrUr%plot(1, trim(prefix)//"Qr_stack.txt")
  call patchQrUr%plot(2, trim(prefix)//"Ur_stack.txt")
  
  !!test the integrator
  call patchI%get_all_radial_profiles()
  call patchQU%get_all_radial_profiles()
  call fpfr%open(trim(prefix)//"frI.txt", "w")
  write(fpfr%unit, *) patchI%fr
  call fpfr%close()
  call fpfr%open(trim(prefix)//"frQU.txt", "w")
  write(fpfr%unit, *) patchQU%fr
  call fpfr%close()
  do i=0, n
     do m=0,2
        if(head_level.eq.0)then
           write(fpI(m)%unit, "(3E16.7)") dr*i, frI(m, i), patchI%fr(i, m, 1)
           write(fpQU(m)%unit, "(4E16.7)") dr*i, frQU(m, i), patchQU%fr(i, m, 1), patchQU%fr(i, m, 2)          
        else
           write(fpI(m)%unit, "(2E16.7)") dr*i, frI(m, i)
           write(fpQU(m)%unit, "(2E16.7)") dr*i, frQU(m, i)
        endif
     enddo
  enddo
  
  call figCr%open(trim(prefix)//"cr.txt")
  call figCr%init(xlabel="$\varpi$", ylabel="$c_{m,n}(\varpi)$")
  call figCr%curve(x = r, y = cr(0,0,:)/sigma0, color="red", linewidth=1.8, linetype="solid", legend="$c_{0,0}(\varpi)/\sigma_0$")
  call figCr%curve(x = r, y = cr(0,1,:)/sigma0, color="orange", linewidth=1.5, linetype="dotted", legend="$c_{0,1}(\varpi)/\sigma_0$")
  call figCr%curve(x = r, y = cr(0,2,:)/sigma0, color="violet", linewidth=1.2, linetype="dashed", legend="$c_{0,2}(\varpi)/\sigma_0$")  
  call figCr%curve(x = r, y = -cr(1,0,:)/sigma2, color="blue", linewidth=1.8, linetype="solid", legend="$-c_{1,0}(\varpi)/\sigma_2$")  
  
  call figCr%curve(x = r, y = -cr(1,1,:)/sigma2, color="black", linewidth=1.5, linetype="dotted", legend="$-c_{1,1}(\varpi)/\sigma_2$")  

  call figCr%curve(x = r, y = -cr(1,2,:)/sigma2, color="skblue", linewidth=1.2, linetype="dashed", legend="$-c_{1,2}(\varpi)/\sigma_2$")  
  
  call figCr%legend(0.5, 0.9, 1)
  call figCr%close()

#else
  stop "you need to install healpix"
#endif  

end program stackth
