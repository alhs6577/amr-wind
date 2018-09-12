module convection_eb_mod
   
   use amrex_fort_module,       only: ar => amrex_real
   use iso_c_binding ,          only: c_int
   use param,                   only: zero, half, one
   use bc,                      only: minf_, nsw_, fsw_, psw_, pinf_, pout_
   use eb_interpolation_mod,    only: interpolate_to_face_centroid
   use amrex_ebcellflag_module, only: is_covered_cell, is_single_valued_cell, &
        &                             get_neighbor_cells

   implicit none
   private
   
contains


   !$************************************************
   !$ WARNING:
   !$
   !$ Make sure this approach is not problematic with
   !$ OpenMP
   !$    
   !$************************************************


   !$************************************************
   !$ WARNING 2:
   !$
   !$ For now the convective term is only div(u_mac . u)
   !$ The term -u*grad(u_mac) is omitted
   !$    
   !$************************************************  
   subroutine compute_ugradu_eb ( lo, hi, &
        ugradu, glo, ghi, &
        vel, vello, velhi, &
        u, ulo, uhi, &
        v, vlo, vhi, &
        w, wlo, whi, &
        afrac_x, axlo, axhi, &
        afrac_y, aylo, ayhi, &
        afrac_z, azlo, azhi, &
        cent_x,  cxlo, cxhi, &
        cent_y,  cylo, cyhi, &
        cent_z,  czlo, czhi, &
        flags,    flo,  fhi, &
        vfrac,   vflo, vfhi, &
        xslopes, yslopes, zslopes, slo, shi, &
        domlo, domhi, &
        bc_ilo, bc_ihi, &
        bc_jlo, bc_jhi, &
        bc_klo, bc_khi, dx, ng ) bind(C)

      use divop_mod, only: compute_divop


      ! Tile bounds
      integer(c_int),  intent(in   ) :: lo(3),  hi(3)

      ! Array Bounds
      integer(c_int),  intent(in   ) :: slo(3), shi(3)
      integer(c_int),  intent(in   ) :: glo(3), ghi(3)
      integer(c_int),  intent(in   ) :: vello(3), velhi(3)
      integer(c_int),  intent(in   ) :: ulo(3), uhi(3)
      integer(c_int),  intent(in   ) :: vlo(3), vhi(3)
      integer(c_int),  intent(in   ) :: wlo(3), whi(3)
      integer(c_int),  intent(in   ) :: axlo(3), axhi(3)
      integer(c_int),  intent(in   ) :: aylo(3), ayhi(3)
      integer(c_int),  intent(in   ) :: azlo(3), azhi(3)
      integer(c_int),  intent(in   ) :: cxlo(3), cxhi(3)
      integer(c_int),  intent(in   ) :: cylo(3), cyhi(3)
      integer(c_int),  intent(in   ) :: czlo(3), czhi(3)
      integer(c_int),  intent(in   ) ::  flo(3),  fhi(3)
      integer(c_int),  intent(in   ) :: vflo(3), vfhi(3)
      integer(c_int),  intent(in   ) :: domlo(3), domhi(3), ng

      ! Grid
      real(ar),        intent(in   ) :: dx(3)

      ! Arrays
      real(ar),        intent(in   ) ::                            &
           & vel(vello(1):velhi(1),vello(2):velhi(2),vello(3):velhi(3),3)    , &
           & xslopes(slo(1):shi(1),slo(2):shi(2),slo(3):shi(3),3), &
           & yslopes(slo(1):shi(1),slo(2):shi(2),slo(3):shi(3),3), &
           & zslopes(slo(1):shi(1),slo(2):shi(2),slo(3):shi(3),3), &
           & u(ulo(1):uhi(1),ulo(2):uhi(2),ulo(3):uhi(3)), &
           & v(vlo(1):vhi(1),vlo(2):vhi(2),vlo(3):vhi(3)), &
           & w(wlo(1):whi(1),wlo(2):whi(2),wlo(3):whi(3)), &
           & afrac_x(axlo(1):axhi(1),axlo(2):axhi(2),axlo(3):axhi(3)),       &
           & afrac_y(aylo(1):ayhi(1),aylo(2):ayhi(2),aylo(3):ayhi(3)),       &
           & afrac_z(azlo(1):azhi(1),azlo(2):azhi(2),azlo(3):azhi(3)), &
           & cent_x(cxlo(1):cxhi(1),cxlo(2):cxhi(2),cxlo(3):cxhi(3),2),&
           & cent_y(cylo(1):cyhi(1),cylo(2):cyhi(2),cylo(3):cyhi(3),2),&
           & cent_z(czlo(1):czhi(1),czlo(2):czhi(2),czlo(3):czhi(3),2),&
           & vfrac(vflo(1):vfhi(1),vflo(2):vfhi(2),vflo(3):vfhi(3))           
      
      real(ar),        intent(  out) ::                           &
           & ugradu(glo(1):ghi(1),glo(2):ghi(2),glo(3):ghi(3),3)

      ! BC types
      integer(c_int), intent(in   ) ::  &
           & bc_ilo(domlo(2)-ng:domhi(2)+ng,domlo(3)-ng:domhi(3)+ng,2), &
           & bc_ihi(domlo(2)-ng:domhi(2)+ng,domlo(3)-ng:domhi(3)+ng,2), &
           & bc_jlo(domlo(1)-ng:domhi(1)+ng,domlo(3)-ng:domhi(3)+ng,2), &
           & bc_jhi(domlo(1)-ng:domhi(1)+ng,domlo(3)-ng:domhi(3)+ng,2), &
           & bc_klo(domlo(1)-ng:domhi(1)+ng,domlo(2)-ng:domhi(2)+ng,2), &
           & bc_khi(domlo(1)-ng:domhi(1)+ng,domlo(2)-ng:domhi(2)+ng,2), &
           & flags(flo(1):fhi(1),flo(2):fhi(2),flo(3):fhi(3))
      
      ! Temporary arrays
      ! Fluxes (this array can probably be shrinked to tile size)
      real(ar)  ::    &
           & fx(ulo(1):uhi(1),ulo(2):uhi(2),ulo(3):uhi(3),3), &
           & fy(vlo(1):vhi(1),vlo(2):vhi(2),vlo(3):vhi(3),3), &
           & fz(wlo(1):whi(1),wlo(2):whi(2),wlo(3):whi(3),3)


      ! Check number of ghost cells
      if (ng < 3) then
         write(*,*) "ERROR: EB convection term requires at least 3 ghost cells"
         stop
      end if

      ! 
      ! First compute the convective fluxes at the face center
      ! Do this on ALL faces on the tile, i.e. INCLUDE as many ghost faces as
      ! possible      
      !
      block
         real(ar)               :: u_face, v_face, w_face
         real(ar)               :: upls, umns, vpls, vmns, wpls, wmns
         integer                :: i, j, k, n
         integer, parameter     :: bc_list(6) = [MINF_, NSW_, FSW_, PSW_, PINF_, POUT_]
         
         do n = 1, 3
            ! 
            ! ===================   X   ===================
            !
            do k = lo(3)-ng, hi(3)+ng
               do j = lo(2)-ng, hi(2)+ng
                  do i = lo(1)-ng+1, hi(1)+ng
                     if ( afrac_x(i,j,k) > zero ) then
                        if ( i >= domlo(1) .and. any(bc_ilo(j,k,1) == bc_list) ) then
                           u_face =  vel(domlo(1)-1,j,k,n)
                        else if ( i >= domhi(1)+1 .and. any(bc_ihi(j,k,1) == bc_list ) ) then
                           u_face =  vel(domhi(1)+1,j,k,n)
                        else
                           upls  = vel(i  ,j,k,n) - half * xslopes(i  ,j,k,n)
                           umns  = vel(i-1,j,k,n) + half * xslopes(i-1,j,k,n)

                           u_face = upwind( umns, upls, u(i,j,k) )
                        end if
                     else
                        u_face = huge(one)
                     end if
                     fx(i,j,k,n) = u(i,j,k) * u_face 
                  end do
               end do
            end do

            ! 
            ! ===================   Y   ===================
            !
            do k = lo(3)-ng,     hi(3)+ng
               do j = lo(2)-ng+1,   hi(2)+ng
                  do i = lo(1)-ng,    hi(1)+ng
                     if ( afrac_y(i,j,k) > zero ) then
                        if ( j <= domlo(2) .and. any(bc_jlo(i,k,1) == bc_list) ) then
                           v_face =  vel(i,domlo(2)-1,k,n)
                        else if ( j >= domhi(2)+1 .and. any(bc_jhi(i,k,1) == bc_list ) ) then
                           v_face =  vel(i,domhi(2)+1,k,n)
                        else
                           vpls  = vel(i,j  ,k,n) - half * yslopes(i,j  ,k,n)
                           vmns  = vel(i,j-1,k,n) + half * yslopes(i,j-1,k,n)

                           v_face = upwind( vmns, vpls, v(i,j,k) )
                        end if
                     else
                        v_face = huge(one)
                     end if
                     fy(i,j,k,n) = v(i,j,k) * v_face
                  end do
               end do
            end do

            ! 
            ! ===================   Z   ===================
            !
            do k = lo(3)-ng+1, hi(3)+ng
               do j = lo(2)-ng, hi(2)+ng
                  do i = lo(1)-ng, hi(1)+ng
                     if ( afrac_z(i,j,k) > zero ) then
                        if ( k <= domlo(3) .and. any(bc_klo(i,j,1) == bc_list) ) then
                           w_face =  vel(i,j,domlo(3)-1,n)
                        else if ( k >= domhi(3)+1 .and. any(bc_khi(i,j,1) == bc_list ) ) then
                           w_face =  vel(i,j,domhi(3)+1,n)
                        else
                           wpls  = vel(i,j,k  ,n) - half * zslopes(i,j,k  ,n)
                           wmns  = vel(i,j,k-1,n) + half * zslopes(i,j,k-1,n)

                           w_face = upwind( wmns, wpls, w(i,j,k) )
                        end if
                     else
                        w_face = huge(one)
                     end if
                     fz(i,j,k,n) = w(i,j,k) * w_face
                  end do
               end do
            end do
            
         end do

      end block

      !
      ! Compute div(u_mac * u_cc )
      ! 
      call compute_divop(lo, hi, ugradu, glo, ghi, fx, ulo, uhi, fy, vlo, vhi, fz, wlo, whi, &
           afrac_x, axlo, axhi, afrac_y, aylo, ayhi, afrac_z, azlo, azhi,                    &
           cent_x, cxlo, cxhi, cent_y, cylo, cyhi, cent_z, czlo, czhi, flags, flo, fhi,      &
           vfrac, vflo, vfhi, dx, ng )
         

      ! Return the negative 
      block
         integer :: i,j,k,n
         
         do n = 1, 3
            do k = lo(3), hi(3)
               do j = lo(2), hi(2)
                  do i = lo(1), hi(1)
                     ugradu(i,j,k,n) = - ugradu(i,j,k,n)
                  end do
               end do
            end do
         end do
      end block
      
   end subroutine compute_ugradu_eb



   ! Upwind non-normal velocity
   function upwind ( velmns, velpls, uedge ) result (ev)

      ! Small value to protect against tiny velocities used in upwinding
      real(ar),        parameter     :: small_vel = 1.0d-10

      real(ar), intent(in) :: velmns, velpls, uedge
      real(ar)             :: ev

      if ( abs(uedge) .lt. small_vel) then
         ev = half * ( velpls + velmns )
      else 
         ev = merge ( velmns, velpls, uedge >= zero ) 
      end if

   end function upwind
   
   
end module convection_eb_mod