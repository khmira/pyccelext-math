!> @brief 
!> Module for Splines 
!> @details
!> basic functions and routines for B-Splines
!> in 1D, 2D and 3D
!>
!> This file contains two modules
!> BSPLINE : basic functions and routines
!> BSP     : specific implementations for 1D,2D,3D
!> Externaly, the user should call BSP

! TODO - uncomment spl_refinement_matrix_one_stage and use FindSpan instead of interv from pppack 
!      - uncomment spl_refinement_matrix_multi_stages  

module mod_pyccelext_math_external_bspline
contains

  ! .......................................................
  !> @brief     Determine non zero elements 
  !>
  !> @param[in]    n             number of control points  - 1
  !> @param[in]    p             spline degree 
  !> @param[in]    U             Knot vector 
  !> @param[inout] n_elements    number of non-zero elements 
  !> @param[inout] grid          the corresponding grid
  subroutine FindNonZeroElements_bspline(n,p,U,n_elements,grid) 
  implicit none
    integer(kind=4), intent(in) :: n, p
    real   (kind=8), intent(in) :: U(0:n+p+1)
    integer(kind=4), intent(inout) :: n_elements
    real   (kind=8), intent(inout) :: grid(0:n+p+1)
    ! local
    integer :: i
    integer :: i_current
    real(kind=8) :: min_current

    grid = -10000000.0 

    i_current = 0 
    grid(i_current) = minval(U)
    do i=1, (n + 1) + p
       min_current = minval(U(i : ))
       if ( min_current > grid(i_current) ) then
               i_current = i_current + 1
               grid(i_current) = min_current
       end if
    end do
    n_elements = i_current 

  end subroutine FindNonZeroElements_bspline
  ! .......................................................

  ! .......................................................
  !> @brief     Determine the knot span index 
  !>
  !> @param[in]  n     number of control points 
  !> @param[in]  p     spline degree 
  !> @param[in]  U     Knot vector 
  !> @param[in]  uu    given knot 
  !> @param[out] span  span index 
  function FindSpan(n,p,uu,U) result (span)
  implicit none
    integer(kind=4), intent(in) :: n, p
    real   (kind=8), intent(in) :: uu, U(0:n+p+1)
    integer(kind=4)             :: span
    integer(kind=4) low, high

    if (uu >= U(n+1)) then
       span = n
       return
    end if
    if (uu <= U(p)) then
       span = p
       return
    end if
    low  = p
    high = n+1
    span = (low + high) / 2
    do while (uu < U(span) .or. uu >= U(span+1))
       if (uu < U(span)) then
          high = span
       else
          low  = span
       end if
       span = (low + high) / 2
    end do
  end function FindSpan
  ! .......................................................

  ! .......................................................
  !> @brief     Computes the multiplicity of a knot  
  !>
  !> @param[in]  n      number of control points 
  !> @param[in]  p      spline degree 
  !> @param[in]  U      Knot vector 
  !> @param[in]  uu     Knot 
  !> @param[in]  i      starting index for search 
  !> @param[out] mult   multiplicit of the given knot 
  function FindMult(i,uu,p,U) result (mult)
  implicit none
    integer(kind=4), intent(in)  :: i, p
    real   (kind=8), intent(in)  :: uu, U(0:i+p+1)
    integer(kind=4)              :: mult
    integer(kind=4) :: j
    
    mult = 0
    do j = -p, p+1
       if (uu == U(i+j)) mult = mult + 1
    end do
  end function FindMult
  ! .......................................................

  ! .......................................................
  !> @brief     Computes the span and multiplicity of a knot  
  !>
  !> @param[in]  n    number of control points 
  !> @param[in]  p    spline degree 
  !> @param[in]  U    Knot vector 
  !> @param[in]  uu   Knot 
  !> @param[out] k    span of a knot 
  !> @param[out] s    multiplicity of a knot 
  subroutine FindSpanMult(n,p,uu,U,k,s)
    implicit none
    integer(kind=4), intent(in)  :: n, p
    real   (kind=8), intent(in)  :: uu, U(0:n+p+1)
    integer(kind=4), intent(out) :: k, s
    k = FindSpan(n,p,uu,U)
    s = FindMult(k,uu,p,U)
  end subroutine FindSpanMult
  ! .......................................................

  ! .......................................................
  !> @brief      Compute the nonvanishing basis functions
  !>
  !> @param[in]  p    spline degree 
  !> @param[in]  U    Knot vector 
  !> @param[in]  uu   Knot 
  !> @param[in]  i    span of a knot 
  !> @param[out] N    all (p+1) Splines non-vanishing at uu 
  subroutine BasisFuns(i,uu,p,U,N)
    implicit none
    integer(kind=4), intent(in) :: i, p
    real   (kind=8), intent(in) :: uu, U(0:i+p)
    real   (kind=8), intent(out):: N(0:p)
    integer(kind=4) :: j, r
    real   (kind=8) :: left(p), right(p), saved, temp
    N(0) = 1.0
    do j = 1, p
       left(j)  = uu - U(i+1-j)
       right(j) = U(i+j) - uu
       saved = 0.0
       do r = 0, j-1
          temp = N(r) / (right(r+1) + left(j-r))
          N(r) = saved + right(r+1) * temp
          saved = left(j-r) * temp
       end do
       N(j) = saved
    end do
  end subroutine BasisFuns
  ! .......................................................

  ! .......................................................
  !> @brief      Compute the nonvanishing basis functions and their derivatives.
  !> @details    First section is A2.2 (The NURBS Book) modified 
  !>             to store functions and knot differences.  
  !>
  !> @param[in]  p      spline degree 
  !> @param[in]  U      Knot vector 
  !> @param[in]  uu     Knot 
  !> @param[in]  i      span of a knot 
  !> @param[in]  n      number of derivatives 
  !> @param[out] ders   all (p+1) Splines non-vanishing at uu and their derivatives
  subroutine DersBasisFuns(i,uu,p,n,U,ders)
    implicit none
    integer(kind=4), intent(in) :: i, p, n
    real   (kind=8), intent(in) :: uu, U(0:i+p)
    real   (kind=8), intent(out):: ders(0:p,0:n)
    integer(kind=4) :: j, k, r, s1, s2, rk, pk, j1, j2
    real   (kind=8) :: saved, temp, d
    real   (kind=8) :: left(p), right(p)
    real   (kind=8) :: ndu(0:p,0:p), a(0:1,0:p)
    ndu(0,0) = 1.0
    do j = 1, p
       left(j)  = uu - U(i+1-j)
       right(j) = U(i+j) - uu
       saved = 0.0
       do r = 0, j-1
          ndu(j,r) = right(r+1) + left(j-r)
          temp = ndu(r,j-1) / ndu(j,r)
          ndu(r,j) = saved + right(r+1) * temp
          saved = left(j-r) * temp
       end do
       ndu(j,j) = saved
    end do
    ders(:,0) = ndu(:,p)
    do r = 0, p
       s1 = 0; s2 = 1;
       a(0,0) = 1.0
       do k = 1, n
          d = 0.0
          rk = r-k; pk = p-k;
          if (r >= k) then
             a(s2,0) = a(s1,0) / ndu(pk+1,rk)
             d =  a(s2,0) * ndu(rk,pk)
          end if
          if (rk > -1) then
             j1 = 1
          else
             j1 = -rk
          end if
          if (r-1 <= pk) then
             j2 = k-1
          else
             j2 = p-r
          end if
          do j = j1, j2
             a(s2,j) = (a(s1,j) - a(s1,j-1)) / ndu(pk+1,rk+j)
             d =  d + a(s2,j) * ndu(rk+j,pk)
          end do
          if (r <= pk) then
             a(s2,k) = - a(s1,k-1) / ndu(pk+1,r)
             d =  d + a(s2,k) * ndu(r,pk)
          end if
          ders(r,k) = d
          j = s1; s1 = s2; s2 = j;
       end do
    end do
    r = p
    do k = 1, n
       ders(:,k) = ders(:,k) * r
       r = r * (p-k)
    end do
  end subroutine DersBasisFuns
  ! .......................................................

  ! .......................................................
  !> @brief     evaluates a B-Spline curve at the knot uu 
  !>
  !> @param[in]    d             dimension of the manifold 
  !> @param[in]    n             number of control points  - 1
  !> @param[in]    p             spline degree 
  !> @param[in]    U             Knot vector 
  !> @param[in]    Pw            weighted control points 
  !> @param[in]    uu            knot to evaluate at 
  !> @param[inout] C             the point on the curve 
  subroutine CurvePoint(d,n,p,U,Pw,uu,C)
    implicit none
    integer(kind=4), intent(in)  :: d
    integer(kind=4), intent(in)  :: n, p
    real   (kind=8), intent(in)  :: U(0:n+p+1)
    real   (kind=8), intent(in)  :: Pw(d,0:n)
    real   (kind=8), intent(in)  :: uu
    real   (kind=8), intent(out) :: C(d)
    integer(kind=4) :: j, span
    real   (kind=8) :: basis(0:p)
    span = FindSpan(n,p,uu,U)
    call BasisFuns(span,uu,p,U,basis)
    C = 0.0
    do j = 0, p
       C = C + basis(j)*Pw(:,span-p+j)
    end do
  end subroutine CurvePoint
  ! .......................................................

  ! .......................................................
  !> @brief     evaluates a B-Spline surface at the knot (uu, vv) 
  !>
  !> @param[in]    d             dimension of the manifold 
  !> @param[in]    n             number of control points  - 1
  !> @param[in]    p             spline degree 
  !> @param[in]    U             Knot vector 
  !> @param[in]    m             number of control points  - 1
  !> @param[in]    q             spline degree 
  !> @param[in]    V             Knot vector 
  !> @param[in]    Pw            weighted control points 
  !> @param[in]    uu            knot to evaluate at 
  !> @param[in]    vv            knot to evaluate at 
  !> @param[inout] S             the point on the surface 
  subroutine SurfacePoint(d,n,p,U,m,q,V,Pw,uu,vv,S)
    implicit none
    integer(kind=4), intent(in)  :: d
    integer(kind=4), intent(in)  :: n, p
    integer(kind=4), intent(in)  :: m, q
    real   (kind=8), intent(in)  :: U(0:n+p+1)
    real   (kind=8), intent(in)  :: V(0:m+q+1)
    real   (kind=8), intent(in)  :: Pw(d,0:m,0:n)
    real   (kind=8), intent(in)  :: uu, vv
    real   (kind=8), intent(out) :: S(d)
    integer(kind=4) :: uj, vj, uspan, vspan
    real   (kind=8) :: ubasis(0:p), vbasis(0:q)
    uspan = FindSpan(n,p,uu,U)
    call BasisFuns(uspan,uu,p,U,ubasis)
    vspan = FindSpan(m,q,vv,V)
    call BasisFuns(vspan,vv,q,V,vbasis)
    S = 0.0
    do uj = 0, p
       do vj = 0, q
          S = S + ubasis(uj)*vbasis(vj)*Pw(:,vspan-q+vj,uspan-p+uj)
       end do
    end do
  end subroutine SurfacePoint
  ! .......................................................

  ! .......................................................
  !> @brief     extracts a B-Spline curve at the knot x 
  !>
  !> @param[in]    d             dimension of the manifold 
  !> @param[in]    n             number of control points  - 1
  !> @param[in]    p             spline degree 
  !> @param[in]    U             Knot vector 
  !> @param[in]    Pw            weighted control points 
  !> @param[in]    x             knot to evaluate at 
  !> @param[inout] Cw            the point on the curve 
  subroutine CurvePntByCornerCut(d,n,p,U,Pw,x,Cw)
    implicit none
    integer(kind=4), intent(in)  :: d
    integer(kind=4), intent(in)  :: n, p
    real   (kind=8), intent(in)  :: U(0:n+p+1)
    real   (kind=8), intent(in)  :: Pw(d,0:n)
    real   (kind=8), intent(in)  :: x
    real   (kind=8), intent(out) :: Cw(d)
    integer(kind=4) :: i, j, k, s, r
    real   (kind=8) :: uu, alpha, Rw(d,0:p)
    if (x <= U(p)) then
       uu = U(p)
       k = p
       s = FindMult(p,uu,p,U)
       if (s >= p) then
          Cw(:) = Pw(:,0)
          return
       end if
    elseif (x >= U(n+1)) then
       uu = U(n+1)
       k = n+1
       s = FindMult(n,uu,p,U)
       if (s >= p) then
          Cw(:) = Pw(:,n)
          return
       end if
    else
       uu = x
       k = FindSpan(n,p,uu,U)
       s = FindMult(k,uu,p,U)
       if (s >= p) then
          Cw(:) = Pw(:,k-p)
          return
       end if
    end if
    r = p-s
    do i = 0, r
       Rw(:,i) = Pw(:,k-p+i)
    end do
    do j = 1, r
       do i = 0, r-j
          alpha = (uu-U(k-p+j+i))/(U(i+k+1)-U(k-p+j+i))
          Rw(:,i) = alpha*Rw(:,i+1)+(1-alpha)*Rw(:,i)
       end do
    end do
    Cw(:) = Rw(:,0)
  end subroutine CurvePntByCornerCut
  ! .......................................................

  ! .......................................................
  !> @brief     inserts the knot uu r times 
  !>
  !> @param[in] d manifold dimension for the control points  
  !> @param[in] n number of control points 
  !> @param[in] p spline degree 
  !> @param[in] U Initial Knot vector 
  !> @param[in] Pw Initial Control points  
  !> @param[in] uu knot to insert 
  !> @param[in] k span of a knot 
  !> @param[in] s multiplicity of a knot 
  !> @param[in] r number of times uu will be inserted
  !> @param[in] V Final Knot vector 
  !> @param[in] Qw Final Control points  
  subroutine InsertKnot(d,n,p,U,Pw,uu,k,s,r,V,Qw)
    implicit none
    integer(kind=4), intent(in)  :: d
    integer(kind=4), intent(in)  :: n, p
    real   (kind=8), intent(in)  :: U(0:n+p+1)
    real   (kind=8), intent(in)  :: Pw(d,0:n)
    real   (kind=8), intent(in)  :: uu
    integer(kind=4), intent(in)  :: k, s, r
    real   (kind=8), intent(out) :: V(0:n+p+1+r)
    real   (kind=8), intent(out) :: Qw(d,0:n+r)
    integer(kind=4) :: i, j, idx
    real   (kind=8) :: alpha, Rw(d,0:p)
    ! Load new knot vector
    forall (i = 0:k) V(i) = U(i)
    forall (i = 1:r) V(k+i) = uu
    forall (i = k+1:n+p+1) V(i+r) = U(i)
    ! Save unaltered control points
    forall (i = 0:k-p) Qw(:,i)   = Pw(:,i)
    forall (i = k-s:n) Qw(:,i+r) = Pw(:,i)
    forall (i = 0:p-s) Rw(:,i)   = Pw(:,k-p+i)
    ! Insert the knot r times
    do j = 1, r
       idx = k-p+j
       do i = 0, p-j-s
          alpha = (uu-U(idx+i))/(U(i+k+1)-U(idx+i))
          Rw(:,i) = alpha*Rw(:,i+1)+(1-alpha)*Rw(:,i)
       end do
       Qw(:,idx) = Rw(:,0)
       Qw(:,k+r-j-s) = Rw(:,p-j-s)
    end do
    ! Load remaining control points
    idx = k-p+r
    do i = idx+1, k-s-1
       Qw(:,i) = Rw(:,i-idx)
    end do
  end subroutine InsertKnot
  ! .......................................................

  ! .......................................................
  !> @brief     removes a knot from a B-Splines curve, given a tolerance 
  !>
  !> @param[in]    d      dimension of the manifold 
  !> @param[in]    n      number of control points  - 1
  !> @param[in]    p      spline degree 
  !> @param[inout] U      Knot vector 
  !> @param[inout] Pw     weighted control points 
  !> @param[in]    uu     knot to remove 
  !> @param[in]    r      starting multiplicity to remove 
  !> @param[in]    s      ending multiplicity to remove 
  !> @param[in]    num    maximum number of iterations 
  !> @param[out]   t      requiered number of iterations 
  !> @param[in]    TOL    tolerance for the distance to the control point 
  subroutine RemoveKnot(d,n,p,U,Pw,uu,r,s,num,t,TOL)
    implicit none
    integer(kind=4), intent(in)    :: d
    integer(kind=4), intent(in)    :: n, p
    real   (kind=8), intent(inout) :: U(0:n+p+1)
    real   (kind=8), intent(inout) :: Pw(d,0:n)
    real   (kind=8), intent(in)    :: uu
    integer(kind=4), intent(in)    :: r, s, num
    integer(kind=4), intent(out)   :: t
    real   (kind=8), intent(in)    :: TOL

    integer(kind=4) :: m,ord,fout,last,first,off
    integer(kind=4) :: i,j,ii,jj,k
    logical         :: remflag
    real   (kind=8) :: temp(d,0:2*p)
    real   (kind=8) :: alfi,alfj

    m = n + p + 1
    ord = p + 1
    fout = (2*r-s-p)/2
    first = r - p
    last  = r - s
    do t = 0,num-1
       off = first - 1
       temp(:,0) = Pw(:,off)
       temp(:,last+1-off) = Pw(:,last+1)
       i = first; ii = 1
       j = last;  jj = last - off
       remflag = .false.
       do while (j-i > t)
          alfi = (uu-U(i))/(U(i+ord+t)-U(i))
          alfj = (uu-U(j-t))/(U(j+ord)-U(j-t))
          temp(:,ii) = (Pw(:,i)-(1.0-alfi)*temp(:,ii-1))/alfi
          temp(:,jj) = (Pw(:,j)-alfj*temp(:,jj+1))/(1.0-alfj)
          i = i + 1; ii = ii + 1
          j = j - 1; jj = jj - 1
       end do
       if (j-i < t) then
          if (Distance(d,temp(:,ii-1),temp(:,jj+1)) <= TOL) then
             remflag = .true.
          end if
       else
          alfi = (uu-U(i))/(U(i+ord+t)-U(i))
          if (Distance(d,Pw(:,i),alfi*temp(:,ii+t+1)+(1-alfi)*temp(:,ii-1)) <= TOL) then
             remflag = .true.
          end if
       end if
       if (remflag .eqv. .false.) then
          exit ! break out of the for loop
       else
          i = first
          j = last
          do while (j-i > t)
             Pw(:,i) = temp(:,i-off)
             Pw(:,j) = temp(:,j-off)
             i = i + 1
             j = j - 1
          end do
       end if
       first = first - 1
       last  = last  + 1
    end do
    if (t == 0) return
    do k = r+1,m
       U(k-t) = U(k)
    end do
    j = fout
    i = j
    do k = 1,t-1
       if (mod(k,2) == 1) then
          i = i + 1
       else
          j = j - 1
       end if
    end do
    do k = i+1,n
       Pw(:,j) = Pw(:,k)
       j = j + 1
    enddo
  contains
    function Distance(d,P1,P2) result (dist)
      implicit none
      integer(kind=4), intent(in) :: d
      real   (kind=8), intent(in) :: P1(d),P2(d)
      integer(kind=4) :: i
      real   (kind=8) :: dist
      dist = 0.0
      do i = 1,d
         dist = dist + (P1(i)-P2(i))*(P1(i)-P2(i))
      end do
      dist = sqrt(dist)
    end function Distance
  end subroutine RemoveKnot
  ! .......................................................

  ! .......................................................
  !> @brief    clampes a B-spline curve 
  !>
  !> @param[in] d manifold dimension for the control points  
  !> @param[in] n number of control points 
  !> @param[in] p spline degree 
  !> @param[in] U Initial Knot vector 
  !> @param[in] Pw Initial Control points  
  !> @param[in] l apply the algorithm on the left 
  !> @param[in] r apply the algorithm on the right 
  subroutine ClampKnot(d,n,p,U,Pw,l,r)
    implicit none
    integer(kind=4), intent(in)    :: d
    integer(kind=4), intent(in)    :: n, p
    real   (kind=8), intent(inout) :: U(0:n+p+1)
    real   (kind=8), intent(inout) :: Pw(d,0:n)
    logical(kind=4), intent(in)    :: l, r
    integer(kind=4) :: k, s
    if (l) then ! Clamp at left end
       k = p
       s = FindMult(p,U(p),p,U)
       call KntIns(d,n,p,U,Pw,k,s)
       U(0:p-1) = U(p)
    end if
    if (r) then ! Clamp at right end
       k = n+1
       s = FindMult(n,U(n+1),p,U)
       call KntIns(d,n,p,U,Pw,k,s)
       U(n+2:n+p+1) = U(n+1)
    end if
  contains
    subroutine KntIns(d,n,p,U,Pw,k,s)
        implicit none
        integer(kind=4), intent(in)    :: d
        integer(kind=4), intent(in)    :: n, p
        real   (kind=8), intent(in)    :: U(0:n+p+1)
        real   (kind=8), intent(inout) :: Pw(d,0:n)
        integer(kind=4), intent(in)    :: k, s
        integer(kind=4) :: r, i, j, idx
        real   (kind=8) :: uu, alpha, Rw(d,0:p), Qw(d,0:2*p)
        if (s >= p) return
        uu = U(k)
        r = p-s
        Qw(:,0) = Pw(:,k-p)
        Rw(:,0:p-s) = Pw(:,k-p:k-s)
        do j = 1, r
           idx = k-p+j
           do i = 0, p-j-s
              alpha = (uu-U(idx+i))/(U(i+k+1)-U(idx+i))
              Rw(:,i) = alpha*Rw(:,i+1)+(1-alpha)*Rw(:,i)
           end do
           Qw(:,j) = Rw(:,0)
           Qw(:,p-j-s+r) = Rw(:,p-j-s)
        end do
        if (k == p) then ! left end
           Pw(:,0:r-1) = Qw(:,r:r+r-1)
        else             ! right end
           Pw(:,n-r+1:n) = Qw(:,p-r:p-1)
        end if
      end subroutine KntIns
  end subroutine ClampKnot
  ! .......................................................

  ! .......................................................
  !> @brief    unclampes a B-spline curve 
  !>
  !> @param[in] d manifold dimension for the control points  
  !> @param[in] n number of control points 
  !> @param[in] p spline degree 
  !> @param[in] U Initial Knot vector 
  !> @param[in] Pw Initial Control points  
  !> @param[in] l apply the algorithm on the left 
  !> @param[in] r apply the algorithm on the right 
  subroutine UnclampKnot(d,n,p,U,Pw,l,r)
    implicit none
    integer(kind=4), intent(in)    :: d
    integer(kind=4), intent(in)    :: n, p
    real   (kind=8), intent(inout) :: U(0:n+p+1)
    real   (kind=8), intent(inout) :: Pw(d,0:n)
    logical(kind=4), intent(in)    :: l, r
    integer(kind=4) :: i, j, k
    real   (kind=8) :: alpha
    if (l) then ! Unclamp at left end
       do i = 0, p-2
          U(p-i-1) = U(p-i) - (U(n-i+1)-U(n-i))
          k = p-1
          do j = i, 0, -1
             alpha = (U(p)-U(k))/(U(p+j+1)-U(k))
             Pw(:,j) = (Pw(:,j)-alpha*Pw(:,j+1))/(1-alpha)
             k = k-1
          end do
       end do
       U(0) = U(1) - (U(n-p+2)-U(n-p+1)) ! Set first knot
    end if
    if (r) then ! Unclamp at right end
       do i = 0, p-2
          U(n+i+2) = U(n+i+1) + (U(p+i+1)-U(p+i))
          do j = i, 0, -1
             alpha = (U(n+1)-U(n-j))/(U(n-j+i+2)-U(n-j))
             Pw(:,n-j) = (Pw(:,n-j)-(1-alpha)*Pw(:,n-j-1))/alpha
          end do
       end do
       U(n+p+1) = U(n+p) + (U(2*p)-U(2*p-1)) ! Set last knot
    end if
  end subroutine UnclampKnot
  ! .......................................................

  ! .......................................................
  !> @brief     inserts all elements of X into the knot vector 
  !>
  !> @param[in] d     manifold dimension for the control points  
  !> @param[in] n     number of control points 
  !> @param[in] p     spline degree 
  !> @param[in] U     Initial Knot vector 
  !> @param[in] Pw    Initial Control points  
  !> @param[in] X     knots to insert 
  !> @param[in] r     size of X 
  !> @param[in] Ubar  Final Knot vector 
  !> @param[in] Qw    Final Control points  
  subroutine RefineKnotVector(d,n,p,U,Pw,r,X,Ubar,Qw)
    implicit none
    integer(kind=4), intent(in)  :: d
    integer(kind=4), intent(in)  :: n, p
    real   (kind=8), intent(in)  :: U(0:n+p+1)
    real   (kind=8), intent(in)  :: Pw(d,0:n)
    integer(kind=4), intent(in)  :: r
    real   (kind=8), intent(in)  :: X(0:r)
    real   (kind=8), intent(out) :: Ubar(0:n+r+1+p+1)
    real   (kind=8), intent(out) :: Qw(d,0:n+r+1)
    integer(kind=4) :: m, a, b
    integer(kind=4) :: i, j, k, l
    integer(kind=4) :: idx
    real   (kind=8) :: alpha
    if (r < 0) then
       Ubar = U
       Qw = Pw
       return
    end if
    m = n + p + 1
    a = FindSpan(n,p,X(0),U)
    b = FindSpan(n,p,X(r),U)
    b = b + 1
    forall (j = 0:a-p) Qw(:,j)     = Pw(:,j)
    forall (j = b-1:n) Qw(:,j+r+1) = Pw(:,j)
    forall (j =   0:a) Ubar(j)     = U(j)
    forall (j = b+p:m) Ubar(j+r+1) = U(j)
    i = b + p - 1
    k = b + p + r
    do j = r, 0, -1
       do while (X(j) <= U(i) .and. i > a)
          Qw(:,k-p-1) = Pw(:,i-p-1)
          Ubar(k) = U(i)
          k = k - 1
          i = i - 1
       end do
       Qw(:,k-p-1) = Qw(:,k-p)
       do l = 1, p
          idx = k - p + l
          alpha = Ubar(k+l) - X(j)
          if (abs(alpha) == 0.0) then
             Qw(:,idx-1) = Qw(:,idx)
          else
             alpha = alpha / (Ubar(k+l) - U(i-p+l))
             Qw(:,idx-1) = alpha*Qw(:,idx-1) + (1-alpha)*Qw(:,idx)
          end if
       end do
       Ubar(k) = X(j)
       k = k-1
    end do
  end subroutine RefineKnotVector
  ! .......................................................

  ! .......................................................
  !> @brief     elevate the spline degree by t 
  !>
  !> @param[in] d manifold dimension for the control points  
  !> @param[in] n number of control points 
  !> @param[in] p spline degree 
  !> @param[in] U Initial Knot vector 
  !> @param[in] Pw Initial Control points  
  !> @param[in] t number of degree elevation 
  !> @param[in] nh equal to n + t *nrb_internal_knots 
  !> @param[in] Uh Final Knot vector 
  !> @param[in] Qw Final Control points  
  subroutine DegreeElevate(d,n,p,U,Pw,t,nh,Uh,Qw)
    implicit none
    integer(kind=4), intent(in)  :: d
    integer(kind=4), intent(in)  :: n, p
    real   (kind=8), intent(in)  :: U(0:n+p+1)
    real   (kind=8), intent(in)  :: Pw(d,0:n)
    integer(kind=4), intent(in)  :: t
    integer(kind=4), intent(in)  :: nh
    real   (kind=8), intent(out) :: Uh(0:nh+p+t+1)
    real   (kind=8), intent(out) :: Qw(d,0:nh)

    integer(kind=4) :: i, j, k, kj, tr, a, b
    integer(kind=4) :: m, ph, kind, cind, first, last
    integer(kind=4) :: r, oldr, s, mul, lbz, rbz

    real   (kind=8) :: bezalfs(0:p+t,0:p)
    real   (kind=8) :: bpts(d,0:p), ebpts(d,0:p+t), nextbpts(d,0:p-2)
    real   (kind=8) :: alfs(0:p-2), ua, ub, alf, bet, gam, den
    if (t < 1) then
       Uh = U
       Qw = Pw
       return
    end if
    m = n + p + 1
    ph = p + t
    ! Bezier coefficients
    bezalfs(0,0)  = 1.0
    bezalfs(ph,p) = 1.0
    do i = 1, ph/2
       do j = max(0,i-t), min(p,i)
          bezalfs(i,j) = Bin(p,j)*Bin(t,i-j)*(1.0d+0/Bin(ph,i))
       end do
    end do
    do i = ph/2+1, ph-1
       do j = max(0,i-t), min(p,i)
          bezalfs(i,j) = bezalfs(ph-i,p-j)
       end do
    end do
    kind = ph+1
    cind = 1
    r = -1
    a = p
    b = p+1
    ua = U(a)
    Uh(0:ph) = ua
    Qw(:,0) = Pw(:,0)
    bpts = Pw(:,0:p)
    do while (b < m)
       i = b
       do while (b < m)
          if (U(b) /= U(b+1)) exit
          b = b + 1
       end do
       mul = b - i + 1
       oldr = r
       r = p - mul
       ub = U(b)
       if (oldr > 0) then
          lbz = (oldr+2)/2
       else
          lbz = 1
       end if
       if (r > 0) then
          rbz = ph - (r+1)/2
       else
          rbz = ph
       end if
       ! insert knots
       if (r > 0) then
          do k = p, mul+1, -1
             alfs(k-mul-1) = (ub-ua)/(U(a+k)-ua)
          end do
          do j = 1, r
             s = mul + j
             do k = p, s, -1
                bpts(:,k) = alfs(k-s)  * bpts(:,k) + &
                       (1.0-alfs(k-s)) * bpts(:,k-1)
             end do
             nextbpts(:,r-j) = bpts(:,p)
          end do
       end if
       ! degree elevate
       do i = lbz, ph
          ebpts(:,i) = 0.0
          do j = max(0,i-t), min(p,i)
             ebpts(:,i) = ebpts(:,i) + bezalfs(i,j)*bpts(:,j)
          end do
       end do
       ! remove knots
       if (oldr > 1) then
          first = kind-2
          last = kind
          den = ub-ua
          bet = (ub-Uh(kind-1))/den
          do tr = 1, oldr-1
             i = first
             j = last
             kj = j-kind+1
             do while (j-i > tr)
                if (i < cind) then
                   alf = (ub-Uh(i))/(ua-Uh(i))
                   Qw(:,i) = alf*Qw(:,i) + (1.0-alf)*alf*Qw(:,i-1)
                end if
                if (j >= lbz) then
                   if (j-tr <= kind-ph+oldr) then
                      gam = (ub-Uh(j-tr))/den
                      ebpts(:,kj) = gam*ebpts(:,kj) + (1.0-gam)*ebpts(:,kj+1)
                   else
                      ebpts(:,kj) = bet*ebpts(:,kj) + (1.0-bet)*ebpts(:,kj+1)
                   end if
                end if
                i = i+1
                j = j-1
                kj = kj-1
             end do
             first = first-1
             last = last+1
          end do
       end if
       !
       if (a /= p) then
          do i = 0, ph-oldr-1
             Uh(kind) = ua
             kind = kind+1
          end do
       end if
       do j = lbz, rbz
          Qw(:, cind) = ebpts(:,j)
          cind = cind+1
       end do
       !
       if (b < m) then
          bpts(:,0:r-1) = nextbpts(:,0:r-1)
          bpts(:,r:p) = Pw(:,b-p+r:b)
          a = b
          b = b+1
          ua = ub
       else
          Uh(kind:kind+ph) = ub
       end if
    end do
  contains
    pure function Bin(n,k) result (C)
      implicit none
      integer(kind=4), intent(in) :: n, k
      integer(kind=4) :: i, C
      C = 1
      do i = 0, min(k,n-k) - 1
         C = C * (n - i)
         C = C / (i + 1)
      end do
    end function Bin
  end subroutine DegreeElevate
  ! .......................................................

