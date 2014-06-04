program test
  use coop_wrapper
  implicit none
#include "constants.h"
#define PHI y(1)
#define PHIDOT y(2)
#define RHOM  y(3)
#define DPHI_DLNA yp(1)    
#define DPHIDOT_DLNA yp(2)    
#define DRHOM_DLNA yp(3)
#define Q_COUPLING args%r(1)
#define C_RUN args%r(2)
#define C_FLAT args%r(3)
#define N_POWER args%i(1)

!!example for coupled quintessence model 
!!V(phi) = c0 / phi^n + c1
!!I am not doing perfect initial conditions, you might get some initial small oscillations

  COOP_INT, parameter::nvars = 3  !!number of variables to evolve
  COOP_INT, parameter::nsteps = 1000  !!number of steps for output
  COOP_REAL, parameter:: MPl = 1.d0 !!define mass unit
  COOP_REAL, parameter:: H0 = 1.d0  !!define time unit
  COOP_REAL:: Q, c_run
  COOP_INT, parameter::npower = 1
  COOP_REAL,parameter:: rhom_ini = 1.e4 * (Mpl**2*H0**2)
  COOP_REAL,parameter:: phieq_ini = 0.005 * Mpl  
  COOP_REAL, parameter::c_flat = rhom_ini* 1.e-4
  COOP_REAL, parameter::lna_start = 0.
  COOP_REAL, parameter::lna_end = log(rhom_ini/c_flat)/3.d0 + 3.d0  !!add  3 more efolds to make sure rho_m < rho_phi happens
  COOP_INT:: itoday

  COOP_INT:: iQ

  type(coop_ode)::co
  type(coop_arguments)::args
  COOP_INT i
  COOP_REAL::phieq_dot_ini, hubble_ini
  COOP_REAL:: phi(nsteps), lna(nsteps), dotphi(nsteps), w(nsteps), Ev, Ek, Vpp, deltaphi
  type(coop_asy)::fp

  call fp%open("w.txt")
  call fp%init(xlabel = "$\ln a$", ylabel = "$w_\phi$", caption = "$\phi_{\rm ini} = "//trim(coop_num2str(phieq_ini/Mpl))//"M_p$" )
     

  do iQ = 1, 3
     Q = iQ * 0.15
     c_run = Q * rhom_ini * phieq_ini ** (npower + 1)/npower
     args = coop_arguments( i = (/ npower /),  r = (/ Q, c_run, c_flat /) )
     hubble_ini = sqrt((potential(phieq_ini, args) + rhom_ini)/(3.d0*Mpl**2))
     phieq_dot_ini = 3.d0*hubble_ini/(npower+1.d0)*phieq_ini
     deltaphi = phieq_ini/100.d0
     Vpp = (dVdphi(phieq_ini+deltaphi, args)- dVdphi(phieq_ini-deltaphi, args))/(2.d0*deltaphi)
     deltaphi = -3.d0*hubble_ini*phieq_dot_ini/Vpp
     if(abs(deltaphi/phieq_ini).gt. 0.1d0)then
        write(*,*) "V''=", Vpp
        write(*,*) deltaphi/Mpl, phieq_ini/Mpl
        stop "deltaphi too big"
     endif
     call co%init(n = nvars, method = COOP_ODE_DVERK)  !!initialize the ode solver
     call co%set_arguments(args = args)
     call co%set_initial_conditions( xini = lna_start, yini = (/ phieq_ini+deltaphi, phieq_dot_ini, rhom_ini /) )
     call coop_set_uniform(nsteps, lna, lna_start, lna_end)
     itoday = 0
     do  i = 1, nsteps
        if(i.gt.1)call co%evolve(get_yprime, lna(i))
        phi(i) = co%PHI / Mpl
        dotphi(i) = co%PHIDOT
        Ek = dotphi(i)**2/2.d0
        Ev = potential(phi(i), args)
        w(i) = (Ek -Ev)/(Ek+Ev)
        if((Ek+Ev)/co%RHOM .ge. (0.7/0.3) .and. itoday.eq.0)then
           itoday = i
        endif
     enddo
     if(itoday .eq. 0)then
        write(*,*) "you might want to increase lna_end"
        stop
     endif
     lna = lna - lna(itoday)  !!renormalize a=1 today

     select case(iQ)
     case(1)
        call coop_asy_curve(fp, x=lna(1:itoday), y=w(1:itoday), &
             color = "black", linewidth = 1., linetype="solid", &
             legend = "Q = "//trim(coop_num2str(co%Q_COUPLING, "(G10.4)")) )
     case(2)
        call coop_asy_curve(fp, x=lna(1:itoday), y=w(1:itoday), &
             color = "red", linewidth = 1.5, linetype="dotted", &
             legend = "Q = "//trim(coop_num2str(co%Q_COUPLING, "(G10.3)")) )
     case(3)
        call coop_asy_curve(fp, x=lna(1:itoday), y=w(1:itoday), &
             color = "blue", linewidth = 1.5, linetype="dashed", &
             legend = "Q = "//trim(coop_num2str(co%Q_COUPLING, "(G10.3)")) )
     end select

  enddo
  call coop_asy_legend(fp, x = fp%xmin*0.6+fp%xmax*0.4, y = fp%ymax*0.2 + fp%ymin*0.8)
  call coop_asy_label(fp, label = "$V(\phi) = C_0 + C_1 \phi^{-"//trim(coop_num2str(co%N_POWER))//"}$", x = fp%xmin*0.8+fp%xmax*0.2, y = fp%ymax*0.9 + fp%ymin*0.1)
  call fp%close()

contains


  function potential(phi, args) result(V)
    COOP_REAL phi, V
    type(coop_arguments) args
    V = C_RUN / phi**N_POWER + C_FLAT
  end function potential

  function dVdphi(phi, args) 
    COOP_REAL phi, dVdphi
    type(coop_arguments) args
    dVdphi = - C_RUN * N_POWER/phi**(N_POWER +1)
  end function dVdphi

  subroutine get_yprime(n, x, y, yp, args)
    COOP_INT n
    COOP_REAL x, y(n), yp(n), hubble, Ek, Ep, Vp
    type(coop_arguments) args
    Ek = PHIDOT ** 2 /2.d0
    Ep = potential(PHI, args)
    Vp = dVdphi(PHI, args)
    hubble = sqrt((Ek + Ep + RHOM)/(3.d0*MPl**2))
    DPHI_DLNA = PHIDOT / hubble
    DPHIDOT_DLNA = (-3.d0*hubble*PHIDOT - Vp - Q_COUPLING/Mpl * RHOM)/hubble
    DRHOM_DLNA = (-3.d0 +  Q_COUPLING/Mpl * PHIDOT / hubble)*RHOM
  end subroutine get_yprime

end program test
