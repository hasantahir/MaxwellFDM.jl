@testset "source" begin

@testset "distweights" begin
    ∆lg = collect(2:2:22)  # make sure ∆l's are varying to prevent false positive
    l′ = cumsum([-1; ∆lg])  # [-1,1,5,11,19,29,41,55,71,89,109,131]: spacing is even

    lprim_g = MaxwellFDM.movingavg(l′)  # [0,3,8,15,24,35,48,63,80,99,120]: spacing is odd, 11 entries (l has 10 entry)
    ldual_g = l′[1:end-1]  # [-1,1,5,11,19,29,41,55,71,89,109]: spacing is even

    domain = [lprim_g[1], lprim_g[end]]

    lprim, ∆lprim = lprim_g[1:end-1], diff(ldual_g)
    ldual, ∆ldual = ldual_g[2:end], diff(lprim_g)

    # Test for sources to assign at the primal grid points [0,3,8,15,24,35,48,63,80,99 (,120)].
    c = 8  # at grid point
    @test all(MaxwellFDM.distweights(c, PRIM, domain, lprim, ∆lprim, true) .≈ ([3], [1/∆lprim[3]]))
    @test all(MaxwellFDM.distweights(c, PRIM, domain, lprim, ∆lprim, false) .≈ ([3], [1/∆lprim[3]]))

    c = 11  # between grid points
    r = (c-8) / (15-8)
    @test all(MaxwellFDM.distweights(c, PRIM, domain, lprim, ∆lprim, true) .≈ ([3,4], [1/∆lprim[3]*(1-r), 1/∆lprim[4]*r]))
    @test all(MaxwellFDM.distweights(c, PRIM, domain, lprim, ∆lprim, false) .≈ ([3,4], [1/∆lprim[3]*(1-r), 1/∆lprim[4]*r]))

    c = 3  # farthest point affected by negative-end boundary
    @test all(MaxwellFDM.distweights(c, PRIM, domain, lprim, ∆lprim, true) .≈ ([2], [1/∆lprim[2]]))
    @test all(MaxwellFDM.distweights(c, PRIM, domain, lprim, ∆lprim, false) .≈ ([2], [1/∆lprim[2]]))

    c = 1  # within range affected by negative-end boundary
    r = (3-c) / (3-0)
    @test all(MaxwellFDM.distweights(c, PRIM, domain, lprim, ∆lprim, true) .≈ ([1,2], [1/∆lprim[1]*r, 1/∆lprim[2]*(1-r)]))
    @test all(MaxwellFDM.distweights(c, PRIM, domain, lprim, ∆lprim, false) .≈ ([2], [1/∆lprim[2]*(1-r)]))

    c = 0  # negative-end boundary
    @test all(MaxwellFDM.distweights(c, PRIM, domain, lprim, ∆lprim, true) .≈ ([1], [1/∆lprim[1]]))
    @test all(MaxwellFDM.distweights(c, PRIM, domain, lprim, ∆lprim, false) .≈ ([2], [0]))

    c = -0.5  # within range affected by negative-end PDC, but outside Bloch and PPC domain (starting at l = 0)
    @test_throws ArgumentError MaxwellFDM.distweights(c, PRIM, domain, lprim, ∆lprim, true)
    @test_throws ArgumentError MaxwellFDM.distweights(c, PRIM, domain, lprim, ∆lprim, false)

    c = -1  # behind negative-end boundary
    @test_throws ArgumentError MaxwellFDM.distweights(c, PRIM, domain, lprim, ∆lprim, true)
    @test_throws ArgumentError MaxwellFDM.distweights(c, PRIM, domain, lprim, ∆lprim, false)

    c = 99  # farthest point affected by positive-end boundary
    @test all(MaxwellFDM.distweights(c, PRIM, domain, lprim, ∆lprim, true) .≈ ([10], [1/∆lprim[10]]))
    @test all(MaxwellFDM.distweights(c, PRIM, domain, lprim, ∆lprim, false) .≈ ([10], [1/∆lprim[10]]))

    c = 105  # within range affected by positive-end boundary
    r = (c-99) / (120-99)
    @test all(MaxwellFDM.distweights(c, PRIM, domain, lprim, ∆lprim, true) .≈ ([10,1], [1/∆lprim[10]*(1-r), 1/∆lprim[1]*r]))
    @test all(MaxwellFDM.distweights(c, PRIM, domain, lprim, ∆lprim, false) .≈ ([10], [1/∆lprim[10]*(1-r)]))

    c = 120  # positive-end boundary
    r = (c-99) / (120-99)
    @test all(MaxwellFDM.distweights(c, PRIM, domain, lprim, ∆lprim, true) .≈ ([10,1], [1/∆lprim[10]*(1-r), 1/∆lprim[1]*r]))
    @test all(MaxwellFDM.distweights(c, PRIM, domain, lprim, ∆lprim, false) .≈ ([10], [1/∆lprim[10]*(1-r)]))


    # Test for sources to assign at the dual grid points [(-1,) 1,5,11,19,29,41,55,71,89,109].
    # Note the domain boundaries are [0, 120].
    c = 11  # at grid point
    @test all(MaxwellFDM.distweights(c, DUAL, domain, ldual, ∆ldual, true) .≈ ([3], [1/∆ldual[3]]))
    @test all(MaxwellFDM.distweights(c, DUAL, domain, ldual, ∆ldual, false) .≈ ([3], [1/∆ldual[3]]))

    c = 15  # between grid points
    r = (c-11) / (19-11)
    @test all(MaxwellFDM.distweights(c, DUAL, domain, ldual, ∆ldual, true) .≈ ([3,4], [1/∆ldual[3]*(1-r), 1/∆ldual[4]*r]))
    @test all(MaxwellFDM.distweights(c, DUAL, domain, ldual, ∆ldual, false) .≈ ([3,4], [1/∆ldual[3]*(1-r), 1/∆ldual[4]*r]))

    c = 1  # farthest point affected by negative-end boundary
    @test all(MaxwellFDM.distweights(c, DUAL, domain, ldual, ∆ldual, true) .≈ ([1], [1/∆ldual[1]]))
    @test all(MaxwellFDM.distweights(c, DUAL, domain, ldual, ∆ldual, false) .≈ ([1], [1/∆ldual[1]]))

    c = 0.5  # within range affected by negative-end boundary
    r = (1-c) / ((1-0) + (120-109))
    @test all(MaxwellFDM.distweights(c, DUAL, domain, ldual, ∆ldual, true) .≈ ([1,10], [1/∆ldual[1]*(1-r), 1/∆ldual[10]*r]))
    @test all(MaxwellFDM.distweights(c, DUAL, domain, ldual, ∆ldual, false) .≈ ([1], [1/∆ldual[1]]))

    c = 0  # negative-end boundary
    r = (1-c) / ((1-0) + (120-109))
    @test all(MaxwellFDM.distweights(c, DUAL, domain, ldual, ∆ldual, true) .≈ ([1,10], [1/∆ldual[1]*(1-r), 1/∆ldual[10]*r]))
    @test all(MaxwellFDM.distweights(c, DUAL, domain, ldual, ∆ldual, false) .≈ ([1], [1/∆ldual[1]]))

    c = -0.5  # behind negative-end boundary
    @test_throws ArgumentError MaxwellFDM.distweights(c, DUAL, domain, ldual, ∆ldual, true)
    @test_throws ArgumentError MaxwellFDM.distweights(c, DUAL, domain, ldual, ∆ldual, false)

    c = 109  # farthest point affected by positive-end boundary
    @test all(MaxwellFDM.distweights(c, DUAL, domain, ldual, ∆ldual, true) .≈ ([10], [1/∆ldual[10]]))
    @test all(MaxwellFDM.distweights(c, DUAL, domain, ldual, ∆ldual, false) .≈ ([10], [1/∆ldual[10]]))

    c = 115  # within range affected by positive-end boundary
    r = (c-109) / ((120-109) + (1-0))
    @test all(MaxwellFDM.distweights(c, DUAL, domain, ldual, ∆ldual, true) .≈ ([10,1], [1/∆ldual[10]*(1-r), 1/∆ldual[1]*r]))
    @test all(MaxwellFDM.distweights(c, DUAL, domain, ldual, ∆ldual, false) .≈ ([10], [1/∆ldual[10]]))

    c = 120  # positive-end boundary
    r = (c-109) / ((120-109) + (1-0))
    @test all(MaxwellFDM.distweights(c, DUAL, domain, ldual, ∆ldual, true) .≈ ([10,1], [1/∆ldual[10]*(1-r), 1/∆ldual[1]*r]))
    @test all(MaxwellFDM.distweights(c, DUAL, domain, ldual, ∆ldual, false) .≈ ([10], [1/∆ldual[10]]))

    # Test for N = 1
    domain = [0, 2]
    lprim, ldual = [0], [1]
    ∆lprim, ∆ldual = [9], [10]  # this doesn't make sense geometrically, but for test purpose (they are used to get current density from current)
    c₁, c₂ = 2rand(), 2rand()  # within domain

    ind_c₁, wt_c₁ = MaxwellFDM.distweights(c₁, PRIM, domain, lprim, ∆lprim, true)
    ind_c₂, wt_c₂ = MaxwellFDM.distweights(c₂, PRIM, domain, lprim, ∆lprim, true)
    @test ind_c₁ == ind_c₂ == [1,1]
    @test sum(wt_c₁) ≈ sum(wt_c₂) ≈ 1 / ∆lprim[1]

    ind_c₁, wt_c₁ = MaxwellFDM.distweights(c₁, DUAL, domain, ldual, ∆ldual, true)
    ind_c₂, wt_c₂ = MaxwellFDM.distweights(c₂, DUAL, domain, ldual, ∆ldual, true)
    @test ind_c₁ == ind_c₂ == [1,1]
    @test sum(wt_c₁) ≈ sum(wt_c₂) ≈ 1 / ∆ldual[1]
end  # @testset "distweights"

@testset "PlaneSrc" begin
    src = PlaneSrc(Ẑ, 0, 0)

    # Verify if the total current does not change with the location of the intercept in 3D for Bloch.
end  # @testset "PlaneSrc"

@testset "PointSrc" begin
    src = PointSrc([0,0,0], [1,1,1])

    # Verify if the total current dipole strength does not change with the location of the point
    # source in 3D for Bloch.

    # Verify if the total current dipole strength does not change with the z-location in 2D
    # assignment for Bloch (because the current assigned at the positive boundary is added to the
    # negative boundary)
end  # @testset "PlaneSrc"

end  # @testset "source"