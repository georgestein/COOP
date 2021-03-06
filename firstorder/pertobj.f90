module coop_pertobj_mod
  use coop_wrapper_background
  implicit none
#include "constants.h"

  COOP_INT, parameter:: coop_pert_default_lmax = 32  
  COOP_INT, parameter:: coop_pert_default_mmax = 2
  COOP_INT, parameter:: coop_pert_default_smax = 2


  COOP_INT, parameter:: coop_pert_default_nq = 5
  COOP_REAL, dimension(coop_pert_default_nq),parameter:: coop_pert_default_q = coop_fermion_int_q5
  COOP_REAL, dimension(coop_pert_default_nq),parameter:: coop_pert_default_q_kernel = coop_fermion_int_kernel5 
  COOP_REAL, dimension(coop_pert_default_nq), parameter::coop_pert_massivenu_threshold = 0.1d0 * coop_pert_default_q !!ma > threshold considered to be massive
  COOP_REAL, parameter::coop_pert_massivenu_cold_threshold = 50.d0 !!ma > threshold considered to be cold 
  type coop_pert_species
     COOP_INT::genre = COOP_PERT_NONE !!NONE = no perturbations, other options are PERFECT_FLUID, HIERARCHY
     COOP_INT::m = 0
     COOP_INT::s = 0
     COOP_INT::lmin = 0
     COOP_INT::lmax = -1
     COOP_INT::nvars = 0
     COOP_INT::index = -1
     COOP_INT::last_index = -1
     COOP_REAL,dimension(0:coop_pert_default_lmax)::F = 0.d0
     COOP_INT,dimension(-1:coop_pert_default_lmax+1)::i = 0
     COOP_REAL::q, mass
   contains
     procedure::set_defaults => coop_pert_species_set_defaults     
  end type coop_pert_species

  type coop_pert_object
     COOP_REAL::k, a, aH, daHdtau, HdotbyHsq, tau, tauc, taucdot, R, rhoa2_b, rhoa2_c, rhoa2_nu, rhoa2_de, rhoa2_g, rhoa2_mnu, pa2_mnu, pa2_g, pa2_nu, pa2_de, rhoa2_sum, pa2_sum, cs2b, capP, kbyaH, ksq, kbyaHsq, latedamp, delta_gamma
#if DO_EFT_DE
     COOP_INT::de_scheme = 0     
     COOP_REAL::M2, alpha_M, alpha_K, alpha_T, alpha_B, alpha_H, alpha_M_prime, alpha_K_prime, alpha_T_prime, alpha_B_prime, alpha_H_prime, HdotbyHsq_prime, p_prime_a2_matter, rho_prime_a2_matter, pa2_matter, rhoa2_matter, HddbyH3, u
     COOP_REAL::deMat(7, 5)
#elif DO_COUPLED_DE
     COOP_REAL::de_Vp, de_phidot, de_delta_rho, de_delta_p
#endif     
     COOP_STRING::initial_conditions = "adiabatic"
     logical::tight_coupling = .true.
     logical::massivenu_cold = .false.
     logical::want_source = .false.
     COOP_REAL::num_mnu_ratio = 0.d0
     COOP_INT::massivenu_iq_used = 0
     COOP_INT::m = 0
     COOP_INT::ny = 0
     COOP_REAL::deltatr_mnu = 0.d0
     COOP_REAL::deltap_mnu = 0.d0
     COOP_REAL::O1_phi, O1_phipr, slip, T2prime, E2prime
     !!only used for source
     COOP_REAL::Pdot, vis, ekappa, visdot, kchi
     type(coop_pert_species)::metric, baryon, cdm, T, E, B, nu, de
     type(coop_pert_species),dimension(coop_pert_default_nq)::massivenu !!massive neutrinos

     COOP_REAL,dimension(:),allocatable::y, yp
   contains
     procedure::init =>  coop_pert_object_initialize
     procedure::save_ode => coop_pert_object_save_ode
     procedure::restore_ode => coop_pert_object_restore_ode
     procedure::free =>  coop_pert_object_free
     procedure::set_zero => coop_pert_object_set_zero
     procedure::delta_T00a2 => coop_pert_object_delta_T00a2
     procedure::delta_G00a2 => coop_pert_object_delta_G00a2
     procedure::delta_T0ia2 => coop_pert_object_delta_T0ia2
     procedure::delta_G0ia2 => coop_pert_object_delta_G0ia2
     procedure::zeta => coop_pert_object_zeta  !!covmoving curvature fluctuations
     procedure::print => coop_pert_object_print
  end type coop_pert_object


