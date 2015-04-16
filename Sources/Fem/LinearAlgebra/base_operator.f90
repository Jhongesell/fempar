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
module base_operator_names
  use types
  use memory_guard_names
  use integrable_names
  use base_operand_names
  implicit none
# include "debug.i90"

  private

  ! Abstract operator (and its pure virtual function apply)
  type, abstract, extends(integrable) :: base_operator
   contains
     procedure (apply_interface)         , deferred :: apply
     procedure (apply_fun_interface)     , deferred :: apply_fun
     procedure (info_interface)          , deferred :: info
     procedure (am_i_fine_task_interface), deferred :: am_i_fine_task
     procedure (bcast_interface)         , deferred :: bcast
     procedure  :: sum       => sum_operator_constructor
     procedure  :: sub       => sub_operator_constructor
     procedure  :: mult      => mult_operator_constructor
     procedure  :: minus     => minus_operator_constructor
     procedure, pass(op_left)  :: scal_left => scal_left_operator_constructor
     procedure, pass(op_right) :: scal_right => scal_right_operator_constructor
     generic    :: operator(+) => sum
     generic    :: operator(*) => mult, scal_right, scal_left, apply_fun
     generic    :: operator(-) => minus, sub
  end type base_operator

  ! Son class expression_operator. These operators are always temporary
  ! and therefore an assignment is needed to make copies. The gfortran
  ! compiler only supports A=B when A and B are polymorphic if the assignment 
  ! is overwritten.
  type, abstract, extends(base_operator) :: expression_operator 
   contains
     procedure (expression_operator_assign_interface), deferred :: assign
     generic  :: assignment(=) => assign
  end type expression_operator

  ! Derived class binary
  type, abstract, extends(expression_operator) :: binary_operator
     class(base_operator), pointer :: op1 => null(), op2 => null()
   contains
     procedure :: free    => binary_operator_destructor
     procedure :: assign  => binary_operator_copy
  end type binary_operator


  ! Son class abstract operator
  type, extends(base_operator) :: abs_operator
     class(base_operator), pointer :: op_stored => null()
     class(base_operator), pointer :: op        => null()
   contains
     procedure  :: apply     => abs_operator_apply
     procedure  :: apply_fun => abs_operator_apply_fun
     procedure  :: info => abs_operator_info
     procedure  :: am_i_fine_task => abs_operator_am_i_fine_task
     procedure  :: bcast => abs_operator_bcast
     procedure  :: free  => abs_operator_destructor
     procedure  :: assign => abs_operator_constructor
     generic    :: assignment(=) => assign
  end type abs_operator

  ! Son class sum
  type, extends(binary_operator) :: sum_operator
  contains
     procedure  :: apply => sum_operator_apply
     procedure  :: apply_fun => sum_operator_apply_fun 
     procedure  :: info => sum_operator_info
     procedure  :: am_i_fine_task => sum_operator_am_i_fine_task
     procedure  :: bcast => sum_operator_bcast
  end type sum_operator


  ! Son class sub
  type, extends(binary_operator) :: sub_operator
   contains
     procedure  :: apply => sub_operator_apply
     procedure  :: apply_fun => sub_operator_apply_fun 
     procedure  :: info => sub_operator_info
     procedure  :: am_i_fine_task => sub_operator_am_i_fine_task
     procedure  :: bcast => sub_operator_bcast
  end type sub_operator


  ! Son class mult
  type, extends(binary_operator) :: mult_operator
   contains
     procedure  :: apply => mult_operator_apply
     procedure  :: apply_fun => mult_operator_apply_fun 
     procedure  :: info => mult_operator_info
     procedure  :: am_i_fine_task => mult_operator_am_i_fine_task
     procedure  :: bcast => mult_operator_bcast
  end type mult_operator


  ! Son class scal
  type, extends(expression_operator) :: scal_operator
     class(base_operator), pointer :: op => null()
     real(rp)                     :: alpha
   contains
     procedure  :: apply => scal_operator_apply
     procedure  :: apply_fun => scal_operator_apply_fun
     procedure  :: info => scal_operator_info
     procedure  :: am_i_fine_task => scal_operator_am_i_fine_task
     procedure  :: bcast => scal_operator_bcast
     procedure  :: free => scal_operator_destructor
     procedure  :: assign => scal_operator_copy
  end type scal_operator


  ! Son class minus
  type, extends(base_operator) :: minus_operator
     class(base_operator), pointer :: op => null()
   contains
     procedure  :: apply => minus_operator_apply
     procedure  :: apply_fun => minus_operator_apply_fun 
     procedure  :: info => minus_operator_info
     procedure  :: am_i_fine_task => minus_operator_am_i_fine_task
     procedure  :: bcast => minus_operator_bcast
     procedure  :: free => minus_operator_destructor
     procedure  :: assign => minus_operator_copy
  end type minus_operator

  ! Abstract interfaces
  abstract interface
     ! op%apply(x,y) <=> y <- op*x
     ! Implicitly assumes that y is already allocated
     subroutine apply_interface(op,x,y) 
       import :: base_operator, base_operand
       implicit none
       class(base_operator), intent(in)    :: op
       class(base_operand) , intent(in)    :: x
       class(base_operand) , intent(inout) :: y 
     end subroutine apply_interface

     ! op%apply(x)
     ! Allocates room for (temporary) y
     function apply_fun_interface(op,x) result(y)
       import :: base_operator, base_operand
       implicit none
       class(base_operator), intent(in)  :: op
       class(base_operand) , intent(in)  :: x
       class(base_operand) , allocatable :: y 
     end function apply_fun_interface

     subroutine info_interface(op,me,np) 
       import :: base_operator, ip
       implicit none
       class(base_operator), intent(in)  :: op
       integer(ip)         , intent(out) :: me
       integer(ip)         , intent(out) :: np
     end subroutine info_interface

     function am_i_fine_task_interface(op) 
       import :: base_operator, ip
       implicit none
       class(base_operator), intent(in)  :: op
       logical                           :: am_i_fine_task_interface 
     end function am_i_fine_task_interface

     subroutine bcast_interface (op, condition)
       import :: base_operator
       implicit none
       class(base_operator), intent(in) :: op
       logical, intent(inout) :: condition
     end subroutine bcast_interface

     subroutine expression_operator_assign_interface(op1,op2)
       import :: base_operator, expression_operator
       implicit none
       class(base_operator)      , intent(in)    :: op2
       class(expression_operator), intent(inout) :: op1
     end subroutine expression_operator_assign_interface

  end interface

  public :: abs_operator, base_operator

