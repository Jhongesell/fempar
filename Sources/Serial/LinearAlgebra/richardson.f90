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
module richardson_names
  use types_names
  use stdio_names
  use memor_names
  
  ! Abstract modules
  use vector_names
  use vector_space_names
  use operator_names
  use environment_names
  use base_linear_solver_names

  implicit none
# include "debug.i90"
  private
  
  character(len=*), parameter :: richardson_name = 'RICHARDSON'
  character(len=*), parameter :: ls_relaxation = 'linear_solver_relaxation'
  
  integer (ip), parameter :: default_richardson_stopping_criteria = res_res
  real (rp)   , parameter :: default_richardson_relaxation        = 1.0_rp

  type, extends(base_linear_solver_t) :: richardson_t
    ! Working space vectors for type(richardson_t)
    class(vector_t), allocatable :: r
    class(vector_t), allocatable :: z 
    real(rp)                     :: relaxation
  contains
    procedure          :: allocate_workspace            => richardson_allocate_workspace
    procedure          :: free_workspace                => richardson_free_workspace
    procedure          :: set_parameters_from_pl        => richardson_set_parameters_from_pl
    procedure          :: solve_body                    => richardson_solve_body
    procedure          :: supports_stopping_criteria    => richardson_supports_stopping_criteria
    procedure          :: get_default_stopping_criteria => richardson_get_default_stopping_criteria
  end type
  
  ! Data types
  public :: richardson_t, create_richardson
  
contains
  subroutine richardson_allocate_workspace(this)
    implicit none
    class(richardson_t), intent(inout) :: this
    type(vector_space_t), pointer :: range
    class(dynamic_state_operator_t), pointer :: A, M
    
    ! Only allocate workspace if actually needed
    if ( this%get_state() == operators_set ) then
      A => this%get_A()
      range  => A%get_range_vector_space()
      call range%create_vector(this%r)
      M => this%get_M()
      range  => M%get_range_vector_space()
      call range%create_vector(this%z)
    end if  
  end subroutine richardson_allocate_workspace
  
  subroutine richardson_free_workspace(this)
    implicit none
    class(richardson_t), intent(inout) :: this
    call this%r%free()
    call this%z%free()
    deallocate(this%r)
    deallocate(this%z)
  end subroutine richardson_free_workspace

  subroutine richardson_set_parameters_from_pl(this) 
   implicit none
   class(richardson_t), intent(inout) :: this
  end subroutine richardson_set_parameters_from_pl
  
  subroutine richardson_solve_body(this,b,x)
    implicit none
    class(richardson_t), intent(inout) :: this
    class(vector_t)    , intent(in)    :: b 
    class(vector_t)    , intent(inout) :: x 
    
    ! Locals
    real(rp)                      :: res_norm, rhs_norm
    integer(ip)                   :: me, np   
 
    ! Local variables to store a copy/reference of the corresponding member variables of base class
    class(environment_t), pointer :: environment
    class(operator_t)   , pointer :: A, M 
    integer(ip)                   :: stopping_criteria, max_num_iterations, output_frequency, luout
    real(rp)                      :: atol, rtol
    logical                       :: track_convergence_history

    ! Pointers to freely modify/read private member variables of base class
    integer(ip), pointer :: num_iterations
    logical    , pointer :: did_converge
    real(rp)   , pointer :: rhs_convergence_test, error_estimate_convergence_test
    real(rp)   , pointer :: error_estimate_history_convergence_test(:)

    environment               => this%get_environment()
    A                         => this%get_A()
    M                         => this%get_M()
    luout                     =  this%get_luout()
    stopping_criteria         =  this%get_stopping_criteria()
    max_num_iterations        =  this%get_max_num_iterations()
    atol                      =  this%get_atol()
    rtol                      =  this%get_rtol()
    output_frequency          =  this%get_output_frequency()
    track_convergence_history =  this%get_track_convergence_history()
     
    num_iterations                          => this%get_pointer_num_iterations()
    did_converge                            => this%get_pointer_did_converge()
    rhs_convergence_test                    => this%get_pointer_rhs_convergence_test()
    error_estimate_convergence_test         => this%get_pointer_error_estimate_convergence_test()
    error_estimate_history_convergence_test => this%get_pointer_error_estimate_history_convergence_test()

    call environment%info(me,np)
   
    ! Evaluate ||b||_2 if required
    if ( stopping_criteria == res_rhs ) then
        rhs_norm = b%nrm2()
    endif
 
    did_converge = .false.
    if ( environment%am_i_fine_task() ) then
        if ((me == 0).and.(output_frequency/=0)) call this%print_convergence_history_header(luout)
    end if

    num_iterations = 0
    loop_prichard: do while( (.not.did_converge) .and. (num_iterations < max_num_iterations))
        ! r = Ax
        call A%apply(x,this%r)

        ! r = b-(r=Ax)
        call this%r%axpby(1.0_rp,b,-1.0_rp)

        ! Evaluate ||r||_L2
        res_norm = this%r%nrm2()

        ! Set upper bound (only in 1st iteration)
        if ( num_iterations == 1 ) then
            if ( stopping_criteria == res_rhs ) then
                rhs_convergence_test = rtol * rhs_norm + atol 
            else if ( stopping_criteria == res_res ) then
                rhs_convergence_test = rtol * res_norm + atol
            end if
        end if
        error_estimate_convergence_test = res_norm
        if (num_iterations > 0 .and. track_convergence_history) then 
          error_estimate_history_convergence_test(num_iterations) = error_estimate_convergence_test
        end if
        did_converge = (error_estimate_convergence_test <= rhs_convergence_test)

        ! Send converged to coarse-grid tasks
        call environment%bcast(did_converge)

        if ( environment%am_i_fine_task() ) then
            if ((num_iterations > 0).and.(me == 0).and.(output_frequency/=0)) call this%print_convergence_history_new_line(luout)
        end if

        ! z = inv(M) r
        call M%apply(this%r, this%z)

        ! x <- x + relax * z	
        call x%axpby(this%relaxation,this%z,1.0_rp)

        num_iterations = num_iterations + 1
    end do loop_prichard

    if ( environment%am_i_fine_task() ) then
        if ((me == 0).and.(output_frequency/=0)) call this%print_convergence_history_footer(luout)
    end if
  end subroutine richardson_solve_body

  function richardson_supports_stopping_criteria(this,stopping_criteria)
    implicit none
    class(richardson_t), intent(in) :: this
    integer(ip)        , intent(in) :: stopping_criteria
    logical :: richardson_supports_stopping_criteria
    richardson_supports_stopping_criteria = (stopping_criteria == res_res .or. stopping_criteria == res_rhs)
  end function richardson_supports_stopping_criteria
  
  function richardson_get_default_stopping_criteria(this)
    implicit none
    class(richardson_t), intent(in) :: this
    integer(ip) :: richardson_get_default_stopping_criteria
    richardson_get_default_stopping_criteria = default_richardson_stopping_criteria
  end function richardson_get_default_stopping_criteria
  
  
  function create_richardson(environment)
    implicit none
    class(environment_t), intent(in) :: environment
    class(base_linear_solver_t), pointer :: create_richardson
    allocate ( richardson_t :: create_richardson )
    
    call create_richardson%set_environment(environment)
    call create_richardson%set_name(richardson_name)
    call create_richardson%set_defaults()
    select type ( create_richardson )
    class is ( richardson_t )
    create_richardson%relaxation = default_richardson_relaxation
    end select
    call create_richardson%set_state(start)
  end function create_richardson
  
end module richardson_names