contains

  function coop_pert_object_delta_T00a2(pert) result(T00)
    class(coop_pert_object)::pert
    COOP_REAL::T00
    T00 =  - pert%rhoa2_b*pert%O1_DELTA_B &
          - pert%rhoa2_c*pert%O1_DELTA_C &
          - pert%rhoa2_g*pert%O1_T(0) &
          - pert%rhoa2_nu*(pert%O1_NU(0))
    if(pert%num_mnu_ratio .ne. 0.d0)then
       if(pert%massivenu_cold)then
          T00 = T00 - pert%rhoa2_mnu * pert%O1_MASSIVENU(0, 1)
       else
         T00 = T00 - pert%rhoa2_nu * (pert%deltatr_mnu + pert%deltap_mnu)
      endif
      endif
    select case(pert%de%genre)
    case (COOP_PERT_NONE)
       !!do nothing
#if DO_COUPLED_DE       
    case(COOP_PERT_SCALAR_FIELD)
       T00 = T00  -  pert%de_delta_rho*pert%a**2
#endif       
#if DO_EFT_DE       
    case(COOP_PERT_EFT)
       T00 = T00/pert%M2 - pert%aH**2 * ( &
            (pert%alpha_K - pert%alpha_B*6.d0)*(pert%O1_DE_HPIPR - pert%HdotbyHsq * pert%O1_DE_HPI) &
            + 6.d0*(pert%alpha_B*pert%HdotbyHsq + pert%u + pert%kbyaHsq/3.d0*(pert%alpha_H - pert%alpha_B))*pert%O1_DE_HPI)
#endif       
    case default
       call coop_tbw("T00: de perturbations not written")
    end select

  end function coop_pert_object_delta_T00a2

  function coop_pert_object_delta_G00a2(pert) result(G00)
    class(coop_pert_object)::pert
    COOP_REAL::G00
#if DO_EFT_DE
    G00 = 2.d0*(pert%k**2 * pert%O1_PSI*(1.d0+pert%alpha_H) + 3.d0*pert%aH**2*((1.d0+pert%alpha_B)*pert%O1_PSIPR + pert%O1_Phi*(1.d0-pert%alpha_K/6.d0+pert%alpha_B*2.d0)))    
#else    
    G00 = 2.d0*(pert%k**2 * pert%O1_PSI + 3.d0*pert%aH**2*(pert%O1_PSIPR + pert%O1_Phi))
#endif    
  end function coop_pert_object_delta_G00a2

  function coop_pert_object_delta_T0ia2(pert) result(T0i)
    class(coop_pert_object)::pert
    integer iq
    COOP_REAL::T0i, Fmnu1(coop_pert_default_nq)
    T0i = (pert%rhoa2_c)*pert%O1_V_C &
         + (pert%rhoa2_b)*pert%O1_V_B &
         + (pert%rhoa2_nu + pert%pa2_nu)*pert%O1_NU(1)/4.d0 &
         + (pert%rhoa2_g + pert%pa2_g)* pert%O1_T(1)/4.d0 
    if(pert%num_mnu_ratio .gt. 0.d0)then
       if(pert%massivenu_cold)then
          T0i = T0i + (pert%rhoa2_mnu + pert%pa2_mnu)*pert%O1_MASSIVENU(1, 1)
       else
          do iq = 1, pert%massivenu_iq_used
             Fmnu1(iq) = pert%O1_MASSIVENU(1, iq)
          enddo
          do iq = pert%massivenu_iq_used+1, coop_pert_default_nq
             Fmnu1(iq) = pert%O1_NU(1)
          enddo
          T0i = T0i + (pert%rhoa2_nu + pert%pa2_nu) * sum(Fmnu1*coop_pert_default_q_kernel)*pert%num_mnu_ratio/4.d0 
       endif
    endif
