module Playground

using Preferences

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
    size::Union{Symbol, Tuple{Int, Int}, Tuple{Tuple{Int, Symbol}, Tuple{Int, Symbol}}} = :auto
end :aliases = Dict(:plot_size => :size)

function plot(; backend = Symbol(@load_preference("backend", "gr")), kwargs...)
    plotattributes = Base.@locals
    for (k, v) in kwargs
        plotattributes[getproperty(aliases, k)] = v
    end
    @show plotattributes
    return Plot{plotattributes[:backend]}()
end

recipe(args...; kwargs...) = plot(args...; seriestype = :recipe, kwargs...)

function __init__()
    @show defaults
end

end # module Playground