contains
  subroutine binary_operator_destructor(this)
    implicit none
    class(binary_operator), intent(inout) :: this
    ! out_verbosity10_2( 'Destructing binary',this%id )

    select type(that => this%op1)
    class is(expression_operator)
       call that%CleanTemp()
    class is(abs_operator)
       call that%CleanTemp()
    class default
       check(1==0)
       ! out_verbosity10_1( 'Why I am here?' )
    end select
    ! out_verbosity10_2( 'Deallocating',this%op1%id )
    deallocate(this%op1)

    select type(that => this%op2)
    class is(expression_operator)
       call that%CleanTemp()
    class is(abs_operator)
       call that%CleanTemp()
    class default
       check(1==0)
       ! out_verbosity10_1( 'Why I am here?')
    end select
    ! out_verbosity10_2( 'Deallocating',this%op2%id )
    deallocate(this%op2)
  end subroutine binary_operator_destructor

  subroutine binary_operator_copy(op1,op2)
    implicit none
    class(base_operator)  , intent(in)    :: op2
    class(binary_operator), intent(inout) :: op1

    ! global_id=global_id+1
    ! op1%id=global_id
    ! out_verbosity10_4( 'Copy binary_operator', op1%id, ' from ',op2%id)
    select type(op2)
    class is(binary_operator)
       call binary_operator_constructor(op2%op1,op2%op2,op1)
    class default
       check(1==0)
    end select
  end subroutine binary_operator_copy

  subroutine binary_operator_constructor(op1,op2,res) 
    implicit none
    class(base_operator)  , intent(in)    :: op1, op2
    class(binary_operator), intent(inout) :: res

    call op1%GuardTemp()
    call op2%GuardTemp()

    ! out_verbosity10_1( 'Creating binary left operator')

    ! Allocate op1
    select type(op1)
    class is(expression_operator)
       allocate(res%op1,mold=op1)
    class default
       allocate(abs_operator::res%op1)
    end select
    ! Assign op1
    select type(this => res%op1)
    class is(expression_operator)
       ! out_verbosity10_1( 'binary left is an expression' )
       this = op1 ! Here = is overloaded (and potentially recursive)
       call this%GuardTemp()
    class is(abs_operator)
       ! out_verbosity10_1( 'binary left is not an expression' )
       this = op1 ! Here = is overloaded (and potentially recursive)
       call this%SetTemp()
       call this%GuardTemp()
    end select

    ! out_verbosity10_1( 'Creating binary right operator')

    ! Allocate op2
    select type(op2)
    class is(expression_operator)
       allocate(res%op2,mold=op2)
    class default
       allocate(abs_operator::res%op2)
    end select
    ! Assign op2
    select type(that => res%op2)
    class is(expression_operator)
       ! out_verbosity10_1( 'binary right is an expression' )
       that = op2 ! Here = is overloaded (and potentially recursive)
       call that%GuardTemp()
    class is(abs_operator)
       ! out_verbosity10_1( 'binary right is not an expression' )
       that = op2 ! Here = is overloaded (and potentially recursive)
       call that%SetTemp()
       call that%GuardTemp()
    end select
    call res%SetTemp()
    call op1%CleanTemp()
    call op2%CleanTemp()
  end subroutine binary_operator_constructor

  recursive subroutine abs_operator_constructor(op1,op2)
    implicit none
    class(base_operator), intent(in), target  :: op2
    class(abs_operator) , intent(inout) :: op1

    call op1%free()
    ! global_id=global_id+1
    ! op1%id=global_id

    call op2%GuardTemp()
    select type(op2)
    class is(abs_operator) ! Can be temporary (or not)
       if(associated(op2%op_stored)) then
          assert(.not.associated(op2%op))
          allocate(op1%op_stored, mold = op2%op_stored)
          select type(this => op1%op_stored)
          class is(expression_operator)
             ! out_verbosity10_4( 'Creating abs ', op1%id, ' from abs (copy content, which is expression)', op2%id)
             this = op2%op_stored
          class is(abs_operator)
             ! out_verbosity10_4( 'Creating abs ', op1%id, ' from abs (copy content, which is abs)', op2%id)
             this = op2%op_stored
          class default
             ! out_verbosity10_1( 'How this is possible????')
             check(1==0)
          end select
       else if(associated(op2%op)) then
          assert(.not.associated(op2%op_stored))
          ! out_verbosity10_4( 'Creating abs ', op1%id, ' from abs (reassign pointer)', op2%id)
          op1%op => op2%op
       else
          ! out_verbosity10_1( 'How this is possible????')
          check(1==0)
       end if
    class is(expression_operator) ! Temporary
       ! out_verbosity10_2( 'Creating abs from expression (copy expression)', op1%id)
       allocate(op1%op_stored,mold=op2)
       select type(this => op1%op_stored)
       class is(expression_operator)
          this = op2              ! Here = overloaded
       end select
   class default                 ! Cannot be temporary (I don't know how to copy it!)
       !assert(.not.op2%IsTemp())
       !out_verbosity10_2( 'Creating abs from base_operator (point to a permanent base_operator)', op1%id)
       op1%op => op2
    end select
    ! out_verbosity10_2( 'Creating abs rhs argument has temporary counter', op2%GetTemp())
    call op2%CleanTemp()
  end subroutine abs_operator_constructor

  subroutine abs_operator_destructor(this)
    implicit none
    class(abs_operator), intent(inout) :: this

    if(associated(this%op)) then
       assert(.not.associated(this%op_stored))
       ! out_verbosity10_2( 'Destructing abs association', this%id)
       ! Nothing to free, the pointer points to permanent data
       this%op => null()
    else if(associated(this%op_stored)) then
       assert(.not.associated(this%op))
       ! out_verbosity10_2( 'Destructing abs allocation', this%id)
       ! Any of the following two lines should give the same result
       call this%op_stored%CleanTemp()
       ! out_verbosity10_2( 'Deallocating',this%op_stored%id )
       deallocate(this%op_stored)
    end if
    ! else
       ! out_verbosity10_2( 'Called when initialized',this%id)
    ! end if
  end subroutine abs_operator_destructor

  subroutine scal_operator_constructor(alpha,op,res)
    implicit none
    class(base_operator), intent(in)    :: op
    real(rp)            , intent(in)    :: alpha
    type(scal_operator) , intent(inout) :: res

    call op%GuardTemp()
    res%alpha = alpha
    ! Allocate op
    select type(op)
    class is(expression_operator)
       allocate(res%op,mold=op)
    class default
       allocate(abs_operator::res%op)
    end select
    ! Assign op
    select type(this => res%op)
    class is(expression_operator)
       this = op ! Here = is overloaded (and potentially recursive)
       call this%GuardTemp()
    class is(abs_operator)
       this = op ! Here = is overloaded (and potentially recursive)
       call this%SetTemp()
       call this%GuardTemp()
    end select
    call res%SetTemp()
    call op%CleanTemp()
  end subroutine scal_operator_constructor

  subroutine scal_operator_destructor(this)
    implicit none
    class(scal_operator), intent(inout) :: this 
    ! out_verbosity10_2( 'Destructing scal ', this%id)
    select type(that => this%op)
    class is(expression_operator)
       call that%CleanTemp()
    class is(abs_operator)
       call that%CleanTemp()
    class default
       ! out_verbosity10_1( 'Why I am here?' )
       check(1==0)
    end select
    ! out_verbosity10_2( 'Deallocating',this%op%id )
    deallocate(this%op)
  end subroutine scal_operator_destructor

  subroutine scal_operator_copy(op1,op2)
    implicit none
    class(base_operator), intent(in)    :: op2
    class(scal_operator), intent(inout) :: op1
    !global_id=global_id+1
    !op1%id=global_id
    !out_verbosity10_4( 'Copy scal_operator ',op1%id,' from ', op2%id)
    select type(op2)
    class is(scal_operator)
       call scal_operator_constructor(op2%alpha,op2%op,op1) ! Not the default constructor
    class default
       check(1==0)
       !out_verbosity10_1( 'Error assigning scal operators')
       !stop
    end select
  end subroutine scal_operator_copy

  function minus_operator_constructor(op) result (res)
    implicit none
    class(base_operator)    , intent(in)  :: op
    type(minus_operator) :: res
    !type(scal_operator), allocatable :: res
    !allocate(res)
    !global_id=global_id+1
    !res%id=global_id
    !out_verbosity10_2('Creating scal left', res%id )
    call minus_operator_constructor_sub(op,res)
  end function minus_operator_constructor

  subroutine minus_operator_constructor_sub(op,res)
    implicit none
    class(base_operator) , intent(in)    :: op
    type(minus_operator) , intent(inout) :: res

    call op%GuardTemp()
    ! Allocate op
    select type(op)
    class is(expression_operator)
       allocate(res%op,mold=op)
    class default
       allocate(abs_operator::res%op)
    end select
    ! Assign op
    select type(this => res%op)
    class is(expression_operator)
       this = op ! Here = is overloaded (and potentially recursive)
       call this%GuardTemp()
    class is(abs_operator)
       this = op ! Here = is overloaded (and potentially recursive)
       call this%SetTemp()
       call this%GuardTemp()
    end select
    call res%SetTemp()
    call op%CleanTemp()
  end subroutine minus_operator_constructor_sub

  subroutine minus_operator_destructor(this)
    implicit none
    class(minus_operator), intent(inout) :: this 
    ! out_verbosity10_2( 'Destructing minus ', this%id)
    select type(that => this%op)
    class is(expression_operator)
       call that%CleanTemp()
    class is(abs_operator)
       call that%CleanTemp()
    class default
       ! out_verbosity10_1( 'Why I am here?' )
       check(1==0)
    end select
    ! out_verbosity10_2( 'Deallocating',this%op%id )
    deallocate(this%op)
  end subroutine minus_operator_destructor

  subroutine minus_operator_copy(op1,op2)
    implicit none
    class(base_operator), intent(in)    :: op2
    class(minus_operator), intent(inout) :: op1
    !global_id=global_id+1
    !op1%id=global_id
    !out_verbosity10_4( 'Copy minus_operator ',op1%id,' from ', op2%id)
    select type(op2)
    class is(minus_operator)
       call minus_operator_constructor_sub(op2%op,op1) ! Not the default constructor
    class default
       check(1==0)
       !out_verbosity10_1( 'Error assigning minus operators')
       !stop
    end select
  end subroutine minus_operator_copy

!!$  !--------------------------------------------------------------------!
!!$  ! Construction and deallocation functions/subroutines of the nodes of! 
!!$  ! the tree that represents an expression among matrix operators      !
!!$  ! -------------------------------------------------------------------!
  function sum_operator_constructor(op1,op2) result (res)
    implicit none
    class(base_operator), intent(in)  :: op1, op2
    type(sum_operator)  :: res
    !type(sum_operator)  , allocatable :: res
    !allocate(res)
    ! global_id=global_id+1
    ! res%id=global_id
    ! out_verbosity10_2( 'Creating sum', res%id)
    call binary_operator_constructor(op1,op2,res) 
  end function sum_operator_constructor

  function sub_operator_constructor(op1,op2) result (res)
    implicit none
    class(base_operator), intent(in)  :: op1, op2
    type(sub_operator)  :: res
    !type(sub_operator)  , allocatable :: res
    !allocate(res)
    ! global_id=global_id+1
    ! res%id=global_id
    ! out_verbosity10_2( 'Creating sub', res%id)
    call binary_operator_constructor(op1,op2,res) 
  end function sub_operator_constructor

  function mult_operator_constructor(op1,op2) result (res)
    implicit none
    class(base_operator), intent(in)  :: op1, op2
    type(mult_operator) :: res
    !type(mult_operator) , allocatable :: res
    !allocate(res)
    !global_id=global_id+1
    !res%id=global_id
    !out_verbosity10_2( 'Creating mult', res%id)
    call binary_operator_constructor(op1,op2,res)
  end function mult_operator_constructor

  function scal_left_operator_constructor(alpha, op_left) result (res)
    implicit none
    class(base_operator)    , intent(in)  :: op_left
    real(rp)                , intent(in)  :: alpha
    type(scal_operator) :: res
    !type(scal_operator), allocatable :: res
    !allocate(res)
    !global_id=global_id+1
    !res%id=global_id
    !out_verbosity10_2('Creating scal left', res%id )
    call scal_operator_constructor(alpha,op_left,res)
  end function scal_left_operator_constructor
  
  function scal_right_operator_constructor(op_right, alpha) result (res)
    implicit none
    class(base_operator)    , intent(in)  :: op_right
    real(rp)                , intent(in)  :: alpha
    type(scal_operator) :: res
    !type(scal_operator), allocatable :: res
    !allocate(res)
    !global_id=global_id+1
    !res%id=global_id
    !out_verbosity10_2( 'Creating scal right', res%id )
    call scal_operator_constructor(alpha,op_right,res)
  end function scal_right_operator_constructor

  !-------------------------------------!
  ! apply_fun and apply implementations !
  !-------------------------------------!
  function sum_operator_apply_fun(op,x) result(y)
    implicit none
    class(sum_operator), intent(in)       :: op
    class(base_operand)     , intent(in)  :: x
    class(base_operand)     , allocatable :: y 
    call op%GuardTemp()
    call x%GuardTemp()
    allocate(y, mold=x)
    y = op%op2 * x
    call y%axpby( 1.0, op%op1*x, 1.0 )
    call x%CleanTemp()
    call op%CleanTemp()
    call y%SetTemp()
  end function sum_operator_apply_fun

  subroutine sum_operator_apply(op,x,y)
    implicit none
    class(sum_operator), intent(in)    :: op
    class(base_operand), intent(in)    :: x
    class(base_operand), intent(inout) :: y 
    call op%GuardTemp()
    call x%GuardTemp()
    ! y <- op2*x
    call op%op2%apply(x,y)
    ! y <- 1.0 * op1*x + 1.0*y
    call y%axpby( 1.0, op%op1*x, 1.0 )
    call x%CleanTemp()
    call op%CleanTemp()
  end subroutine sum_operator_apply

  
  function sub_operator_apply_fun(op,x) result(y)
    implicit none
    class(sub_operator), intent(in)       :: op
    class(base_operand)     , intent(in)  :: x
    class(base_operand)     , allocatable :: y 
    call op%GuardTemp()
    call x%GuardTemp()
    allocate(y, mold=x)
    y = op%op2 * x
    call y%axpby( 1.0, op%op1*x, -1.0 )
    call x%CleanTemp()
    call op%CleanTemp()
    call y%SetTemp()
  end function sub_operator_apply_fun

  subroutine sub_operator_apply(op,x,y)
    implicit none
    class(sub_operator), intent(in)    :: op
    class(base_operand), intent(in)    :: x
    class(base_operand), intent(inout) :: y 
    call op%GuardTemp()
    call x%GuardTemp()
    ! y <- op2*x
    call op%op2%apply(x,y)
    ! y <- 1.0 * op1*x - 1.0*y
    call y%axpby( 1.0, op%op1*x, -1.0 )
    call x%CleanTemp()
    call op%CleanTemp()
  end subroutine sub_operator_apply
  
  function mult_operator_apply_fun(op,x) result(y)
    implicit none
    class(mult_operator), intent(in)       :: op
    class(base_operand)     , intent(in)  :: x
    class(base_operand)     , allocatable :: y 
    call op%GuardTemp()
    call x%GuardTemp()
    allocate(y, mold=x)
    y = op%op1 * ( op%op2 * x )
    call x%CleanTemp()
    call op%CleanTemp()
    call y%SetTemp()
  end function mult_operator_apply_fun

  subroutine mult_operator_apply(op,x,y)
    implicit none
    class(mult_operator), intent(in)    :: op
    class(base_operand), intent(in)    :: x
    class(base_operand), intent(inout) :: y 
    call op%GuardTemp()
    call x%GuardTemp()
    call op%op2%apply ( op%op1*x, y )
    call x%CleanTemp()
    call op%CleanTemp()
  end subroutine mult_operator_apply

  function  scal_operator_apply_fun(op,x) result(y)
    implicit none
    class(scal_operator), intent(in)      :: op
    class(base_operand)     , intent(in)  :: x
    class(base_operand)     , allocatable :: y 
    call op%GuardTemp()
    call x%GuardTemp()
    allocate(y, mold=x)
    y =  op%op * x
    call y%scal ( op%alpha, y)
    call x%CleanTemp()
    call op%CleanTemp()
    call y%SetTemp()
  end function scal_operator_apply_fun

  subroutine scal_operator_apply(op,x,y)
    implicit none
    class(scal_operator), intent(in)   :: op
    class(base_operand), intent(in)    :: x
    class(base_operand), intent(inout) :: y 
    call op%GuardTemp()
    call x%GuardTemp()
    call op%op%apply(x,y)
    call y%scal( op%alpha, y )
    call x%CleanTemp()
    call op%CleanTemp()
  end subroutine scal_operator_apply

  function  minus_operator_apply_fun(op,x) result(y)
    implicit none
    class(minus_operator), intent(in)       :: op
    class(base_operand)     , intent(in)  :: x
    class(base_operand)     , allocatable :: y 
    call op%GuardTemp()
    call x%GuardTemp()
    allocate(y, mold=x)
    y = op%op*x
    call y%scal( -1.0, y )
    call x%CleanTemp()
    call y%SetTemp()
    call op%CleanTemp()
  end function minus_operator_apply_fun

  subroutine minus_operator_apply(op,x,y)
    implicit none
    class(minus_operator), intent(in)  :: op
    class(base_operand), intent(in)    :: x
    class(base_operand), intent(inout) :: y 
    call op%GuardTemp()
    call x%GuardTemp()
    call op%op%apply(x,y)
    call y%scal( -1.0, y )
    call x%CleanTemp()
    call op%CleanTemp()
  end subroutine minus_operator_apply

  function  abs_operator_apply_fun(op,x) result(y)
    implicit none
    class(abs_operator), intent(in)       :: op
    class(base_operand)     , intent(in)  :: x
    class(base_operand)     , allocatable :: y 
    call op%GuardTemp()
    call x%GuardTemp()
    allocate(y, mold=x)

    if(associated(op%op_stored)) then
       assert(.not.associated(op%op))
       y = op%op_stored*x
    else if(associated(op%op)) then
       assert(.not.associated(op%op_stored))
       y = op%op*x
    else
       check(1==0)
    end if

    call x%CleanTemp()
    call op%CleanTemp()
    call y%SetTemp()
  end function abs_operator_apply_fun

  subroutine abs_operator_apply(op,x,y)
    implicit none
    class(abs_operator), intent(in)    :: op
    class(base_operand), intent(in)    :: x
    class(base_operand), intent(inout) :: y 
    call op%GuardTemp()
    call x%GuardTemp()

    if(associated(op%op_stored)) then
       assert(.not.associated(op%op))
       call op%op_stored%apply(x,y)
    else if(associated(op%op)) then
       assert(.not.associated(op%op_stored))
       call op%op%apply(x,y)
    else
       check(1==0)
    end if

    call x%CleanTemp()
    call op%CleanTemp()
  end subroutine abs_operator_apply

  !-------------------------------------!
  ! info implementations                !
  !-------------------------------------!
  subroutine sum_operator_info(op,me,np)
    implicit none
    class(sum_operator), intent(in)    :: op
    integer(ip)        , intent(out)   :: me
    integer(ip)        , intent(out)   :: np
    call op%GuardTemp()
    call op%op1%info(me,np)
    call op%CleanTemp()
  end subroutine sum_operator_info

  subroutine sub_operator_info(op,me,np)
    implicit none
    class(sub_operator), intent(in)    :: op
    integer(ip)        , intent(out)   :: me
    integer(ip)        , intent(out)   :: np
    call op%GuardTemp()
    call op%op1%info(me,np)
    call op%CleanTemp()
  end subroutine sub_operator_info
  
  subroutine mult_operator_info(op,me,np)
    implicit none
    class(mult_operator), intent(in)    :: op
    integer(ip)         , intent(out)   :: me
    integer(ip)         , intent(out)   :: np
    call op%GuardTemp()
    call op%op1%info(me,np)
    call op%CleanTemp()
  end subroutine mult_operator_info

  subroutine minus_operator_info(op,me,np)
    implicit none
    class(minus_operator), intent(in)   :: op
    integer(ip)         , intent(out)   :: me
    integer(ip)         , intent(out)   :: np
    call op%GuardTemp()
    call op%op%info(me,np)
    call op%CleanTemp()
  end subroutine minus_operator_info
  
  subroutine scal_operator_info(op,me,np)
    implicit none
    class(scal_operator), intent(in)    :: op
    integer(ip)         , intent(out)   :: me
    integer(ip)         , intent(out)   :: np
    call op%GuardTemp()
    call op%op%info(me,np)
    call op%CleanTemp()
  end subroutine scal_operator_info

  subroutine abs_operator_info(op,me,np)
    implicit none
    class(abs_operator), intent(in)    :: op
    integer(ip)        , intent(out)   :: me
    integer(ip)        , intent(out)   :: np

    call op%GuardTemp()
    if(associated(op%op_stored)) then
       assert(.not.associated(op%op))
       call op%op_stored%info(me,np)
    else if(associated(op%op)) then
       assert(.not.associated(op%op_stored))
       call op%op%info(me,np)
    else
       check(1==0)
    end if
    call op%CleanTemp()
  end subroutine abs_operator_info

  !-------------------------------------!
  ! am_i_fine_task implementations      !
  !-------------------------------------!
  function sum_operator_am_i_fine_task(op)
    implicit none
    class(sum_operator), intent(in)    :: op
    logical :: sum_operator_am_i_fine_task
    call op%GuardTemp()
    sum_operator_am_i_fine_task = op%op1%am_i_fine_task()
    call op%CleanTemp()
  end function sum_operator_am_i_fine_task
  
  function sub_operator_am_i_fine_task(op)
    implicit none
    class(sub_operator), intent(in)    :: op
    logical :: sub_operator_am_i_fine_task
    call op%GuardTemp()
    sub_operator_am_i_fine_task = op%op1%am_i_fine_task()
    call op%CleanTemp()
  end function sub_operator_am_i_fine_task

  function mult_operator_am_i_fine_task(op)
    implicit none
    class(mult_operator), intent(in)    :: op
    logical :: mult_operator_am_i_fine_task
    call op%GuardTemp()
    mult_operator_am_i_fine_task = op%op1%am_i_fine_task()
    call op%CleanTemp()
  end function mult_operator_am_i_fine_task
  
  function minus_operator_am_i_fine_task(op)
    implicit none
    class(minus_operator), intent(in)    :: op
    logical :: minus_operator_am_i_fine_task
    call op%GuardTemp()
    minus_operator_am_i_fine_task = op%op%am_i_fine_task()
    call op%CleanTemp()
  end function minus_operator_am_i_fine_task

  function scal_operator_am_i_fine_task(op)
    implicit none
    class(scal_operator), intent(in)    :: op
    logical :: scal_operator_am_i_fine_task
    call op%GuardTemp()
    scal_operator_am_i_fine_task = op%op%am_i_fine_task()
    call op%CleanTemp()
  end function scal_operator_am_i_fine_task

  function abs_operator_am_i_fine_task(op)
    implicit none
    class(abs_operator), intent(in)    :: op
    logical :: abs_operator_am_i_fine_task
    call op%GuardTemp()
    if(associated(op%op_stored)) then
       assert(.not.associated(op%op))
       abs_operator_am_i_fine_task = op%op_stored%am_i_fine_task()
    else if(associated(op%op)) then
       assert(.not.associated(op%op_stored))
       abs_operator_am_i_fine_task = op%op%am_i_fine_task()
    else
       check(1==0)
    end if
    call op%CleanTemp()
  end function abs_operator_am_i_fine_task

  !-------------------------------------!
  ! bcast implementations               !
  !-------------------------------------!
  subroutine sum_operator_bcast(op,condition)
    implicit none
    class(sum_operator), intent(in)    :: op
    logical            , intent(inout)   :: condition
    call op%GuardTemp()
    call op%op1%bcast(condition)
    call op%CleanTemp()
  end subroutine sum_operator_bcast

  subroutine sub_operator_bcast(op,condition)
    implicit none
    class(sub_operator), intent(in)    :: op
    logical            , intent(inout)   :: condition
    call op%GuardTemp()
    call op%op1%bcast(condition)
    call op%CleanTemp()
  end subroutine sub_operator_bcast

  subroutine mult_operator_bcast(op,condition)
    implicit none
    class(mult_operator), intent(in)   :: op
    logical            , intent(inout)   :: condition
    call op%GuardTemp()
    call op%op1%bcast(condition)
    call op%CleanTemp()
  end subroutine mult_operator_bcast

  subroutine minus_operator_bcast(op,condition)
    implicit none
    class(minus_operator), intent(in)   :: op
    logical            , intent(inout)   :: condition
    call op%GuardTemp()
    call op%op%bcast(condition)
    call op%CleanTemp()
  end subroutine minus_operator_bcast

  subroutine scal_operator_bcast(op,condition)
    implicit none
    class(scal_operator), intent(in)   :: op
    logical            , intent(inout)   :: condition
    call op%GuardTemp()
    call op%op%bcast(condition)
    call op%CleanTemp()
  end subroutine scal_operator_bcast

  subroutine abs_operator_bcast(op,condition)
    implicit none
    class(abs_operator), intent(in)     :: op
    logical            , intent(inout)   :: condition
    call op%GuardTemp()
    if(associated(op%op_stored)) then
       assert(.not.associated(op%op))
       call op%op_stored%bcast(condition)
    else if(associated(op%op)) then
       assert(.not.associated(op%op_stored))
       call op%op%bcast(condition)
    else
       check(1==0)
    end if
    call op%CleanTemp()
  end subroutine abs_operator_bcast

end module base_operator_names