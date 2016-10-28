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

module xh5_utils_names

USE types_names
USE xh5_parameters_names
USE xh5for,             only: XDMF_ATTRIBUTE_TYPE_SCALAR, XDMF_ATTRIBUTE_TYPE_VECTOR, &
                              XDMF_ATTRIBUTE_TYPE_TENSOR, XDMF_ATTRIBUTE_TYPE_TENSOR6
USE reference_fe_names, only: topology_hex, topology_tet
USE iso_fortran_env,    only: error_unit


implicit none
#include "debug.i90"
private



public :: topology_to_xh5_celltype
public :: number_components_to_xh5_AttributeType

contains


    function topology_to_xh5_CellType(topology, dimension) result(cell_type)
    !-----------------------------------------------------------------
    !< Translate the topology type of the reference_fe_geo into XH5 cell type
    !-----------------------------------------------------------------
        character(len=*),            intent(in)    :: topology
        integer(ip),                 intent(in)    :: dimension
        integer(ip)                                :: cell_type
    !-----------------------------------------------------------------
        if(topology == topology_hex) then 
            if(dimension == 2) then
                cell_type = XDMF_QUADRILATERAL
            elseif(dimension == 3) then
                cell_type = XDMF_HEXAHEDRON
            endif
        elseif(topology == topology_tet) then
            if(dimension == 2) then
                cell_type = XDMF_TRIANGLE
            elseif(dimension == 3) then
                cell_type = XDMF_TETRAHEDRON
            endif
        else
            write(error_unit,*) 'Topology_to_xh5_CellType: Topology not supported ('//trim(adjustl(topology))//')'
            check(.false.)    
        endif
    end function topology_to_xh5_CellType


    function number_components_to_xh5_AttributeType(number_components) result(attribute_type)
    !-----------------------------------------------------------------
    !< Translate the number of components into XH5 attribute type
    !-----------------------------------------------------------------
        integer(ip), intent(in)    :: number_components
        integer(ip)                :: attribute_type
    !-----------------------------------------------------------------
        select case (number_components)
            case (1)
                attribute_type = XDMF_ATTRIBUTE_TYPE_SCALAR
            case (2,3)
                attribute_type = XDMF_ATTRIBUTE_TYPE_VECTOR
            case (6)
                attribute_type = XDMF_ATTRIBUTE_TYPE_TENSOR6
            case (9)
                attribute_type = XDMF_ATTRIBUTE_TYPE_TENSOR
            case DEFAULT
                write(error_unit,*) 'number_components_to_xh5_AttributeType: number_componets not supported ', number_components
                check(.false.)    
        end select
    end function number_components_to_xh5_AttributeType

end module xh5_utils_names
