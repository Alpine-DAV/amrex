module mg_prolongation_module

  use bl_types

  implicit none

  interface pc_c_prolongation
     module procedure pc_c_prolongation_1d
     module procedure pc_c_prolongation_2d
     module procedure pc_c_prolongation_3d
  end interface

  interface lin_c_prolongation
     module procedure lin_c_prolongation_1d
     module procedure lin_c_prolongation_2d
     module procedure lin_c_prolongation_3d
  end interface

  interface nodal_prolongation
     module procedure nodal_prolongation_1d
     module procedure nodal_prolongation_2d
     module procedure nodal_prolongation_3d
  end interface

  private :: cubicInterpolate, bicubicInterpolate, tricubicInterpolate

contains

  subroutine pc_c_prolongation_1d(ff, lof, cc, loc, lo, hi, ir)
    integer,     intent(in   ) :: loc(:),lof(:)
    integer,     intent(in   ) :: lo(:), hi(:)
    real (dp_t), intent(inout) :: ff(lof(1):)
    real (dp_t), intent(in   ) :: cc(loc(1):)
    integer,     intent(in   ) :: ir(:)

    integer :: i, ic

    do i = lo(1),hi(1)
       ic = i / ir(1) 
       ff(i) = ff(i) + cc(ic)
    end do

  end subroutine pc_c_prolongation_1d

  subroutine pc_c_prolongation_2d(ff, lof, cc, loc, lo, hi, ir)
    integer,     intent(in   ) :: loc(:), lof(:)
    integer,     intent(in   ) :: lo(:), hi(:)
    real (dp_t), intent(inout) :: ff(lof(1):,lof(2):)
    real (dp_t), intent(in   ) :: cc(loc(1):,loc(2):)
    integer,     intent(in   ) :: ir(:)

    integer :: i, j, ic, jc, twoi, twoj, twoip1, twojp1, clo(2), chi(2)

    if ( ir(1) == 2 .and. ir(2) == 2 ) then
       !
       ! Specialized unrolled 2D version.
       !
       clo = lo / 2
       chi = hi / 2

       do j = clo(2),chi(2)
             twoj   = 2*j
             twojp1 = twoj+1
          do i = clo(1),chi(1)
             twoi   = 2*i
             twoip1 = twoi+1

             ff(twoi,   twoj  ) = ff(twoi,   twoj  ) + cc(i,j)
             ff(twoip1, twoj  ) = ff(twoip1, twoj  ) + cc(i,j)
             ff(twoi,   twojp1) = ff(twoi,   twojp1) + cc(i,j)
             ff(twoip1, twojp1) = ff(twoip1, twojp1) + cc(i,j)
          end do
       end do

    else
       !
       ! Generic ir/=2 case.
       !
       do j = lo(2),hi(2)
          jc = j / ir(2)
          do i = lo(1),hi(1)
             ic = i / ir(1) 
             ff(i,j) = ff(i,j) + cc(ic,jc)
          end do
       end do

    end if

  end subroutine pc_c_prolongation_2d

  subroutine pc_c_prolongation_3d(ff, lof, cc, loc, lo, hi, ir)
    integer,     intent(in   ) :: loc(:),lof(:)
    integer,     intent(in   ) :: lo(:), hi(:)
    real (dp_t), intent(inout) :: ff(lof(1):,lof(2):,lof(3):)
    real (dp_t), intent(in   ) :: cc(loc(1):,loc(2):,loc(3):)
    integer,     intent(in   ) :: ir(:)

    integer :: i, j, k, ic, jc, kc
    integer :: clo(3), chi(3), twoi, twoj, twok, twoip1, twojp1, twokp1

    if ( ir(1) == 2 .and. ir(2) == 2 .and. ir(3) == 2 ) then
       !
       ! Specialized unrolled 3D version.
       !
       clo = lo / 2
       chi = hi / 2

       do k = clo(3),chi(3)
          twok   = 2*k
          twokp1 = twok+1
          do j = clo(2),chi(2)
             twoj   = 2*j
             twojp1 = twoj+1
             do i = clo(1),chi(1)
                twoi   = 2*i
                twoip1 = twoi+1

                ff(twoip1, twojp1, twokp1) = ff(twoip1, twojp1, twokp1) + cc(i,j,k)
                ff(twoi,   twojp1, twokp1) = ff(twoi,   twojp1, twokp1) + cc(i,j,k)
                ff(twoip1, twoj,   twokp1) = ff(twoip1, twoj,   twokp1) + cc(i,j,k)
                ff(twoi,   twoj,   twokp1) = ff(twoi,   twoj,   twokp1) + cc(i,j,k)
                ff(twoip1, twojp1, twok  ) = ff(twoip1, twojp1, twok  ) + cc(i,j,k)
                ff(twoi,   twojp1, twok  ) = ff(twoi,   twojp1, twok  ) + cc(i,j,k)
                ff(twoip1, twoj,   twok  ) = ff(twoip1, twoj,   twok  ) + cc(i,j,k)
                ff(twoi,   twoj,   twok  ) = ff(twoi,   twoj,   twok  ) + cc(i,j,k)
             end do
          end do
       end do

    else
       !
       ! General ir/=2 case.
       !
       do k = lo(3),hi(3)
          kc = k / ir(3)
          do j = lo(2),hi(2)
             jc = j / ir(2)
             do i = lo(1),hi(1)
                ic = i / ir(1)
                ff(i,j,k) = ff(i,j,k) + cc(ic,jc,kc)
             end do
          end do
       end do

    end if

  end subroutine pc_c_prolongation_3d

  subroutine lin_c_prolongation_1d(ff, lof, cc, loc, lo, hi, ir)
    use bl_error_module
    integer,     intent(in   ) :: loc(:),lof(:)
    integer,     intent(in   ) :: lo(:), hi(:)
    real (dp_t), intent(inout) :: ff(lof(1):)
    real (dp_t), intent(in   ) :: cc(loc(1):)
    integer,     intent(in   ) :: ir(:)

    integer :: i, clo(1), chi(1)

    if ( ir(1) == 2 ) then
       !
       ! Do piecewise constant at boundaries.
       !
       clo = lo / 2
       chi = hi / 2

       i = clo(1)
       ff(2*i  ) = ff(2*i  ) + cc(i)
       ff(2*i+1) = ff(2*i+1) + cc(i)

       i = chi(1)
       ff(2*i  ) = ff(2*i  ) + cc(i)
       ff(2*i+1) = ff(2*i+1) + cc(i)
       !
       ! And linear interp interior.
       !
       do i = clo(1)+1,chi(1)-1
          ff(2*i  ) = ff(2*i  ) + 0.25d0*( 3*cc(i) + cc(i-1) )
          ff(2*i+1) = ff(2*i+1) + 0.25d0*( 3*cc(i) + cc(i+1) )
       end do
    else
       !
       ! For now don't bother with a generic lininterp.
       !
       call bl_warn('lin_c_prolongation_1d: calling pc_c_prolongation() since ir /= 2')

       call pc_c_prolongation(ff, lof, cc, loc, lo, hi, ir)
    end if

  end subroutine lin_c_prolongation_1d

  subroutine lin_c_prolongation_2d(ff, lof, cc, loc, lo, hi, ir, ptype)
    use bl_error_module
    integer,     intent(in   ) :: loc(:), lof(:)
    integer,     intent(in   ) :: lo(:), hi(:)
    real (dp_t), intent(inout) :: ff(lof(1):,lof(2):)
    real (dp_t), intent(in   ) :: cc(loc(1):,loc(2):)
    integer,     intent(in   ) :: ir(:), ptype

    integer :: i, j, clo(2), chi(2), twoi, twoj, twoip1, twojp1
    logical :: interior_i, interior_j

    real (dp_t), parameter :: one6th  = 1.0d0 / 6.0d0
    real (dp_t), parameter :: one16th = 1.0d0 /16.0d0

    if ( ir(1) == 2 .and. ir(2) == 2 ) then
       !
       ! First do all face points using piecewise-constant interpolation.
       !
       clo = lo / 2
       chi = hi / 2

       do j = clo(2),chi(2)
          twoj   = 2*j
          twojp1 = twoj+1
          interior_j = ( j > clo(2) .and. j < chi(2) )
          do i = clo(1),chi(1)
             interior_i = ( i > clo(1) .and. i < chi(1) )
             if ( interior_i .and. interior_j ) cycle
             twoi   = 2*i
             twoip1 = twoi+1
             ff(twoi,   twoj  ) = ff(twoi,   twoj  ) + cc(i,j)
             ff(twoip1, twoj  ) = ff(twoip1, twoj  ) + cc(i,j)
             ff(twoi,   twojp1) = ff(twoi,   twojp1) + cc(i,j)
             ff(twoip1, twojp1) = ff(twoip1, twojp1) + cc(i,j)
          end do
       end do
       !
       ! Then the interior points.
       !
       select case ( ptype )
       case ( 1 )
          !
          ! Type 1 - {2,1,1} weighted average of our neighbors.
          !
          do j = clo(2)+1, chi(2)-1
             twoj   = 2*j
             twojp1 = twoj+1
             do i = clo(1)+1, chi(1)-1
                twoi   = 2*i
                twoip1 = twoi+1
                ff(twoip1, twojp1) = ff(twoip1, twojp1) + .25d0 * ( 2*cc(i,j) + cc(i+1,j) + cc(i,j+1) )
                ff(twoi,   twojp1) = ff(twoi,   twojp1) + .25d0 * ( 2*cc(i,j) + cc(i-1,j) + cc(i,j+1) )
                ff(twoip1, twoj  ) = ff(twoip1, twoj  ) + .25d0 * ( 2*cc(i,j) + cc(i+1,j) + cc(i,j-1) )
                ff(twoi,   twoj  ) = ff(twoi,   twoj  ) + .25d0 * ( 2*cc(i,j) + cc(i-1,j) + cc(i,j-1) )
             end do
          end do
       case ( 2 )
          !
          ! Type 2 - {4,1,1} weighted average of our neighbors.
          !
          do j = clo(2)+1, chi(2)-1
             twoj   = 2*j
             twojp1 = twoj+1
             do i = clo(1)+1, chi(1)-1
                twoi   = 2*i
                twoip1 = twoi+1
                ff(twoip1, twojp1) = ff(twoip1, twojp1) + one6th * ( 4*cc(i,j) + cc(i+1,j) + cc(i,j+1) )
                ff(twoi,   twojp1) = ff(twoi,   twojp1) + one6th * ( 4*cc(i,j) + cc(i-1,j) + cc(i,j+1) )
                ff(twoip1, twoj  ) = ff(twoip1, twoj  ) + one6th * ( 4*cc(i,j) + cc(i+1,j) + cc(i,j-1) )
                ff(twoi,   twoj  ) = ff(twoi,   twoj  ) + one6th * ( 4*cc(i,j) + cc(i-1,j) + cc(i,j-1) )
             end do
          end do
       case ( 3 )
          !
          ! Type 3 - bilinear.
          !
          do j = clo(2)+1, chi(2)-1
             twoj   = 2*j
             twojp1 = twoj+1
             do i = clo(1)+1, chi(1)-1
                twoi   = 2*i
                twoip1 = twoi+1
                ff(twoip1, twojp1) = ff(twoip1, twojp1) + one16th * &
                     ( 9*cc(i,j) + 3*cc(i+1,j) + 3*cc(i,j+1) + cc(i+1,j+1) )
                ff(twoi,   twojp1) = ff(twoi,   twojp1) + one16th * &
                     ( 9*cc(i,j) + 3*cc(i-1,j) + 3*cc(i,j+1) + cc(i-1,j+1) )
                ff(twoip1, twoj  ) = ff(twoip1, twoj  ) + one16th * &
                     ( 9*cc(i,j) + 3*cc(i,j-1) + 3*cc(i+1,j) + cc(i+1,j-1) )
                ff(twoi,   twoj  ) = ff(twoi,   twoj  ) + one16th * &
                     ( 9*cc(i,j) + 3*cc(i-1,j) + 3*cc(i,j-1) + cc(i-1,j-1) )
             end do
          end do
       case default
          call bl_error("lin_c_prolongation_2d: unknown ptype", ptype)
       end select

    else
       !
       ! For now don't bother with a generic lininterp.
       !
       call bl_warn('lin_c_prolongation_2d: calling pc_c_prolongation() since ir /= 2')

       call pc_c_prolongation(ff, lof, cc, loc, lo, hi, ir)
    end if

  end subroutine lin_c_prolongation_2d

  subroutine lin_c_prolongation_3d(ff, lof, cc, loc, lo, hi, ir, ptype)
    use bl_error_module
    integer,     intent(in   ) :: loc(:),lof(:)
    integer,     intent(in   ) :: lo(:), hi(:)
    real (dp_t), intent(inout) :: ff(lof(1):,lof(2):,lof(3):)
    real (dp_t), intent(in   ) :: cc(loc(1):,loc(2):,loc(3):)
    integer,     intent(in   ) :: ir(:), ptype

    integer :: i, j, k, clo(3), chi(3), twoi, twoj, twoip1, twojp1, twok, twokp1
    logical :: interior_i, interior_j, interior_k

    real (dp_t), parameter ::   one64ths = 1.0d0 / 64.0d0
    real (dp_t), parameter :: three64ths = 3.0d0 / 64.0d0
    real (dp_t), parameter ::     sixth  = 1.0d0 /  6.0d0

    if ( ir(1) == 2 .and. ir(2) == 2 .and. ir(3) == 2 ) then
       !
       ! First do all face points using piecewise-constant interpolation.
       !
       clo = lo / 2
       chi = hi / 2

       do k = clo(3),chi(3)
          twok   = 2*k
          twokp1 = twok+1
          interior_k = ( k > clo(3) .and. k < chi(3) )
          do j = clo(2),chi(2)
             twoj   = 2*j
             twojp1 = twoj+1
             interior_j = ( j > clo(2) .and. j < chi(2) )
             do i = clo(1),chi(1)
                interior_i = ( i > clo(1) .and. i < chi(1) )
                if ( interior_i .and. interior_j .and. interior_k ) cycle
                twoi   = 2*i
                twoip1 = twoi+1
                ff(twoip1, twojp1, twokp1) = ff(twoip1, twojp1, twokp1) + cc(i,j,k)
                ff(twoi,   twojp1, twokp1) = ff(twoi,   twojp1, twokp1) + cc(i,j,k)
                ff(twoip1, twoj,   twokp1) = ff(twoip1, twoj,   twokp1) + cc(i,j,k)
                ff(twoi,   twoj,   twokp1) = ff(twoi,   twoj,   twokp1) + cc(i,j,k)
                ff(twoip1, twojp1, twok  ) = ff(twoip1, twojp1, twok  ) + cc(i,j,k)
                ff(twoi,   twojp1, twok  ) = ff(twoi,   twojp1, twok  ) + cc(i,j,k)
                ff(twoip1, twoj,   twok  ) = ff(twoip1, twoj,   twok  ) + cc(i,j,k)
                ff(twoi,   twoj,   twok  ) = ff(twoi,   twoj,   twok  ) + cc(i,j,k)
             end do
          end do
       end do
       !
       ! Then the interior points.
       !
       select case ( ptype )
       case ( 1 )
          !
          ! Type 1 - {1,1,1,1} weighted average of our neighbors.
          !
          do k = clo(3)+1,chi(3)-1
             twok   = 2*k
             twokp1 = twok+1
             do j = clo(2)+1,chi(2)-1
                twoj   = 2*j
                twojp1 = twoj+1
                do i = clo(1)+1,chi(1)-1
                   twoi   = 2*i
                   twoip1 = twoi+1
                   ff(twoip1, twojp1, twokp1) = ff(twoip1, twojp1, twokp1) + &
                        .25d0 * ( cc(i,j,k) + cc(i+1,j,k) + cc(i,j+1,k) + cc(i,j,k+1) )
                   ff(twoi,   twojp1, twokp1) = ff(twoi,   twojp1, twokp1) + &
                        .25d0 * ( cc(i,j,k) + cc(i-1,j,k) + cc(i,j+1,k) + cc(i,j,k+1) )
                   ff(twoip1, twoj,   twokp1) = ff(twoip1, twoj,   twokp1) + &
                        .25d0 * ( cc(i,j,k) + cc(i+1,j,k) + cc(i,j-1,k) + cc(i,j,k+1) )
                   ff(twoi,   twoj,   twokp1) = ff(twoi,   twoj,   twokp1) + &
                        .25d0 * ( cc(i,j,k) + cc(i-1,j,k) + cc(i,j-1,k) + cc(i,j,k+1) )
                   ff(twoip1, twojp1, twok  ) = ff(twoip1, twojp1, twok  ) + &
                        .25d0 * ( cc(i,j,k) + cc(i+1,j,k) + cc(i,j+1,k) + cc(i,j,k-1) )
                   ff(twoi,   twojp1, twok  ) = ff(twoi,   twojp1, twok  ) + &
                        .25d0 * ( cc(i,j,k) + cc(i-1,j,k) + cc(i,j+1,k) + cc(i,j,k-1) )
                   ff(twoip1, twoj,   twok  ) = ff(twoip1, twoj,   twok  ) + &
                        .25d0 * ( cc(i,j,k) + cc(i+1,j,k) + cc(i,j-1,k) + cc(i,j,k-1) )
                   ff(twoi,   twoj,   twok  ) = ff(twoi,   twoj,   twok  ) + &
                        .25d0 * ( cc(i,j,k) + cc(i-1,j,k) + cc(i,j-1,k) + cc(i,j,k-1) )
                end do
             end do
          end do
       case ( 2 )
          !
          ! Type 2 - {3,1,1,1} weighted average of our neighbors.
          !
          do k = clo(3)+1,chi(3)-1
             twok   = 2*k
             twokp1 = twok+1
             do j = clo(2)+1,chi(2)-1
                twoj   = 2*j
                twojp1 = twoj+1
                do i = clo(1)+1,chi(1)-1
                   twoi   = 2*i
                   twoip1 = twoi+1
                   ff(twoip1, twojp1, twokp1) = ff(twoip1, twojp1, twokp1) + &
                        sixth * ( 3*cc(i,j,k) + cc(i+1,j,k) + cc(i,j+1,k) + cc(i,j,k+1) )
                   ff(twoi,   twojp1, twokp1) = ff(twoi,   twojp1, twokp1) + &
                        sixth * ( 3*cc(i,j,k) + cc(i-1,j,k) + cc(i,j+1,k) + cc(i,j,k+1) )
                   ff(twoip1, twoj,   twokp1) = ff(twoip1, twoj,   twokp1) + &
                        sixth * ( 3*cc(i,j,k) + cc(i+1,j,k) + cc(i,j-1,k) + cc(i,j,k+1) )
                   ff(twoi,   twoj,   twokp1) = ff(twoi,   twoj,   twokp1) + &
                        sixth * ( 3*cc(i,j,k) + cc(i-1,j,k) + cc(i,j-1,k) + cc(i,j,k+1) )
                   ff(twoip1, twojp1, twok  ) = ff(twoip1, twojp1, twok  ) + &
                        sixth * ( 3*cc(i,j,k) + cc(i+1,j,k) + cc(i,j+1,k) + cc(i,j,k-1) )
                   ff(twoi,   twojp1, twok  ) = ff(twoi,   twojp1, twok  ) + &
                        sixth * ( 3*cc(i,j,k) + cc(i-1,j,k) + cc(i,j+1,k) + cc(i,j,k-1) )
                   ff(twoip1, twoj,   twok  ) = ff(twoip1, twoj,   twok  ) + &
                        sixth * ( 3*cc(i,j,k) + cc(i+1,j,k) + cc(i,j-1,k) + cc(i,j,k-1) )
                   ff(twoi,   twoj,   twok  ) = ff(twoi,   twoj,   twok  ) + &
                        sixth * ( 3*cc(i,j,k) + cc(i-1,j,k) + cc(i,j-1,k) + cc(i,j,k-1) )
                end do
             end do
          end do
       case ( 3 )
          !
          ! Type 3 - trilinear.
          !
          do k = clo(3)+1,chi(3)-1
             twok   = 2*k
             twokp1 = twok+1
             do j = clo(2)+1,chi(2)-1
                twoj   = 2*j
                twojp1 = twoj+1
                do i = clo(1)+1,chi(1)-1
                   twoi   = 2*i
                   twoip1 = twoi+1
                   ff(twoip1, twojp1, twokp1) = ff(twoip1, twojp1, twokp1) + &
                        three64ths * ( 9*cc(i,j,k  ) + 3*cc(i+1,j,k  ) + 3*cc(i,j+1,k  ) + cc(i+1,j+1,k  ) ) + &
                        one64ths * ( 9*cc(i,j,k+1) + 3*cc(i+1,j,k+1) + 3*cc(i,j+1,k+1) + cc(i+1,j+1,k+1) )
                   ff(twoi,   twojp1, twokp1) = ff(twoi,   twojp1, twokp1) + &
                        three64ths * ( 9*cc(i,j,k  ) + 3*cc(i-1,j,k  ) + 3*cc(i,j+1,k  ) + cc(i-1,j+1,k  ) ) + &
                        one64ths * ( 9*cc(i,j,k+1) + 3*cc(i-1,j,k+1) + 3*cc(i,j+1,k+1) + cc(i-1,j+1,k+1) )
                   ff(twoip1, twoj,   twokp1) = ff(twoip1, twoj,   twokp1) + &
                        three64ths * ( 9*cc(i,j,k  ) + 3*cc(i+1,j,k  ) + 3*cc(i,j-1,k  ) + cc(i+1,j-1,k  ) ) + &
                        one64ths * ( 9*cc(i,j,k+1) + 3*cc(i+1,j,k+1) + 3*cc(i,j-1,k+1) + cc(i+1,j-1,k+1) )
                   ff(twoi,   twoj,   twokp1) = ff(twoi,   twoj,   twokp1) + &
                        three64ths * ( 9*cc(i,j,k  ) + 3*cc(i-1,j,k  ) + 3*cc(i,j-1,k  ) + cc(i-1,j-1,k  ) ) + &
                        one64ths * ( 9*cc(i,j,k+1) + 3*cc(i-1,j,k+1) + 3*cc(i,j-1,k+1) + cc(i-1,j-1,k+1) )
                   ff(twoip1, twojp1, twok) = ff(twoip1, twojp1, twok) + &
                        three64ths * ( 9*cc(i,j,k  ) + 3*cc(i+1,j,k  ) + 3*cc(i,j+1,k  ) + cc(i+1,j+1,k  ) ) + &
                        one64ths * ( 9*cc(i,j,k-1) + 3*cc(i+1,j,k-1) + 3*cc(i,j+1,k-1) + cc(i+1,j+1,k-1) )
                   ff(twoi,   twojp1, twok) = ff(twoi,   twojp1, twok) + &
                        three64ths * ( 9*cc(i,j,k  ) + 3*cc(i-1,j,k  ) + 3*cc(i,j+1,k  ) + cc(i-1,j+1,k  ) ) + &
                        one64ths * ( 9*cc(i,j,k-1) + 3*cc(i-1,j,k-1) + 3*cc(i,j+1,k-1) + cc(i-1,j+1,k-1) )
                   ff(twoip1, twoj,   twok) = ff(twoip1, twoj,   twok) + &
                        three64ths * ( 9*cc(i,j,k  ) + 3*cc(i+1,j,k  ) + 3*cc(i,j-1,k  ) + cc(i+1,j-1,k  ) ) + &
                        one64ths * ( 9*cc(i,j,k-1) + 3*cc(i+1,j,k-1) + 3*cc(i,j-1,k-1) + cc(i+1,j-1,k-1) )
                   ff(twoi,   twoj,   twok) = ff(twoi,   twoj,   twok) + &
                        three64ths * ( 9*cc(i,j,k  ) + 3*cc(i-1,j,k  ) + 3*cc(i,j-1,k  ) + cc(i-1,j-1,k  ) ) + &
                        one64ths * ( 9*cc(i,j,k-1) + 3*cc(i-1,j,k-1) + 3*cc(i,j-1,k-1) + cc(i-1,j-1,k-1) )
                end do
             end do
          end do
       case default
          call bl_error("lin_c_prolongation_3d: unknown ptype", ptype)
       end select

    else
       !
       ! For now don't bother with a generic lininterp.
       !
       call bl_warn('lin_c_prolongation_3d: calling pc_c_prolongation() since ir /= 2')

       call pc_c_prolongation(ff, lof, cc, loc, lo, hi, ir)
    end if

  end subroutine lin_c_prolongation_3d

  pure function cubicInterpolate (p, x) result (r)
    real (dp_t), intent(in) :: p(0:3), x
    real (dp_t) r
    r=p(1)+0.5*x*(p(2)-p(0)+x*(2*p(0)-5*p(1)+4*p(2)-p(3)+x*(3*(p(1)-p(2))+p(3)-p(0))))
  end function cubicInterpolate

  function bicubicInterpolate (p, x, y) result (r)
    real (dp_t), intent(in) :: p(0:15), x, y
    real (dp_t) r, arr(0:3)
    !
    ! First interpolate in x.
    !
    arr(0) = cubicInterpolate(p( 0:3 ), x) ! row 0
    arr(1) = cubicInterpolate(p( 4:7 ), x) ! row 1
    arr(2) = cubicInterpolate(p( 8:11), x) ! row 2
    arr(3) = cubicInterpolate(p(12:15), x) ! row 3
    !
    ! Then using those four points interpolate in y.
    !
    r = cubicInterpolate(arr, y)
  end function bicubicInterpolate

  function tricubicInterpolate (p, x, y, z) result (r)
    real (dp_t), intent(in) :: p(0:63), x, y, z
    real (dp_t) r, arr(0:3)
    arr(0) = bicubicInterpolate(p( 0:15), x, y)
    arr(1) = bicubicInterpolate(p(16:31), x, y)
    arr(2) = bicubicInterpolate(p(32:47), x, y)
    arr(3) = bicubicInterpolate(p(48:63), x, y)
    r = cubicInterpolate(arr, z)
  end function tricubicInterpolate

  subroutine nodal_prolongation_1d(ff, lof, cc, loc, lo, hi, ir, ptype)
    integer,     intent(in   ) :: loc(:), lof(:)
    integer,     intent(in   ) :: lo(:), hi(:)
    real (dp_t), intent(inout) :: ff(lof(1):)
    real (dp_t), intent(in   ) :: cc(loc(1):)
    integer,     intent(in   ) :: ir(:), ptype

    integer               :: i, ic, l
    real (dp_t)           :: fac_left, fac_rght, coeffs(0:3)
    real(dp_t), parameter :: ONE = 1.0_dp_t
    !
    ! Direct injection for fine points overlaying coarse ones.
    !
    do i = lo(1),hi(1),ir(1)
       ic = i / ir(1) 
       ff(i) = ff(i) + cc(ic)
    end do

    if ( ptype == 1 .and. ir(1) == 2 ) then
       !
       ! Use linear interpolation at points one off from boundaries.
       !
       i  = lo(1)
       ic = i / ir(1)
       ff(i+1) = 0.5d0 * (cc(ic) + cc(ic+1))

       i  = hi(1) -1
       ic = i / ir(1)
       ff(i+1) = 0.5d0 * (cc(ic) + cc(ic+1))
       !
       ! Use cubic interpolation only on interior points away from boundary.
       ! This way we don't need to assume we have any grow cells.
       !
       do i = lo(1)+1, hi(1)-2, ir(1)

          ic = i / ir(1)

          coeffs(0) = cc(ic-1)
          coeffs(1) = cc(ic+0)
          coeffs(2) = cc(ic+1)
          coeffs(3) = cc(ic+2)

          ff(i+1) = ff(i+1) + cubicInterpolate(coeffs, 0.5d0)
       end do

    else

       do l = 1, ir(1)-1
          fac_rght = real(l,dp_t) / real(ir(1),dp_t)
          fac_left = ONE - fac_rght
          do i = lo(1), hi(1)-1, ir(1)
             ic = i / ir(1) 
             ff(i+l) = ff(i+1) + fac_left*cc(ic) + fac_rght*cc(ic+1)
          end do
       end do

    end if

  end subroutine nodal_prolongation_1d

  subroutine nodal_prolongation_2d(ff, lof, cc, loc, lo, hi, ir, ptype)
    use bl_error_module
    integer,     intent(in   ) :: loc(:),lof(:)
    integer,     intent(in   ) :: lo(:), hi(:)
    real (dp_t), intent(inout) :: ff(lof(1):,lof(2):)
    real (dp_t), intent(in   ) :: cc(loc(1):,loc(2):)
    integer,     intent(in   ) :: ir(:), ptype

    integer     :: i, j, ic, jc, l, m, ng
    real (dp_t) :: fac_left, fac_rght, coeffs(0:15)
    real (dp_t) :: temp(lo(1):hi(1),lo(2):hi(2))

    real(dp_t), parameter :: ONE = 1.0_dp_t

    ng = min((lo(1)/ir(1))-loc(1),(lo(2)/ir(2))-loc(2))

    if ( ir(1) == 2 .and. ir(2) == 2 ) then

       if ( ptype == 1 .and. ng > 0 ) then
          !
          ! Bicubic was requested and we have one ghost cell.
          !
          do j = lo(2),hi(2),ir(2)
             jc = j / ir(2) 
             do i = lo(1),hi(1),ir(1)
                ic = i / ir(1) 
                !
                ! Direct injection for fine points overlaying coarse ones.
                !
                ff(i,j) = ff(i,j) + cc(ic,jc)

                if ( i < hi(1) ) then

                   if ( j == hi(2) ) then
                      coeffs( 0 :  3) = (/ (cc(m,jc-2), m=ic-1,ic+2) /)
                      coeffs( 4 :  7) = (/ (cc(m,jc-1), m=ic-1,ic+2) /)
                      coeffs( 8 : 11) = (/ (cc(m,jc+0), m=ic-1,ic+2) /)
                      coeffs(12 : 15) = (/ (cc(m,jc+1), m=ic-1,ic+2) /)
                   else
                      coeffs( 0 :  3) = (/ (cc(m,jc-1), m=ic-1,ic+2) /)
                      coeffs( 4 :  7) = (/ (cc(m,jc+0), m=ic-1,ic+2) /)
                      coeffs( 8 : 11) = (/ (cc(m,jc+1), m=ic-1,ic+2) /)
                      coeffs(12 : 15) = (/ (cc(m,jc+2), m=ic-1,ic+2) /)
                   end if

                   ff(i+1,j) = ff(i+1,j) + bicubicInterpolate(coeffs, 0.5d0, 0.0d0) 

                   if ( j < hi(2) ) then

                      ff(i+1,j+1) = ff(i+1,j+1) + bicubicInterpolate(coeffs, 0.5d0, 0.5d0) 
                   end if
                end if

                if ( j < hi(2) ) then

                   if ( i == hi(1) ) then
                      coeffs( 0 :  3) = (/ (cc(m,jc-1), m=ic-2,ic+1) /)
                      coeffs( 4 :  7) = (/ (cc(m,jc+0), m=ic-2,ic+1) /)
                      coeffs( 8 : 11) = (/ (cc(m,jc+1), m=ic-2,ic+1) /)
                      coeffs(12 : 15) = (/ (cc(m,jc+2), m=ic-2,ic+1) /)
                   end if

                   ff(i,j+1) = ff(i,j+1) + bicubicInterpolate(coeffs, 0.0d0, 0.5d0)
                end if

             end do
          end do

       else
          !
          ! Do fast unrolled linear interp.
          !
          do j = lo(2),hi(2),ir(2)
             jc = j / ir(2) 
             do i = lo(1),hi(1),ir(1)
                ic = i / ir(1) 
                !
                ! Direct injection for fine points overlaying coarse ones.
                !
                ff(i,j) = ff(i,j) + cc(ic,jc)

                if ( i < hi(1) ) then

                   ff(i+1,j) = ff(i+1,j) + 0.5d0*( cc(ic,jc)+cc(ic+1,jc) )

                   if ( j < hi(2) ) then

                      ff(i+1,j+1) = ff(i+1,j+1) + 0.25d0*( cc(ic,jc)+cc(ic+1,jc)+cc(ic,jc+1)+cc(ic+1,jc+1) )
                   end if
                end if

                if ( j < hi(2) ) then

                   ff(i,j+1) = ff(i,j+1) + 0.5d0*( cc(ic,jc)+cc(ic,jc+1) )
                end if
             end do
          end do
       end if

    else
       !
       ! General ir/=2 case.
       !
       ! Direct injection for fine points overlaying coarse ones.
       !
       do j = lo(2),hi(2),ir(2)
          jc = j / ir(2) 
          do i = lo(1),hi(1),ir(1)
             ic = i / ir(1) 
             temp(i,j) = cc(ic,jc)
          end do
       end do
       !
       ! Interpolate at fine nodes between coarse nodes in the i-direction only.
       !
       do j = lo(2),hi(2),ir(2)
          do l = 1, ir(1)-1
             fac_rght = real(l,dp_t) / real(ir(1),dp_t)
             fac_left = ONE - fac_rght
             do i = lo(1),hi(1)-1,ir(1)
                temp(i+l,j) = fac_left*temp(i,j) + fac_rght*temp(i+ir(1),j)
             end do
          end do
       end do
       !
       ! Interpolate in the j-direction using previously interpolated "temp".
       !
       do m = 1, ir(2)-1
          fac_rght = real(m,dp_t) / real(ir(2),dp_t)
          fac_left = ONE - fac_rght
          do j = lo(2),hi(2)-1,ir(2)
             do i = lo(1),hi(1)
                temp(i,j+m) = fac_left*temp(i,j)+fac_rght*temp(i,j+ir(2))
             end do
          end do
       end do

       do j = lo(2),hi(2)
          do i = lo(1),hi(1)
             ff(i,j) = ff(i,j) + temp(i,j)
          end do
       end do

    end if

  end subroutine nodal_prolongation_2d

  subroutine nodal_prolongation_3d(ff, lof, cc, loc, lo, hi, ir)
    integer,     intent(in   ) :: loc(:), lof(:)
    integer,     intent(in   ) :: lo(:), hi(:)
    real (dp_t), intent(inout) :: ff(lof(1):,lof(2):,lof(3):)
    real (dp_t), intent(in   ) :: cc(loc(1):,loc(2):,loc(3):)
    integer,     intent(in   ) :: ir(:)

    integer               :: i, j, k, ic, jc, kc, l, m, n
    real (dp_t)           :: fac_left, fac_rght
    real(dp_t), parameter :: ONE = 1.0_dp_t

    real (dp_t), allocatable :: temp(:,:,:)

    if ( ir(1) == 2 .and. ir(2) == 2 .and. ir(3) == 2 ) then
       !
       ! Do fast unrolled linear interp.
       !
       do k = lo(3),hi(3),ir(3)
          kc = k / ir(3) 
          do j = lo(2),hi(2),ir(2)
             jc = j / ir(2) 
             do i = lo(1),hi(1),ir(1)
                ic = i / ir(1) 
                !
                ! Direct injection for fine points overlaying coarse ones.
                !
                ff(i,j,k) = ff(i,j,k) + cc(ic,jc,kc)

                if ( i < hi(1) ) then
                   ff(i+1,j,k) = ff(i+1,j,k) + 0.5d0*( cc(ic,jc,kc) + cc(ic+1,jc,kc) )

                   if ( j < hi(2) ) then
                      ff(i+1,j+1,k) = ff(i+1,j+1,k) + &
                           0.25d0*( cc(ic,jc,kc) + cc(ic+1,jc,kc) + cc(ic,jc+1,kc) + cc(ic+1,jc+1,kc) )
                   end if
                end if

                if ( j < hi(2) ) then
                   ff(i,j+1,k) = ff(i,j+1,k) + 0.5d0*( cc(ic,jc,kc) + cc(ic,jc+1,kc) )
                end if

                if ( k < hi(3) ) then
                   ff(i,j,k+1) = ff(i,j,k+1) + 0.5d0*( cc(ic,jc,kc)+cc(ic,jc,kc+1) )

                   if ( i < hi(1) ) then
                      ff(i+1,j,k+1) = ff(i+1,j,k+1) + &
                           0.25d0*( cc(ic,jc,kc) + cc(ic+1,jc,kc) + cc(ic,jc,kc+1) + cc(ic+1,jc,kc+1) )

                      if ( j < hi(2) ) then
                         ff(i+1,j+1,k+1) = ff(i+1,j+1,k+1) + &
                              0.125d0*( ( cc(ic,jc,kc) + cc(ic+1,jc,kc) + cc(ic,jc+1,kc) + cc(ic+1,jc+1,kc) ) +  &
                              ( cc(ic,jc,kc+1) + cc(ic+1,jc,kc+1) + cc(ic,jc+1,kc+1) + cc(ic+1,jc+1,kc+1) ) )
                      end if
                   end if

                   if ( j < hi(2) ) then
                      ff(i,j+1,k+1) = ff(i,j+1,k+1) + &
                           0.25d0*( cc(ic,jc,kc) + cc(ic,jc+1,kc) + cc(ic,jc,kc+1) + cc(ic,jc+1,kc+1) )
                   end if
                end if

             end do
          end do
       end do

    else
       !
       ! General ir/=2 case.
       !
       allocate(temp(lo(1):hi(1), lo(2):hi(2), lo(3):hi(3)))
       !
       ! Direct injection for fine points overlaying coarse ones.
       !
       do k = lo(3),hi(3),ir(3)
          kc = k / ir(3) 
          do j = lo(2),hi(2),ir(2)
             jc = j / ir(2) 
             do i = lo(1),hi(1),ir(1)
                ic = i / ir(1) 
                temp(i,j,k) = cc(ic,jc,kc)
             end do
          end do
       end do
       !
       ! Interpolate at fine nodes between coarse nodes in the i-direction only.
       !
       do k = lo(3),hi(3),ir(3)
          do j = lo(2),hi(2),ir(2)
             do l = 1, ir(1)-1
                fac_rght = real(l,dp_t) / real(ir(1),dp_t)
                fac_left = ONE - fac_rght
                do i = lo(1),hi(1)-1,ir(1)
                   temp(i+l,j,k) = fac_left*temp(i,j,k) + fac_rght*temp(i+ir(1),j,k)
                end do
             end do
          end do
       end do
       !
       ! Interpolate in the j-direction.
       !
       do k = lo(3),hi(3),ir(3)
          do m = 1, ir(2)-1
             fac_rght = real(m,dp_t) / real(ir(2),dp_t)
             fac_left = ONE - fac_rght
             do j = lo(2),hi(2)-1,ir(2)
                do i = lo(1),hi(1)
                   temp(i,j+m,k) = fac_left*temp(i,j,k)+fac_rght*temp(i,j+ir(2),k)
                end do
             end do
          end do
       end do
       !
       ! Interpolate in the k-direction.
       !
       do n = 1, ir(3)-1
          fac_rght = real(n,dp_t) / real(ir(3),dp_t)
          fac_left = ONE - fac_rght
          do j = lo(2),hi(2)
             do k = lo(3),hi(3)-1,ir(3)
                do i = lo(1),hi(1)
                   temp(i,j,k+n) = fac_left*temp(i,j,k)+fac_rght*temp(i,j,k+ir(3))
                end do
             end do
          end do
       end do
       !
       ! Finally do the prolongation.
       !
       do k = lo(3),hi(3)
          do j = lo(2),hi(2)
             do i = lo(1),hi(1)
                ff(i,j,k) = ff(i,j,k) + temp(i,j,k)
             end do
          end do
       end do

    endif

  end subroutine nodal_prolongation_3d

end module mg_prolongation_module