#if DO_EFT_DE       
    T0i = T0i/pert%M2 + 2.d0* (pert%alpha_B *pert%O1_DE_HPIPR - (pert%u + pert%alpha_B * pert%HdotbyHsq)*pert%O1_DE_HPI)*pert%k*pert%aH
#elif DO_COUPLED_DE
    T0i = T0i + pert%de_phidot*pert%a*pert%k*pert%O1_DELTA_PHI
#endif       

  end function coop_pert_object_delta_T0ia2

  function coop_pert_object_delta_G0ia2(pert) result(G0i)
    class(coop_pert_object)::pert
    COOP_REAL::G0i
#if DO_EFT_DE
    G0i = 2.d0*pert%k*pert%aH*(pert%O1_PSIPR + pert%O1_Phi*(1.d0+pert%alpha_B))    
#else    
    G0i = 2.d0*pert%k*pert%aH*(pert%O1_PSIPR + pert%O1_Phi)
#endif    
  end function coop_pert_object_delta_G0ia2

  function coop_pert_object_zeta(pert) result(zeta)
    class(coop_pert_object)::pert
    COOP_REAL zeta
    zeta =  - (pert%O1_PSI + (2.d0/3.d0)/(1.d0+pert%pa2_sum/pert%rhoa2_sum)*(pert%O1_Phi + Pert%O1_PSIPR))
  end function coop_pert_object_zeta



  subroutine coop_pert_object_set_zero(this)
    class(coop_pert_object)::this
    COOP_INT iq
    this%metric%F = 0.d0
    this%baryon%F = 0.d0
    this%cdm%F = 0.d0
    this%T%F = 0.d0
    this%E%F = 0.d0
    this%B%F = 0.d0
    this%nu%F = 0.d0
    this%de%F = 0.d0
    do iq = 1, coop_pert_default_nq
       this%massivenu(iq)%F = 0.d0
    enddo
  end subroutine coop_pert_object_set_zero

  subroutine coop_pert_species_set_defaults(this, genre, m, s, lmax, index, q, mass)
    class(coop_pert_species)::this
    COOP_INT::genre, m, s, lmax, index, l
    COOP_REAL::q, mass
    this%genre = genre       
    this%m = m
    this%s = s
    this%lmin = max(m, s, 0)
    if(genre .eq. COOP_PERT_NONE)then
       this%lmax = this%lmin - 1
    else
       this%lmax = max(this%lmin - 1, lmax)
    endif
    this%nvars = this%lmax - this%lmin + 1
    this%index = index
    this%last_index = this%index + this%nvars - 1
    this%i = 0
    do l = this%lmin, this%lmax
       this%i(l) = this%index + l - this%lmin
    enddo
    this%q = q
    this%mass = mass
    if(this%nvars .le. 0)then
       this%genre = COOP_PERT_NONE
    endif
  end subroutine coop_pert_species_set_defaults

  subroutine coop_pert_object_initialize(this, m, nu_mass, de_genre, a)
    !!nu_mass = neutrino mass to temprature ratio
    class(coop_pert_object)::this
    COOP_REAL,optional::nu_mass, a
    COOP_INT, optional::de_genre
    COOP_INT::m, i, iq, l, lmax_massivenu
    this%m = m
    call this%free()
    call this%metric%set_defaults( genre = COOP_PERT_METRIC,  &
         m = m, s = 0, index = 1,  &
         lmax = m + 1 - mod(m, 2), q=1.d0, mass = 0.d0 )

    call this%cdm%set_defaults( genre = COOP_PERT_PERFECT_FLUID, &
         m = m, s = 0, index = this%metric%last_index + 1, &
         lmax = 1,  q = 1.d-30, mass = 1.d30 )


    call this%baryon%set_defaults( genre = COOP_PERT_PERFECT_FLUID, &
         m = m, s = 0, index = this%cdm%last_index + 1, &
         lmax = 1, q = 1.d-30, mass = 1.d30 )

    if(this%tight_coupling)then
       call this%T%set_defaults( genre = COOP_PERT_HIERARCHY, &
            m = m, s = 0, index = this%baryon%last_index + 1, &
            lmax = 1, q = 1.d0, mass = 0.d0 )
       call this%E%set_defaults( genre = COOP_PERT_NONE, &
            m = m, s = 2, index = this%T%last_index + 1, &
            lmax = 1, q = 1.d0, mass = 0.d0 )
       
       call this%B%set_defaults( genre = COOP_PERT_NONE, &
            m = m, s = 2, index = this%E%last_index + 1, &
            lmax = 1, q = 1.d0, mass = 0.d0 )

    else
       call this%T%set_defaults( genre = COOP_PERT_HIERARCHY, &
            m = m, s = 0, index = this%baryon%last_index + 1, &
            lmax = 10, q = 1.d0, mass = 0.d0 )

       call this%E%set_defaults( genre = COOP_PERT_HIERARCHY, &
            m = m, s = 2, index = this%T%last_index + 1, &
            lmax = 8, q = 1.d0, mass = 0.d0 )

       if(m.eq.0)then
          call this%B%set_defaults( genre = COOP_PERT_NONE, &
               m = m, s = 2, index = this%E%last_index + 1, &
               lmax = 1, q = 1.d0, mass = 0.d0 )
       else
          call this%B%set_defaults( genre = COOP_PERT_HIERARCHY, &
               m = m, s = 2, index = this%E%last_index + 1, &
               lmax = this%E%lmax, q = 1.d0, mass = 0.d0 )
       endif
    endif


    call this%nu%set_defaults( genre = COOP_PERT_HIERARCHY, &
         m = m, s = 0, index = this%B%last_index + 1, &
         lmax = 12, q = 1.d0, mass = 0.d0 )

    if(present(nu_mass))then
       if( present(a) .and. nu_mass .gt. 0.d0)then
          if(nu_mass*a .ge. coop_pert_massivenu_cold_threshold)then
             this%massivenu_cold = .true.
             this%massivenu_iq_used  = 1
          else
             this%massivenu_cold = .false.
             iq = 1
             do while(iq .le. coop_pert_default_nq)          
                if(nu_mass * a .lt.  coop_pert_massivenu_threshold(iq))then
                   exit
                else
                   iq = iq + 1
                endif
             enddo
             this%massivenu_iq_used = iq - 1
          endif
       else
          this%massivenu_iq_used = 0
       endif
    else
       this%massivenu_iq_used = 0
    endif
    if(this%massivenu_cold)then
       lmax_massivenu = 1
    else
       lmax_massivenu = 10
    endif
    do iq = 1,  this%massivenu_iq_used
       if(iq .eq. 1)then
          call this%massivenu(1)%set_defaults( genre =  COOP_PERT_HIERARCHY, &
               m = m, s = 0, index = this%nu%last_index + 1, &
               lmax = lmax_massivenu, q = coop_pert_default_q(1), mass = nu_mass )
       else
          call this%massivenu(iq)%set_defaults(genre = COOP_PERT_HIERARCHY, &
               m = m, s = 0, index = this%massivenu(iq-1)%last_index + 1, &
               lmax = lmax_massivenu, q = coop_pert_default_q(iq), mass = nu_mass )
       endif
    enddo

    do iq =  this%massivenu_iq_used + 1, coop_pert_default_nq 
       if(this%massivenu_iq_used .ge. 1)then
          call this%massivenu(iq)%set_defaults(genre = COOP_PERT_NONE, &
               m = m, s = 0, index = this%massivenu(iq-1)%last_index + 1, &
               lmax = lmax_massivenu, q = coop_pert_default_q(iq), mass = nu_mass )
       else
          call this%massivenu(iq)%set_defaults(genre = COOP_PERT_NONE, &
               m = m, s = 0, index = this%nu%last_index + 1, &
               lmax = lmax_massivenu, q = coop_pert_default_q(iq), mass = nu_mass )
       endif
    enddo

    if(present(de_genre))then
       !!dark energy
       select case(de_genre)