end module mod_pyccelext_math_external_bspline






! .......................................................
!> @brief 
!> Module for Splines 
!> @details
!> mostly wrappers for mod_pyccelext_math_external_bspline 
!> the user should use this module and not mod_pyccelext_math_external_bspline
module mod_pyccelext_math_external_bsp
contains

  ! .......................................................
  !> @brief     Determine non zero elements 
  !>
  !> @param[in] n number of control points 
  !> @param[in] p spline degree 
  !> @param[in] U Knot vector 
  !> @param[in] n_elements number of non-zero elements 
  !> @param[in] grid the corresponding grid
  subroutine FindNonZeroElements(p,m,U,n_elements,grid)
    use mod_pyccelext_math_external_bspline, Find => FindNonZeroElements_bspline
    implicit none
    integer(kind=4), intent(in)  :: p, m
    real   (kind=8), intent(in)  :: U(0:m)
    integer(kind=4), intent(inout) :: n_elements
    real   (kind=8), intent(inout) :: grid(0:m)

    call Find(m-(p+1),p,U,n_elements,grid) 
  end subroutine FindNonZeroElements
  ! .......................................................

  ! .......................................................
  !> @brief     Determine the knot span index 
  !>
  !> @param[in] n number of control points 
  !> @param[in] p spline degree 
  !> @param[in] U Knot vector 
  !> @param[in] uu given knot 
  !> @param[out] span the span index 
  subroutine FindSpan(p,m,U,uu,span)
    use mod_pyccelext_math_external_bspline, FindS => FindSpan
    implicit none
    integer(kind=4), intent(in)  :: p, m
    real   (kind=8), intent(in)  :: U(0:m), uu
    integer(kind=4), intent(out) :: span
    span = FindS(m-(p+1),p,uu,U)
  end subroutine FindSpan
  ! .......................................................

  ! .......................................................
  !> @brief     Determine the multiplicity of a given knot starting from a span
  !>
  !> @param[in]    p     spline degree 
  !> @param[in]    m     number of control points - 1
  !> @param[in]    U     Knot vector 
  !> @param[in]    uu    given knot 
  !> @param[inout] span  the span index 
  !> @param[out]   mult  multiplicity of the given knot
  subroutine FindMult(p,m,U,uu,span,mult)
    use mod_pyccelext_math_external_bspline, FindM => FindMult
    implicit none
    integer(kind=4), intent(in)  :: p, m
    real   (kind=8), intent(in)  :: U(0:m), uu
    integer(kind=4), intent(inout)  :: span
    integer(kind=4), intent(out) :: mult

    if (span < 0) then
       span = FindSpan(m-(p+1),p,uu,U)
    end if
    mult = FindM(span,uu,p,U)
  end subroutine FindMult
  ! .......................................................

  ! .......................................................
  !> @brief     Determine the multiplicity of a given knot
  !>
  !> @param[in]    p     spline degree 
  !> @param[in]    m     number of control points - 1
  !> @param[in]    U     Knot vector 
  !> @param[in]    uu    given knot 
  !> @param[out]   mult  multiplicity of the given knot
  subroutine FindSpanMult(p,m,U,uu,k,s)
    use mod_pyccelext_math_external_bspline, FindSM => FindSpanMult
    implicit none
    integer(kind=4), intent(in)  :: p, m
    real   (kind=8), intent(in)  :: U(0:m), uu
    integer(kind=4), intent(out) :: k, s
    call FindSM(m-(p+1),p,uu,U,k,s)
  end subroutine FindSpanMult
  ! .......................................................

  ! .......................................................
  !> @brief     evaluates all b-splines at a given site 
  !>
  !> @param[in]    p     spline degree 
  !> @param[in]    m     number of control points - 1
  !> @param[in]    U     Knot vector 
  !> @param[in]    uu    given knot 
  !> @param[inout] span  the span index 
  !> @param[out]   N     the p+1 non vanishing b-splines at uu 
  subroutine EvalBasisFuns(p,m,U,uu,span,N)
    use mod_pyccelext_math_external_bspline
    implicit none
    integer(kind=4), intent(in) :: p, m
    integer(kind=4), intent(inout) :: span
    real   (kind=8), intent(in) :: U(0:m), uu
    real   (kind=8), intent(out):: N(0:p)

    if (span < 0) then
       span = FindSpan(m-(p+1),p,uu,U)
    end if
    call BasisFuns(span,uu,p,U,N)
  end subroutine EvalBasisFuns
  ! .......................................................

  ! .......................................................
  !> @brief     evaluates all b-splines and their derivatives at a given site 
  !>
  !> @param[in]    p     spline degree 
  !> @param[in]    m     number of control points - 1
  !> @param[in]    U     Knot vector 
  !> @param[in]    uu    given knot 
  !> @param[inout] span  the span index 
  !> @param[out]   dN    the p+1 non vanishing b-splines and their derivatives at uu 
  subroutine EvalBasisFunsDers(p,m,U,uu,d,span,dN)
    use mod_pyccelext_math_external_bspline
    implicit none
    integer(kind=4), intent(in) :: p, m, d
    integer(kind=4), intent(inout) :: span
    real   (kind=8), intent(in) :: U(0:m), uu
    real   (kind=8), intent(out):: dN(0:p,0:d)

    if (span < 0) then
       span = FindSpan(m-(p+1),p,uu,U)
    end if
    call DersBasisFuns(span,uu,p,d,U,dN)
  end subroutine EvalBasisFunsDers
  ! .......................................................

  ! .......................................................
  !> @brief     evaluates all b-splines and their derivatives at given sites
  !>
  !> @param[in]    p     spline degree 
  !> @param[in]    m     number of control points - 1
  !> @param[in]    d     number of derivatives
  !> @param[in]    r     size of tau
  !> @param[in]    U     Knot vector 
  !> @param[in]    tau   given knot 
  !> @param[out]   dN    the p+1 non vanishing b-splines and their derivatives at uu 
  subroutine spl_eval_splines_ders(p,m,d,r,U,tau,dN)
    use mod_pyccelext_math_external_bspline
    implicit none
    integer(kind=4), intent(in) :: p, m, d, r
    real   (kind=8), intent(in) :: U(0:m), tau(0:r)
    real   (kind=8), intent(out):: dN(0:p,0:d,0:r)
    ! local
    integer(kind=4) :: span
    integer(kind=4) :: i

    do i = 0, r
      span = -1
      call EvalBasisFunsDers(p,m,U,tau(i),d,span,dN(0:p,0:d,i))
    end do
  end subroutine spl_eval_splines_ders
  ! .......................................................

  ! .......................................................
  !> @brief     Determine the span indices for every knot 
  !>
  !> @param[in]    p     spline degree 
  !> @param[in]    m     number of control points - 1
  !> @param[in]    U     Knot vector 
  !> @param[inout] r     maximum number of knots 
  !> @param[out]   I     span for every knot 
  subroutine SpanIndex(p,m,U,r,I)
    integer(kind=4), intent(in)  :: p, m
    real   (kind=8), intent(in)  :: U(0:m)
    integer(kind=4), intent(in)  :: r
    integer(kind=4), intent(out) :: I(r)
    integer(kind=4) :: k, s
    s = 1
    do k = p, m-(p+1)
       if (U(k) /= U(k+1)) then
          I(s) = k; s = s + 1
          if (s > r) exit
       end if
    end do
  end subroutine SpanIndex
  ! .......................................................

  ! .......................................................
  !> @brief     returns the Greville abscissae 
  !>
  !> @param[in]    p     spline degree 
  !> @param[in]    m     number of control points - 1
  !> @param[in]    U     Knot vector 
  !> @param[out]   X     Greville abscissae 
  subroutine Greville(p,m,U,X)
    implicit none
    integer(kind=4), intent(in)  :: p, m
    real   (kind=8), intent(in)  :: U(0:m)
    real   (kind=8), intent(out) :: X(0:m-(p+1))
    integer(kind=4) :: i
    do i = 0, m-(p+1)
       X(i) = sum(U(i+1:i+p)) / p
    end do
  end subroutine Greville
  ! .......................................................

  ! .......................................................
  !> @brief     inserts the knot uu r times 
  !>
  !> @param[in] d manifold dimension for the control points  
  !> @param[in] n number of control points 
  !> @param[in] p spline degree 
  !> @param[in] U Initial Knot vector 
  !> @param[in] Pw Initial Control points  
  !> @param[in] uu knot to insert 
  !> @param[in] r number of times uu will be inserted
  !> @param[in] V Final Knot vector 
  !> @param[in] Qw Final Control points  
  subroutine InsertKnot(d,n,p,U,Pw,uu,r,V,Qw)
    use mod_pyccelext_math_external_bspline, InsKnt => InsertKnot
    implicit none
    integer(kind=4), intent(in)  :: d
    integer(kind=4), intent(in)  :: n, p
    real   (kind=8), intent(in)  :: U(0:n+p+1)
    real   (kind=8), intent(in)  :: Pw(d,0:n)
    real   (kind=8), intent(in)  :: uu
    integer(kind=4), intent(in)  :: r
    real   (kind=8), intent(out) :: V(0:n+p+1+r)
    real   (kind=8), intent(out) :: Qw(d,0:n+r)
    integer(kind=4) :: k, s
    if (r == 0) then
       V = U; Qw = Pw; return
    end if
    call FindSpanMult(n,p,uu,U,k,s)
    call InsKnt(d,n,p,U,Pw,uu,k,s,r,V,Qw)
  end subroutine InsertKnot
  ! .......................................................

  ! .......................................................
  !> @brief     removes a knot from a B-Splines curve, given a tolerance 
  !>
  !> @param[in]    d      dimension of the manifold 
  !> @param[in]    n      number of control points  - 1
  !> @param[in]    p      spline degree 
  !> @param[in]    U      Knot vector 
  !> @param[in]    Pw     weighted control points 
  !> @param[in]    uu     knot to remove 
  !> @param[in]    r      maximum number of iterations 
  !> @param[out]   t      requiered number of iterations 
  !> @param[out]   V      new Knot vector 
  !> @param[out]   Qw     new control points 
  !> @param[in]    TOL    tolerance for the distance to the control point 
  subroutine RemoveKnot(d,n,p,U,Pw,uu,r,t,V,Qw,TOL)
    use mod_pyccelext_math_external_bspline, RemKnt => RemoveKnot
    implicit none
    integer(kind=4), intent(in)  :: d
    integer(kind=4), intent(in)  :: n, p
    real   (kind=8), intent(in)  :: U(0:n+p+1)
    real   (kind=8), intent(in)  :: Pw(d,0:n)
    real   (kind=8), intent(in)  :: uu
    integer(kind=4), intent(in)  :: r
    integer(kind=4), intent(out) :: t
    real   (kind=8), intent(out) :: V(0:n+p+1)
    real   (kind=8), intent(out) :: Qw(d,0:n)
    real   (kind=8), intent(in)  :: TOL
    integer(kind=4) :: k, s
    t = 0
    V = U
    Qw = Pw
    if (r == 0) return
    if (uu <= U(p)) return
    if (uu >= U(n+1)) return
    call FindSpanMult(n,p,uu,U,k,s)
    call RemKnt(d,n,p,V,Qw,uu,k,s,r,t,TOL)
  end subroutine RemoveKnot
  ! .......................................................

  ! .......................................................
  !> @brief    clampes a B-spline curve 
  !>
  !> @param[in] d manifold dimension for the control points  
  !> @param[in] n number of control points 
  !> @param[in] p spline degree 
  !> @param[in] U Initial Knot vector 
  !> @param[in] Pw Initial Control points  
  !> @param[in] l apply the algorithm on the left 
  !> @param[in] r apply the algorithm on the right 
  !> @param[in] V Final Knot vector 
  !> @param[in] Qw Final Control points  
  subroutine Clamp(d,n,p,U,Pw,l,r,V,Qw)
    use mod_pyccelext_math_external_bspline
    implicit none
    integer(kind=4), intent(in)  :: d
    integer(kind=4), intent(in)  :: n, p
    real   (kind=8), intent(in)  :: U(0:n+p+1)
    real   (kind=8), intent(in)  :: Pw(d,0:n)
    logical(kind=4), intent(in)  :: l, r
    real   (kind=8), intent(out) :: V(0:n+p+1)
    real   (kind=8), intent(out) :: Qw(d,0:n)
    V  = U
    Qw = Pw
    call ClampKnot(d,n,p,V,Qw,l,r)
  end subroutine Clamp
  ! .......................................................

  ! .......................................................
  !> @brief    unclampes a B-spline curve 
  !>
  !> @param[in] d manifold dimension for the control points  
  !> @param[in] n number of control points 
  !> @param[in] p spline degree 
  !> @param[in] U Initial Knot vector 
  !> @param[in] Pw Initial Control points  
  !> @param[in] l apply the algorithm on the left 
  !> @param[in] r apply the algorithm on the right 
  !> @param[in] V Final Knot vector 
  !> @param[in] Qw Final Control points  
  subroutine Unclamp(d,n,p,U,Pw,l,r,V,Qw)
    use mod_pyccelext_math_external_bspline
    implicit none
    integer(kind=4), intent(in)  :: d
    integer(kind=4), intent(in)  :: n, p
    real   (kind=8), intent(in)  :: U(0:n+p+1)
    real   (kind=8), intent(in)  :: Pw(d,0:n)
    logical(kind=4), intent(in)  :: l, r
    real   (kind=8), intent(out) :: V(0:n+p+1)
    real   (kind=8), intent(out) :: Qw(d,0:n)
    V  = U
    Qw = Pw
    call UnclampKnot(d,n,p,V,Qw,l,r)
  end subroutine Unclamp
  ! .......................................................

  ! .......................................................
  !> @brief     inserts all elements of X into the knot vector 
  !>
  !> @param[in] d     manifold dimension for the control points  
  !> @param[in] n     number of control points 
  !> @param[in] p     spline degree 
  !> @param[in] U     Initial Knot vector 
  !> @param[in] Pw    Initial Control points  
  !> @param[in] X     knots to insert 
  !> @param[in] r     size of X 
  !> @param[in] Ubar  Final Knot vector 
  !> @param[in] Qw    Final Control points  
  subroutine RefineKnotVector(d,n,p,U,Pw,r,X,Ubar,Qw)
    use mod_pyccelext_math_external_bspline, RefKnt => RefineKnotVector
    implicit none
    integer(kind=4), intent(in)  :: d
    integer(kind=4), intent(in)  :: n, p
    real   (kind=8), intent(in)  :: U(0:n+p+1)
    real   (kind=8), intent(in)  :: Pw(d,0:n)
    integer(kind=4), intent(in)  :: r
    real   (kind=8), intent(in)  :: X(0:r)
    real   (kind=8), intent(out) :: Ubar(0:n+r+1+p+1)
    real   (kind=8), intent(out) :: Qw(d,0:n+r+1)
    call RefKnt(d,n,p,U,Pw,r,X,Ubar,Qw)
  end subroutine RefineKnotVector
  ! .......................................................

  ! .......................................................
  !> @brief     elevate the spline degree by t 
  !>
  !> @param[in] d manifold dimension for the control points  
  !> @param[in] n number of control points 
  !> @param[in] p spline degree 
  !> @param[in] U Initial Knot vector 
  !> @param[in] Pw Initial Control points  
  !> @param[in] t number of degree elevation 
  !> @param[in] nh equal to n + t *nrb_internal_knots 
  !> @param[in] Uh Final Knot vector 
  !> @param[in] Qw Final Control points  
  subroutine DegreeElevate(d,n,p,U,Pw,t,nh,Uh,Qw)
    use mod_pyccelext_math_external_bspline, DegElev => DegreeElevate
    implicit none
    integer(kind=4), intent(in)  :: d
    integer(kind=4), intent(in)  :: n, p
    real   (kind=8), intent(in)  :: U(0:n+p+1)
    real   (kind=8), intent(in)  :: Pw(d,0:n)
    integer(kind=4), intent(in)  :: t
    integer(kind=4), intent(in)  :: nh
    real   (kind=8), intent(out) :: Uh(0:nh+p+t+1)
    real   (kind=8), intent(out) :: Qw(d,0:nh)
    call DegElev(d,n,p,U,Pw,t,nh,Uh,Qw)
  end subroutine DegreeElevate
  ! .......................................................

  ! .......................................................
  !> @brief     extracts a B-Spline curve at the knot x 
  !>
  !> @param[in]    d             dimension of the manifold 
  !> @param[in]    n             number of control points  - 1
  !> @param[in]    p             spline degree 
  !> @param[in]    U             Knot vector 
  !> @param[in]    Pw            weighted control points 
  !> @param[in]    x             knot to evaluate at 
  !> @param[inout] Cw            the point on the curve 
  subroutine Extract(d,n,p,U,Pw,x,Cw)
    use mod_pyccelext_math_external_bspline, CornerCut => CurvePntByCornerCut
    implicit none
    integer(kind=4), intent(in)  :: d
    integer(kind=4), intent(in)  :: n, p
    real   (kind=8), intent(in)  :: U(0:n+p+1)
    real   (kind=8), intent(in)  :: Pw(d,0:n)
    real   (kind=8), intent(in)  :: x
    real   (kind=8), intent(out) :: Cw(d)
    call CornerCut(d,n,p,U,Pw,x,Cw)
  end subroutine Extract
  ! .......................................................

  ! .......................................................
  !> @brief     elevate the spline at X 
  !>
  !> @param[in] d manifold dimension for the control points  
  !> @param[in] n number of control points 
  !> @param[in] p spline degree 
  !> @param[in] U Initial Knot vector 
  !> @param[in] Q Initial Control points  
  !> @param[in] r dimension of X - 1 
  !> @param[in] X the positions on wich evaluation is done  
  !> @param[out] Cw Values  
  subroutine Evaluate1(d,n,p,U,Q,weights,r,X,Cw)
    use mod_pyccelext_math_external_bspline
    implicit none
    integer(kind=4), intent(in)  :: d
    integer(kind=4), intent(in)  :: n, p
    real   (kind=8), intent(in)  :: U(0:n+p+1)
    real   (kind=8), intent(in)  :: Q(d,0:n)
    real   (kind=8), intent(in)  :: weights(0:n)
    integer(kind=4), intent(in)  :: r
    real   (kind=8), intent(in)  :: X(0:r)
    real   (kind=8), intent(out) :: Cw(d,0:r)
    integer(kind=4) :: i, j, span
    real   (kind=8) :: basis(0:p), C(d)
    real   (kind=8) :: w 
    !
    do i = 0, r
       span = FindSpan(n,p,X(i),U)
       call BasisFuns(span,X(i),p,U,basis)
       !
       ! compute w = sum wi Ni
       w  = 0.0
       do j = 0, p
          w  = w  + basis(j) * weights(span-p+j)
       end do

       !
       C = 0.0
       do j = 0, p
          C = C + basis(j) * weights(span-p+j) * Q(:,span-p+j)
       end do
       Cw(:,i) = C / w
       !
    end do
    !
  end subroutine Evaluate1
  ! .......................................................

  ! .......................................................
  !> @brief     elevate the spline at X, works with M-splines too 
  !>
  !> @param[in] normalize use M-Splines in the 1st direction  
  !> @param[in] d manifold dimension for the control points  
  !> @param[in] n number of control points 
  !> @param[in] p spline degree 
  !> @param[in] U Initial Knot vector 
  !> @param[in] Q Initial Control points  
  !> @param[in] r dimension of X - 1 
  !> @param[in] X the positions on wich evaluation is done  
  !> @param[out] Cw Values  
  subroutine EvaluateNormal1(normalize,d,n,p,U,Q,weights,r,X,Cw)
    use mod_pyccelext_math_external_bspline
    implicit none
    logical,         intent(in)  :: normalize
    integer(kind=4), intent(in)  :: d
    integer(kind=4), intent(in)  :: n, p
    real   (kind=8), intent(in)  :: U(0:n+p+1)
    real   (kind=8), intent(in)  :: Q(d,0:n)
    real   (kind=8), intent(in)  :: weights(0:n)
    integer(kind=4), intent(in)  :: r
    real   (kind=8), intent(in)  :: X(0:r)
    real   (kind=8), intent(out) :: Cw(d,0:r)
    integer(kind=4) :: i, j, span, o
    real   (kind=8) :: basis(0:p), C(d)
    real   (kind=8) :: w 
    real   (kind=8) :: x_scale 
    !
    do i = 0, r
       span = FindSpan(n,p,X(i),U)
       call BasisFuns(span,X(i),p,U,basis)
       !

       if (normalize) then
          o = span - p 
          do j = 0, p 
            x_scale =   ( p + 1) &
                    & / ( U(o+j + p + 1) &
                    &   - U(o+j) )
           
            basis(j) = basis(j) * x_scale
          end do
       end if

       !
       C = 0.0
       do j = 0, p
          C = C + basis(j) * weights(span-p+j) * Q(:,span-p+j)
       end do
       Cw(:,i) = C 
       !
    end do
    !
  end subroutine EvaluateNormal1
  ! .......................................................

  ! .......................................................
  !> @brief     elevate the spline at X 
  !>
  !> @param[in] nderiv number of derivatives 
  !> @param[in] N corresponding number of partial derivatives
  !> @param[in] rationalize true if rational B-Splines are to be used
  !> @param[in] d manifold dimension for the control points  
  !> @param[in] nx number of control points 
  !> @param[in] px spline degree 
  !> @param[in] U Initial Knot vector 
  !> @param[in] Q Initial Control points  
  !> @param[in] rx dimension of X - 1 
  !> @param[in] X the positions on wich evaluation is done  
  !> @param[out] Cw Values  
  subroutine EvaluateDeriv1(nderiv,N,d,nx,px,U,Q,weights,rx,X,Cw)
    use mod_pyccelext_math_external_bspline
    implicit none
    integer(kind=4), intent(in)  :: nderiv
    integer(kind=4), intent(in)  :: N   
    integer(kind=4), intent(in)  :: d
    integer(kind=4), intent(in)  :: nx, px
    real   (kind=8), intent(in)  :: U(0:nx+px+1)
    real   (kind=8), intent(in)  :: Q(d,0:nx)
    real   (kind=8), intent(in)  :: weights(0:nx)
    integer(kind=4), intent(in)  :: rx
    real   (kind=8), intent(in)  :: X(0:rx)
    real   (kind=8), intent(out) :: Cw(0:N,d,0:rx)
    integer(kind=4) :: i, j, span, deriv
    real   (kind=8) :: dbasis(0:px,0:nderiv), C(d), w(0:nderiv)
    real   (kind=8) :: Rdbasis(0:px,0:nderiv)
    real   (kind=8) :: basis(0:px)
    !

    do i = 0, rx
       span = FindSpan(nx,px,X(i),U)
       call DersBasisFuns(span,X(i),px,nderiv,U,dbasis)

       !
       ! compute w = sum wi Ni
       ! and w' = sum wi Ni'
       w  = 0.0
       do j = 0, px
          w  = w  + dbasis(j,:) * weights(span-px+j)
       end do
       ! compute Nurbs
       Rdbasis  = 0.0
       Rdbasis(:,0) = dbasis(:,0) / w(0) 

       if (nderiv >= 1) then
          Rdbasis(:,1) = dbasis(:,1) / w(0) - dbasis(:,0) * w(1) / w(0)**2   
       end if

       if (nderiv>=2) then
          Rdbasis(:,2) = dbasis(:,2) / w(0)               &
                     & - 2 * dbasis(:,1) * w(1) / w(0)**2 &
                     & - dbasis(:,0) * w(2) / w(0)**2     &
                     & + 2 * dbasis(:,0) * w(1)**2 / w(0)**3
       end if

       do deriv = 0, N
          C = 0.0
          do j = 0, px
             C = C + Rdbasis(j,deriv) * weights(span-px+j) * Q(:,span-px+j)
          end do
          Cw(deriv,:,i) = C
       end do
       !
    end do
    !
  end subroutine EvaluateDeriv1
  ! .......................................................

  ! .......................................................
  !> @brief     elevate the spline at X 
  !>
  !> @param[in] d manifold dimension for the control points  
  !> @param[in] nx number of control points 
  !> @param[in] px spline degree 
  !> @param[in] Ux Initial Knot vector 
  !> @param[in] ny number of control points 
  !> @param[in] py spline degree 
  !> @param[in] Uy Initial Knot vector 
  !> @param[in] Q Initial Control points  
  !> @param[in] rx dimension of X - 1 
  !> @param[in] X the positions on wich evaluation is done  
  !> @param[in] ry dimension of Y - 1 
  !> @param[in] Y the positions on wich evaluation is done  
  !> @param[out] Cw Values  
  subroutine Evaluate2(d,nx,px,Ux,ny,py,Uy,Q,weights,rx,X,ry,Y,Cw)
    use mod_pyccelext_math_external_bspline
    implicit none
    integer(kind=4), intent(in)  :: d
    integer(kind=4), intent(in)  :: nx, ny
    integer(kind=4), intent(in)  :: px, py
    integer(kind=4), intent(in)  :: rx, ry
    real   (kind=8), intent(in)  :: Ux(0:nx+px+1)
    real   (kind=8), intent(in)  :: Uy(0:ny+py+1)
    real   (kind=8), intent(in)  :: Q(d,0:nx,0:ny)
    real   (kind=8), intent(in)  :: weights(0:nx,0:ny)
    real   (kind=8), intent(in)  :: X(0:rx), Y(0:ry)
    real   (kind=8), intent(out) :: Cw(d,0:rx,0:ry)
    integer(kind=4) :: ix, jx, iy, jy, ox, oy
    integer(kind=4) :: spanx(0:rx), spany(0:ry)
    real   (kind=8) :: basisx(0:px,0:rx), basisy(0:py,0:ry)
    real   (kind=8) :: M, C(d)
    real   (kind=8) :: w 

    !
    do ix = 0, rx
       spanx(ix) = FindSpan(nx,px,X(ix),Ux)
       call BasisFuns(spanx(ix),X(ix),px,Ux,basisx(:,ix))
    end do
    do iy = 0, ry
       spany(iy) = FindSpan(ny,py,Y(iy),Uy)
       call BasisFuns(spany(iy),Y(iy),py,Uy,basisy(:,iy))
    end do
    !
    do iy = 0, ry
      oy = spany(iy) - py
      do ix = 0, rx
        ox = spanx(ix) - px
        ! ---
        w = 0.0
        do jy = 0, py
          do jx = 0, px
             M = basisx(jx,ix) * basisy(jy,iy)
             w = w + M * weights(ox+jx,oy+jy)
          end do
        end do
        ! ---
        ! ---
        C = 0.0
        do jy = 0, py
          do jx = 0, px
             M = basisx(jx,ix) * basisy(jy,iy)
             C = C + M * weights(ox+jx,oy+jy) * Q(:,ox+jx,oy+jy)
          end do
        end do
        Cw(:,ix,iy) = C / w
        ! ---
      end do
    end do
    !
  end subroutine Evaluate2
  ! .......................................................

  ! .......................................................
  !> @brief     elevate the spline at X, works with M-splines too 
  !>
  !> @param[in] normalize_x use M-Splines in the 1st direction  
  !> @param[in] normalize_y use M-Splines in the 2nd direction  
  !> @param[in] d manifold dimension for the control points  
  !> @param[in] nx number of control points 
  !> @param[in] px spline degree 
  !> @param[in] Ux Initial Knot vector 
  !> @param[in] ny number of control points 
  !> @param[in] py spline degree 
  !> @param[in] Uy Initial Knot vector 
  !> @param[in] Q Initial Control points  
  !> @param[in] rx dimension of X - 1 
  !> @param[in] X the positions on wich evaluation is done  
  !> @param[in] ry dimension of Y - 1 
  !> @param[in] Y the positions on wich evaluation is done  
  !> @param[out] Cw Values  
  subroutine EvaluateNormal2( normalize_x,normalize_y,&
                            & d,nx,px,Ux,ny,py,Uy,Q,weights,rx,X,ry,Y,Cw)
    use mod_pyccelext_math_external_bspline
    implicit none
    logical,         intent(in)  :: normalize_x
    logical,         intent(in)  :: normalize_y
    integer(kind=4), intent(in)  :: d
    integer(kind=4), intent(in)  :: nx, ny
    integer(kind=4), intent(in)  :: px, py
    integer(kind=4), intent(in)  :: rx, ry
    real   (kind=8), intent(in)  :: Ux(0:nx+px+1)
    real   (kind=8), intent(in)  :: Uy(0:ny+py+1)
    real   (kind=8), intent(in)  :: Q(d,0:nx,0:ny)
    real   (kind=8), intent(in)  :: weights(0:nx,0:ny)
    real   (kind=8), intent(in)  :: X(0:rx), Y(0:ry)
    real   (kind=8), intent(out) :: Cw(d,0:rx,0:ry)
    integer(kind=4) :: ix, jx, iy, jy, ox, oy
    integer(kind=4) :: spanx(0:rx), spany(0:ry)
    real   (kind=8) :: basisx(0:px,0:rx), basisy(0:py,0:ry)
    real   (kind=8) :: M, C(d)
    real   (kind=8) :: w 
    real   (kind=8) :: x_scale 
    real   (kind=8) :: y_scale 

    !
    do ix = 0, rx
       spanx(ix) = FindSpan(nx,px,X(ix),Ux)
       call BasisFuns(spanx(ix),X(ix),px,Ux,basisx(:,ix))

       if (normalize_x) then
          ox = spanx(ix) - px 
          do jx = 0, px 
            x_scale =   ( px + 1) &
                    & / ( Ux(ox+jx + px + 1) &
                    &   - Ux(ox+jx) )
           
            basisx(jx,ix) = basisx(jx,ix) * x_scale
          end do
       end if
    end do
    do iy = 0, ry
       spany(iy) = FindSpan(ny,py,Y(iy),Uy)
       call BasisFuns(spany(iy),Y(iy),py,Uy,basisy(:,iy))

       if (normalize_y) then
          oy = spany(iy) - py 
          do jy = 0, py 
            y_scale =   ( py + 1) &
                    & / ( Uy(oy+jy + py + 1) &
                    &   - Uy(oy+jy) )
           
            basisy(jy,iy) = basisy(jy,iy) * y_scale
          end do
       end if
    end do
    !
    do iy = 0, ry
      oy = spany(iy) - py
      do ix = 0, rx
        ox = spanx(ix) - px
        ! ---
        C = 0.0
        do jy = 0, py
          do jx = 0, px
             M = basisx(jx,ix) * basisy(jy,iy)
             C = C + M * Q(:,ox+jx,oy+jy)
          end do
        end do
        Cw(:,ix,iy) = C 
        ! ---
      end do
    end do
    !

  end subroutine EvaluateNormal2
  ! .......................................................

  ! .......................................................
  !> @brief     elevate spline derivatives the spline at X 
  !>
  !> @param[in] nderiv number of derivatives 
  !> @param[in] N corresponding number of partial derivatives
  !> @param[in] rationalize true if rational B-Splines are to be used
  !> @param[in] d manifold dimension for the control points  
  !> @param[in] nx number of control points 
  !> @param[in] px spline degree 
  !> @param[in] Ux Initial Knot vector 
  !> @param[in] ny number of control points 
  !> @param[in] py spline degree 
  !> @param[in] Uy Initial Knot vector 
  !> @param[in] Q Initial Control points  
  !> @param[in] rx dimension of X - 1 
  !> @param[in] X the positions on wich evaluation is done  
  !> @param[in] ry dimension of Y - 1 
  !> @param[in] Y the positions on wich evaluation is done  
  !> @param[out] Cw Values  
  subroutine EvaluateDeriv2(nderiv,N,d,nx,px,Ux,ny,py,Uy,Q,weights,rx,X,ry,Y,Cw)
    use mod_pyccelext_math_external_bspline
    implicit none
    integer(kind=4), intent(in)  :: nderiv
    integer(kind=4), intent(in)  :: N 
    integer(kind=4), intent(in)  :: d
    integer(kind=4), intent(in)  :: nx, ny
    integer(kind=4), intent(in)  :: px, py
    integer(kind=4), intent(in)  :: rx, ry
    real   (kind=8), intent(in)  :: Ux(0:nx+px+1)
    real   (kind=8), intent(in)  :: Uy(0:ny+py+1)
    real   (kind=8), intent(in)  :: Q(d,0:nx,0:ny)
    real   (kind=8), intent(in)  :: weights(0:nx,0:ny)
    real   (kind=8), intent(in)  :: X(0:rx), Y(0:ry)
    real   (kind=8), intent(out) :: Cw(0:N,d,0:rx,0:ry)
    integer(kind=4) :: ix, jx, iy, jy, ox, oy, deriv
    integer(kind=4) :: spanx(0:rx), spany(0:ry)
    real   (kind=8) :: dbasisx(0:px,0:nderiv,0:rx)
    real   (kind=8) :: dbasisy(0:py,0:nderiv,0:ry)
    ! Rdbasis(0) => Rij
    ! Rdbasis(1) => dx Rij
    ! Rdbasis(2) => dy Rij
    real   (kind=8) :: Rdbasis(0:N)  
    real   (kind=8) :: C(0:N,d)
    real   (kind=8) :: weight 
    real   (kind=8) :: M, Mx, My, Mxy, Mxx, Myy
    real   (kind=8) :: w, wx, wy, wxy, wxx, wyy

    Cw = 0.0

    !
    do ix = 0, rx
       spanx(ix) = FindSpan(nx,px,X(ix),Ux)
       call DersBasisFuns(spanx(ix),X(ix),px,nderiv,Ux,dbasisx(:,0:nderiv,ix))
    end do
    do iy = 0, ry
       spany(iy) = FindSpan(ny,py,Y(iy),Uy)
       call DersBasisFuns(spany(iy),Y(iy),py,nderiv,Uy,dbasisy(:,0:nderiv,iy))
    end do

    !
    ! compute 
    ! w   = sum wij Ni   Nj
    ! wx  = sum wij Ni'  Nj
    ! wy  = sum wij Ni   Nj'
    ! wxx = sum wij Ni'' Nj
    ! wxy = sum wij Ni'  Nj'
    ! wyy = sum wij Ni   Nj''
    do iy = 0, ry
    oy = spany(iy) - py
    do ix = 0, rx
    ox = spanx(ix) - px

       ! --- compute w and its Derivatives
       w   = 0.0 ; wx  = 0.0 ; wy  = 0.0
       wxx = 0.0 ; wxy = 0.0 ; wyy = 0.0
       do jy = 0, py
       do jx = 0, px
          weight = weights(ox+jx,oy+jy)

          M   = dbasisx(jx,0,ix) * dbasisy(jy,0,iy)
          w  = w  + M   * weight

          if (nderiv >= 1) then
             Mx  = dbasisx(jx,1,ix) * dbasisy(jy,0,iy)
             My  = dbasisx(jx,0,ix) * dbasisy(jy,1,iy)

             wx = wx + Mx  * weight
             wy = wy + My  * weight
          end if

          if (nderiv >= 2) then
             Mxx = dbasisx(jx,2,ix) * dbasisy(jy,0,iy)
             Mxy = dbasisx(jx,1,ix) * dbasisy(jy,1,iy)
             Myy = dbasisx(jx,0,ix) * dbasisy(jy,2,iy)

             wxx = wxx + Mxx * weight
             wxy = wxy + Mxy * weight
             wyy = wyy + Myy * weight
          end if 
       end do
       end do
       ! ---

       ! compute Nurbs and their derivatives
       C = 0.0     
       do jy = 0, py     
       do jx = 0, px
          M   = dbasisx(jx,0,ix) * dbasisy(jy,0,iy)
          Rdbasis(0) = M / w 

          if (nderiv >= 1) then
             Mx  = dbasisx(jx,1,ix) * dbasisy(jy,0,iy)
             My  = dbasisx(jx,0,ix) * dbasisy(jy,1,iy)

             Rdbasis(1) = Mx / w - M * wx / w**2 
             Rdbasis(2) = My / w - M * wy / w**2 
          end if
       
          if (nderiv >= 2) then
             Mxx = dbasisx(jx,2,ix) * dbasisy(jy,0,iy)
             Mxy = dbasisx(jx,1,ix) * dbasisy(jy,1,iy)
             Myy = dbasisx(jx,0,ix) * dbasisy(jy,2,iy)

             Rdbasis(3) = Mxx / w                 &
                        - 2 * Mx * wx / w**2      &
                        - M * wxx / w**2          &
                        + 2 * M * wx**2 / w**3
          
             Rdbasis(4) = Mxy / w                 &
                        - Mx * wy / w**2          &
                        - My * wx / w**2          &
                        - M * wxy / w**2          &
                        + 2 * M * wx * wy / w**3
          
             Rdbasis(5) = Myy / w                 &
                        - 2 * My * wy / w**2      &
                        - M * wyy / w**2          &
                        + 2 * M * wy**2 / w**3
          end if

          do deriv=0,N
             C(deriv,:) = C(deriv,:) + Rdbasis(deriv) * Q(:,ox+jx,oy+jy) * weights(ox+jx,oy+jy)
          end do
       end do
       end do

       Cw(0:N,1:d,ix,iy) = C(0:N,1:d)
       ! ---

    end do
    end do
    !
  end subroutine EvaluateDeriv2
  ! .......................................................

  ! .......................................................
  !> @brief     evaluate the spline at X 
  !>
  !> @param[in] d manifold dimension for the control points  
  !> @param[in] nx number of control points 
  !> @param[in] px spline degree 
  !> @param[in] Ux Initial Knot vector 
  !> @param[in] ny number of control points 
  !> @param[in] py spline degree 
  !> @param[in] Uy Initial Knot vector 
  !> @param[in] nz number of control points 
  !> @param[in] pz spline degree 
  !> @param[in] Uz Initial Knot vector 
  !> @param[in] Q Initial Control points  
  !> @param[in] rx dimension of X - 1 
  !> @param[in] X the positions on wich evaluation is done  
  !> @param[in] ry dimension of Y - 1 
  !> @param[in] Y the positions on wich evaluation is done  
  !> @param[in] rz dimension of Z - 1 
  !> @param[in] Z the positions on wich evaluation is done  
  !> @param[out] Cw Values  
  subroutine Evaluate3(d,nx,px,Ux,ny,py,Uy,nz,pz,Uz,Q,weights,rx,X,ry,Y,rz,Z,Cw)
    use mod_pyccelext_math_external_bspline
    implicit none
    integer(kind=4), intent(in)  :: d
    integer(kind=4), intent(in)  :: nx, ny, nz
    integer(kind=4), intent(in)  :: px, py, pz
    integer(kind=4), intent(in)  :: rx, ry, rz
    real   (kind=8), intent(in)  :: Ux(0:nx+px+1)
    real   (kind=8), intent(in)  :: Uy(0:ny+py+1)
    real   (kind=8), intent(in)  :: Uz(0:nz+pz+1)
    real   (kind=8), intent(in)  :: Q(d,0:nx,0:ny,0:nz)
    real   (kind=8), intent(in)  :: weights(0:nx,0:ny,0:nz)
    real   (kind=8), intent(in)  :: X(0:rx), Y(0:ry), Z(0:rz)
    real   (kind=8), intent(out) :: Cw(d,0:rx,0:ry,0:rz)
    integer(kind=4) :: ix, jx, iy, jy, iz, jz, ox, oy, oz
    integer(kind=4) :: spanx(0:rx), spany(0:ry), spanz(0:rz)
    real   (kind=8) :: basisx(0:px,0:rx), basisy(0:py,0:ry), basisz(0:pz,0:rz)
    real   (kind=8) :: M, C(d)
    real   (kind=8) :: w 

    !
    do ix = 0, rx
       spanx(ix) = FindSpan(nx,px,X(ix),Ux)
       call BasisFuns(spanx(ix),X(ix),px,Ux,basisx(:,ix))
    end do
    do iy = 0, ry
       spany(iy) = FindSpan(ny,py,Y(iy),Uy)
       call BasisFuns(spany(iy),Y(iy),py,Uy,basisy(:,iy))
    end do
    do iz = 0, rz
       spanz(iz) = FindSpan(nz,pz,Z(iz),Uz)
       call BasisFuns(spanz(iz),Z(iz),pz,Uz,basisz(:,iz))
    end do
    !
    do iz = 0, rz
    oz = spanz(iz) - pz
      do iy = 0, ry
      oy = spany(iy) - py
        do ix = 0, rx
        ox = spanx(ix) - px
        ! ---
        w = 0.0
        do jx = 0, px
           do jy = 0, py
              do jz = 0, pz
                 M = basisx(jx,ix) * basisy(jy,iy) * basisz(jz,iz)
                 w = w + M * weights(ox+jx,oy+jy,oz+jz)
              end do
           end do
        end do
        ! ---
        ! ---
        C = 0.0
        do jx = 0, px
           do jy = 0, py
              do jz = 0, pz
                 M = basisx(jx,ix) * basisy(jy,iy) * basisz(jz,iz)
                 C = C + M * weights(ox+jx,oy+jy,oz+jz) * Q(:,ox+jx,oy+jy,oz+jz)
              end do
           end do
        end do
        Cw(:,ix,iy,iz) = C / w
        ! ---
        end do
      end do
    end do
    !
  end subroutine Evaluate3
  ! .......................................................

  ! .......................................................
  !> @brief     elevate spline derivatives the spline at X 
  !>
  !> @param[in] nderiv number of derivatives 
  !> @param[in] N corresponding number of partial derivatives
  !> @param[in] rationalize true if rational B-Splines are to be used
  !> @param[in] d manifold dimension for the control points  
  !> @param[in] nx number of control points 
  !> @param[in] px spline degree 
  !> @param[in] Ux Initial Knot vector 
  !> @param[in] ny number of control points 
  !> @param[in] py spline degree 
  !> @param[in] Uy Initial Knot vector 
  !> @param[in] nz number of control points 
  !> @param[in] pz spline degree 
  !> @param[in] Uz Initial Knot vector 
  !> @param[in] Q Initial Control points  
  !> @param[in] rx dimension of X - 1 
  !> @param[in] X the positions on wich evaluation is done  
  !> @param[in] ry dimension of Y - 1 
  !> @param[in] Y the positions on wich evaluation is done  
  !> @param[in] rz dimension of Z - 1 
  !> @param[in] Z the positions on wich evaluation is done  
  !> @param[out] Cw Values  
  subroutine EvaluateDeriv3(nderiv,N,d,nx,px,Ux,ny,py,Uy,nz,pz,Uz,Q,weights,rx,X,ry,Y,rz,Z,Cw)
    use mod_pyccelext_math_external_bspline
    implicit none
    integer(kind=4), intent(in)  :: nderiv
    integer(kind=4), intent(in)  :: N 
    integer(kind=4), intent(in)  :: d
    integer(kind=4), intent(in)  :: nx, ny, nz
    integer(kind=4), intent(in)  :: px, py, pz
    integer(kind=4), intent(in)  :: rx, ry, rz
    real   (kind=8), intent(in)  :: Ux(0:nx+px+1)
    real   (kind=8), intent(in)  :: Uy(0:ny+py+1)
    real   (kind=8), intent(in)  :: Uz(0:nz+pz+1)
    real   (kind=8), intent(in)  :: Q(d,0:nx,0:ny,0:nz)
    real   (kind=8), intent(in)  :: weights(0:nx,0:ny,0:nz)
    real   (kind=8), intent(in)  :: X(0:rx), Y(0:ry), Z(0:rz) 
    real   (kind=8), intent(out) :: Cw(0:N,d,0:rx,0:ry,0:rz)
    integer(kind=4) :: ix, jx, iy, jy, iz, jz, ox, oy, oz, deriv
    integer(kind=4) :: spanx(0:rx), spany(0:ry), spanz(0:rz)
    real   (kind=8) :: dbasisx(0:px,0:nderiv,0:rx)
    real   (kind=8) :: dbasisy(0:py,0:nderiv,0:ry)
    real   (kind=8) :: dbasisz(0:pz,0:nderiv,0:rz)
    ! Rdbasis(0) => Rij
    ! Rdbasis(1) => dx Rij
    ! Rdbasis(2) => dy Rij
    real   (kind=8) :: Rdbasis(0:N)  
    real   (kind=8) :: C(0:N,d)
    real   (kind=8) :: M, Mx, My, Mz, Mxy, Myz, Mzx, Mxx, Myy, Mzz
    real   (kind=8) :: w, wx, wy, wz, wxy, wyz, wzx, wxx, wyy, wzz
    real   (kind=8) :: weight 

    Cw = 0.0
    Rdbasis = 0.0

    !
    do ix = 0, rx
       spanx(ix) = FindSpan(nx,px,X(ix),Ux)
       call DersBasisFuns(spanx(ix),X(ix),px,nderiv,Ux,dbasisx(:,0:nderiv,ix))
    end do
    do iy = 0, ry
       spany(iy) = FindSpan(ny,py,Y(iy),Uy)
       call DersBasisFuns(spany(iy),Y(iy),py,nderiv,Uy,dbasisy(:,0:nderiv,iy))
    end do
    do iz = 0, rz
       spanz(iz) = FindSpan(nz,pz,Z(iz),Uz)
       call DersBasisFuns(spanz(iz),Z(iz),pz,nderiv,Uz,dbasisz(:,0:nderiv,iz))
    end do

    !
    ! compute 
    do iz = 0, rz
    oz = spanz(iz) - pz
      do iy = 0, ry
      oy = spany(iy) - py
        do ix = 0, rx
        ox = spanx(ix) - px

         ! --- compute w and its Derivatives
         w   = 0.0
         wx  = 0.0 ; wy  = 0.0 ; wz  = 0.0
         wxx = 0.0 ; wyy = 0.0 ; wzz = 0.0
         wxy = 0.0 ; wyz = 0.0 ; wzx = 0.0
         do jz = 0, pz     
         do jy = 0, py     
         do jx = 0, px
            weight = weights(ox+jx,oy+jy,oz+jz)

            M   = dbasisx(jx,0,ix) * dbasisy(jy,0,iy) * dbasisz(jz,0,iz)
            w  = w  + M   * weight

            if (nderiv >= 1) then
              Mx  = dbasisx(jx,1,ix) * dbasisy(jy,0,iy) * dbasisz(jz,0,iz)
              My  = dbasisx(jx,0,ix) * dbasisy(jy,1,iy) * dbasisz(jz,0,iz) 
              Mz  = dbasisx(jx,0,ix) * dbasisy(jy,0,iy) * dbasisz(jz,1,iz) 

              wx = wx + Mx * weight
              wy = wy + My * weight
              wz = wz + Mz * weight
            end if
         
            if (nderiv >= 2) then
              Mxx = dbasisx(jx,2,ix) * dbasisy(jy,0,iy) * dbasisz(jz,0,iz) 
              Myy = dbasisx(jx,0,ix) * dbasisy(jy,2,iy) * dbasisz(jz,0,iz)
              Mzz = dbasisx(jx,0,ix) * dbasisy(jy,0,iy) * dbasisz(jz,2,iz)

              Mxy = dbasisx(jx,1,ix) * dbasisy(jy,1,iy) * dbasisz(jz,0,iz)
              Myz = dbasisx(jx,0,ix) * dbasisy(jy,1,iy) * dbasisz(jz,1,iz)
              Mzx = dbasisx(jx,1,ix) * dbasisy(jy,0,iy) * dbasisz(jz,1,iz)

              wxx = wxx + Mxx * weight
              wyy = wyy + Myy * weight
              wzz = wzz + Mzz * weight

              wxy = wxy + Mxy * weight
              wyz = wyz + Myz * weight
              wzx = wzx + Mzx * weight
            end if

         end do
         end do
         end do
        ! ---

        ! compute Nurbs and their derivatives
         C = 0.0
         do jz = 0, pz     
         do jy = 0, py     
         do jx = 0, px
            M   = dbasisx(jx,0,ix) * dbasisy(jy,0,iy) * dbasisz(jz,0,iz)
            Rdbasis(0) = M / w

            if (nderiv >= 1) then
              Mx  = dbasisx(jx,1,ix) * dbasisy(jy,0,iy) * dbasisz(jz,0,iz)
              My  = dbasisx(jx,0,ix) * dbasisy(jy,1,iy) * dbasisz(jz,0,iz) 
              Mz  = dbasisx(jx,0,ix) * dbasisy(jy,0,iy) * dbasisz(jz,1,iz) 

              Rdbasis(1) = Mx / w - M * wx / w**2 
              Rdbasis(2) = My / w - M * wy / w**2 
              Rdbasis(3) = Mz / w - M * wz / w**2 
            end if
         
            if (nderiv >= 2) then
              Mxx = dbasisx(jx,2,ix) * dbasisy(jy,0,iy) * dbasisz(jz,0,iz) 
              Myy = dbasisx(jx,0,ix) * dbasisy(jy,2,iy) * dbasisz(jz,0,iz)
              Mzz = dbasisx(jx,0,ix) * dbasisy(jy,0,iy) * dbasisz(jz,2,iz)

              Mxy = dbasisx(jx,1,ix) * dbasisy(jy,1,iy) * dbasisz(jz,0,iz)
              Myz = dbasisx(jx,0,ix) * dbasisy(jy,1,iy) * dbasisz(jz,1,iz)
              Mzx = dbasisx(jx,1,ix) * dbasisy(jy,0,iy) * dbasisz(jz,1,iz)

              Rdbasis(4) = Mxx / w                 &
                         - 2 * Mx * wx / w**2      &
                         - M * wxx / w**2          &
                         + 2 * M * wx**2 / w**3
          
              Rdbasis(5) = Myy / w                 &
                         - 2 * My * wy / w**2      &
                         - M * wyy / w**2          &
                         + 2 * M * wy**2 / w**3

              Rdbasis(6) = Mzz / w                 &
                         - 2 * Mz * wz / w**2      &
                         - M * wzz / w**2          &
                         + 2 * M * wz**2 / w**3
          
              Rdbasis(7) = Mxy / w                 &
                         - Mx * wy / w**2          &
                         - My * wx / w**2          &
                         - M * wxy / w**2          &
                         + 2 * M * wx * wy / w**3
          
              Rdbasis(8) = Myz / w                 &
                         - My * wz / w**2          &
                         - Mz * wy / w**2          &
                         - M * wyz / w**2          &
                         + 2 * M * wy * wz / w**3
          
              Rdbasis(9) = Mzx / w                 &
                         - Mz * wx / w**2          &
                         - Mx * wz / w**2          &
                         - M * wzx / w**2          &
                         + 2 * M * wz * wx / w**3
            end if

            do deriv=0,N
               C(deriv,:) = C(deriv,:) + Rdbasis(deriv) * Q(:,ox+jx,oy+jy,oz+jz) &
                                                      & * weights(ox+jx,oy+jy,oz+jz)
            end do
         end do
         end do
         end do

         Cw(0:N,1:d,ix,iy,iz) = C(0:N,1:d)
        ! ---

        end do
      end do
    end do
    !
  end subroutine EvaluateDeriv3
  ! .......................................................
    
  ! .......................................................
  !> @brief returns pp form coeffs of a uniform quadratic spline
  !> pp_form(i,1:2): pp form on i-th element
  function pp_square() &
       result(pp_form)! todo : name of res
    implicit none
    real(kind=8),dimension(3,3)            :: pp_form
    ! LOCAL
    !> 1st element
    pp_form(1,1:2) =  0.
    pp_form(1,3)   =  1.
    !> 2nd element
    pp_form(2,2)   =  1.
    pp_form(2,3)   = -1.
      
  end function pp_square
  ! .......................................................

  ! .......................................................
  !> @brief returns pp form coeffs of uniform cubic spline
  !> pp_form(i,1:4): pp form on i-th element
  function pp_cubic() &
       result(pp_form)! todo : name of res
    implicit none
    real(kind=8),dimension(4,4)            :: pp_form
    ! LOCAL
    !> 1st element
    pp_form(1,1:3) =  0.
    pp_form(1,4)   =  1./6.
    !> 2nd element
    pp_form(2,1)   =  1./6.
    pp_form(2,2)   =  1./2.
    pp_form(2,3)   =  1./2.
    pp_form(2,4)   = -1./2.
    !> 3rd element
    pp_form(3,1)   =  2./3.
    pp_form(3,2)   =  0.
    pp_form(3,3)   = -1.
    pp_form(3,4)   =  1./2.
    !> 4th element
    pp_form(4,1)   =  1./6.
    pp_form(4,2)   = -1./2.   
    pp_form(4,3)   =  1./2.
    pp_form(4,4)   = -1./6.
    
  end function pp_cubic
  ! .......................................................

