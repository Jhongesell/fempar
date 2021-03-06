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

!****************************************************************************************
module piecewise_cell_map_names
  use types_names
  use reference_fe_names
  use field_names

  implicit none
# include "debug.i90"
  private

  ! This type encapsulates maps from a common reference element to several physical elements of the same type
  ! The user sees it as a single fe map
  ! TODO define this type as an extension of cell_map_t. Is this type actually needed?
  type :: piecewise_cell_map_t

    private

    type(facet_map_t)   :: fe_sub_map
    integer(ip)        :: num_sub_maps
    integer(ip)        :: num_quadrature_points_sub_map
    integer(ip)        :: num_nodes_sub_map
    integer(ip)        :: num_nodes
    class  (reference_fe_t), pointer:: reference_fe_geometry => null()

    ! The same as in cell_map_t (this can be inherited form cell_map_t)
    real(rp),      allocatable    :: det_jacobian(:)
    type(point_t), allocatable    :: coordinates_quadrature(:)
    type(point_t), allocatable    :: nodes_coordinates(:)
    real(rp),      allocatable    :: normals(:,:)
    integer(ip)                   :: num_dims
    integer(ip)                   :: num_quadrature_points

  contains

    ! This are thought as an extension of the same methods in cell_map_t
    procedure, non_overridable :: create_facet_map                => piecewise_cell_map_create_facet_map
    procedure, non_overridable :: free                           => piecewise_cell_map_free
    procedure, non_overridable :: update_facet_map                => piecewise_cell_map_update_facet_map
    procedure, non_overridable :: compute_quadrature_points_coordinates => piecewise_cell_map_compute_quadrature_points_coordinates

    ! The same as in cell_map_t (this can be inherited form cell_map_t)
    procedure, non_overridable :: get_det_jacobian                  => piecewise_cell_map_get_det_jacobian
    procedure, non_overridable :: get_coordinates                   => piecewise_cell_map_get_coordinates
    procedure, non_overridable :: get_quadrature_points_coordinates => piecewise_cell_map_get_quadrature_points_coordinates
    procedure, non_overridable :: get_normal                        => piecewise_cell_map_get_normal

  end type piecewise_cell_map_t

  public :: piecewise_cell_map_t

contains

!========================================================================================
  subroutine piecewise_cell_map_create_facet_map( this, quadrature, reference_fe_geometry, num_sub_maps )

    implicit none
    class  (piecewise_cell_map_t),        intent(inout) :: this
    type   (quadrature_t),              intent(in)    :: quadrature
    class  (reference_fe_t), target, intent(in)    :: reference_fe_geometry
    integer(ip),                        intent(in)    :: num_sub_maps

    integer(ip) :: istat
    type(point_t), pointer :: nod_coords(:)

    call this%free()

    this%num_quadrature_points_sub_map = quadrature%get_num_quadrature_points()
    this%num_sub_maps                  = num_sub_maps
    this%num_quadrature_points         = quadrature%get_num_quadrature_points() * num_sub_maps
    this%num_dims                = reference_fe_geometry%get_num_dims()

    call this%fe_sub_map%create( quadrature, reference_fe_geometry )

    nod_coords => this%fe_sub_map%get_coordinates()
    this%num_nodes_sub_map = size(nod_coords)
    this%num_nodes = size(nod_coords) * num_sub_maps

    allocate( this%nodes_coordinates     (1:this%num_nodes),             stat = istat ); check(istat==0)
    allocate( this%coordinates_quadrature(1:this%num_quadrature_points), stat = istat ); check(istat==0)

    call memalloc( this%num_quadrature_points, this%det_jacobian, __FILE__,__LINE__ )
    call memalloc( SPACE_DIM, this%num_quadrature_points, this%normals, __FILE__,__LINE__  )
    
    this%reference_fe_geometry => reference_fe_geometry

  end subroutine piecewise_cell_map_create_facet_map

!========================================================================================
  subroutine piecewise_cell_map_free( this )
    implicit none
    class(piecewise_cell_map_t), intent(inout) :: this
    this%num_dims                = -1
    this%num_quadrature_points         = -1
    this%num_sub_maps                  = -1
    this%num_quadrature_points_sub_map = -1
    this%num_nodes_sub_map             = -1
    this%num_nodes                     = -1
    if (allocated(this%nodes_coordinates     )) deallocate  ( this%nodes_coordinates      )
    if (allocated(this%coordinates_quadrature)) deallocate  ( this%coordinates_quadrature )
    if (allocated(this%det_jacobian))           call memfree( this%det_jacobian, __FILE__,__LINE__  )
    if (allocated(this%normals     ))           call memfree( this%normals,      __FILE__,__LINE__  )
    call this%fe_sub_map%free()
    this%reference_fe_geometry => null()
  end subroutine piecewise_cell_map_free

