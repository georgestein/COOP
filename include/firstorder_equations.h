  subroutine coop_cosmology_firstorder_equations(n, lna, y, yp, cosmology, pert)
    COOP_INT n
    type(coop_cosmology_firstorder)::cosmology
    type(coop_pert_object)::pert
    COOP_REAL lna, y(0:n-1), yp(0:n-1)
    COOP_INT i, l, iq
    COOP_REAL a, aniso,  ktauc, ktaucdot, ktaucdd, aniso_prime, aHtauc, aHtau, aHsq, uterm, vterm, ma, doptdlna
    COOP_REAL :: pa2pr_g, pa2pr_nu
    COOP_REAL, dimension(coop_pert_default_nq)::Fmnu2_prime, Fmnu2, Fmnu0, qbye, wp, wp_prime, wrho_minus_wp
    COOP_REAL::asq, Hsq
    !!My PHI = Psi in Hu & White = Psi in Ma et al;
    !!My PSI = - Phi in Hu & White = Phi in Ma et al;
    !!My multipoles  = 4 * multipoles in Hu & White = (2l + 1) * multipoles in Ma et al
    !!My neutrino multipoles = (2l + 1) / (d ln f_0/d ln q) * Psi_l(q) in Ma et al
    !!finally, my time variable is log(a)
    yp(0) = 0
    pert%ksq = pert%k**2
    a = exp(lna)
    asq = a**2
    pert%a = a
    pert%rhoa2_g = O0_RADIATION(cosmology)%rhoa2(a)
    pert%pa2_g = O0_RADIATION(cosmology)%wofa(a) * pert%rhoa2_g
    pert%rhoa2_b = O0_BARYON(cosmology)%rhoa2(a)
    pert%cs2b = cosmology%cs2bofa(a)
    pert%rhoa2_c = O0_CDM(cosmology)%rhoa2(a)
    pert%rhoa2_nu = O0_NU(cosmology)%rhoa2(a)
    pert%pa2_nu = pert%rhoa2_nu *  O0_NU(cosmology)%wofa(a)
    pert%rhoa2_de = O0_DE(cosmology)%rhoa2(a)
    pert%pa2_de = O0_DE(cosmology)%wofa(a)* pert%rhoa2_de
    if(cosmology%index_massivenu .ne. 0 )then
       pert%rhoa2_mnu = O0_MASSIVENU(cosmology)%rhoa2(a)
       pert%pa2_mnu = pert%rhoa2_mnu *  O0_MASSIVENU(cosmology)%wofa(a)
       ma = cosmology%mnu_by_Tnu * a
       if(ma  .lt. 1.d-4)then
          wrho_minus_wp = (cosmology%mnu_by_Tnu * a)**2/coop_pert_default_q**2
          qbye = 1.d0 - wrho_minus_wp/2.d0
          wrho_minus_wp = wrho_minus_wp * coop_pert_default_q_kernel *  pert%num_mnu_ratio
       else
          qbye =  coop_pert_default_q/sqrt(coop_pert_default_q**2 + (cosmology%mnu_by_Tnu * a)**2)
          wrho_minus_wp = coop_pert_default_q_kernel *  pert%num_mnu_ratio * (1.d0/qbye - qbye)
       endif
       wp = qbye * coop_pert_default_q_kernel * pert%num_mnu_ratio
       wp_prime = -(cosmology%mnu_by_Tnu*a)**2/(coop_pert_default_q**2 + (cosmology%mnu_by_Tnu * a)**2) * wp
    else
       pert%rhoa2_mnu = 0.d0
       pert%pa2_mnu = 0.d0
    endif

    pert%rhoa2_sum = pert%rhoa2_g + pert%rhoa2_b + pert%rhoa2_c + pert%rhoa2_nu +pert%rhoa2_mnu+pert%rhoa2_de 
    pert%pa2_sum = pert%pa2_g + pert%pa2_nu + pert%pa2_mnu + pert%pa2_de
    aHsq = (pert%rhoa2_sum + cosmology%Omega_k())/3.d0
    Hsq = aHsq/asq

    pert%aH = sqrt(aHsq)

    

    pert%daHdtau = -(pert%rhoa2_sum+3.d0*pert%pa2_sum)/6.d0

    pa2pr_nu = O0_NU(cosmology)%dpa2da(a)*a
    pa2pr_g = O0_RADIATION(cosmology)%dpa2da(a)*a

    pert%R = 0.75d0 * pert%rhoa2_b/pert%rhoa2_g
    pert%tauc = cosmology%taucofa(a)
    pert%taucdot = cosmology%dot_tauc(a)

    ktauc = pert%k * pert%tauc
    ktaucdot = pert%k * pert%taucdot
    pert%kbyaH  = pert%k/pert%aH
    pert%kbyaHsq = pert%kbyaH**2
    aHtauc = pert%aH * pert%tauc
    doptdlna = 1.d0/aHtauc
    pert%tau = cosmology%tauofa(a)
    aHtau = pert%aH*pert%tau
    pert%latedamp = cosmology%late_damp_factor(pert%k, pert%tau)
    
    ktaucdd = pert%k*(cosmology%dot_tauc(a*1.01)-cosmology%dot_tauc(a/1.01))/(0.02/pert%aH)					      
    select case(pert%m)
    case(0)

       O1_PSI_PRIME = O1_PSIPR

       O1_DELTA_C_PRIME = - O1_V_C * pert%kbyaH + 3.d0 * O1_PSI_PRIME
       O1_DELTA_B_PRIME = - O1_V_B * pert%kbyaH + 3.d0 * O1_PSI_PRIME
       O1_T_PRIME(0) = (- O1_T(1) * pert%kbyaH/3.d0 + 4.d0 * O1_PSI_PRIME)*pert%latedamp
       O1_NU_PRIME(0) = (- O1_NU(1) * pert%kbyaH/3.d0 + 4.d0 * O1_PSI_PRIME)*pert%latedamp

       if(pert%tight_coupling)then
          pert%T%F(2) = (8.d0/9.d0)*ktauc * O1_T(1)
          Uterm = - pert%aH * O1_V_B + (pert%cs2b * O1_DELTA_B - O1_T(0)/4.d0 +  pert%T%F(2)/10.d0)*pert%k
          vterm = pert%k * (pert%R+1.d0)/pert%R + ktaucdot 
          pert%slip = ktauc &
               * (Uterm - ktauc*(Uterm*(-pert%aH*pert%k/pert%R + pert%daHdtau/pert%aH*ktaucdot)/vterm)/vterm)/vterm   !!v_b - v_g accurate to (k tau_c)^2 
       else
          pert%T%F(2) = O1_T(2)             
          pert%slip = O1_V_B - O1_T(1)/4.d0
       endif
       aniso = pert%pa2_g * pert%T%F(2) + pert%pa2_nu * O1_NU(2)
       if(cosmology%index_massivenu .ne. 0 .and. .not. pert%massivenu_cold)then       
          do iq = 1, pert%massivenu_iq_used
             Fmnu2(iq) = O1_MASSIVENU(2, iq)
             Fmnu0(iq) = O1_MASSIVENU(0, iq)
             O1_MASSIVENU_PRIME(0, iq) = - O1_MASSIVENU(1, iq)*pert%kbyaH/3.d0 * qbye(iq) + 4.d0 * O1_PSI_PRIME 
          enddo
          do iq = pert%massivenu_iq_used + 1, coop_pert_default_nq
             Fmnu2(iq) = O1_NU(2)
             Fmnu0(iq) = O1_NU(0)
          enddo
          aniso = aniso +  pert%pa2_nu * sum(Fmnu2*wp)
       endif
       aniso = 0.6d0/pert%ksq * aniso
       O1_PHI = O1_PSI - aniso
       pert%delta_gamma = pert%latedamp * O1_T(0) - 4.d0*(1.d0-pert%latedamp)*(O1_PHI + O1_V_B/ktauc)
       !!velocities
       O1_V_C_PRIME = - O1_V_C + pert%kbyaH * O1_PHI
       O1_NU_PRIME(1) = ((O1_NU(0) + 4.d0*O1_PHI - 0.4d0 * O1_NU(2))*pert%kbyaH)*pert%latedamp
       do iq=1, pert%massivenu_iq_used
          O1_MASSIVENU_PRIME(1, iq) = (O1_MASSIVENU(0, iq)*qbye(iq) + 4.d0*O1_PHI/qbye(iq) - 0.4d0 * O1_MASSIVENU(2, iq)*qbye(iq)) * pert%kbyaH
       enddo
       O1_V_B_PRIME = - O1_V_B + pert%kbyaH * (O1_PHI + pert%cs2b * O1_DELTA_B) - pert%slip/(pert%R * aHtauc)
       O1_T_PRIME(1) = ((O1_T(0) + 4.d0*O1_PHI - 0.4d0*pert%T%F(2))*pert%kbyaH + 4.d0*pert%slip/aHtauc)*pert%latedamp


       !!higher moments
       !!massless neutrinos
       do l = 2, pert%nu%lmax - 1
          O1_NU_PRIME(l) =  (pert%kbyaH * (cosmology%klms_by_2lm1(l, 0, 0) *   O1_NU( l-1 ) - cosmology%klms_by_2lp1(l+1, 0, 0) *  O1_NU( l+1 ) ))*pert%latedamp
       enddo

       O1_NU_PRIME(pert%nu%lmax) = (pert%kbyaH * (pert%nu%lmax +0.5d0)/(pert%nu%lmax-0.5d0)*  O1_NU(pert%nu%lmax-1) -  (pert%nu%lmax+1)* O1_NU(pert%nu%lmax)/(aHtau))*pert%latedamp

       if(cosmology%index_massivenu .ne. 0)then
          !!massive neutrinos
          if(pert%massivenu_cold)then
             O1_MASSIVENU_PRIME(0, 1) = - O1_MASSIVENU(1, 1)* pert%kbyaH+ 3.d0 * O1_PSI_PRIME
             O1_MASSIVENU_PRIME(1, 1) = - O1_MASSIVENU(1, 1) + pert%kbyaH * O1_PHI
          else
             do iq = 1, pert%massivenu_iq_used
                do l = 2, pert%massivenu(iq)%lmax - 1
                   O1_MASSIVENU_PRIME(l, iq) = pert%kbyaH * qbye(iq) * (cosmology%klms_by_2lm1(l, 0, 0) * O1_MASSIVENU(l-1, iq) - cosmology%klms_by_2lp1(l+1, 0, 0) * O1_MASSIVENU(l+1,iq))
                enddo
                O1_MASSIVENU_PRIME(pert%massivenu(iq)%lmax, iq) =  pert%kbyaH * qbye(iq) * (pert%massivenu(iq)%lmax+0.5d0)/(pert%massivenu(iq)%lmax-0.5d0) *  O1_MASSIVENU(pert%nu%lmax-1, iq) &
                     -  (pert%nu%lmax+1)* O1_MASSIVENU(pert%nu%lmax, iq) / aHtau 
             enddo
          endif
       endif
       
       if(pert%tight_coupling)then

          pert%T2prime = (8.d0/9.d0)*(ktauc*O1_T_PRIME(1) + ktaucdot/pert%aH*O1_T(1)) !2.d0*pert%T%F(2)
          pert%E%F(2) = -coop_sqrt6/4.d0 * pert%T%F(2)
          pert%E2prime = -coop_sqrt6/4.d0 * pert%T2prime 
          pert%capP = (pert%T%F(2) - coop_sqrt6 * pert%E%F(2))/10.d0

       else
          !!T
          pert%capP = (O1_T(2) - coop_sqrt6 * O1_E(2))/10.d0
          O1_T_PRIME(2) =  (pert%kbyaH * (cosmology%klms_by_2lm1(2, 0, 0)*O1_T(1) - cosmology%klms_by_2lp1(3, 0, 0)*O1_T(3))  - (O1_T(2) - pert%capP)/aHtauc)*pert%latedamp
          pert%T2prime =  O1_T_PRIME(2)
          do l = 3, pert%T%lmax -1
             O1_T_PRIME(l) = (pert%kbyaH * (cosmology%klms_by_2lm1(l, 0, 0)*O1_T(l-1) -cosmology%klms_by_2lp1(l+1, 0, 0)*O1_T(l+1))  - O1_T(l)/aHtauc)*pert%latedamp
          enddo
          O1_T_PRIME(pert%T%lmax) =  ( pert%kbyaH *((pert%T%lmax+0.5d0)/(pert%T%lmax-0.5d0))*  O1_T(pert%T%lmax-1) &
               -  ((pert%T%lmax+1)/aHtau + doptdlna) * O1_T(pert%T%lmax))*pert%latedamp
          !!E
          O1_E_PRIME(2) = (pert%kbyaH * ( - cosmology%klms_by_2lp1(3, 0, 2)*O1_E(3))  - (O1_E(2) + coop_sqrt6 * pert%capP)/aHtauc)*pert%latedamp
          pert%E2prime = O1_E_PRIME(2)

          do l = 3, pert%E%lmax - 1
             O1_E_PRIME(l) = (pert%kbyaH * (cosmology%klms_by_2lm1(l, 0, 2)*O1_E(l-1) - cosmology%klms_by_2lp1(l+1, 0, 2)*O1_E(l+1)) - O1_E(l)/aHtauc)*pert%latedamp
          enddo
          O1_E_PRIME(pert%E%lmax) =  (pert%kbyaH *( (pert%E%lmax-2.d0/pert%E%lmax+0.5d0)/(pert%E%lmax-2.d0/pert%E%lmax-0.5d0)) *  O1_E(pert%E%lmax-1) &
               -  ((pert%E%lmax-2.d0/pert%E%lmax+1)/aHtau + doptdlna) * O1_E(pert%E%lmax))*pert%latedamp
       endif
       aniso_prime =  pert%pa2_g * pert%T2prime + pa2pr_g * pert%T%F(2) + pert%pa2_nu * O1_NU_PRIME(2) + pa2pr_nu*O1_NU(2)
       if(cosmology%index_massivenu .ne. 0 .and. .not. pert%massivenu_cold)then
          do iq = 1, pert%massivenu_iq_used
             Fmnu2_prime(iq) = O1_MASSIVENU_PRIME(2, iq)
          enddo
          do iq = pert%massivenu_iq_used + 1, coop_pert_default_nq
             Fmnu2_prime(iq) = O1_NU_PRIME(2)
          enddo
          aniso_prime = aniso_prime + pa2pr_nu * sum(Fmnu2*wp) + pert%pa2_nu*sum(Fmnu2_prime*wp + Fmnu2*wp_prime) 
       endif
       aniso_prime =  0.6d0/pert%ksq * aniso_prime
       
       O1_PHI_PRIME = O1_PSI_PRIME - aniso_prime
       if(pert%want_source)then
          pert%ekappa = cosmology%ekappaofa(pert%a)
          pert%vis = pert%ekappa/pert%tauc
          pert%visdot = cosmology%vis%derivative(pert%a) * pert%a * pert%aH
          pert%Pdot = (pert%T2prime  - coop_sqrt6 *  pert%E2prime)/10.d0 * pert%aH
          pert%kchi = 1.d0 - pert%tau/cosmology%tau0
          pert%kchi = pert%k* cosmology%tau0*(pert%kchi + exp(-1.d3*pert%kchi))
       endif
       O1_PSIPR_PRIME = - O1_PHI_PRIME &
            - (3.d0 + pert%daHdtau/aHsq)*O1_PSI_PRIME &
            - 2.d0*(pert%daHdtau/aHsq + 1.d0)*O1_PHI &
            - pert%kbyaHsq/3.d0*(O1_PSI+aniso) &
            + ( &
            pert%rhoa2_b/aHsq * O1_DELTA_B * (pert%cs2b - 1.d0/3.d0) &
            + pert%rhoa2_c/aHsq*O1_DELTA_C*(-1.d0/3.d0) &
            )/2.d0

       if(cosmology%index_massivenu .ne. 0)then
          if(pert%massivenu_cold)then
             O1_PSIPR_PRIME = O1_PSIPR_PRIME - O1_MASSIVENU(0, 1)*pert%rhoa2_mnu/6.0/aHsq
          else
             pert%deltatr_mnu = sum(Fmnu0*wrho_minus_wp)
	     pert%deltap_mnu = sum(Fmnu0*wp)
             O1_PSIPR_PRIME =  O1_PSIPR_PRIME - (pert%pa2_nu/aHsq * pert%deltatr_mnu)/2.d0
          endif
       else
          pert%deltatr_mnu = 0.d0
          pert%deltap_mnu = 0.d0
       endif
    case(1)
       call coop_tbw("vector equations not written")
    case(2)
       if(pert%want_source)then
          pert%ekappa = cosmology%ekappaofa(pert%a)
          pert%vis = pert%ekappa/pert%tauc
          pert%visdot = cosmology%vis%derivative(pert%a) * pert%a * pert%aH
          pert%Pdot = (pert%T2prime  - coop_sqrt6 *  pert%E2prime)/10.d0 * pert%aH
          pert%kchi = 1.d0 - pert%tau/cosmology%tau0
          pert%kchi = pert%k* cosmology%tau0*(pert%kchi + exp(-1.d3*pert%kchi))
       endif
       O1_TEN_H_PRIME = O1_TEN_HPR
       if(pert%tight_coupling)then
          pert%T%F(2) =  (-16.d0/3.d0 )*O1_TEN_HPR*aHtauc