!  ! .......................................................
!  !> @brief     computes the refinement matrix corresponding to the insertion of a given knot 
!  !>
!  !> @param[in]    t             knot to be inserted 
!  !> @param[in]    n             number of control points 
!  !> @param[in]    p             spline degree 
!  !> @param[in]    knots         Knot vector 
!  !> @param[out]   mat           refinement matrix 
!  !> @param[out]   knots_new     new Knot vector 
!  subroutine spl_refinement_matrix_one_stage(t, n, p, knots, mat, knots_new)
!  use m_pppack, only : interv 
!  implicit none
!    real(8),               intent(in)    :: t
!    integer,                    intent(in)    :: n
!    integer,                    intent(in)    :: p
!    real(8), dimension(:), intent(in)    :: knots
!    real(8), dimension(:,:), intent(out)    :: mat 
!    real(8), dimension(:), optional, intent(out)    :: knots_new
!    ! local
!    integer :: i 
!    integer :: j
!    integer :: k
!    integer :: i_err
!    real(8) :: alpha
!
!    mat = 0.0d0
!
!    ! ...
!    call interv ( knots, n+p+1, t, k, i_err) 
!    ! ...
!
!    ! ...
!    j = 1
!    call alpha_function(j, k, t, n, p, knots, alpha)
!    mat(j,j) = alpha 
!
!    do j=2, n
!      call alpha_function(j, k, t, n, p, knots, alpha)
!      mat(j,j)   = alpha 
!      mat(j,j-1) = 1.0d0- alpha 
!    end do
!
!    j = n + 1
!    call alpha_function(j, k, t, n, p, knots, alpha)
!    mat(j,j-1) = 1.0d0 - alpha 
!    ! ...
!
!    ! ...
!    if (present(knots_new)) then
!      knots_new = -100000
!      do i = 1, k
!        knots_new(i) = knots(i)
!      end do
!      knots_new(k+1) = t
!      do i = k+1, n+p+1
!        knots_new(i+1) = knots(i)
!      end do
!    end if
!    ! ...
!
!  contains
!    subroutine alpha_function(i, k, t, n, p, knots, alpha)
!    implicit none
!      integer,                    intent(in)    :: i 
!      integer,                    intent(in)    :: k
!      real(8),               intent(in)    :: t
!      integer,                    intent(in)    :: n
!      integer,                    intent(in)    :: p
!      real(8), dimension(:), intent(in)    :: knots
!      real(8),               intent(inout) :: alpha 
!      ! local
!
!      ! ...
!      if (i <= k-p) then
!        alpha = 1.0d0
!      elseif ((k-p < i) .and. (i <= k)) then 
!        alpha = (t - knots(i)) / (knots(i+p) - knots(i))
!      else
!        alpha = 0.0d0
!      end if
!      ! ...
!    end subroutine alpha_function
!
!  end subroutine spl_refinement_matrix_one_stage
!  ! .......................................................
!
!  ! .......................................................
!  !> @brief     computes the refinement matrix corresponding to the insertion of a given list of knots 
!  !>
!  !> @param[in]    ts            array of knots to be inserted 
!  !> @param[in]    n             number of control points 
!  !> @param[in]    p             spline degree 
!  !> @param[in]    knots         Knot vector 
!  !> @param[out]   mat           refinement matrix 
!  subroutine spl_refinement_matrix_multi_stages(ts, n, p, knots, mat)  
!  implicit none
!    real(8), dimension(:),   intent(in)  :: ts
!    integer,                 intent(in)  :: n
!    integer,                 intent(in)  :: p
!    real(8), dimension(:),   intent(in)  :: knots
!    real(8), dimension(:,:), intent(out) :: mat 
!    ! local
!    integer :: i
!    integer :: j 
!    integer :: m 
!    integer :: k 
!    real(8), dimension(:,:), allocatable :: mat_1
!    real(8), dimension(:,:), allocatable :: mat_2
!    real(8), dimension(:,:), allocatable :: mat_stage
!    real(8), dimension(:), allocatable :: knots_1
!    real(8), dimension(:), allocatable :: knots_2
!   
!    m = size(ts,1)
!   
!    allocate(mat_1(n + m, n + m))
!    allocate(mat_2(n + m, n + m))
!    allocate(mat_stage(n + m, n + m))
!   
!    allocate(knots_1(n + p + 1 + m))
!    allocate(knots_2(n + p + 1 + m))
!    
!    ! ... mat is the identity at t=0
!    mat_1 = 0.0d0
!    do i = 1, n
!      mat_1(i,i) = 1.0d0
!    end do
!    ! ...
!   
!    knots_1(1:n+p+1) = knots(1:n+p+1) 
!
!    k = n
!    do i = 1, m
!      call spl_refinement_matrix_one_stage( ts(i), &
!                               & k, &
!                               & p, &
!                               & knots_1, &
!                               & mat_stage, & 
!                               & knots_new=knots_2) 
!   
!      mat_2 = 0.0d0
!      mat_2(1:k+1, 1:n) = matmul(mat_stage(1:k+1, 1:k), mat_1(1:k, 1:n))
!   
!      mat_1(1:k+1, 1:n) = mat_2(1:k+1, 1:n)  
!      
!      k = k + 1
!      knots_1(1:k+p+1) = knots_2(1:k+p+1) 
!    end do
!    mat(1:k, 1:n) = mat_1(1:k, 1:n)  
!
!  end subroutine spl_refinement_matrix_multi_stages
!  ! .......................................................

  ! .......................................................
  !> @brief    Computes the derivative matrix for B-Splines 
  !>
  !> @param[in]  n              number of control points 
  !> @param[in]  p              spline degree 
  !> @param[in]  knots          Knot vector 
  !> @param[out] mat            derivatives matrix 
  !>                            where m depends on the boundary condition
  !> @param[in]  normalize      uses normalized B-Splines [optional] (Default: False) 
  subroutine spl_derivative_matrix(n, p, knots, mat, normalize)
  implicit none
    integer,                 intent(in)  :: n
    integer,                 intent(in)  :: p
    real(8), dimension(:),   intent(in)  :: knots
    real(8), dimension(:,:), intent(out) :: mat 
    logical, optional      , intent(in)  :: normalize
    ! local
    integer :: i
    integer :: j 
    real(8) :: alpha
    logical :: l_normalize

    ! ...
    l_normalize = .false.
    if (present(normalize)) then
      l_normalize = normalize
    end if
    ! ...

    ! ...
    mat = 0.0d0
    ! ...

    ! ...
    i = 1
    mat(i,i)   =  1.0d0 

    if (.not. l_normalize) then
      alpha      = p * 1.0d0 / (knots(i+p+1) - knots(i)) 

      mat(i,i)   =   alpha * mat(i,i)
    end if
    ! ...

    ! ...
    do i = 2, n 
      ! ...
      mat(i,i)   =  1.0d0 
      mat(i-1,i) = -1.0d0 
      ! ...

      ! ...
      if (.not. l_normalize) then
        alpha      = p * 1.0d0 / (knots(i+p+1) - knots(i)) 

        mat(i,i)   =   alpha * mat(i,i)
        mat(i-1,i) = - alpha * mat(i-1,i) 
      end if
      ! ...
    end do
    ! ...

  end subroutine spl_derivative_matrix
  ! .......................................................

  ! .......................................................
  !> @brief    Computes the toeplitz matrix associated to the stiffness-preconditioner symbol 
  !>
  !> @param[in]  p              spline degree 
  !> @param[in]  n_points       number of collocation points 
  !> @param[out] mat            mat is a dense matrix of size (n_points, n_points) 
  !>                            where m depends on the boundary condition
  subroutine spl_compute_symbol_stiffness(p, n_points, mat)
  use mod_pyccelext_math_external_bspline, finds => findspan
  implicit none
    integer,                 intent(in)  :: p
    integer,                 intent(in)  :: n_points
    real(8), dimension(:,:), intent(out) :: mat 
    ! local
    integer :: i
    integer :: j
    integer :: span
    integer :: p_new
    integer :: n
    real(8) :: x
    real(8), dimension(:), allocatable :: batx
    real(8), dimension(:), allocatable :: knots

    ! ...
    p_new = 2*p - 1
    n     = 2*p_new + 1
    ! ...

    ! ...
    allocate(batx(p_new+1))
    allocate(knots(p_new+n+1))
    ! ...

    ! ...
    knots(1) = -float(p_new)
    do i = 2, p_new+n+1
      knots(i) = knots(i-1) + 1.0d0
    enddo
    ! ...

    ! ...
    ! TODO to fix. we are rewriting on the same array
    do j = 0, p_new
      x = float(j)
      span = finds(n-1,p_new,x,knots)
      call evalbasisfuns(p_new,n,knots,x,span,batx)
    end do
    ! ...
       
    ! ...
    mat = 0.0d0
    do i = 1, n_points
      do j = 1, n_points
        if ((abs(i-j) .le. p) .and. ((p-i+j) .ne. 0)) then
          mat(i,j) = batx(p-i+j)
        endif
      enddo
    enddo
    ! ...
    
    ! ...
    deallocate(batx)
    deallocate(knots)
    ! ...

  end subroutine spl_compute_symbol_stiffness 
  ! .......................................................

  ! .......................................................
  !> @brief    Computes collocation matrix 
  !>
  !> @param[in]  n              number of control points 
  !> @param[in]  p              spline degree 
  !> @param[in]  knots          Knot vector 
  !> @param[in]  arr_x          array of sites for evaluation 
  !> @param[out] mat            mat is a dense matrix of size (n_points, n_points) 
  !>                            where m depends on the boundary condition
  subroutine spl_collocation_matrix(n, p, knots, arr_x, mat)
  use mod_pyccelext_math_external_bspline, finds => findspan
  implicit none
    integer,                 intent(in)  :: n
    integer,                 intent(in)  :: p
    real(8), dimension(:),   intent(in)  :: knots
    real(8), dimension(:),   intent(in)  :: arr_x 
    real(8), dimension(:,:), intent(out) :: mat 
    ! local
    integer :: i
    integer :: j
    integer :: span
    integer :: n_points
    real(8) :: x
    real(8), dimension(:,:), allocatable :: batx
    integer, dimension(:), allocatable :: spans

    ! ...
    n_points = size(arr_x, 1)
    ! ...

    ! ...
    allocate(batx(p+1,n_points))
    allocate(spans(n_points))
    ! ...

    ! ...
    do i = 1, n_points
      x = arr_x(i) 
      span = finds(n-1, p, x, knots)
      spans(i) = span
      call BasisFuns(span, x, p, knots, batx(:,i))
    end do
    ! ...
       
    ! ...
    mat = 0.0d0
    do i = 1, n_points
      span = spans(i)
      do j = 0, p
        mat(i,span-p+j+1) = batx(j+1,i)
      enddo
    enddo
    ! ...

    ! ...
    deallocate(spans)
    deallocate(batx)
    ! ...

  end subroutine spl_collocation_matrix 
  ! .......................................................

  ! .......................................................
  !> @brief    Computes collocation matrix using periodic bc.
  !>           mat must be allocatable. we allocate its memory inside the subroutine
  !>
  !> @param[in]  r         spline space regularity at extremities 
  !> @param[in]  n         number of control points 
  !> @param[in]  p         spline degree 
  !> @param[in]  knots     Knot vector 
  !> @param[in]  arr_x     array of sites for evaluation 
  !> @param[out] mat       mat is a dense matrix of size (n_points, n_points) 
  !>                       where m depends on the boundary condition
  subroutine spl_collocation_periodic_matrix(r, n, p, knots, arr_x, mat)
  use mod_pyccelext_math_external_bspline, finds => findspan
  implicit none
    integer,                 intent(in)  :: r 
    integer,                 intent(in)  :: n
    integer,                 intent(in)  :: p
    real(8), dimension(:),   intent(in)  :: knots
    real(8), dimension(:),   intent(in)  :: arr_x 
    real(8), dimension(:,:), intent(out) :: mat 
    ! local
    integer :: i
    integer :: j
    integer :: k 
    integer :: span
    integer :: n_points
    integer :: nu
    real(8) :: x
    real(8), dimension(:,:), allocatable :: batx
    integer, dimension(:), allocatable :: spans

    ! ...
    n_points = size(arr_x, 1)
    nu = r + 1
    ! ...

    ! ...
