using SFEModelling
using Test

@testset "SFEModelling.jl" begin

    @testset "ExtractionCurve construction" begin
        curve = ExtractionCurve(
            data = [5.0  0.1;
                    10.0 0.25;
                    15.0 0.42;
                    20.0 0.58;
                    30.0 0.85;
                    45.0 1.10;
                    60.0 1.28;
                    90.0 1.45;
                    120.0 1.52],
            porosity = 0.4,
            x0 = 0.05,
            solid_density = 1.1,
            solvent_density = 0.8,
            flow_rate = 5.0,
            bed_height = 20.0,
            bed_diameter = 2.0,
            particle_diameter = 0.05,
            solid_mass = 50.0,
            solubility = 0.005,
        )
        # Check SI conversions
        @test curve.t[1] ≈ 5.0 * 60.0
        @test curve.m_ext[1] ≈ 0.1 / 1000.0
        @test curve.solid_density ≈ 1.1 * 1000.0
        @test curve.bed_height ≈ 20.0 / 100.0
    end

    @testset "simulate produces non-negative output" begin
        t_vals = collect(range(5.0, 120.0, length=10))
        m_vals = collect(range(0.1, 1.5, length=10))
        curve = ExtractionCurve(
            data = hcat(t_vals, m_vals),
            porosity = 0.4,
            x0 = 0.05,
            solid_density = 1.1,
            solvent_density = 0.8,
            flow_rate = 5.0,
            bed_height = 20.0,
            bed_diameter = 2.0,
            particle_diameter = 0.05,
            solid_mass = 50.0,
            solubility = 0.005,
        )
        kya = 0.01
        kxa = 0.001
        xk = 0.03
        ycal = SFEModelling.simulate(curve, kya, kxa, xk)
        @test length(ycal) == 10
        @test all(ycal .>= 0.0)
        # Extraction should be monotonically non-decreasing
        @test all(diff(ycal) .>= -1e-15)
    end

    @testset "fit_model(Sovova()) fitting (single curve)" begin
        # Generate synthetic data with known parameters, then fit
        t_vals = collect(range(5.0, 180.0, length=15))
        curve_for_gen = ExtractionCurve(
            data = hcat(t_vals, zeros(15)),
            porosity = 0.4,
            x0 = 0.05,
            solid_density = 1.1,
            solvent_density = 0.8,
            flow_rate = 5.0,
            bed_height = 20.0,
            bed_diameter = 2.0,
            particle_diameter = 0.05,
            solid_mass = 50.0,
            solubility = 0.005,
        )

        # Generate "experimental" data with known parameters
        true_kya = 0.02
        true_kxa = 0.002
        true_xk = 0.03
        m_ext_true = SFEModelling.simulate(curve_for_gen, true_kya, true_kxa, true_xk)

        # Now create curve with this synthetic data (convert back to user units)
        curve = ExtractionCurve(
            data = hcat(t_vals, m_ext_true .* 1000.0),
            porosity = 0.4,
            x0 = 0.05,
            solid_density = 1.1,
            solvent_density = 0.8,
            flow_rate = 5.0,
            bed_height = 20.0,
            bed_diameter = 2.0,
            particle_diameter = 0.05,
            solid_mass = 50.0,
            solubility = 0.005,
        )

        result = fit_model(curve; maxevals=20_000)
        @test result.objective < 1e-8
        @test length(result.kya) == 1
        @test length(result.kxa) == 1
    end

    @testset "mateus1 experimental data" begin
        curve = ExtractionCurve(
            data = [  0.0   0.0000  0.0000;
                      5.0   0.1097  0.0935;
                     10.0   0.2571  0.2265;
                     15.0   0.3894  0.3507;
                     20.0   0.5228  0.4746;
                     30.0   0.7872  0.7270;
                     45.0   1.1633  1.0636;
                     60.0   1.4848  1.3746;
                     75.0   1.7484  1.6411;
                     90.0   1.9751  1.8913;
                    110.0   2.2485  2.1785;
                    135.0   2.5630  2.5539;
                    155.0   2.7584  2.7690;
                    180.0   3.0323  3.0527;
                    210.0   3.3022  3.3416;
                    240.0   3.5332  3.5906;
                    270.0   3.7349  3.8130;
                    300.0   3.9260  4.0177],
            porosity          = 0.7,
            x0                = 0.069,
            solid_density     = 1.32,
            solvent_density   = 0.78023,
            flow_rate         = 9.9,
            bed_height        = 9.2,
            bed_diameter      = 5.42,
            particle_diameter = 0.0337,
            solid_mass        = 100.01,
            solubility        = 0.003166,
        )

        result = fit_model(curve; maxevals=50_000)

        # Should achieve a reasonable fit
        @test result.objective < 1e-2
        # Parameters should be within physical bounds
        @test 0 < result.kya[1] < 0.05
        @test 0 < result.kxa[1] < 0.005
        @test 0 < result.xk_ratio < 1.0
        @test result.tcer[1] > 0
        # Calculated curve should have correct length
        @test length(result.ycal[1]) == 36
    end

    @testset "TextTable reading" begin
        data = TextTable(joinpath(@__DIR__, "testdata.txt"))
        @test size(data) == (8, 3)       # 8 rows, 3 columns (t, rep1, rep2)
        @test data[1, 1] ≈ 0.0          # first time
        @test data[2, 2] ≈ 0.1097       # first rep, second row
        @test data[2, 3] ≈ 0.0935       # second rep, second row
    end

    @testset "ExcelTable reading" begin
        data = ExcelTable(joinpath(@__DIR__, "testdata.xlsx"))
        @test size(data) == (8, 3)       # 8 rows, 3 columns (header skipped)
        @test data[1, 1] ≈ 0.0
        @test data[2, 2] ≈ 0.1097
        @test data[2, 3] ≈ 0.0935
    end

    @testset "Matrix with replicates expansion" begin
        # 3 time points, 2 replicates → 6 interleaved data points
        mat = [0.0  1.0  2.0;
               5.0  3.0  4.0;
               10.0 5.0  6.0]
        curve = ExtractionCurve(
            data = mat,
            porosity = 0.4,
            x0 = 0.05,
            solid_density = 1.1,
            solvent_density = 0.8,
            flow_rate = 5.0,
            bed_height = 20.0,
            bed_diameter = 2.0,
            particle_diameter = 0.05,
            solid_mass = 50.0,
            solubility = 0.005,
        )
        # Should have 6 data points (3 rows × 2 replicates)
        @test length(curve.t) == 6
        @test length(curve.m_ext) == 6
        # Times repeated per replicate: [0, 0, 5, 5, 10, 10] in minutes → SI
        @test curve.t[1] ≈ 0.0 * 60.0
        @test curve.t[2] ≈ 0.0 * 60.0
        @test curve.t[3] ≈ 5.0 * 60.0
        @test curve.t[4] ≈ 5.0 * 60.0
        # m_ext interleaved: [1, 2, 3, 4, 5, 6] in g → kg
        @test curve.m_ext[1] ≈ 1.0 / 1000.0
        @test curve.m_ext[2] ≈ 2.0 / 1000.0
        @test curve.m_ext[3] ≈ 3.0 / 1000.0
        @test curve.m_ext[4] ≈ 4.0 / 1000.0
    end
end
