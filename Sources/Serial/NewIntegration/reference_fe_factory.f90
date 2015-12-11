module reference_fe_factory_names
  use reference_fe_names
!  use quad_lagrangian_reference_fe_names
  use types_names
  implicit none
# include "debug.i90"
  private

  public :: make_reference_fe

contains

  function make_reference_fe ( topology, fe_type, number_dimensions, order, field_type, continuity )
    implicit none 
    character(*)          , intent(in) :: topology, fe_type
    integer(ip)           , intent(in) :: number_dimensions, order
    character(*), optional, intent(in) :: field_type
    logical     , optional, intent(in) :: continuity
    type(p_reference_fe_t)             :: make_reference_fe

    if ( topology == "quad" ) then
       if ( fe_type == "Lagrangian") then
          allocate ( quad_lagrangian_reference_fe_t :: make_reference_fe%p )
       else
          write (*,*) 'ERROR: ELEMENT TYPE NOT SUPPORTED'
       end if
    end if
    
    call make_reference_fe%p%create( number_dimensions, order, field_type, continuity )
  end function make_reference_fe

end module reference_fe_factory_names