!========================================================================================
  subroutine piecewise_cell_map_update_facet_map( this, quadrature, cell_map_det_jacobian_is_positive )

    implicit none
    class  (piecewise_cell_map_t),      intent(inout) :: this
    type   (quadrature_t),              intent(in)    :: quadrature
    logical,                            intent(in)    :: cell_map_det_jacobian_is_positive

    ! The arguments quadrature is needed only
    ! because the cell_map_update_facet_map requires them, ...

    integer(ip) :: imap, nini, nend, pini, pend
    type(point_t), pointer :: nod_coords(:), quad_coords(:)
    real(rp), pointer :: det_jacobs(:)
    real(rp), pointer :: normal_vecs(:,:)
    real(rp) :: reorientation_factor
    
    reorientation_factor = this%reference_fe_geometry%get_normal_orientation_factor(&
                                                      facet_lid = 1_ip,&
                                                      cell_map_det_jacobian_is_positive = cell_map_det_jacobian_is_positive)

    do imap = 1, this%num_sub_maps

      ! Update the coordinates of the sub map
      nend = imap * this%num_nodes_sub_map
      nini = nend - this%num_nodes_sub_map + 1
      nod_coords => this%fe_sub_map%get_coordinates()
      nod_coords(:) = this%nodes_coordinates(nini:nend)

      ! Compute the info of the sub map
      call this%fe_sub_map%update(reorientation_factor,quadrature)

      ! Recover the computed quantities in the sub map, and put them in the arrays
      quad_coords => this%fe_sub_map%get_quadrature_points_coordinates()
      det_jacobs => this%fe_sub_map%get_pointer_det_jacobians()
      normal_vecs => this%fe_sub_map%get_raw_normals()
      pend = imap * this%num_quadrature_points_sub_map
      pini = pend - this%num_quadrature_points_sub_map + 1
      this%coordinates_quadrature(pini:pend) = quad_coords(:)
      this%det_jacobian(pini:pend) = det_jacobs(:)
      this%normals(:,pini:pend) = normal_vecs(:,:)

    end do

  end subroutine piecewise_cell_map_update_facet_map

!========================================================================================
  subroutine piecewise_cell_map_compute_quadrature_points_coordinates( this )

    implicit none
    class(piecewise_cell_map_t), intent(inout) :: this

    integer(ip) :: imap, nini, nend, pini, pend
    type(point_t), pointer :: nod_coord(:), quad_coord(:)


    do imap = 1, this%num_sub_maps

      ! Update the coordinates of the sub map
      nend = imap * this%num_nodes_sub_map
      nini = nend - this%num_nodes_sub_map + 1
      nod_coord => this%fe_sub_map%get_coordinates()
      nod_coord(:) = this%nodes_coordinates(nini:nend)

      ! Compute the coordinates in the sub map
      call this%fe_sub_map%compute_quadrature_points_coordinates()

      ! Recover the computed quantities in the sub map, and put them in the arrays
      quad_coord => this%fe_sub_map%get_quadrature_points_coordinates()
      pend = imap * this%num_quadrature_points_sub_map
      pini = pend - this%num_quadrature_points_sub_map + 1
      this%coordinates_quadrature(pini:pend) = quad_coord(:)

    end do

  end subroutine piecewise_cell_map_compute_quadrature_points_coordinates

!========================================================================================
  function piecewise_cell_map_get_det_jacobian ( this, i )
    implicit none
    class(piecewise_cell_map_t), intent(in) :: this
    integer(ip)    , intent(in) :: i
    real(rp) :: piecewise_cell_map_get_det_jacobian
    piecewise_cell_map_get_det_jacobian = this%det_jacobian(i)
  end function piecewise_cell_map_get_det_jacobian

!========================================================================================
  function piecewise_cell_map_get_coordinates(this)
    implicit none
    class(piecewise_cell_map_t)   , target, intent(in) :: this
    type(point_t), pointer :: piecewise_cell_map_get_coordinates(:)
    piecewise_cell_map_get_coordinates => this%nodes_coordinates
  end function piecewise_cell_map_get_coordinates

!========================================================================================
  function piecewise_cell_map_get_quadrature_points_coordinates(this)
    implicit none
    class(piecewise_cell_map_t)   , target, intent(in) :: this
    type(point_t), pointer :: piecewise_cell_map_get_quadrature_points_coordinates(:)
    piecewise_cell_map_get_quadrature_points_coordinates => this%coordinates_quadrature
  end function piecewise_cell_map_get_quadrature_points_coordinates

!========================================================================================
  subroutine piecewise_cell_map_get_normal(this, qpoint, normal)
   implicit none
   class(piecewise_cell_map_t)     , intent(in)    :: this
   integer(ip)         , intent(in)    :: qpoint
   type(vector_field_t), intent(inout) :: normal
   integer(ip) :: idime
   assert ( allocated(this%normals) )
   do idime = 1, SPACE_DIM
     call normal%set(idime,this%normals(idime,qpoint))
   end do
  end subroutine  piecewise_cell_map_get_normal

!****************************************************************************************
end module piecewise_cell_map_names
