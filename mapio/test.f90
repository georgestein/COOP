program test
  use coop_wrapper_utils
  use coop_healpix_mod
  use coop_fitswrap_mod
  implicit none
#include "constants.h"
  type(coop_healpix_maps)::map, mask
  call map%read("lowl/commander_I_n0128_60a.fits")
!!$  call mask%read("lowl/commander_mask_n0128_60a.fits")
!!$  call map%apply_mask(mask, bad_data = .true.)
!!$  call map%write("lowl/commander_I_n0128_60a_masked.fits")
!!$  stop
  call map%rotate_coor(l_deg = 212.d0, b_deg = -13.d0)
  call map%draw_latitude_line(30.d0, 0.5d0)
  call map%draw_latitude_line(60.d0, 0.5d0)
  call map%draw_latitude_line(-30.d0, 0.5d0)
  call map%draw_latitude_line(-60.d0, 0.5d0)
  call map%draw_latitude_line(0.d0, 0.5d0)  
  call map%write("map_asym.fits")
end program test
