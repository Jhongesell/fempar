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

module poisson_analytical_functions_names
  use serial_names
  implicit none
# include "debug.i90"
  private

  type, extends(scalar_function_t) :: base_scalar_function_t
    private
    integer(ip) :: num_dimensions = -1  
  contains
    procedure :: set_num_dimensions    => base_scalar_function_set_num_dimensions
  end type base_scalar_function_t
  
  type, extends(base_scalar_function_t) :: source_term_t
    private 
   contains
     procedure :: get_value_space    => source_term_get_value_space
  end type source_term_t

  type, extends(base_scalar_function_t) :: boundary_function_t
    private
   contains
     procedure :: get_value_space => boundary_function_get_value_space
  end type boundary_function_t

  type, extends(base_scalar_function_t) :: solution_function_t
    private 
   contains
     procedure :: get_value_space    => solution_function_get_value_space
     procedure :: get_gradient_space => solution_function_get_gradient_space
  end type solution_function_t

  type poisson_analytical_functions_t
     private
     type(source_term_t)       :: source_term
     type(boundary_function_t) :: boundary_function
     type(solution_function_t) :: solution_function
   contains
     procedure :: set_num_dimensions      => poisson_analytical_functions_set_num_dimensions
     procedure :: get_source_term         => poisson_analytical_functions_get_source_term
     procedure :: get_boundary_function   => poisson_analytical_functions_get_boundary_function
     procedure :: get_solution_function   => poisson_analytical_functions_get_solution_function
  end type poisson_analytical_functions_t

  public :: poisson_analytical_functions_t

contains  

  subroutine base_scalar_function_set_num_dimensions ( this, num_dimensions )
    implicit none
    class(base_scalar_function_t), intent(inout)    :: this
    integer(ip), intent(in) ::  num_dimensions
    this%num_dimensions = num_dimensions
  end subroutine base_scalar_function_set_num_dimensions

  !===============================================================================================
  subroutine source_term_get_value_space ( this, point, result )
    implicit none
    class(source_term_t), intent(in)    :: this
    type(point_t)       , intent(in)    :: point
    real(rp)            , intent(inout) :: result
    assert ( this%num_dimensions == 2 .or. this%num_dimensions == 3 )
    result = 0.0_rp 
  end subroutine source_term_get_value_space

  !===============================================================================================
  subroutine boundary_function_get_value_space ( this, point, result )
    implicit none
    class(boundary_function_t), intent(in)  :: this
    type(point_t)           , intent(in)    :: point
    real(rp)                , intent(inout) :: result
    assert ( this%num_dimensions == 2 .or. this%num_dimensions == 3 )
    if ( this%num_dimensions == 2 ) then
      result = point%get(1) + point%get(2) ! x+y
    else if ( this%num_dimensions == 3 ) then
      result = point%get(1) + point%get(2) + point%get(3) ! x+y+z
    end if  
  end subroutine boundary_function_get_value_space 

  !===============================================================================================
  subroutine solution_function_get_value_space ( this, point, result )
    implicit none
    class(solution_function_t), intent(in)    :: this
    type(point_t)             , intent(in)    :: point
    real(rp)                  , intent(inout) :: result
    assert ( this%num_dimensions == 2 .or. this%num_dimensions == 3 )
    if ( this%num_dimensions == 2 ) then
      result = point%get(1) + point%get(2) ! x+y 
    else if ( this%num_dimensions == 3 ) then
      result = point%get(1) + point%get(2) + point%get(3) ! x+y+z
    end if  
      
  end subroutine solution_function_get_value_space
  
  !===============================================================================================
  subroutine solution_function_get_gradient_space ( this, point, result )
    implicit none
    class(solution_function_t), intent(in)    :: this
    type(point_t)             , intent(in)    :: point
    type(vector_field_t)      , intent(inout) :: result
    assert ( this%num_dimensions == 2 .or. this%num_dimensions == 3 )
    if ( this%num_dimensions == 2 ) then
      call result%set( 1, 1.0_rp ) 
      call result%set( 2, 1.0_rp )
    else if ( this%num_dimensions == 3 ) then
      call result%set( 1, 1.0_rp ) 
      call result%set( 2, 1.0_rp )
      call result%set( 3, 1.0_rp ) 
    end if
  end subroutine solution_function_get_gradient_space
  
  !===============================================================================================
  subroutine poisson_analytical_functions_set_num_dimensions ( this, num_dimensions )
    implicit none
    class(poisson_analytical_functions_t), intent(inout)    :: this
    integer(ip), intent(in) ::  num_dimensions
    call this%source_term%set_num_dimensions(num_dimensions)
    call this%boundary_function%set_num_dimensions(num_dimensions)
    call this%solution_function%set_num_dimensions(num_dimensions)
  end subroutine poisson_analytical_functions_set_num_dimensions 
  
  !===============================================================================================
  function poisson_analytical_functions_get_source_term ( this )
    implicit none
    class(poisson_analytical_functions_t), target, intent(in)    :: this
    class(scalar_function_t), pointer :: poisson_analytical_functions_get_source_term
    poisson_analytical_functions_get_source_term => this%source_term
  end function poisson_analytical_functions_get_source_term
  
  !===============================================================================================
  function poisson_analytical_functions_get_boundary_function ( this )
    implicit none
    class(poisson_analytical_functions_t), target, intent(in)    :: this
    class(scalar_function_t), pointer :: poisson_analytical_functions_get_boundary_function
    poisson_analytical_functions_get_boundary_function => this%boundary_function
  end function poisson_analytical_functions_get_boundary_function
  
  !===============================================================================================
  function poisson_analytical_functions_get_solution_function ( this )
    implicit none
    class(poisson_analytical_functions_t), target, intent(in)    :: this
    class(scalar_function_t), pointer :: poisson_analytical_functions_get_solution_function
    poisson_analytical_functions_get_solution_function => this%solution_function
  end function poisson_analytical_functions_get_solution_function

end module poisson_analytical_functions_names
!***************************************************************************************************