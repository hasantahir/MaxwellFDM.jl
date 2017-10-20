@testset "shape" begin

const rtol = Base.rtoldefault(Float64)
const one⁻ = 1 - rtol  # slightly less than 1
const intv1⁻ = (-one⁻, one⁻)

@testset "Interval" begin
    box = Box([0,1], [2,3])
    vac = Material("vacuum")
    ge = PRIM
    evac = EncodedMaterial(ge, vac)
    setmat!(box, evac)
    setmax∆l!(box, [0.1, 0.15])
    b = bounds(box)
    oi = OpenInterval(box, nX)
    ci = ClosedInterval(box, nY)

    @test bounds(oi) == (-1,1)
    @test bounds(ci) == (-0.5, 2.5)
    @test -1∉oi && 1∉oi && 0∈oi
    @test -0.5∈ci && 2.5∈ci && 1∈ci
    @test max∆l(oi) == 0.1
    @test max∆l(ci) == 0.15
    @test length(oi) == 2
    @test length(ci) == 3

    # ∆lmax = (bound[2]-bound[1]) / 10
    # center = mean(bound)
    # i1 = Interval1D(bound, ∆lmax)
    #
    # @test contains(i1, center)
    # @test all(contains.(i1, bound))
    # @test !contains(i1, bound[1]-eps())
    # @test center_(i1) ≈ center
end


# @testset "Interval1D" begin
#     bound = (sort(rand(2))...)
#     ∆lmax = (bound[2]-bound[1]) / 10
#     center = mean(bound)
#     i1 = Interval1D(bound, ∆lmax)
#
#     @test contains(i1, center)
#     @test all(contains.(i1, bound))
#     @test !contains(i1, bound[1]-eps())
#     @test center_(i1) ≈ center
# end
#
# @testset "Interval3D" begin
#     ba = sort(rand(3,2), 2)
#     bound = ([(ba[i,:]...) for i = 1:3]...)
#     ∆lmax = (/).((x->-(x...)).(bound), -10)
#     center = mean.(bound)
#     i3 = Interval3D(bound, ∆lmax)
#
#     @test contains(i3, center)
#     @test all(contains.(i3, [first.(bound), last.(bound)]))
#     @test center_(i3) ≈ center
# end

@testset "Object" begin
    mat = Material("material", ε=rand(), μ=rand())
    ge = PRIM
    emat = EncodedMaterial(ge, mat)

    @testset "Box" begin
        ba = sort(rand(3,2), 2)  # array
        b = (ba[:,1], ba[:,2])
        # ∆lmax = (b[2]-b[1]) / 10
        box = Box(b)
        setmat!(box, emat)

        @test bounds(box) ≈ b
        @test all(b .∈ box)
        @test max∆l(box) == fill(Inf,3)
        @test matparam(box,PRIM)==emat.param[nPR] && matparam(box,DUAL)==emat.param[nDL]
    end  # @testset "Box"

    @testset "Ellipsoid" begin
        c = rand(3)
        r = rand(3)
        b = (c-r, c+r)
        ∆lmax = r / 10
        el = Ellipsoid(c, r)
        setmat!(el, emat)
        setmax∆l!(el, ∆lmax)

        @test bounds(el) ≈ b
        @test all([(c′ = copy(c); c′[w] += s*r[w]; c′) for w = nXYZ, s = intv1⁻] .∈ el)
        @test all([(c′ = copy(c); c′[nX] += sx*r[nX]; c′[nY] += sy*r[nY]; c′[nZ] += sz*r[nZ];
            all(bounds(el)[nN] .≤ c′ .≤ bounds(el)[nP])) for sx = intv1⁻, sy = intv1⁻, sz = intv1⁻])
        @test max∆l(el) == ∆lmax
        @test matparam(el,PRIM)==emat.param[nPR] && matparam(el,DUAL)==emat.param[nDL]
    end  # @testset "Ellipsoid"

    @testset "Cylinder" begin
        c = rand(3)
        r = rand()
        h = rand()
        R = [r,r,h/2]
        a = [0,0,1]
        ∆lmax = R ./ 10
        cyl = Cylinder(c, r, a, h)
        setmat!(cyl, emat)
        setmax∆l!(cyl, ∆lmax)

        b = (c-R, c+R)

        @test bounds(cyl) ≈ b
        @test all([(c′ = copy(c); c′[w] += s*R[w]; c′) for w = (nX, nZ), s = intv1⁻] .∈ cyl)
        @test all([(c′ = copy(c); c′[w] += s*R[w]; c′) for w = (nY, nZ), s = intv1⁻] .∈ cyl)
        @test max∆l(cyl) == ∆lmax
        @test matparam(cyl,PRIM)==emat.param[nPR] && matparam(cyl,DUAL)==emat.param[nDL]
    end  # @testset "Cylinder"

    @testset "Sphere" begin
        c = rand(3)
        r = rand()
        ∆lmax = r / 10
        sph = Sphere(c, r)
        setmat!(sph, emat)
        setmax∆l!(sph, ∆lmax)

        R = [r,r,r]
        b = (c-R, c+R)

        @test bounds(sph) ≈ b
        @test all([all([(c′ = copy(c); c′[w] += s*R[w]; c′) for s = intv1⁻] .∈ sph) for w = nXYZ])
        @test max∆l(sph) == fill(∆lmax,3)
        @test matparam(sph,PRIM)==emat.param[nPR] && matparam(sph,DUAL)==emat.param[nDL]
    end  # @testset "Sphere"
