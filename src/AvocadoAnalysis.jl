module AvocadoAnalysis

using CSV
using DataFrames
using FileIO
using Images: Gray
using ImageTransformations: imresize
using Ripserer
using Statistics

const DEFAULT_IMAGE_EXTENSIONS = Set([
    ".png",
    ".jpg",
    ".jpeg",
    ".tif",
    ".tiff",
    ".bmp",
])

"""
    list_image_files(images_dir; extensions = DEFAULT_IMAGE_EXTENSIONS)

Return sorted image file paths in `images_dir` filtered by extension.
"""
function list_image_files(
    images_dir::AbstractString;
    extensions::AbstractSet{<:AbstractString} = DEFAULT_IMAGE_EXTENSIONS,
)
    isdir(images_dir) || throw(ArgumentError("Image directory not found: $(images_dir)"))

    normalized_extensions = Set(lowercase(ext) for ext in extensions)
    files = String[]

    for file in readdir(images_dir)
        path = joinpath(images_dir, file)
        if isfile(path)
            extension = lowercase(splitext(file)[2])
            extension in normalized_extensions && push!(files, path)
        end
    end

    return sort(files)
end

"""
    load_and_resize_image(path; resize_to = (256, 256))

Load an image file, convert it to grayscale in `[0, 1]`, optionally invert
intensities (`x -> 1 - x`), and resize to the requested dimensions.
"""
function load_and_resize_image(
    path::AbstractString;
    resize_to::NTuple{2, Int} = (256, 256),
    invert::Bool = false,
)
    image = load(path)
    grayscale = Float64.(Gray.(image))
    processed = invert ? (1 .- grayscale) : grayscale
    resized = imresize(processed, resize_to)
    return clamp.(resized, 0.0, 1.0)
end

"""
    h0_cubical_diagram(image; cutoff = 0.0)

Compute the 0-dimensional persistence diagram from a cubical filtration.
"""
function h0_cubical_diagram(image::AbstractMatrix; cutoff::Real = 0.0)
    diagrams = ripserer(Cubical(image); dim_max = 0, cutoff = cutoff)
    return first(diagrams)
end

"""
    diagram_summary(diagram)

Compute summary statistics from a 0D persistence diagram.
"""
function diagram_summary(diagram)
    finite_intervals = collect(filter(isfinite, diagram))
    persistences = Float64[Ripserer.persistence(interval) for interval in finite_intervals]
    births = Float64[Ripserer.birth(interval) for interval in finite_intervals]
    deaths = Float64[Ripserer.death(interval) for interval in finite_intervals]

    n_total = length(diagram)
    n_finite = length(finite_intervals)

    if isempty(persistences)
        return (
            n_intervals_total = n_total,
            n_intervals_finite = n_finite,
            n_intervals_infinite = n_total - n_finite,
            median_persistence = NaN,
            mean_persistence = NaN,
            std_persistence = NaN,
            min_persistence = NaN,
            q25_persistence = NaN,
            q75_persistence = NaN,
            max_persistence = NaN,
            median_birth = NaN,
            median_death = NaN,
            mean_birth = NaN,
            mean_death = NaN,
        )
    end

    return (
        n_intervals_total = n_total,
        n_intervals_finite = n_finite,
        n_intervals_infinite = n_total - n_finite,
        median_persistence = median(persistences),
        mean_persistence = mean(persistences),
        std_persistence = std(persistences; corrected = false),
        min_persistence = minimum(persistences),
        q25_persistence = quantile(persistences, 0.25),
        q75_persistence = quantile(persistences, 0.75),
        max_persistence = maximum(persistences),
        median_birth = median(births),
        median_death = median(deaths),
        mean_birth = mean(births),
        mean_death = mean(deaths),
    )
end

"""
    analyze_image(path; resize_to = (256, 256), cutoff = 0.0)

Analyze one image and return a named tuple with persistence statistics.
"""
function analyze_image(
    path::AbstractString;
    resize_to::NTuple{2, Int} = (256, 256),
    cutoff::Real = 0.0,
    invert::Bool = false,
)
    resized = load_and_resize_image(path; resize_to = resize_to, invert = invert)
    diagram = h0_cubical_diagram(resized; cutoff = cutoff)
    stats = diagram_summary(diagram)

    return merge(
        (
            image_file = basename(path),
            image_path = abspath(path),
            resized_height = size(resized, 1),
            resized_width = size(resized, 2),
            cutoff = Float64(cutoff),
            invert = invert,
        ),
        stats,
    )
end

"""
    analyze_directory(images_dir; resize_to = (256, 256), cutoff = 0.0, output_csv = nothing)

Analyze all images in a directory and return a `DataFrame` with per-image statistics.
"""
function analyze_directory(
    images_dir::AbstractString;
    resize_to::NTuple{2, Int} = (256, 256),
    cutoff::Real = 0.0,
    invert::Bool = false,
    output_csv::Union{Nothing, AbstractString} = nothing,
)
    image_files = list_image_files(images_dir)
    rows = [analyze_image(path; resize_to = resize_to, cutoff = cutoff, invert = invert) for path in image_files]

    results = DataFrame(rows)

    if output_csv !== nothing
        mkpath(dirname(output_csv))
        CSV.write(output_csv, results)
    end

    return results
end

export analyze_directory
export analyze_image
export diagram_summary
export h0_cubical_diagram
export list_image_files
export load_and_resize_image

end
