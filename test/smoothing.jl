@testset "smoothing" begin

@testset "sort8!" begin
    v = rand(8)
    ind = collect(1:8)
    @inferred(MaxwellFDM.sort8!(ind,v))
    @test issorted(v[ind])
    @test @inferred(MaxwellFDM.countdiff(ind,v)) == (8,8)
end  # @testset "sort8!"

# @testset "Object" begin
#     vac = Material("Vacuum")
#     ivac = EncodedMaterial(PRIM, vac)
#     box = Box(((0,1), (0,1), (0,1)))
#     obj = Object(ivac, box)
#     obj_array = Object.(ivac, [box,box,box])  # vectorization over shapes
#     @test obj_array == [obj, obj, obj]
# end  # @testset "Object"

# Need to test non-box object, such as a sphere and see if subpixel smoothing generates
# the expected smoothed material parameters (instead of simply using kottke_input_simple or
# amean_param or hmean_param.)

@testset "smoothing, box with odd number of voxels" begin
    # Create a grid.
    isbloch = [true, true, true]
    # isbloch = [true, false, false]
    lprim = ([-1.5, -0.5, 0.5, 1.5], [-1.5, -0.5, 0.5, 1.5], [-1.5, -0.5, 0.5, 1.5])
    g3 = Grid(lprim, isbloch)
    N = g3.N

    # Create materials.
    εvac = 1.0
    vac = Material("Vacuum", ε=εvac)

    εdiel = 2.0
    diel = Material("Dielectric", ε=εdiel)

    # Create objects.
    dom_vac = Object(Box(g3.bounds), vac)
    obj_diel = Object(Box([0,0,0], [1,1,1]), diel)
    # obj_diel = Object(Sphere([0,0,0], 1), diel)

    # Add objects.
    ovec = Object3[]
    paramset = (SMat3Complex[], SMat3Complex[])
    add!(ovec, paramset, dom_vac, obj_diel)

    # Construct arguments and call assign_param!.
    ε3d = create_param3d(N)
    εobj3d = create_n3d(Object3, N)
    εind3d = create_n3d(ParamInd, N)
    εoind3d = create_n3d(ObjInd, N)

    μ3d = create_param3d(N)
    μobj3d = create_n3d(Object3, N)
    μind3d = create_n3d(ParamInd, N)
    μoind3d = create_n3d(ObjInd, N)

    boundft = SVector(EE,EE,EE)
    assign_param!((ε3d,μ3d), (εobj3d,μobj3d), (εind3d,μind3d), (εoind3d,μoind3d), boundft, ovec, g3.ghosted.τl, g3.isbloch)
    # Test the sanity the assigned param3d here.  It is relatively easy, and it was very helpful.

    ft = EE
    smooth_param!(ε3d, εobj3d, εind3d, εoind3d, ft, boundft, g3.l, g3.ghosted.l, g3.σ, g3.ghosted.∆τ)

    ε3dred = view(ε3d, 1:N[nX], 1:N[nY], 1:N[nZ], 1:3, 1:3)

    # Construct an expected ε3d.
    ε3dexp = Array{ComplexF64}(undef,3,3,3,3,3)
    rvol = 0.5  # all nonzero rvol used in this test is 0.5
    εh = 1 / (rvol/εdiel + (1-rvol)/εvac)  # harmonic average
    εa = rvol*εdiel + (1-rvol)*εvac  # arithmetic average

    # Initialize ε3dexp.
    for k = 1:N[nZ], j = 1:N[nY], i = 1:N[nX]
        ε3dexp[i,j,k,:,:] = εvac * Matrix(I,3,3)
    end

    # Yee's cell at (2,2,2)
    nout = normalize([-1,-1,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,2,2,:,:] = εsm  # corner of (2,2,2) cell
    nout = normalize([0,-1,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,2,2,1,1] = εsm[1,1]  # x-edge of (2,2,2) cell
    nout = normalize([-1,0,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,2,2,2,2] = εsm[2,2]  # y-edge of (2,2,2) cell
    nout = normalize([-1,-1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,2,2,3,3] = εsm[3,3]  # z-edge of (2,2,2) cell

    # Yee's cell at (3,2,2)
    nout = normalize([1,-1,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,2,2,:,:] = εsm
    ε3dexp[3,2,2,1,1] = εvac
    nout = normalize([1,0,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,2,2,2,2] = εsm[2,2]
    nout = normalize([1,-1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,2,2,3,3] = εsm[3,3]

    # Yee's cell at (2,3,2)
    nout = normalize([-1,1,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,3,2,:,:] = εsm
    nout = normalize([0,1,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,3,2,1,1] = εsm[1,1]
    ε3dexp[2,3,2,2,2] = εvac
    nout = normalize([-1,1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,3,2,3,3] = εsm[3,3]

    # Yee's cell at (3,3,2)
    nout = normalize([1,1,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,3,2,:,:] = εsm
    ε3dexp[3,3,2,1,1] = εvac
    ε3dexp[3,3,2,2,2] = εvac
    nout = normalize([1,1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,3,2,3,3] = εsm[3,3]

    # Yee's cell at (2,2,3)
    nout = normalize([-1,-1,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,2,3,:,:] = εsm
    nout = normalize([0,-1,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,2,3,1,1] = εsm[1,1]
    nout = normalize([-1,0,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,2,3,2,2] = εsm[2,2]
    ε3dexp[2,2,3,3,3] = εvac

    # Yee's cell at (3,2,3)
    nout = normalize([1,-1,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,2,3,:,:] = εsm
    ε3dexp[3,2,3,1,1] = εvac
    nout = normalize([-1,0,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,2,3,2,2] = εsm[2,2]
    ε3dexp[3,2,3,3,3] = εvac

    # Yee's cell at (2,3,3)
    nout = normalize([-1,1,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,3,3,:,:] = εsm
    nout = normalize([0,1,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,3,3,1,1] = εsm[1,1]
    ε3dexp[2,3,3,2,2] = εvac
    ε3dexp[2,3,3,3,3] = εvac

    # Yee's cell at (3,3,3)
    nout = normalize([1,1,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,3,3,:,:] = εsm
    ε3dexp[3,3,3,1,1] = εvac
    ε3dexp[3,3,3,2,2] = εvac
    ε3dexp[3,3,3,3,3] = εvac

    for k = 1:N[nZ], j = 1:N[nY], i = 1:N[nX]
        # @info "(i,j,k) = $((i,j,k))"  # uncomment this to know where test fails
        @test @view(ε3dred[i,j,k,:,:]) ≈ @view(ε3dexp[i,j,k,:,:])
        @test issymmetric(@view(ε3dred[i,j,k,:,:]))
    end
end  # @testset "smoothing, box with odd number of voxels"

@testset "smoothing, box with even number of voxels" begin
    # Create a grid.
    lprim = ([-2,-1,0,1,2], [-2,-1,0,1,2], [-2,-1,0,1,2])
    isbloch = [true, true, true]
    g3 = Grid(lprim, isbloch)
    N = g3.N

    # Create materials.
    εvac = 1.0
    vac = Material("Vacuum", ε=εvac)

    εdiel = 2.0
    diel = Material("Dielectric", ε=εdiel)

    # Create objects.
    dom_vac = Object(Box(g3.bounds), vac)
    obj_diel = Object(Box([0,0,0], [2,2,2]), diel)
    # obj_diel = Object(Sphere([0,0,0], 1), diel)

    # Add objects.
    ovec = Object3[]
    paramset = (SMat3Complex[], SMat3Complex[])
    add!(ovec, paramset, dom_vac, obj_diel)

    # Construct arguments and call assign_param!.
    ε3d = create_param3d(N)
    εobj3d = create_n3d(Object3, N)
    εind3d = create_n3d(ParamInd, N)
    εoind3d = create_n3d(ObjInd, N)

    μ3d = create_param3d(N)
    μobj3d = create_n3d(Object3, N)
    μind3d = create_n3d(ParamInd, N)
    μoind3d = create_n3d(ObjInd, N)

    boundft = SVector(EE,EE,EE)
    assign_param!((ε3d,μ3d), (εobj3d,μobj3d), (εind3d,μind3d), (εoind3d,μoind3d), boundft, ovec, g3.ghosted.τl, g3.isbloch)

    ft = EE
    smooth_param!(ε3d, εobj3d, εind3d, εoind3d, ft, boundft, g3.l, g3.ghosted.l, g3.σ, g3.ghosted.∆τ)

    ε3dred = view(ε3d, 1:N[nX], 1:N[nY], 1:N[nZ], 1:3, 1:3)

    # Construct an expected ε3d.
    ε3dexp = Array{ComplexF64}(undef,4,4,4,3,3)
    rvol = 0.5  # all nonzero rvol used in this test is 0.5
    εh = 1 / (rvol/εdiel + (1-rvol)/εvac)  # harmonic average
    εa = rvol*εdiel + (1-rvol)*εvac  # arithmetic average

    # Initialize ε3dexp.
    for k = 1:N[nZ], j = 1:N[nY], i = 1:N[nX]
        ε3dexp[i,j,k,:,:] = εvac * Matrix(I,3,3)
    end

    ## k = 2
    # Yee's cell at (2,2,2)
    nout = normalize([-1,-1,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,2,2,:,:] = εsm  # corner of (2,2,2) cell
    nout = normalize([0,-1,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,2,2,1,1] = εsm[1,1]  # x-edge of (2,2,2) cell
    nout = normalize([-1,0,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,2,2,2,2] = εsm[2,2]  # y-edge of (2,2,2) cell
    nout = normalize([-1,-1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,2,2,3,3] = εsm[3,3]  # z-edge of (2,2,2) cell

    # Yee's cell at (3,2,2)
    nout = normalize([0,-1,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,2,2,:,:] = εsm
    nout = normalize([0,-1,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,2,2,1,1] = εsm[1,1]
    nout = normalize([0,0,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,2,2,2,2] = εsm[2,2]
    nout = normalize([0,-1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,2,2,3,3] = εsm[3,3]

    # Yee's cell at (4,2,2)
    nout = normalize([1,-1,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[4,2,2,:,:] = εsm
    ε3dexp[4,2,2,1,1] = εvac
    nout = normalize([1,0,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[4,2,2,2,2] = εsm[2,2]
    nout = normalize([1,-1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[4,2,2,3,3] = εsm[3,3]

    # Yee's cell at (2,3,2)
    nout = normalize([-1,0,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,3,2,:,:] = εsm
    nout = normalize([0,0,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,3,2,1,1] = εsm[1,1]
    nout = normalize([-1,0,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,3,2,2,2] = εsm[2,2]
    nout = normalize([-1,0,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,3,2,3,3] = εsm[3,3]

    # Yee's cell at (3,3,2)
    nout = normalize([0,0,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,3,2,:,:] = εsm
    nout = normalize([0,0,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,3,2,1,1] = εsm[1,1]
    nout = normalize([0,0,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,3,2,2,2] = εsm[2,2]
    ε3dexp[3,3,2,3,3] = εdiel

    # Yee's cell at (4,3,2)
    nout = normalize([1,0,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[4,3,2,:,:] = εsm
    ε3dexp[4,3,2,1,1] = εvac
    nout = normalize([1,0,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[4,3,2,2,2] = εsm[2,2]
    nout = normalize([1,0,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[4,3,2,3,3] = εsm[3,3]

    # Yee's cell at (2,4,2)
    nout = normalize([-1,1,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,4,2,:,:] = εsm
    nout = normalize([0,1,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,4,2,1,1] = εsm[1,1]
    ε3dexp[2,4,2,2,2] = εvac
    nout = normalize([-1,1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,4,2,3,3] = εsm[3,3]

    # Yee's cell at (3,4,2)
    nout = normalize([0,1,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,4,2,:,:] = εsm
    nout = normalize([0,1,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,4,2,1,1] = εsm[1,1]
    ε3dexp[3,4,2,2,2] = εvac
    nout = normalize([0,1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,4,2,3,3] = εsm[3,3]

    # Yee's cell at (4,4,2)
    nout = normalize([1,1,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[4,4,2,:,:] = εsm
    ε3dexp[4,4,2,1,1] = εvac
    ε3dexp[4,4,2,2,2] = εvac
    nout = normalize([1,1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[4,4,2,3,3] = εsm[3,3]


    ## k = 3
    # Yee's cell at (2,2,3)
    nout = normalize([-1,-1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,2,3,:,:] = εsm
    nout = normalize([0,-1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,2,3,1,1] = εsm[1,1]
    nout = normalize([-1,0,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,2,3,2,2] = εsm[2,2]
    nout = normalize([-1,-1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,2,3,3,3] = εsm[3,3]

    # Yee's cell at (3,2,3)
    nout = normalize([0,-1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,2,3,:,:] = εsm
    nout = normalize([0,-1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,2,3,1,1] = εsm[1,1]
    ε3dexp[3,2,3,2,2] = εdiel
    nout = normalize([0,-1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,2,3,3,3] = εsm[3,3]

    # Yee's cell at (4,2,3)
    nout = normalize([1,-1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[4,2,3,:,:] = εsm
    ε3dexp[4,2,3,1,1] = εvac
    nout = normalize([1,0,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[4,2,3,2,2] = εsm[2,2]
    nout = normalize([1,-1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[4,2,3,3,3] = εsm[3,3]

    # Yee's cell at (2,3,3)
    nout = normalize([-1,0,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,3,3,:,:] = εsm
    ε3dexp[2,3,3,1,1] = εdiel
    nout = normalize([-1,0,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,3,3,2,2] = εsm[2,2]
    nout = normalize([-1,0,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,3,3,3,3] = εsm[3,3]

    # Yee's cell at (3,3,3)
    ε3dexp[3,3,3,1,1] = εdiel
    ε3dexp[3,3,3,2,2] = εdiel
    ε3dexp[3,3,3,3,3] = εdiel

    # Yee's cell at (4,3,3)
    nout = normalize([1,0,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[4,3,3,:,:] = εsm
    ε3dexp[4,3,3,1,1] = εvac
    nout = normalize([1,0,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[4,3,3,2,2] = εsm[2,2]
    nout = normalize([1,0,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[4,3,3,3,3] = εsm[3,3]

    # Yee's cell at (2,4,3)
    nout = normalize([-1,1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,4,3,:,:] = εsm
    nout = normalize([0,1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,4,3,1,1] = εsm[1,1]
    ε3dexp[2,4,3,2,2] = εvac
    nout = normalize([-1,1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,4,3,3,3] = εsm[3,3]

    # Yee's cell at (3,4,3)
    nout = normalize([0,1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,4,3,:,:] = εsm
    nout = normalize([0,1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,4,3,1,1] = εsm[1,1]
    ε3dexp[3,4,3,2,2] = εvac
    nout = normalize([0,1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,4,3,3,3] = εsm[3,3]

    # Yee's cell at (4,4,3)
    nout = normalize([1,1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[4,4,3,:,:] = εsm
    ε3dexp[4,4,3,1,1] = εvac
    ε3dexp[4,4,3,2,2] = εvac
    nout = normalize([1,1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[4,4,3,3,3] = εsm[3,3]


    ## k = 4
    # Yee's cell at (2,2,4)
    nout = normalize([-1,-1,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,2,4,:,:] = εsm
    nout = normalize([0,-1,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,2,4,1,1] = εsm[1,1]
    nout = normalize([-1,0,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,2,4,2,2] = εsm[2,2]
    ε3dexp[2,2,4,3,3] = εvac

    # Yee's cell at (3,2,4)
    nout = normalize([0,-1,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,2,4,:,:] = εsm
    nout = normalize([0,-1,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,2,4,1,1] = εsm[1,1]
    nout = normalize([0,0,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,2,4,2,2] = εsm[2,2]
    ε3dexp[3,2,4,3,3] = εvac

    # Yee's cell at (4,2,4)
    nout = normalize([1,-1,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[4,2,4,:,:] = εsm
    ε3dexp[4,2,4,1,1] = εvac
    nout = normalize([-1,0,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[4,2,4,2,2] = εsm[2,2]
    ε3dexp[4,2,4,3,3] = εvac

    # Yee's cell at (2,3,4)
    nout = normalize([-1,0,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,3,4,:,:] = εsm
    nout = normalize([0,0,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,3,4,1,1] = εsm[1,1]
    nout = normalize([-1,0,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,3,4,2,2] = εsm[2,2]
    ε3dexp[2,3,4,3,3] = εvac

    # Yee's cell at (3,3,4)
    nout = normalize([0,0,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,3,4,:,:] = εsm
    nout = normalize([0,0,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,3,4,1,1] = εsm[1,1]
    nout = normalize([0,0,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,3,4,2,2] = εsm[2,2]
    ε3dexp[3,3,4,3,3] = εvac

    # Yee's cell at (4,3,4)
    nout = normalize([1,0,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[4,3,4,:,:] = εsm
    ε3dexp[4,3,4,1,1] = εvac
    nout = normalize([1,0,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[4,3,4,2,2] = εsm[2,2]
    ε3dexp[4,3,4,3,3] = εvac

    # Yee's cell at (2,4,4)
    nout = normalize([-1,1,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,4,4,:,:] = εsm
    nout = normalize([0,1,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,4,4,1,1] = εsm[1,1]
    ε3dexp[2,4,4,2,2] = εvac
    ε3dexp[2,4,4,3,3] = εvac

    # Yee's cell at (3,4,4)
    nout = normalize([0,1,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,4,4,:,:] = εsm
    nout = normalize([0,1,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,4,4,1,1] = εsm[1,1]
    ε3dexp[3,4,4,2,2] = εvac
    ε3dexp[3,4,4,3,3] = εvac

    # Yee's cell at (4,4,4)
    nout = normalize([1,1,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[4,4,4,:,:] = εsm
    ε3dexp[4,4,4,1,1] = εvac
    ε3dexp[4,4,4,2,2] = εvac
    ε3dexp[4,4,4,3,3] = εvac

    for k = 1:N[nZ], j = 1:N[nY], i = 1:N[nX]
        # @info "(i,j,k) = $((i,j,k))"  # uncomment this to know where test fails
        @test @view(ε3dred[i,j,k,:,:]) ≈ @view(ε3dexp[i,j,k,:,:])
        @test issymmetric(@view(ε3dred[i,j,k,:,:]))
    end
end  # @testset "smoothing, box with even number of voxels"

# Not sure if this test was completed.  It was commented out.  When uncommented, the test failed.
# @testset "smoothing, inspired from SALT3D/test/usage2d_phcwg_test_sym" begin
#     # Create a grid.
#     lprim = ([-0.5,0.5], [-2,-1,0,1,2], [-0.5,0.5])
#     isbloch = [true, true, true]
#     g3 = Grid(lprim, isbloch)
#     N = g3.N
#
#     # Create materials.
#     εvac = 1.0
#     vac = EncodedMaterial(PRIM, Material("Vacuum", ε=εvac))
#
#     εdiel = 2.0
#     diel = EncodedMaterial(PRIM, Material("Dielectric", ε=εdiel))
#
#     # Create objects.
#     dom_vac = Object(Box(g3.bounds), vac)
#     obj_diel = Object(Box([0,0,0], [1,2,1]), diel)
#     # obj_diel = Object(Sphere([0,0,0], 1), diel)
#
#     # Add objects.
#     ovec = Object3[]
#     paramset = (SMat3Complex[], SMat3Complex[])
#     add!(ovec, paramset, dom_vac, obj_diel)
#
#     # Construct arguments and call assign_param!.
#     param3d = create_param3d(N)
#     obj3d = create_n3d(Object3, N)
#     pind3d = create_n3d(ParamInd, N)
#     oind3d = create_n3d(ObjInd, N)
#
#     assign_param!(param3d, obj3d, pind3d, oind3d, ovec, g3.ghosted.τl, g3.isbloch)
#     smooth_param!(param3d, obj3d, pind3d, oind3d, g3.l, g3.ghosted.l, g3.σ, g3.ghosted.∆τ)
#
#     ε3d = view(param3d[nPR], 1:N[nX], 1:N[nY], 1:N[nZ], 1:3, 1:3)
#
#     # Construct an expected ε3d.
#     ε3dexp = Array{ComplexF64}(undef,4,4,4,3,3)
#     rvol = 0.5  # all nonzero rvol used in this test is 0.5
#     εh = 1 / (rvol/εdiel + (1-rvol)/εvac)  # harmonic average
#     εa = rvol*εdiel + (1-rvol)*εvac  # arithmetic average
#
#     # Initialize ε3dexp.
#     for k = 1:4, j = 1:4, i = 1:4
#         ε3dexp[i,j,k,:,:] = εvac * Matrix(I,3,3)
#     end
#
#     # Yee's cell at (1,2,1)
#     nout = normalize([-1,-1,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[1,2,1,:,:] = εsm  # corner of (2,2,2) cell
#     nout = normalize([0,-1,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[1,2,1,1,1] = εsm[1,1]  # x-edge of (2,2,2) cell
#     nout = normalize([-1,0,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[1,2,1,2,2] = εsm[2,2]  # y-edge of (2,2,2) cell
#     nout = normalize([-1,-1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[1,2,1,3,3] = εsm[3,3]  # z-edge of (2,2,2) cell
#
#     # Yee's cell at (3,2,2)
#     nout = normalize([1,-1,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,2,2,:,:] = εsm
#     ε3dexp[3,2,2,1,1] = εvac
#     nout = normalize([1,0,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,2,2,2,2] = εsm[2,2]
#     nout = normalize([1,-1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,2,2,3,3] = εsm[3,3]
#
#     # Yee's cell at (2,3,2)
#     nout = normalize([-1,1,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,3,2,:,:] = εsm
#     nout = normalize([0,1,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,3,2,1,1] = εsm[1,1]
#     ε3dexp[2,3,2,2,2] = εvac
#     nout = normalize([-1,1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,3,2,3,3] = εsm[3,3]
#
#     # Yee's cell at (3,3,2)
#     nout = normalize([1,1,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,3,2,:,:] = εsm
#     ε3dexp[3,3,2,1,1] = εvac
#     ε3dexp[3,3,2,2,2] = εvac
#     nout = normalize([1,1,0]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,3,2,3,3] = εsm[3,3]
#
#     # Yee's cell at (2,2,3)
#     nout = normalize([-1,-1,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,2,3,:,:] = εsm
#     nout = normalize([0,-1,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,2,3,1,1] = εsm[1,1]
#     nout = normalize([-1,0,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,2,3,2,2] = εsm[2,2]
#     ε3dexp[2,2,3,3,3] = εvac
#
#     # Yee's cell at (3,2,3)
#     nout = normalize([1,-1,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,2,3,:,:] = εsm
#     ε3dexp[3,2,3,1,1] = εvac
#     nout = normalize([-1,0,-1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,2,3,2,2] = εsm[2,2]
#     ε3dexp[3,2,3,3,3] = εvac
#
#     # Yee's cell at (2,3,3)
#     nout = normalize([-1,1,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,3,3,:,:] = εsm
#     nout = normalize([0,1,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[2,3,3,1,1] = εsm[1,1]
#     ε3dexp[2,3,3,2,2] = εvac
#     ε3dexp[2,3,3,3,3] = εvac
#
#     # Yee's cell at (3,3,3)
#     nout = normalize([1,1,1]); P = nout*nout'; εsm = εh * P + εa * (I-P); ε3dexp[3,3,3,:,:] = εsm
#     ε3dexp[3,3,3,1,1] = εvac
#     ε3dexp[3,3,3,2,2] = εvac
#     ε3dexp[3,3,3,3,3] = εvac
#
#     for k = 1:3, j = 1:3, i = 1:3
#         # @info "(i,j,k) = $((i,j,k))"  # uncomment this to know where test fails
#         @test ε3d[i,j,k,:,:] ≈ ε3dexp[i,j,k,:,:]
#     end
# end

# Need to include a test with three objects with mat1, mat2, mat1.  In the wrong code I
# assumed that I could find the foreground object by sorting voxel corners in terms of pind,
# but this test would show that that is not the case.

end  # @testset "smoothing"
