! Copyright (C) 2014 Santiago Badia, Alberto F. Martín and Javier Principe
!
! This file is part of FEMPAR (Finite Element Multiphysics PARallel library)
!
! FEMPAR is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! FEMPAR is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with FEMPAR. If not, see <http://www.gnu.org/licenses/>.
!
! Additional permission under GNU GPL version 3 section 7
!
! If you modify this Program, or any covered work, by linking or combining it 
! with the Intel Math Kernel Library and/or the Watson Sparse Matrix Package 
! and/or the HSL Mathematical Software Library (or a modified version of them), 
! containing parts covered by the terms of their respective licenses, the
! licensors of this Program grant you additional permission to convey the 
! resulting work. 
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
module par_integration_names
  use integration_names
  use problem_names
  use integrable_names
  use par_fe_space_names
  use par_assembly_names
  implicit none
# include "debug.i90"
  private

  public :: par_volume_integral

contains

  subroutine par_volume_integral(approx,p_fe_space,res1,res2)
    implicit none
    ! Parameters
    type(par_fe_space_t)         , intent(inout) :: p_fe_space
    class(integrable_t)          , intent(inout) :: res1
    class(integrable_t), optional, intent(inout) :: res2
    class(discrete_integration_t) , intent(inout) :: approx

    if(p_fe_space%p_trian%p_env%am_i_fine_task()) then
       call volume_integral(approx,p_fe_space%fe_space,res1,res2,par_assembly)
    end if
    
  end subroutine par_volume_integral

end module par_integration_names

