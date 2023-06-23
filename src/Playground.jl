module Playground

using Preferences

const KW = Dict{Symbol, Any}
include("utils.jl")

const defaults = (
    palette = Symbol(@load_preference("palette", "default")),
)

const aliases = (be = :backend,)

function default(attribute)
    getproperty(defaults, attribute)
end

macro with(f, attributes)
    return quote
        new_defaults = merge($(Playground.defaults), $attributes)
        #will splice new_defaults in every plot/plot! call
    end |> esc
end

@define_attributes struct Plot{T}
    size::Union{Symbol, Tuple{Int, Int}, Tuple{Tuple{Int, Symbol}, Tuple{Int, Symbol}}} = eval(Meta.parse(@load_preference("plot_size", ":auto")))
end :aliases = Dict(:plot_size => (:size,))

function plot(; backend = Symbol(@load_preference("backend", "gr")), kwargs...)
    plotattributes = KW(kwargs...)
    @show plotattributes
    return Plot{backend}()
end

recipe(args...; kwargs...) = plot(args...; seriestype = :recipe, kwargs...)

function __init__()
    @show defaults
end

end # module Playground
