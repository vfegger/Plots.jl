module Playground

using Preferences

const defaults = (
    backend = Symbol(@load_preference("backend", "gr")),
    palette = Symbol(@load_preference("palette", "default"))
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

struct Plot{T} end

function plot(; backend = defaults.backend, kwargs...)
    plotattributes = Base.@locals
    for (k, v) in kwargs
        plotattributes[getproperty(aliases, k)] = v
    end
    @show plotattributes
    return Plot{plotattributes[:backend]}()
end

function __init__()
    @show defaults
end

end # module Playground