#if DO_EFT_DE
       case(COOP_PERT_EFT)          
          if(m.eq.0)then
             call this%de%set_defaults(genre = de_genre, m = m, s = 0, &
                  index = this%massivenu(coop_pert_default_nq)%last_index + 1, &
                  lmax = 1, q = 1.d0, mass = 0.d0)
          else
             call this%de%set_defaults(genre = COOP_PERT_NONE, m = m, s = 0, &
                  index = this%massivenu(coop_pert_default_nq)%last_index + 1, &
                  lmax = 1, q = 1.d0, mass = 0.d0)
          endif
#elif DO_COUPLED_DE
       case(COOP_PERT_SCALAR_FIELD)
          if(m .eq. 0)then
             call this%de%set_defaults(genre = de_genre, m = m, s = 0, &
                  index = this%massivenu(coop_pert_default_nq)%last_index + 1, &
                  lmax = 1, q = 1.d0, mass = 0.d0)
          else
             call this%de%set_defaults(genre = COOP_PERT_NONE, m = m, s = 0, &
                  index = this%massivenu(coop_pert_default_nq)%last_index + 1, &
                  lmax = 1, q = 1.d0, mass = 0.d0)
          endif
#endif
       case default  !!lambda
          call this%de%set_defaults(genre = COOP_PERT_NONE, m = m, s = 0, &
               index = this%massivenu(coop_pert_default_nq)%last_index + 1, &
               lmax = -1, q = 1.d0, mass = 0.d0)
       end select
    else  !!lambda
       call this%de%set_defaults(genre = COOP_PERT_NONE, m = m, s = 0, &
            index = this%massivenu(coop_pert_default_nq)%last_index + 1, &
            lmax = -1, q = 1.d0, mass = 0.d0)
    endif
    this%ny = this%de%last_index
    allocate(this%y(0:this%ny))
    allocate(this%yp(0:this%ny))
    this%y = 0.d0
    this%yp = 0.d0
  end subroutine coop_pert_object_initialize


  subroutine coop_pert_object_free(this)
    class(coop_pert_object)::this
    if(allocated(this%y))deallocate(this%y, this%yp)
    this%ny = 0
  end subroutine coop_pert_object_free
  
  subroutine coop_pert_object_save_ode(this)
    class(coop_pert_object)::this
    COOP_INT iq

    this%metric%F = 0.d0
    if(this%metric%nvars .gt. 0)  this%metric%F(this%metric%lmin:this%metric%lmax) = this%y(this%metric%index:this%metric%last_index)


    this%baryon%F = 0.d0
    if(this%baryon%nvars .gt. 0)  this%baryon%F(this%baryon%lmin:this%baryon%lmax) = this%y(this%baryon%index:this%baryon%last_index)

    this%cdm%F = 0.d0
    if(this%cdm%nvars .gt. 0)  this%cdm%F(this%cdm%lmin:this%cdm%lmax) = this%y(this%cdm%index:this%cdm%last_index)

    this%T%F = 0.d0
    if(this%T%nvars .gt. 0)  this%T%F(this%T%lmin:this%T%lmax) = this%y(this%T%index:this%T%last_index)

    this%E%F = 0.d0
    if(this%E%nvars .gt. 0)  this%E%F(this%E%lmin:this%E%lmax) = this%y(this%E%index:this%E%last_index)
    
    this%B%F = 0.d0
    if(this%B%nvars .gt. 0)  this%B%F(this%B%lmin:this%B%lmax) = this%y(this%B%index:this%B%last_index)

    this%nu%F = 0.d0
    if(this%nu%nvars .gt. 0)  this%nu%F(this%nu%lmin:this%nu%lmax) = this%y(this%nu%index:this%nu%last_index)

    do iq = 1, coop_pert_default_nq
       if(this%massivenu(iq)%nvars .gt. 0)then
          this%massivenu(iq)%F = 0.d0
          this%massivenu(iq)%F(this%massivenu(iq)%lmin:this%massivenu(iq)%lmax) = this%y(this%massivenu(iq)%index:this%massivenu(iq)%last_index)
       else
          this%massivenu(iq)%F = this%nu%F
       endif
    enddo

    this%de%F = 0.d0
    if(this%de%nvars .gt. 0)  this%de%F(this%de%lmin:this%de%lmax) = this%y(this%de%index:this%de%last_index)


  end subroutine coop_pert_object_save_ode

  subroutine coop_pert_object_restore_ode(this)
    class(coop_pert_object)::this
    COOP_INT iq
    this%y = 0.d0
    if(this%metric%nvars .gt. 0)   this%y(this%metric%index:this%metric%last_index) = this%metric%F(this%metric%lmin:this%metric%lmax)
    if(this%baryon%nvars .gt. 0)   this%y(this%baryon%index:this%baryon%last_index) = this%baryon%F(this%baryon%lmin:this%baryon%lmax)
    if(this%cdm%nvars .gt. 0)   this%y(this%cdm%index:this%cdm%last_index) = this%cdm%F(this%cdm%lmin:this%cdm%lmax)
    if(this%T%nvars .gt. 0)   this%y(this%T%index:this%T%last_index) = this%T%F(this%T%lmin:this%T%lmax)
    if(this%E%nvars .gt. 0)   this%y(this%E%index:this%E%last_index) = this%E%F(this%E%lmin:this%E%lmax)
    if(this%B%nvars .gt. 0)   this%y(this%B%index:this%B%last_index) = this%B%F(this%B%lmin:this%B%lmax)
    if(this%nu%nvars .gt. 0)   this%y(this%nu%index:this%nu%last_index) = this%nu%F(this%nu%lmin:this%nu%lmax)
    do iq = 1, coop_pert_default_nq
       if(this%massivenu(iq)%nvars .gt. 0)   this%y(this%massivenu(iq)%index:this%massivenu(iq)%last_index) = this%massivenu(iq)%F(this%massivenu(iq)%lmin:this%massivenu(iq)%lmax)
    enddo
    if(this%de%nvars .gt. 0)   this%y(this%de%index:this%de%last_index) = this%de%F(this%de%lmin:this%de%lmax)    
  end subroutine coop_pert_object_restore_ode


  !!user specified subroutine
  !!this example shows how to print T00, T00/G00-1, T0i, T0i/G0i-1, Phi, PSI
  subroutine coop_pert_object_print(pert, cosmology, unit, names)
    class(coop_pert_object)::pert
    class(coop_cosmology_background)::cosmology
    COOP_INT, optional::unit
    COOP_INT::output_unit
    type(coop_list_string), optional::names
    COOP_REAL::T00, T0i, G00, G0i
    T00 = pert%delta_T00a2()
    T0i = pert%delta_T0ia2()
    G00 = pert%delta_G00a2()
    G0i = pert%delta_G0ia2()
    if(present(unit))then
       output_unit = unit
    else
       output_unit = 6
    endif
    if(present(names))then
       write(output_unit, "(80E16.7)") coop_pert_names_mapping(pert, cosmology, names)
    else
       write(output_unit, "(80E16.7)")  log(pert%a), T00, T00/G00-1.d0, T0i,  T0i/G0i-1.d0, pert%O1_Phi, pert%O1_PSI
    endif

  end subroutine coop_pert_object_print

  function coop_pert_names_mapping(pert, cosmology, names) result(vars)
    class(coop_pert_object)::pert
    class(coop_cosmology_background)::cosmology
    type(coop_list_string)::names
    COOP_REAL::vars(names%n)
    COOP_INT::i
    do i = 1, names%n
       vars(i) = coop_pert_name_mapping(pert, cosmology, names%element(i))
    enddo
  end function coop_pert_names_mapping

  function coop_pert_name_mapping(pert, cosmology, name) result(var)
    class(coop_pert_object)::pert
    class(coop_cosmology_background)::cosmology
    COOP_UNKNOWN_STRING::name
    COOP_REAL::var, alpha
    select case(COOP_LOWER_STR(name))
    case("kmpc")
       var = pert%k*cosmology%H0Mpc()
    case("a")
       var = pert%a
    case("z")
       var = 1.d0/pert%a - 1.d0
    case("tau") 
       var = cosmology%tauofa(pert%a)
    case("t") 
       var = cosmology%time(pert%a)
    case("lna")
       var = log(pert%a)
    case("h")
       var = cosmology%Hratio(pert%a)
    case("ha", "ah")
       var = cosmology%aHratio(pert%a)
    case("rhoc")
       var = O0_CDM(cosmology)%density(pert%a)
    case("rhob")
       var = O0_BARYON(cosmology)%density(pert%a)
    case("rhode")
       var = O0_DE(cosmology)%density(pert%a)
    case("rhogamma")
       var = O0_RADIATION(cosmology)%density(pert%a)
    case("rhonu")
       var = O0_NU(cosmology)%density(pert%a)
    case("rhomassivenu")
       var = O0_MASSIVENU(cosmology)%density(pert%a)
    case("t00")
       var = pert%delta_T00a2()
    case("t0i")
       var = pert%delta_T0ia2()
    case("g00")
       var = pert%delta_G00a2()
    case("g0i")
       var = pert%delta_G0ia2()
    case("phi")
       var = pert%O1_phi
    case("psi")
       var = pert%O1_PSI
    case("deltac")
       var = pert%O1_DELTA_C
    case("deltacsync")
       var = (pert%O1_DELTA_C + 3.d0*pert%O1_V_C/pert%kbyaH)/pert%k**2
    case("deltab")
       var = pert%O1_DELTA_B
    case("deltabsync")
       var = (pert%O1_DELTA_B + 3.d0*pert%O1_V_B/pert%kbyaH)/pert%k**2       
    case("vc")
       var = pert%O1_V_C
    case("vb")
       var = pert%O1_V_B
    case("deltag")
       var = pert%O1_T(0)
    case("vg")
       var = pert%O1_T(1)/4.d0
    case("deltanu")
       var = pert%O1_NU(0)
    case("vnu")
       var = pert%O1_NU(1)/4.d0
    case("dpsidlna")
       var = pert%O1_PSIPR
    case("dphidlna")
       var = pert%O1_PHIPR
