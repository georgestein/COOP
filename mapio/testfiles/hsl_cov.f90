program test
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

  COOP_UNKNOWN_STRING, parameter::prefix="hsl6deg20a/T_on_Tmax_"
  COOP_INT, parameter::nside = 4
  COOP_INT, parameter::nfiles = nside**2*6
  COOP_INT, parameter::nsims = 1000
  COOP_INT, parameter::nbins = 6
  COOP_INT, parameter::npix_per_bin = 6
  COOP_INT, parameter::npix = nbins*npix_per_bin
  COOP_INT i, j, k1, k2, cnt, pix, imin
  COOP_REAL minprob, l, b
  type(coop_healpix_maps)::map
  COOP_REAL::diff(nbins, nsims), cov(nbins, nbins), ddf(nbins), mean(nbins), junk(2), line(0:npix), chi2data,  prob(0:nfiles-1), theta, phi, rms(nbins)
  type(coop_file)::fp
  call map%init(nside = nside, nmaps=1, spin = (/ 0 /))
  minprob = 1.d30
  do i=0, nfiles-1
     call fp%open(prefix//"log_"//COOP_STR_OF(nside)//"_"//COOP_STR_OF(i)//".txt", "r")
     read(fp%unit, *) k1, k2, theta, phi, junk
     read(fp%unit, *) line
     call do_bins(line, ddf)
     call fp%close()

     call fp%open(prefix//"fr_"//COOP_STR_OF(nside)//"_"//COOP_STR_OF(i)//".txt", "r")
     do j=1, nsims
        read(fp%unit, *)line
        call do_bins(line, diff(:, j))
     enddo
     call fp%close()
     do j=1, nbins
        mean(j) = sum(diff(j, :))/nsims
     enddo
     do k1 = 1, nbins
        do k2 = 1, k1
           cov(k1, k2) = sum((diff(k1, :)-mean(k1))*(diff(k2, :) - mean(k2)))/nsims
           if(k1.ne.k2) cov(k2, k1) = cov(k1, k2)
        enddo
        rms(k1) = sqrt(cov(k1, k1))
     enddo
     call coop_matsym_inverse(cov)
     chi2data = chisq(ddf)
     cnt = 0
     do j=1, nsims
        if(chisq(diff(:, j)).gt.chi2data)then
           cnt = cnt + 1
        endif
     enddo
     prob(i) = dble(cnt)/nsims
     write(*, "(I5, 20F9.1)") i, chi2data, prob(i)*100., (ddf-mean)/rms
     map%map(i, 1) = log10(prob(i))
     if(prob(i).lt. minprob)then
        minprob = prob(i)
        imin = i
     endif
     theta = coop_pi - theta
     phi = coop_pi + phi
     call ang2pix_ring(map%nside, theta, phi, pix)
     map%map(pix, 1) = map%map(i, 1)  

  enddo
  call map%write("hsl_T_on_Tmax.fits")
  call pix2ang_ring(map%nside, imin, theta, phi)
  call coop_healpix_ang2lb(theta, phi, l, b)
  write(*,"(A, F10.1)") "min prob = ", minprob*100, "%"
  write(*,*) "direction l = ", nint(l), " b = ", nint(b)

contains

  function chisq(fb)
    COOP_REAL fb(nbins), chisq
    chisq = dot_product(fb-mean, matmul(cov, fb-mean))
  end function chisq

  subroutine do_bins(fraw, fb)
    COOP_REAL fraw(0:npix), fb(nbins)
    COOP_INT i
    fraw = fraw - fraw(0)
    do i=1, nbins
       fb(i) = sum(fraw( (i-1)*npix_per_bin+1  : i*npix_per_bin))/npix_per_bin
    enddo
  end subroutine do_bins



end program test
