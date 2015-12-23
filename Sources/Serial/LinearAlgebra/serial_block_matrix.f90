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
module serial_block_matrix_names
  use types_names
  use memor_names
  use serial_scalar_matrix_names
  use serial_block_array_names
  use serial_scalar_array_names
  
  ! Abstract types
  use vector_names
  use operator_names
  use matrix_names
  use vector_space_names

  implicit none
# include "debug.i90"

  private
  
  type p_serial_scalar_matrix_t
    type(serial_scalar_matrix_t), pointer :: serial_scalar_matrix
  end type p_serial_scalar_matrix_t

  type, extends(matrix_t):: serial_block_matrix_t
     ! private ! IBM XLF 14.1 bug
     integer(ip) :: nblocks = -1
     type(p_serial_scalar_matrix_t), allocatable :: blocks(:,:)
   contains
     procedure, private :: serial_block_matrix_create_only_blocks_container
     procedure, private :: serial_block_matrix_create_blocks_container_and_all_blocks
     !generic :: create  => serial_block_matrix_create_only_blocks_container, &
     !                      serial_block_matrix_create_blocks_container_and_all_blocks
     generic :: create => serial_block_matrix_create_blocks_container_and_all_blocks
     
     ! This set of methods should be re-thought/developed in the future whenever we have a clearer
     ! idea of which services these objects should provide and how they should behave
     ! (i.e., once we know how to precisely define their state transition diagram)
     ! procedure, private :: serial_block_matrix_create_diagonal_block
     ! procedure, private :: serial_block_matrix_create_offdiagonal_block
     ! generic :: create_block => serial_block_matrix_create_diagonal_block, &
     !                            serial_block_matrix_create_offdiagonal_block
     procedure :: set_block_to_zero => serial_block_matrix_set_block_to_zero                     
                           
     procedure :: allocate                      => serial_block_matrix_allocate
     procedure :: free_in_stages                => serial_block_matrix_free_in_stages
     procedure :: get_block                     => serial_block_matrix_get_block
     procedure :: get_nblocks                   => serial_block_matrix_get_nblocks
     procedure :: apply                         => serial_block_matrix_apply
     procedure, private :: create_vector_spaces => serial_block_matrix_create_vector_spaces
  end type serial_block_matrix_t

  ! Types
  public :: serial_block_matrix_t