!    allocate(mat(n_points, n-nu))
    allocate(batx(p+1,n_points))
    allocate(spans(n_points))
    ! ...

    ! ...
    do i = 1, n_points
      x = arr_x(i) 
      span = finds(n-1, p, x, knots)
      spans(i) = span
      call BasisFuns(span, x, p, knots, batx(:,i))
    end do
    ! ...
       
    ! ...
    mat = 0.0d0
    do i = 1, n_points
      span = spans(i)
      do k = 1, p+1
        j = span-p+k  
        if (j <= n-nu) then
          mat(i,j) = batx(k,i)
        else
          mat(i,j-(n-nu)) = batx(k,i)
        end if
      enddo
    enddo
    ! ...

    ! ...
    deallocate(spans)
    deallocate(batx)
    ! ...

  end subroutine spl_collocation_periodic_matrix 
  ! .......................................................

  ! .......................................................
  !> @brief     symetrizes a knot vector, needed for periodic interpolation 
  !>
  !> @param[in]    r     spline space regularity at extremities 
  !> @param[in]    n     number of control points
  !> @param[in]    p     spline degree 
  !> @param[inout] knots Knot vector 
  subroutine spl_symetrize_knots(r, n, p, knots)
    implicit none
    integer(kind=4), intent(in)  :: r 
    integer(kind=4), intent(in)  :: n 
    integer(kind=4), intent(in)  :: p
    real   (kind=8), dimension(:), intent(inout)  :: knots
    ! local
    integer(kind=4) :: i
    integer(kind=4) :: nu 
    real(8) :: period
    real(8), dimension(:), allocatable :: arr_u 

    allocate(arr_u(n+p+1))

    nu = r +1

    period = knots(n+1) - knots(p+1)
    do i=1,nu
      arr_u(i) = knots(n+i-nu) - period
    end do
    do i=nu+1, p+1
      arr_u(i) = knots(p+1)
    end do
    arr_u(p+2:n+p+1-nu) = knots(p+2:n+p+1-nu)
    do i=1,nu
      arr_u(n+p+1-nu+i) = knots(p+1+i) + period
    end do

    knots = arr_u
    deallocate(arr_u)

  end subroutine spl_symetrize_knots
  ! .......................................................

  ! .......................................................
  !> @brief     returns the Greville abscissae 
  !>
  !> @param[in]    n     number of control points
  !> @param[in]    p     spline degree 
  !> @param[in]    knots Knot vector 
  !> @param[out]   arr_x Greville abscissae 
  subroutine spl_compute_greville(n, p, knots, arr_x)
    implicit none
    integer(kind=4), intent(in)  :: n 
    integer(kind=4), intent(in)  :: p
    real   (kind=8), dimension(:), intent(in)  :: knots
    real   (kind=8), dimension(:), intent(out) :: arr_x 
    integer(kind=4) :: i

    call Greville(p,n+p,knots,arr_x)

  end subroutine spl_compute_greville
  ! .......................................................

  ! .......................................................
  !> @brief     computes span index for every element 
  !>
  !> @param[in]    n               number of control points
  !> @param[in]    p               spline degree 
  !> @param[in]    knots           Knot vector 
  !> @param[out]   elements_spans  Knot vector 
  subroutine spl_compute_spans(p, n, knots, elements_spans, basis_elements)
  implicit none
    integer,                    intent(in)  :: n
    integer,                    intent(in)  :: p
    real(kind=8), dimension(:), intent(in)  :: knots
    integer,      dimension(:), intent(out) :: elements_spans
    integer,      dimension(:), intent(out) :: basis_elements
    ! local variables
    integer :: i_element
    integer :: i_knot

    ! ...
    elements_spans = -1 
    basis_elements = -1 
    ! ...

    ! ...
    i_element = 0
    do i_knot = p + 1, n 
      basis_elements(i_knot) = i_element

      ! we check if the element has zero measure
      if ( knots(i_knot) /= knots(i_knot + 1) ) then
        i_element = i_element + 1
        
        elements_spans(i_element) = i_knot
      end if
    end do
    ! ...
     
  end subroutine spl_compute_spans 
  ! .......................................................

end module mod_pyccelext_math_external_bsp