end  # @testset "Object"

@testset "Object Vector" begin
    ovec = Object3[]
    paramset = (SMat3Complex[], SMat3Complex[])
    vac = Material("vacuum")
    Si = Material("Si", ε = 12)

    ge = PRIM
    evac = EncodedMaterial(ge, vac)
    eSi = EncodedMaterial(ge, Si)

    box = Box((rand(3), rand(3))); @test_throws ArgumentError add!(ovec, paramset, box)
    setmat!(box, evac);
    add!(ovec, paramset, box)

    el = Ellipsoid(rand(3), rand(3));
    setmat!(el, eSi);
    add!(ovec, paramset, el)

    box2 = Box((rand(3), rand(3)));
    setmat!(box2, evac);
    add!(ovec, paramset, box2)

    @test paramind(box,PRIM)==1 && paramind(box,DUAL)==1
    @test objind(box) == 1

    @test paramind(el,PRIM)==2 && paramind(el,DUAL)==1
    @test objind(el) == 2

    @test paramind(box2,PRIM)==1 && paramind(box2,DUAL)==1
    @test objind(box2) == 3
end



# @testset "union" begin
#     b1 = Box(((0,1),(0,1),(0,1)))
#     b2 = Box(((-1,0),(-1,0),(-1,0)))
#     s = sphere((0,0,0), 1)
#     lsf_union = union(lsf(b1), lsf(s), lsf(b2))
#     @test all(contains.(lsf_union, [(1,1,1), (-1,-1,-1), (-1/√3,-1/√3,1/√3), (1/√3,1/√3,-1/√3)]))
# end
#
# @testset "intersect" begin
#     b1 = Box(((-1,2),(-1,2),(-1,2)))
#     b2 = Box(((-2,1),(-2,1),(-2,1)))
#     lsf_intersect = intersect(lsf(b1), lsf(b2))
#     @test all(contains.(lsf_intersect, [(x,y,z) for x = -1:1, y = -1:1, z = -1:1]))
#     @test all(!contains.(lsf_intersect, [(x,y,z) for x = (-2,2), y = (-2,2), z = (-2,2)]))
# end
#
# @testset "flip" begin
#     b = Box(((0,1),(0,1),(0,1)))
#     lsf0 = lsf(b)
#     lsf_x = flip(lsf0, XX, 0)
#     lsf_y = flip(lsf0, YY, 0)
#     lsf_z = flip(lsf0, ZZ, 0)
#
#     @test all(contains.(lsf0, [(x,y,z) for x = 0:1, y = 0:1, z = 0:1]))
#     @test all(contains.(lsf_x, [(x,y,z) for x = -1:0, y = 0:1, z = 0:1]))
#     @test all(contains.(lsf_y, [(x,y,z) for x = 0:1, y = -1:0, z = 0:1]))
#     @test all(contains.(lsf_z, [(x,y,z) for x = 0:1, y = 0:1, z = -1:0]))
# end
#
# @testset "shift" begin
#     b = Box(((0,1),(0,1),(0,1)))
#     lsf0 = lsf(b)
#     lsf_x = shift(lsf0, XX, -1)
#     lsf_y = shift(lsf0, YY, -1)
#     lsf_z = shift(lsf0, ZZ, -1)
#
#     @test all(contains.(lsf0, [(x,y,z) for x = 0:1, y = 0:1, z = 0:1]))
#     @test all(contains.(lsf_x, [(x,y,z) for x = -1:0, y = 0:1, z = 0:1]))
#     @test all(contains.(lsf_y, [(x,y,z) for x = 0:1, y = -1:0, z = 0:1]))
#     @test all(contains.(lsf_z, [(x,y,z) for x = 0:1, y = 0:1, z = -1:0]))
# end

end  # @testset "shape"
