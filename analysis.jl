#!/usr/bin/env julia

using Pkg
Pkg.activate(@__DIR__)

using AvocadoAnalysis
using Statistics

const DEFAULT_RESIZE = (256, 256)
const DEFAULT_CUTOFF = 0.0
const DEFAULT_INVERT = false
const DEFAULT_IMAGES_DIR = joinpath(@__DIR__, "images")
const DEFAULT_OUTPUT_CSV = joinpath(@__DIR__, "results", "h0_persistence_summary.csv")

function finite_values(v::AbstractVector{<:Real})
    return filter(isfinite, Float64.(v))
end

function print_overall_summary(results)
    println("\nOverall summary across images")
    println("- Images analyzed: ", nrow(results))

    if nrow(results) == 0
        println("- No image files found.")
        return
    end

    medians = finite_values(results.median_persistence)
    means = finite_values(results.mean_persistence)
    stdevs = finite_values(results.std_persistence)

    println("- Mean finite intervals per image: ", round(mean(results.n_intervals_finite), digits = 2))

    if !isempty(medians)
        println("- Median of image median persistences: ", round(median(medians), digits = 6))
    end

    if !isempty(means)
        println("- Mean of image mean persistences: ", round(mean(means), digits = 6))
    end

    if !isempty(stdevs)
        println("- Mean of image persistence std: ", round(mean(stdevs), digits = 6))
    end
end

function main()
    results = analyze_directory(
        DEFAULT_IMAGES_DIR;
        resize_to = DEFAULT_RESIZE,
        cutoff = DEFAULT_CUTOFF,
        invert = DEFAULT_INVERT,
        output_csv = DEFAULT_OUTPUT_CSV,
    )

    println("Per-image 0D cubical persistence statistics")
    show(results; allrows = true, allcols = true)
    println()
    println("\nWrote CSV to: ", DEFAULT_OUTPUT_CSV)

    print_overall_summary(results)
end

main()