#if DO_COUPLED_DE
    case("cpldephi")
       var=pert%O1_DELTA_PHI
    case("cpldephiprime")
       var= pert%O1_DELTA_PHIPR
#endif
#if DO_EFT_DE       
    case("hpi")
       var = pert%O1_DE_HPI
    case("dhpidlna")
       var = pert%O1_DE_HPIPR
    case("pi")
       var = pert%O1_DE_HPI / cosmology%Hratio(pert%a)
    case("dealphacs2")
       var = cosmology%alphacs2(pert%a)
    case("decs2")
       alpha = cosmology%total_alpha(pert%a)
       if(abs(alpha).gt.1.d-5)then
          var = cosmology%alphacs2(pert%a)/alpha
       else
          var = 0.d0
       endif
    case("dealpha")
       var = cosmology%total_alpha(pert%a)
    case("dealpham")
       var = cosmology%alpha_M(pert%a)
    case("demstar")
       var = sqrt(cosmology%Mpsq(pert%a))
    case("dealphak")
       var = cosmology%alpha_K(pert%a)
    case("dealphab")
       var = cosmology%alpha_B(pert%a)
    case("dealphat")
       var = cosmology%alpha_T(pert%a)
    case("dealphah")
       var = cosmology%alpha_H(pert%a)

#endif
    case default
       write(*,*) trim(name)//" is not predefined. Cannot map it to a known variable."
       stop
    end select
  end function coop_pert_name_mapping
  
  
end module coop_pertobj_mod



