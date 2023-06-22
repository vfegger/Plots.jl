#--------------------------------------------------
## inspired by Base.@kwdef
"""
    define_attributes(level, expr, args...)

Takes a `struct` definition and recurses into its fields to create keywords by chaining the field names with the structs' name with underscore.
Also creates pluralized and non-underscore aliases for these keywords.
- `level` indicates which group of `plot`, `subplot`, `series`, etc. the keywords belong to.
- `expr` is the struct definition with default values like `Base.@kwdef`
- `args` can be any of the following
  - `match_table`: an expression of the form `:match = (symbols)`, with symbols whose default value should be `:match`
  - `alias_dict`: an expression of the form `:aliases = Dict(symbol1 => symbol2)`, which will create aliases such that `symbol1` is an alias for `symbol2`
"""
macro define_attributes(expr, args...)
    # TODO: pluralization, non_underscorisation, match-table
    match_table = :(:match = ())
    alias_dict = Dict()
    for arg in args
        if arg.head == :(=) && arg.args[1] == QuoteNode(:match)
            match_table = arg
        elseif arg.head == :(=) && arg.args[1] == QuoteNode(:aliases)
            alias_dict = eval(arg.args[2])
        else
            @warn "Unsupported extra argument $arg will be ignored"
        end
    end
    expr = macroexpand(__module__, expr) # to expand @static
    expr isa Expr && expr.head === :struct || error("Invalid usage of @add_attributes")
    if (T = expr.args[2]) isa Expr && (T.head === :<: || T.head === :curly)
        T = T.args[1]
    end

    key_dict = Dict()
    original = copy(expr)
    _splitdef!(expr.args[3], key_dict)

    insert_block = Expr(:block)
    push!(insert_block.args, :(
            const $(Symbol(lowercase(string(T)), "_defaults")) = $(NamedTuple(Symbol(lowercase(string(T)), "_", key)=> value for (key, value) in key_dict))
        ),
        #TODO: :(
        #     const $(Symbol(lowercase(string(T)), "_aliases")) = $(NamedTuple( value => key for value in alias_dict(key), key in keys(alias_dict)))
        # ),
    )
    # for (key, value) in key_dict
    #     # e.g. _series_defaults[key] = value
    #     exp_key = Symbol(lowercase(string(T)), "_", key)
    #     pl_key = makeplural(exp_key)
    #     if QuoteNode(exp_key) in match_table.args[2].args
    #         value = QuoteNode(:match)
    #     end
    #     field = QuoteNode(Symbol("_", level, "_defaults"))
    #     aliases = get(alias_dict, exp_key, nothing)
    #     push!(
    #         insert_block.args,
    #         Expr(
    #             :(=),
    #             Expr(:ref, Expr(:call, getfield, Plots, field), QuoteNode(exp_key)),
    #             value,
    #         ),
    #         :(Plots.add_aliases($(QuoteNode(exp_key)), $(QuoteNode(pl_key)))),
    #         :(Plots.add_aliases(
    #             $(QuoteNode(exp_key)),
    #             $(QuoteNode(Plots.make_non_underscore(exp_key)))...,
    #         )),
    #         :(Plots.add_aliases(
    #             $(QuoteNode(exp_key)),
    #             $(QuoteNode(Plots.make_non_underscore(pl_key)))...,
    #         )),
    #     )
    #     if aliases !== nothing
    #         pl_aliases = Plots.makeplural.(aliases)
    #         push!(
    #             insert_block.args,
    #             :(Plots.add_aliases(
    #                 $(QuoteNode(exp_key)),
    #                 $(aliases)...,
    #                 $(pl_aliases)...,
    #                 $(Iterators.flatten(Plots.make_non_underscore.(aliases)))...,
    #                 $(Iterators.flatten(Plots.make_non_underscore.(pl_aliases)))...,
    #             )),
    #         )
    #     end
    # end
    quote
        Base.@kwdef $original
        $insert_block
    end |> esc
end

function _splitdef!(blk, key_dict)
    for i in eachindex(blk.args)
        if (ei = blk.args[i]) isa Symbol
            #  var
            continue
        elseif ei isa Expr
            if ei.head === :(=)
                lhs = ei.args[1]
                if lhs isa Symbol
                    #  var = defexpr
                    var = lhs
                elseif lhs isa Expr && lhs.head === :(::) && lhs.args[1] isa Symbol
                    #  var::T = defexpr
                    var = lhs.args[1]
                    type = lhs.args[2]
                    if @isdefined(type) && isstructtype(type)
                        for field in fieldnames(getproperty(@__MODULE__, type))
                            key_dict[Symbol(var, "_", field)] =
                                :(getfield($(ei.args[2]), $(QuoteNode(field))))
                        end
                    end
                else
                    # something else, e.g. inline inner constructor
                    #   F(...) = ...
                    continue
                end
                defexpr = ei.args[2]  # defexpr
                # filter e.g. marker::Marker = Marker(...)
                if !(
                    defexpr isa Expr &&
                    defexpr.head == :call &&
                    defexpr.args[1] == ei.args[1].args[2]
                )
                    key_dict[var] = defexpr
                end
                blk.args[i] = lhs
            elseif ei.head === :(::) && ei.args[1] isa Symbol
                # var::Typ
                var = ei.args[1]
                key_dict[var] = defexpr
            elseif ei.head === :block
                # can arise with use of @static inside type decl
                _kwdef!(ei, value_args, key_args)
            end
        end
    end
    blk
end
