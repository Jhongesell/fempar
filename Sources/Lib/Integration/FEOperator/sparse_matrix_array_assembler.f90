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
module sparse_matrix_array_assembler_names
  use types_names
  use allocatable_array_names

  ! Abstract modules
  use matrix_array_assembler_names
  use matrix_names
  use array_names

  ! Concrete implementations
  use sparse_matrix_names
  use serial_scalar_array_names

  implicit none
# include "debug.i90"
  private

  type, extends(matrix_array_assembler_t) :: sparse_matrix_array_assembler_t
  contains
    procedure :: assemble_array   => sparse_matrix_array_assembler_assemble_array
    procedure :: assemble_matrix  => sparse_matrix_array_assembler_assemble_matrix
    procedure :: allocate         => sparse_matrix_array_assembler_allocate
    procedure :: compress_storage => sparse_matrix_array_assembler_compress_storage
  end type

! Data types
public :: sparse_matrix_array_assembler_t

contains

  subroutine sparse_matrix_array_assembler_assemble_array( this,           & 
                                                           number_fields,  &
                                                           field_blocks,   &
                                                           field_coupling, &
                                                           number_dofs,    &
                                                           cell2dof,       &
                                                           elvec )
    implicit none
    class(sparse_matrix_array_assembler_t), intent(inout) :: this
    integer(ip)                           , intent(in)    :: number_fields
    integer(ip)                           , intent(in)    :: field_blocks(number_fields)
    logical                               , intent(in)    :: field_coupling(number_fields,number_fields)
    integer(ip)                           , intent(in)    :: number_dofs(number_fields)
    type(i1p_t)                           , intent(in)    :: cell2dof(number_fields)
    real(rp)                              , intent(in)    :: elvec(:)

    class(array_t) , pointer :: array

    array  => this%get_array()
    select type(array)
      class is(serial_scalar_array_t)
      call element_serial_scalar_array_assembly( array,         &
                                                 number_fields, &
                                                 number_dofs,   &
                                                 cell2dof,      &
                                                 elvec )
      class default
      check(.false.)
    end select
    
  end subroutine sparse_matrix_array_assembler_assemble_array
  
  subroutine sparse_matrix_array_assembler_assemble_matrix( this,            &
                                                            number_fields,   &
                                                            field_blocks,    &
                                                            field_coupling,  &
                                                            number_row_dofs, &
                                                            number_col_dofs, &
                                                            cell2row_dofs,   &
                                                            cell2col_dofs,   &
                                                            elmat )
    implicit none
    class(sparse_matrix_array_assembler_t), intent(inout) :: this
    integer(ip)                           , intent(in)    :: number_fields
    integer(ip)                           , intent(in)    :: field_blocks(number_fields)
    logical                               , intent(in)    :: field_coupling(number_fields,number_fields)
    integer(ip)                           , intent(in)    :: number_row_dofs(number_fields)
    integer(ip)                           , intent(in)    :: number_col_dofs(number_fields)
    type(i1p_t)                           , intent(in)    :: cell2row_dofs(number_fields)
    type(i1p_t)                           , intent(in)    :: cell2col_dofs(number_fields)
    real(rp)                              , intent(in)    :: elmat(:,:) 

    class(matrix_t), pointer :: matrix

    matrix => this%get_matrix()
    select type(matrix)
      class is(sparse_matrix_t)
      call element_sparse_matrix_assembly( matrix,          &
                                           number_fields,   &
                                           number_row_dofs, &
                                           number_col_dofs, &
                                           cell2row_dofs,   &
                                           cell2col_dofs,   &
                                           field_coupling,  &
                                           elmat )
      class default
      check(.false.)
    end select

  end subroutine sparse_matrix_array_assembler_assemble_matrix

  subroutine sparse_matrix_array_assembler_allocate( this )
    implicit none
    class(sparse_matrix_array_assembler_t), intent(inout) :: this
    class(array_t), pointer :: array
    array=>this%get_array()
    call array%allocate()
  end subroutine sparse_matrix_array_assembler_allocate

  subroutine sparse_matrix_array_assembler_compress_storage( this, & 
                                                             sparse_matrix_storage_format )
    implicit none
    class(sparse_matrix_array_assembler_t) , intent(inout) :: this
    character(*)                              , intent(in)    :: sparse_matrix_storage_format
    class(matrix_t), pointer :: matrix
    matrix=>this%get_matrix() 
    select type(matrix)
      class is(sparse_matrix_t)
      call matrix%convert(sparse_matrix_storage_format)
      class default
      check(.false.)
    end select
  end subroutine sparse_matrix_array_assembler_compress_storage

  subroutine element_serial_scalar_array_assembly( array, number_fields, number_dofs, cell2dof, elvec )
    implicit none
    ! Parameters
    type(serial_scalar_array_t), intent(inout) :: array
    integer(ip)                , intent(in)    :: number_fields
    integer(ip)                , intent(in)    :: number_dofs(number_fields)
    type(i1p_t)                , intent(in)    :: cell2dof(number_fields)
    real(rp)                   , intent(in)    :: elvec(:) 
    
    integer(ip) :: inode, idof, ielvec, ife_space
    
    ielvec = 0
    do ife_space = 1, number_fields
      call array%add( number_dofs(ife_space), &
                      cell2dof(ife_space)%p,   &
                      ielvec,                  &
                      elvec )
      ielvec = ielvec + number_dofs(ife_space)
    end do
    
  end subroutine element_serial_scalar_array_assembly

  subroutine element_sparse_matrix_assembly( matrix, number_fields, number_row_dofs,      &
                                             number_col_dofs, cell2row_dofs, cell2col_dofs,  &
                                             field_coupling, elmat )
    implicit none
    ! Parameters
    type(sparse_matrix_t), intent(inout) :: matrix
    integer(ip)          , intent(in)    :: number_fields
    integer(ip)          , intent(in)    :: number_row_dofs(number_fields)
    integer(ip)          , intent(in)    :: number_col_dofs(number_fields)
    type(i1p_t)          , intent(in)    :: cell2row_dofs(number_fields)
    type(i1p_t)          , intent(in)    :: cell2col_dofs(number_fields)
    logical              , intent(in)    :: field_coupling(number_fields,number_fields)
    real(rp)             , intent(in)    :: elmat(:,:) 

    integer(ip) :: ife_space, jfe_space
    integer(ip) :: idof, jdof 
    integer(ip) :: inode, jnode
    integer(ip) :: ielmat, jelmat

    ielmat=0
    do ife_space=1, number_fields
       jelmat=0
       do jfe_space=1, number_fields
          if ((field_coupling(ife_space,jfe_space))) then
             call matrix%insert(number_row_dofs(ife_space),number_col_dofs(jfe_space),                 &
                  &             cell2row_dofs(ife_space)%p,cell2col_dofs(jfe_space)%p,ielmat,jelmat,   &
                  &             elmat)
          end if
          jelmat=jelmat+number_col_dofs(jfe_space)
       end do
       ielmat=ielmat+number_row_dofs(ife_space)
    end do

  end subroutine element_sparse_matrix_assembly

end module sparse_matrix_array_assembler_names

