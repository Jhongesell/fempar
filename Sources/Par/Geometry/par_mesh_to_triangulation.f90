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
module par_mesh_to_triangulation_names
  ! Serial modules
  use types_names
  use list_types_names
  use memor_names
  use triangulation_names
  use element_import_names
  use element_import_create_names
  use hash_table_names
  use mesh_to_triangulation_names
  use psi_penv_mod_names

  ! Parallel modules
  use par_triangulation_names
  use par_mesh_names
  use par_element_exchange_names
  use par_conditions_names

  implicit none
# include "debug.i90"
  private

  public :: par_mesh_to_triangulation

contains

  subroutine par_mesh_to_triangulation (p_gmesh, p_trian, p_cond)
    implicit none
    ! Parameters
    type(par_mesh_t)         , target  , intent(in)    :: p_gmesh ! Geometry mesh
    type(par_triangulation_t), target  , intent(inout) :: p_trian 
    type(par_conditions_t)   , optional, intent(inout) :: p_cond

    ! Locals
    integer(ip) :: istat, ielem, iobj, jobj, state
    integer(ip) :: num_elems, num_ghosts, num_verts
    type (hash_table_igp_ip_t) :: hash ! Topological info hash table (SBmod)
    integer(ip) :: ilele, nvert, jelem, jlele, idime, count, ivere 
    integer(igp):: iobjg
    integer(igp), allocatable :: aux_igp(:)
    integer(ip), allocatable :: aux(:)
    integer(ip) :: aux_val
    type(list_t), pointer :: vertices_vef
    
    ! Set a reference to the type(par_environment_t) instance describing the set of MPI tasks
    ! among which this type(par_triangulation) instance is going to be distributed 
    p_trian%p_env => p_gmesh%p_env

    if(p_trian%p_env%p_context%iam >= 0) then

       state = p_trian%state
       assert(state == par_triangulation_not_created .or. state == par_triangulation_filled )

       if ( state == par_triangulation_filled ) call par_triangulation_free(p_trian)

       ! Create element_import from geometry mesh partition data
       ! AFM: CURRENTLY element_import_create is the only way to create a type(element_import) instance.
       !      I have stored it inside type(par_triangulation) as I do not have a better guess.
       !      In the future, we should get rid of finite_element_t_import_create, and provide a new
       !      subroutine which allows to create this instance using the dual graph and the gluing
       !      data describing its distributed-memory layout. Both the dual graph and associated gluing
       !      data are to be stored in type(par_neighborhood) according to Javier's UML diagram (i.e., fempar.dia). 
       !      From this point of view, type(par_neighborhood) should somehow aggregate/reference an instance of 
       !      type(element_import) and manage its creation. However, this is not currently reflected in fempar.dia, 
       !      which defines a type(triangulation_partition) which in turn includes an instance of type(element_import) inside. 
       !      Assuming we agree in the first option, how type(par_triangulation) is going to access type(par_neighbourhood) ??? 
       !      This is related with a parallel discussion about the possibility of enriching type(par_triangulation) with the dual graph 
       !      and associated gluing data. Does it make sense? If yes, does type(par_neighborhood) still makes any sense?
       call element_import_create ( p_gmesh%f_mesh_dist, p_trian%f_el_import )

       ! Now we are sure that the local portion of p_trian, i.e., p_trian%f_trian is in triangulation_not_created state
       ! Let's create and fill it
       num_elems  = p_trian%f_el_import%nelem
       num_ghosts = p_trian%f_el_import%nghost

       p_trian%num_ghosts = num_ghosts
       p_trian%num_elems  = num_elems

       ! Fill local portion with local data
       call mesh_to_triangulation_fill_elements ( p_gmesh%f_mesh, p_trian%f_trian, num_elems + num_ghosts, p_cond%f_conditions )

       ! p_trian%f_trian%num_elems = num_elems+num_ghosts
       ! **IMPORTANT NOTE**: the code that comes assumes that edges and faces in p_trian%f_trian are numbered after vertices.
       ! This requirement is currently fulfilled by mesh_to_triangulation (in particular, by geom2topo within) but we should
       ! keep this in mind all the way through. If this were not assumed, we should find a way to identify a corner within
       ! p_trian%f_trian, and map from a corner local ID in p_trian%f_trian to a vertex local ID in p_gmesh%f_mesh.
       num_verts = p_gmesh%f_mesh%npoin

       ! Create array of elements with room for ghost elements
       allocate( par_elem_topology_t :: p_trian%mig_elems(num_elems + num_ghosts), stat=istat)
       check(istat==0)

       select type( this => p_trian%mig_elems )
       type is(par_elem_topology_t)
          p_trian%elems => this
       end select

       p_trian%elems(:)%interface = -1 
       do ielem=1, p_gmesh%f_mesh_dist%nebou
          p_trian%elems(p_gmesh%f_mesh_dist%lebou(ielem))%interface = ielem
       end do

       p_trian%num_itfc_elems = p_gmesh%f_mesh_dist%nebou
       call memalloc( p_trian%num_itfc_elems, p_trian%lst_itfc_elems, __FILE__, __LINE__ )
       p_trian%lst_itfc_elems = p_gmesh%f_mesh_dist%lebou

       ! Fill array of elements (local ones)
       do ielem=1, num_elems
          p_trian%elems(ielem)%mypart      = p_trian%p_env%p_context%iam + 1
          p_trian%elems(ielem)%globalID    = p_gmesh%f_mesh_dist%emap%l2g(ielem)
          p_trian%elems(ielem)%num_vefs = p_trian%f_trian%elems(ielem)%num_vefs
          call memalloc( p_trian%elems(ielem)%num_vefs, p_trian%elems(ielem)%vefs_GIDs, __FILE__, __LINE__ )
          do iobj=1, p_trian%elems(ielem)%num_vefs
             jobj = p_trian%f_trian%elems(ielem)%vefs(iobj)
             if ( jobj <= num_verts ) then ! It is a corner => re-use global ID
                p_trian%elems(ielem)%vefs_GIDs(iobj) = p_gmesh%f_mesh_dist%nmap%l2g(jobj)
             else ! It is an edge or face => generate new local-global ID (non-consistent, non-consecutive)
                ! The ISHFT(1,50) is used to start numbering efs after vertices, assuming nvert < 2**60
                p_trian%elems(ielem)%vefs_GIDs(iobj) = ISHFT(int(p_gmesh%f_mesh_dist%ipart,igp),int(32,igp)) + int(jobj, igp) + ISHFT(int(1,igp),int(60,igp))
                !p_trian%elems(ielem)%vefs_GIDs(iobj) = ISHFT(int(p_gmesh%f_mesh_dist%ipart,igp),int(6,igp)) + int(jobj, igp) + ISHFT(int(1,igp),int(6,igp))
             end if
          end do
       end do

       ! Get vefs_GIDs from ghost elements
       call ghost_elements_exchange ( p_trian%p_env%p_context%icontxt, p_trian%f_el_import, p_trian%elems )

       ! Allocate elem_topology in triangulation for ghost elements  (SBmod)
       do ielem = num_elems+1, num_elems+num_ghosts       
          p_trian%f_trian%elems(ielem)%num_vefs = p_trian%elems(ielem)%num_vefs
          call memalloc(p_trian%f_trian%elems(ielem)%num_vefs, p_trian%f_trian%elems(ielem)%vefs, &
               & __FILE__, __LINE__)
          p_trian%f_trian%elems(ielem)%vefs = -1
       end do

       ! Put the topology info in the ghost elements
       do ielem= num_elems+1, num_elems+num_ghosts
          call put_topology_element_triangulation ( ielem, p_trian%f_trian )
       end do

       ! Hash table global to local for ghost elements
       call hash%init(num_ghosts)
       do ielem=num_elems+1, num_elems+num_ghosts
          aux_val = ielem
          call hash%put( key = p_trian%elems(ielem)%globalID, val = aux_val, stat=istat)
       end do

       do ielem = 1, p_gmesh%f_mesh_dist%nebou     ! Loop interface elements 
          ! Step 1: Put LID of vertices in the ghost elements (f_mesh_dist)
          ilele = p_gmesh%f_mesh_dist%lebou(ielem) ! local ID element
          ! aux : array of ilele (LID) vertices in GID
          nvert  = p_trian%f_trian%elems(ilele)%reference_fe_geo%get_number_vertices()
          call memalloc( nvert, aux_igp, __FILE__, __LINE__  )
          do iobj = 1, nvert                        ! vertices only
             aux_igp(iobj) = p_trian%elems(ilele)%vefs_GIDs(iobj) ! extract GIDs vertices
          end do
          do jelem = p_gmesh%f_mesh_dist%pextn(ielem), & 
               p_gmesh%f_mesh_dist%pextn(ielem+1)-1  ! external neighbor elements
             call hash%get(key = p_gmesh%f_mesh_dist%lextn(jelem), val=jlele, stat=istat) ! LID external element
             do jobj = 1, p_trian%f_trian%elems(jlele)%reference_fe_geo%get_number_vertices() ! vertices external 
                if ( p_trian%f_trian%elems(jlele)%vefs(jobj) == -1) then
                   do iobj = 1, nvert
                      if ( aux_igp(iobj) == p_trian%elems(jlele)%vefs_GIDs(jobj) ) then
                         ! Put LID of vertices for ghost_elements
                         p_trian%f_trian%elems(jlele)%vefs(jobj) =  p_trian%f_trian%elems(ilele)%vefs(iobj)
                      end if
                   end do
                end if
             end do
          end do
          call memfree(aux_igp, __FILE__, __LINE__) 
       end do

       do ielem = 1, p_gmesh%f_mesh_dist%nebou     ! Loop interface elements 
          ! Step 2: Put LID of efs in the ghost elements (f_mesh_dist) 
          ilele = p_gmesh%f_mesh_dist%lebou(ielem) ! local ID element
          do jelem = p_gmesh%f_mesh_dist%pextn(ielem), &
               p_gmesh%f_mesh_dist%pextn(ielem+1)-1  ! external neighbor elements
             call hash%get(key = p_gmesh%f_mesh_dist%lextn(jelem), val=jlele, stat=istat) ! LID external element
             vertices_vef => p_trian%f_trian%elems(jlele)%reference_fe_geo%get_vertices_vef()
             ! loop over all efs of external elements
             do idime =2,p_trian%f_trian%num_dims
                do iobj = p_trian%f_trian%elems(jlele)%reference_fe_geo%get_first_vef_id_of_dimension(idime-1), &
                     p_trian%f_trian%elems(jlele)%reference_fe_geo%get_first_vef_id_of_dimension(idime)-1 
                   if ( p_trian%f_trian%elems(jlele)%vefs(iobj) == -1) then ! efs not assigned yet
                      count = 1
                      ! loop over vertices of every ef
                      do jobj = vertices_vef%p(iobj), vertices_vef%p(iobj+1)-1    
                         ivere = vertices_vef%l(jobj)
                         if (p_trian%f_trian%elems(jlele)%vefs(ivere) == -1) then
                            count = 0 ! not an vef of the local triangulation
                            exit
                         end if
                      end do
                      if (count == 1) then
                         nvert = vertices_vef%p(iobj+1)-vertices_vef%p(iobj)
                         call memalloc( nvert, aux, __FILE__, __LINE__)
                         count = 1
                         do jobj = vertices_vef%p(iobj), vertices_vef%p(iobj+1)-1
                            ivere = vertices_vef%l(jobj)
                            aux(count) = p_trian%f_trian%elems(jlele)%vefs(ivere)
                            count = count+1
                         end do
                         call local_id_from_vertices( p_trian%f_trian%elems(ilele), idime, aux, nvert, &
                              p_trian%f_trian%elems(jlele)%vefs(iobj) )
                         call memfree(aux, __FILE__, __LINE__) 
                      end if
                   end if
                end do
             end do
          end do
       end do

       call hash%free

       call par_triangulation_to_dual ( p_trian )

       !pause

       ! Check results
       ! if ( p_trian%p_env%p_context%iam == 0) then
       !    do ielem = 1,num_elems+num_ghosts
       !       write (*,*) '****ielem:',ielem          
       !       write (*,*) '****LID_vefs ghost:',p_trian%f_trian%elems(ielem)%vefs
       !       write (*,*) '****GID_vefs ghost:',p_trian%elems(ielem)%vefs_GIDs
       !    end do
       ! end if
       ! pause

       ! write (*,*) '*********************************'
       ! write (*,*) '*********************************' 
       ! if ( p_trian%p_env%p_context%iam == 0) then
       !    do iobj = 1, p_trian%f_trian%num_vefs 
       !       write (*,*) 'is interface vef',iobj, ' :', p_trian%vefs(iobj)%interface 
       !       write (*,*) 'is interface vef',iobj, ' :', p_trian%f_trian%vefs(iobj)%dimension
       !    end do
       ! end if
       ! write (*,*) '*********************************'
       ! write (*,*) '*********************************'

       ! Step 3: Make GID consistent among processors (p_part%elems%vefs_GIDs)
       do iobj = 1, p_trian%f_trian%num_vefs 
          if ( (p_trian%vefs(iobj)%interface .ne. -1) .and. &
               (p_trian%f_trian%vefs(iobj)%dimension >= 1) ) then
             idime = p_trian%f_trian%vefs(iobj)%dimension+1
             iobjg = -1

             do jelem = 1,p_trian%f_trian%vefs(iobj)%num_elems_around
                jlele = p_trian%f_trian%vefs(iobj)%elems_around(jelem)

                do jobj = p_trian%f_trian%elems(jlele)%reference_fe_geo%get_first_vef_id_of_dimension(idime-1), &
                     & p_trian%f_trian%elems(jlele)%reference_fe_geo%get_first_vef_id_of_dimension(idime)-1 ! efs of neighbor els
                   if ( p_trian%f_trian%elems(jlele)%vefs(jobj) == iobj ) then
                      if ( iobjg == -1 ) then 
                         iobjg  = p_trian%elems(jlele)%vefs_GIDs(jobj)
                      else
                         iobjg  = min(iobjg,p_trian%elems(jlele)%vefs_GIDs(jobj))
                         exit
                      end if
                   end if
                end do

             end do


             do jelem = 1,p_trian%f_trian%vefs(iobj)%num_elems_around
                jlele = p_trian%f_trian%vefs(iobj)%elems_around(jelem)
                do jobj = p_trian%f_trian%elems(jlele)%reference_fe_geo%get_first_vef_id_of_dimension(idime-1), &
                     & p_trian%f_trian%elems(jlele)%reference_fe_geo%get_first_vef_id_of_dimension(idime)-1 ! efs of neighbor els
                   if ( p_trian%f_trian%elems(jlele)%vefs(jobj) == iobj) then
                      p_trian%elems(jlele)%vefs_GIDs(jobj) = iobjg
                      exit
                   end if
                end do
             end do
             p_trian%vefs(iobj)%globalID = iobjg          
          end if
       end do

       p_trian%state = par_triangulation_filled
       ! Check results
       ! if ( p_trian%p_env%p_context%iam == 0) then
       !    do ielem = 1,num_elems+num_ghosts
       !       write (*,*) '****ielem:',ielem          
       !       write (*,*) '****LID_vefs ghost:',p_trian%f_trian%elems(ielem)%vefs
       !       write (*,*) '****GID_vefs ghost:',p_trian%elems(ielem)%vefs_GIDs
       !    end do
       ! end if
       ! pause
    else
       ! AFM: TODO: Partially broadcast p_trian%f_trian from 1st level tasks to 2nd level tasks (e.g., num_dims)
    end if

  end subroutine par_mesh_to_triangulation

end module par_mesh_to_triangulation_names