!(-16.d0/3.d0 + (8.d0*19.d0/63.d0)*(pert%kbyaH**2*aHtauc + (231.D0/19.D0))*aHtauc  )*O1_TEN_HPR*aHtauc
          pert%E%F(2) =  (-coop_sqrt6/4.d0)*pert%T%F(2) !- (110.d0/63.d0*coop_sqrt6)*(pert%kbyaH**2*aHtauc +(63.d0/11.d0))*O1_TEN_HPR*aHtauc**2
       else
          pert%T%F(2) =O1_T(2)
          pert%E%F(2) = O1_E(2)
       endif
       pert%capP = (pert%T%F(2) - coop_sqrt6 * pert%E%F(2))/10.d0
       aniso = pert%pa2_g * pert%T%F(2) +  pert%pa2_nu * O1_NU(2)
       if(cosmology%index_massivenu .ne. 0 .and. .not. pert%massivenu_cold)then
          do iq = 1, pert%massivenu_iq_used
             Fmnu2(iq) = O1_MASSIVENU(2, iq)
          enddo
          do iq = pert%massivenu_iq_used + 1, coop_pert_default_nq
             Fmnu2(iq) = O1_NU(2)
          enddo
          aniso = aniso +  pert%pa2_nu * sum(Fmnu2*wp)
       endif
       O1_TEN_HPR_PRIME = -(2.d0+pert%daHdtau/aHsq)*O1_TEN_HPR &
            - pert%kbyaH**2 * O1_TEN_H &
            + 0.4d0/aHsq * aniso
       O1_NU_PRIME(2) =  (pert%kbyaH * ( - cosmology%klms_by_2lp1(3, 2, 0) *  O1_NU( 3 ) ) - 4.d0*O1_TEN_HPR)*pert%latedamp
       do l = 3, pert%nu%lmax - 1
          O1_NU_PRIME(l) =  (pert%kbyaH * (cosmology%klms_by_2lm1(l, 2, 0) *   O1_NU( l-1 ) - cosmology%klms_by_2lp1(l+1, 2, 0) *  O1_NU( l+1 ) ))*pert%latedamp
       enddo

       O1_NU_PRIME(pert%nu%lmax) = (pert%kbyaH * (pert%nu%lmax-2.d0/pert%nu%lmax+0.5d0)/(pert%nu%lmax-2.d0/pert%nu%lmax-0.5d0)*  O1_NU(pert%nu%lmax-1) &
            -  (pert%nu%lmax-2.d0/pert%nu%lmax+1)* O1_NU(pert%nu%lmax)/(aHtau))*pert%latedamp

       if(cosmology%index_massivenu .ne. 0 .and. .not. pert%massivenu_cold)then
             !!massive neutrinos
          do iq = 1, pert%massivenu_iq_used
             O1_MASSIVENU_PRIME(2, iq) = pert%kbyaH * qbye(iq) * (- cosmology%klms_by_2lp1(3, 2, 0) * O1_MASSIVENU(3, iq))-4.d0*O1_TEN_HPR
             do l = 3, pert%massivenu(iq)%lmax - 1
                O1_MASSIVENU_PRIME(l, iq) = pert%kbyaH * qbye(iq) * (cosmology%klms_by_2lm1(l, 2, 0) * O1_MASSIVENU(l-1, iq) - cosmology%klms_by_2lp1(l+1, 2, 0) * O1_MASSIVENU(l+1,iq))
             enddo
             O1_MASSIVENU_PRIME(pert%massivenu(iq)%lmax, iq) =  pert%kbyaH * qbye(iq) * (pert%massivenu(iq)%lmax-2.d0/pert%massivenu(iq)%lmax+0.5d0)/(pert%massivenu(iq)%lmax-2.d0/pert%massivenu(iq)%lmax-0.5d0) *  O1_MASSIVENU(pert%nu%lmax-1, iq) &
                  -  (pert%nu%lmax-2.d0/pert%massivenu(iq)%lmax+1)* O1_MASSIVENU(pert%nu%lmax, iq) / aHtau 
          enddo
       endif
       if(pert%tight_coupling)then
          pert%T2prime = -16.d0/3.d0*(O1_TEN_HPR_PRIME*aHtauc - O1_TEN_HPR * (pert%taucdot  + pert%tauc*pert%daHdtau/pert%aH)/aHtauc**2)
          pert%E2prime = (-coop_sqrt6/4.d0)*pert%T2prime
       else
          O1_T_PRIME(2) =  (pert%kbyah * ( -  cosmology%klms_by_2lp1(3, 2, 0) * O1_T(3))  -  ( O1_T(2) - pert%capP)/aHtauc &
               - O1_TEN_HPR*4.d0)*pert%latedamp
          pert%T2prime = O1_T_PRIME(2)
          O1_E_PRIME(2) = (pert%kbyah * ( - cosmology%fourbyllp1(2)*O1_B(2)- cosmology%klms_by_2lp1(3, 2, 2) * O1_E(3)) - (O1_E(2) + coop_sqrt6 * pert%capP)/aHtauc)*pert%latedamp
          pert%E2prime = O1_E_PRIME(2)
          O1_B_PRIME(2) = (pert%kbyah * ( cosmology%fourbyllp1(2)*O1_E(2)- cosmology%klms_by_2lp1(3, 2, 2) * O1_B(3)) - O1_B(2)/aHtauc)*pert%latedamp
          do l = 3, pert%T%lmax -1 
             O1_T_PRIME(l) = (pert%kbyah * (cosmology%klms_by_2lm1(l, 2, 0) * O1_T(l-1) -  cosmology%klms_by_2lp1(l+1, 2, 0) * O1_T(l+1)) -  O1_T(l)/aHtauc)*pert%latedamp
          enddo
          O1_T_PRIME(pert%T%lmax) = (pert%kbyah  *((pert%T%lmax-2.d0/pert%T%lmax+0.5d0)/(pert%T%lmax-2.d0/pert%T%lmax-0.5d0)) * O1_T(pert%T%lmax-1) &
               - (doptdlna + (pert%T%lmax-2.d0/pert%T%lmax+1)/aHtau)* O1_T(pert%T%lmax))*pert%latedamp
          if(pert%E%lmax .ne. pert%B%lmax) stop "lmax(E) must be the same as lmax(B)"
          do l=3, pert%E%lmax -1
             O1_E_PRIME(l) = (pert%kbyah * (cosmology%klms_by_2lm1(l, 2, 2) * O1_E(l-1) &
                  - cosmology%fourbyllp1(l)*O1_B(l) &
                  - cosmology%klms_by_2lp1(l+1, 2, 2) * O1_E(l+1)) - O1_E(l)/aHtauc)*pert%latedamp
             O1_B_PRIME(l) = (pert%kbyah * (cosmology%klms_by_2lm1(l, 2, 2) * O1_B(l-1) + cosmology%fourbyllp1(l)*O1_E(l)- cosmology%klms_by_2lp1(l+1, 2, 2) * O1_B(l+1)) -  O1_B(l)/aHtauc)*pert%latedamp
          enddo
          O1_E_PRIME(pert%E%lmax) = (pert%kbyah  *((pert%E%lmax-4.d0/pert%E%lmax+0.5d0)/(pert%E%lmax-4.d0/pert%E%lmax-0.5d0)) * O1_E(pert%E%lmax-1) &
               - cosmology%fourbyllp1(pert%E%lmax)*O1_B(pert%E%lmax) &
               - (doptdlna + (pert%E%lmax-4.d0/pert%E%lmax+1)/aHtau)* O1_E(pert%E%lmax))*pert%latedamp
          O1_B_PRIME(pert%E%lmax) = (pert%kbyah  *((pert%E%lmax-4.d0/pert%E%lmax+0.5d0)/(pert%E%lmax-4.d0/pert%E%lmax-0.5d0)) * O1_B(pert%E%lmax-1)  + cosmology%fourbyllp1(pert%E%lmax)*O1_E(pert%E%lmax) &
               - (doptdlna + (pert%E%lmax-4.d0/pert%E%lmax+1)/aHtau)* O1_B(pert%E%lmax))*pert%latedamp
       endif
       if(pert%want_source)then
          pert%ekappa = cosmology%ekappaofa(pert%a)
          pert%vis = pert%ekappa/pert%tauc
          pert%visdot = cosmology%vis%derivative(pert%a) * pert%a * pert%aH
          pert%Pdot = (pert%T2prime  - coop_sqrt6 *  pert%E2prime)/10.d0 * pert%aH
          pert%kchi = 1.d0 - pert%tau/cosmology%tau0
          pert%kchi = pert%k* cosmology%tau0*(pert%kchi + exp(-1.d3*pert%kchi))
       endif
    case default
       call coop_return_error("firstorder_equations", "Unknown m = "//trim(coop_num2str(pert%m)), "stop")
    end select
    pert%capP = pert%capP*pert%latedamp
  end subroutine coop_cosmology_firstorder_equations