contains

  !=============================================================================
  subroutine serial_block_matrix_create_blocks_container_and_all_blocks(this, & 
                                                                        nblocks, & 
                                                                        diagonal_blocks_num_rows, &
                                                                        diagonal_blocks_num_cols, &
                                                                        diagonal_blocks_symmetric_storage,&
                                                                        diagonal_blocks_symmetric,& 
                                                                        diagonal_blocks_sign)
    implicit none
    class(serial_block_matrix_t), intent(inout) :: this
    integer(ip)                 , intent(in)    :: nblocks
    integer(ip)                 , intent(in)    :: diagonal_blocks_num_rows(nblocks)
    integer(ip)                 , intent(in)    :: diagonal_blocks_num_cols(nblocks)
    logical                     , intent(in)    :: diagonal_blocks_symmetric_storage(nblocks)
    logical                     , intent(in)    :: diagonal_blocks_symmetric(nblocks)
    integer(ip)                 , intent(in)    :: diagonal_blocks_sign(nblocks)

    integer(ip) :: ib,jb,istat

    call this%serial_block_matrix_create_only_blocks_container(nblocks)
    do ib=1, this%nblocks 
       do jb=1, this%nblocks
          allocate ( this%blocks(ib,jb)%serial_scalar_matrix )
          if ( ib == jb ) then
             assert ( diagonal_blocks_num_rows(ib) == diagonal_blocks_num_cols(ib) )
             call this%blocks(ib,jb)%serial_scalar_matrix%create ( diagonal_blocks_num_rows(ib), &
                                                                   diagonal_blocks_symmetric_storage(ib), &
                                                                   diagonal_blocks_symmetric(ib), &
                                                                   diagonal_blocks_sign(ib) )
          else
             call this%blocks(ib,jb)%serial_scalar_matrix%create( diagonal_blocks_num_rows(ib), &
                                                                  diagonal_blocks_num_cols(ib) )
          end if
       end do
    end do
    call this%create_vector_spaces()
  end subroutine serial_block_matrix_create_blocks_container_and_all_blocks

  !=============================================================================
  subroutine serial_block_matrix_create_only_blocks_container(this,nblocks)
    implicit none
    ! Parameters
    class(serial_block_matrix_t), intent(inout) :: this
    integer(ip)                 , intent(in)    :: nblocks
    integer(ip) :: istat
    this%nblocks = nblocks
    allocate ( this%blocks(this%nblocks,this%nblocks), stat=istat )
    check (istat==0)
  end subroutine serial_block_matrix_create_only_blocks_container
  
  !=============================================================================
  subroutine serial_block_matrix_allocate(this)
    implicit none
    class(serial_block_matrix_t), intent(inout) :: this
    integer(ip) :: ib,jb
    do ib=1, this%nblocks
       do jb=1, this%nblocks
          if ( associated( this%blocks(ib,jb)%serial_scalar_matrix ) ) then
            call this%blocks(ib,jb)%serial_scalar_matrix%allocate()
          end if
       end do
    end do
  end subroutine serial_block_matrix_allocate
  
  subroutine serial_block_matrix_create_vector_spaces(this)
    implicit none
    class(serial_block_matrix_t), intent(inout) :: this
    integer(ip) :: ib
    
    integer(ip), allocatable :: size_of_blocks_domain(:)
    integer(ip), allocatable :: size_of_blocks_range(:)
    type(serial_block_array_t) :: range_vector
    type(serial_block_array_t) :: domain_vector
    class(vector_space_t), pointer :: range_vector_space
    class(vector_space_t), pointer :: domain_vector_space

    call memalloc(this%nblocks,size_of_blocks_domain,__FILE__,__LINE__)
    call memalloc(this%nblocks,size_of_blocks_range,__FILE__,__LINE__)
    
    do ib=1, this%nblocks
        size_of_blocks_domain(ib) = this%blocks(ib,ib)%serial_scalar_matrix%graph%get_nv2()
        size_of_blocks_range(ib) = this%blocks(ib,ib)%serial_scalar_matrix%graph%get_nv()
    end do
    
    ! Create and set domain and range vector spaces
    call range_vector%create(this%nblocks, size_of_blocks_range)
    call domain_vector%create(this%nblocks, size_of_blocks_domain)
    
    range_vector_space => this%get_range_vector_space()
    call range_vector_space%create(range_vector)
    
    domain_vector_space => this%get_domain_vector_space()
    call domain_vector_space%create(domain_vector)
    
    call range_vector%free()
    call domain_vector%free()
    
    call memfree(size_of_blocks_domain,__FILE__,__LINE__)
    call memfree(size_of_blocks_range,__FILE__,__LINE__)
  end subroutine serial_block_matrix_create_vector_spaces
  

  function serial_block_matrix_get_block (bmat,ib,jb)
    implicit none
    ! Parameters
    class(serial_block_matrix_t), target, intent(in) :: bmat
    integer(ip)                    , intent(in) :: ib,jb
    type(serial_scalar_matrix_t)               , pointer    :: serial_block_matrix_get_block
    serial_block_matrix_get_block =>  bmat%blocks(ib,jb)%serial_scalar_matrix
  end function serial_block_matrix_get_block

  function serial_block_matrix_get_nblocks (this)
    implicit none
    ! Parameters
    class(serial_block_matrix_t), target, intent(in) :: this
    integer(ip)                                :: serial_block_matrix_get_nblocks
    serial_block_matrix_get_nblocks = this%nblocks
  end function serial_block_matrix_get_nblocks

  ! op%apply(x,y) <=> y <- op*x
  ! Implicitly assumes that y is already allocated
  subroutine serial_block_matrix_apply(op,x,y)
    implicit none
    class(serial_block_matrix_t), intent(in)    :: op
    class(vector_t), intent(in)    :: x
    class(vector_t), intent(inout) :: y
    ! Locals
    integer(ip) :: ib,jb
    type(serial_scalar_array_t) :: aux

    call op%abort_if_not_in_domain(x)
    call op%abort_if_not_in_range(y)
    
    call x%GuardTemp()
    call y%init(0.0_rp)
    select type(x)
       class is (serial_block_array_t)
       select type(y)
          class is(serial_block_array_t)
          do ib=1,op%nblocks
             call aux%clone(y%blocks(ib))
             do jb=1,op%nblocks
                if ( associated(op%blocks(ib,jb)%serial_scalar_matrix) ) then
                   ! aux <- A(ib,jb) * x(jb)
                   call op%blocks(ib,jb)%serial_scalar_matrix%apply(x%blocks(jb),aux)
                   ! y(ib) <- y(ib) + aux
                   call y%blocks(ib)%axpby(1.0_rp,aux,1.0_rp)
                end if
             end do
             call aux%free()
          end do
       end select
    end select
    call x%CleanTemp()
  end subroutine serial_block_matrix_apply

  subroutine serial_block_matrix_free_in_stages(this,action)
    implicit none
    class(serial_block_matrix_t), intent(inout) :: this
    integer(ip)                 , intent(in)    :: action
    integer(ip) :: ib,jb, istat

    do ib=1, this%nblocks 
       do jb=1, this%nblocks
          if ( associated(this%blocks(ib,jb)%serial_scalar_matrix) ) then
             if ( action == free_clean ) then
                call this%blocks(ib,jb)%serial_scalar_matrix%free_in_stages(free_clean)
                deallocate (this%blocks(ib,jb)%serial_scalar_matrix, stat=istat)
                check(istat==0)
             else if ( action == free_symbolic_setup ) then 
                call this%blocks(ib,jb)%serial_scalar_matrix%free_in_stages(free_symbolic_setup)
             else if ( action == free_numerical_setup ) then
                call this%blocks(ib,jb)%serial_scalar_matrix%free_in_stages(free_numerical_setup)
             end if
          end if
       end do
    end do
    if (action == free_clean) then
       this%nblocks = 0
       deallocate (this%blocks, stat=istat)
       check(istat==0)
       call this%free_vector_spaces()
    end if
  end subroutine serial_block_matrix_free_in_stages
  
  !subroutine serial_block_matrix_create_diagonal_block (bmat,ib,diagonal_block_num_rows_and_cols,diagonal_block_symmetric_storage,diagonal_block_symmetric,diagonal_block_sign)
  !  implicit none
  !  ! Parameters
  !  class(serial_block_matrix_t)   , intent(inout) :: bmat
  !  integer(ip)                    , intent(in)    :: ib
  !  integer(ip)                    , intent(in)    :: diagonal_block_num_rows_and_cols
  !  logical                        , intent(in)    :: diagonal_block_symmetric_storage
  !  logical                        , intent(in)    :: diagonal_block_symmetric
  !  integer(ip)                    , intent(in)    :: diagonal_block_sign
  !  integer(ip) :: istat

  !  assert ( .not. associated ( bmat%blocks(ib,ib)%serial_scalar_matrix ) )
  !  allocate ( bmat%blocks(ib,ib)%serial_scalar_matrix, stat=istat )
  !  check ( istat==0 )
  !  call bmat%blocks(ib,ib)%serial_scalar_matrix%create ( diagonal_block_num_rows_and_cols, diagonal_block_symmetric_storage, diagonal_block_symmetric, diagonal_block_sign )
  !end subroutine serial_block_matrix_create_diagonal_block

  !subroutine serial_block_matrix_create_offdiagonal_block (bmat,ib,jb,num_rows,num_cols)
  !  implicit none
  !  ! Parameters
  !  class(serial_block_matrix_t)   , intent(inout) :: bmat
  !  integer(ip)                    , intent(in)    :: ib,jb
  !  integer(ip)                    , intent(in)    :: num_rows, num_cols
  !  integer(ip) :: istat
  !  assert ( ib /= jb ) 
  !  assert ( .not. associated(bmat%blocks(ib,jb)%serial_scalar_matrix ))
  !  allocate ( bmat%blocks(ib,ib)%serial_scalar_matrix, stat=istat )
  !  check ( istat==0 )
  !  call bmat%blocks(ib,jb)%serial_scalar_matrix%create (num_rows,num_cols)
  !end subroutine serial_block_matrix_create_offdiagonal_block
  
  subroutine serial_block_matrix_set_block_to_zero (bmat,ib,jb)
   implicit none
   ! Parameters
   class(serial_block_matrix_t), intent(inout) :: bmat
   integer(ip)                 , intent(in)    :: ib,jb
   integer(ip) :: istat

   if ( associated(bmat%blocks(ib,jb)%serial_scalar_matrix) ) then
      ! Undo create
      call bmat%blocks(ib,jb)%serial_scalar_matrix%free_in_stages(free_clean)
      deallocate (bmat%blocks(ib,jb)%serial_scalar_matrix,stat=istat)
      check(istat==0)
      nullify ( bmat%blocks(ib,jb)%serial_scalar_matrix )
   end if
  end subroutine serial_block_matrix_set_block_to_zero

end module serial_block_matrix_names
