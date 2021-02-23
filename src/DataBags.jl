module DataBags

export
    DataBag,
    contents,
    wrap

using Dates

"""

`AbstractDataBag{K,V,D}` is the super-type of data-bags.

"""
abstract type AbstractDataBag{K,V,D<:AbstractDict{K,V}} <: AbstractDict{K,V} end

struct DataBag{K,V,D<:AbstractDict{K,V}} <: AbstractDataBag{K,V,D}
    data::D
    DataBag{K,V,D}(data::D) where {K,V,D<:AbstractDict{K,V}} =
        new{K,V,D}(data)
end

# Generic outer constructors relying on `contents(Dict{K,V},...)` to build
# their contents.
DataBag(args...; kwds...) =
    wrap(DataBag, contents(Dict{Any,Any}, args...; kwds...))
DataBag{K}(args...; kwds...) where {K} =
    wrap(DataBag, contents(Dict{K,Any}, args...; kwds...))
DataBag{K,V}(args...; kwds...) where {K,V} =
    wrap(DataBag, contents(Dict{K,V}, args...; kwds...))

# Extends the `contents` methods to benefit from the API of `AbstractDataBag`.
@inline contents(A::DataBag) = Base.getfield(A, :data)

"""
    DataBags.contents(A)

yields the contents associated with an instance `A` of a sub-type of
`DataBags.AbstractDataBag` or of `AbstractDict`.

This method should be specialized by types derived from
`DataBags.AbstractDataBag`, this is the most simple way to inherit of the
common behavior implemented by this abstract type.

The `contents` method is also meant to be called by data-bag constructors to
create a new dictionary out of their arguments.  For that usage, the syntax is:

    content(Dict{K,V}, args...; kwds...) -> Dict

which yields a new dictionary built out of arguments `args` and keywords `kwds`
and accounting for type constraints set by `K` and `V` for respectively the
keys and values of the returned dictionary.  Types `K` and/or `V` can be ``Any`
if no type constraints are imposed.

""" contents

@noinline contents(::T) where {T<:AbstractDataBag} =
    error(string("method DataBags.contents has not been specialized for ", T))
@inline contents(A::AbstractDict) = A

# Methods for initial contents set from an existing dictionary data
# (e.g. another data-bag).  We create a new empty dictionary with proper
# key and value types and fill it with the contents of the argument.
contents(::Type{Dict{Any,Any}}, A::AbstractDict{K}) where {K} =
    merge!(Dict{K,Any}(), contents(A))
contents(::Type{Dict{K,Any}}, A::AbstractDict) where {K} =
    merge!(Dict{K,Any}(), contents(A))
contents(::Type{Dict{Any,V}}, A::AbstractDict{K}) where {K,V} =
    merge!(Dict{K,V}(), contents(A))
contents(::Type{Dict{K,V}}, A::AbstractDict) where {K,V} =
    merge!(Dict{K,V}(), contents(A))

# Methods for initial contents specified by keywords.
contents(::Type{Dict{Any,Any}}; kwds...) = Dict{Symbol,Any}(kwds...)
contents(::Type{Dict{Symbol,Any}}; kwds...) = Dict{Symbol,Any}(kwds...)
contents(::Type{Dict{Any,V}}; kwds...) where {V} = Dict{Symbol,V}(kwds...)
contents(::Type{Dict{Symbol,V}}; kwds...) where {V} = Dict{Symbol,V}(kwds...)

# Methods for initial contents specified as key-value pairs.  Unless key or
# value types are explictely specified, we want to have a dictionary whose
# key type is the most specific (for efficiency) and having the least
# specific value type (for flexibility).  If type constraint or type of
# pairs are insufficient, we eventually first make a dictionary and
# convert it so as to use the least specific value type.  Conversion is
# no-op if the dictionary is already of the correct type.  Since the key
# type must be known, we need a helper function of the initial dictionary
# must be known
contents(::Type{Dict{K,V}}, args::Pair...) where {K,V} = Dict{K,V}(args...)
contents(::Type{Dict{K,Any}}, args::Pair...) where {K} = Dict{K,Any}(args...)
contents(::Type{Dict{Any,V}}, args::Pair{K}...) where {K,V} = Dict{K,V}(args...)
contents(::Type{Dict{Any,V}}, args::Pair{<:AbstractString}...) where {V} =
    Dict{String,V}(args...)
contents(::Type{Dict{Any,V}}, args::Pair...) where {V} =
    withspecificvaluetype(V, Dict(args...))
contents(::Type{Dict{Any,Any}}, args::Pair{K}...) where {K} =
    Dict{K,Any}(args...)
contents(::Type{Dict{Any,Any}}, args::Pair{<:AbstractString}...) =
    Dict{String,Any}(args...)
contents(::Type{Dict{Any,Any}}, args::Pair...) =
    withspecificvaluetype(Any, Dict(args...))

withspecificvaluetype(::Type{V}, data::Dict{<:Any,V}) where {V} = data
withspecificvaluetype(::Type{V}, data::Dict{K}) where {K,V} = Dict{K,V}(data)

"""
    wrap(T::Type{<:AbstractDataBag}, arg) -> obj::T

wraps argument `arg` in a data-bag of type `T`.  The returned object shares
its contents with `arg`.

This method can be used to build a data-bag from an existing dictionary
without duplicating the dictionary.  As an example:

    dict = Dict{Symbol,Any}(:a => 1, :foo => "bar")
    cont = wrap(DataBag, dict)
    cont.b = 33
    dict["b"] == 33 # yields `true`

If the statement `wrap(DataBag, dict)` is replaced by `DataBag(dict)`, the
result of the last statement is `false`.

"""
wrap(::Type{DataBag}, data::D) where {K,V,D<:AbstractDict{K,V}} =
    DataBag{K,V,D}(data)
wrap(::Type{DataBag{K}}, data::D) where {K,V,D<:AbstractDict{K,V}} =
    wrap(DataBag, data)
wrap(::Type{DataBag{K,V}}, data::D) where {K,V,D<:AbstractDict{K,V}} =
    wrap(DataBag, data)
wrap(::Type{DataBag{K,V,D}}, data::D) where {K,V,D<:AbstractDict{K,V}} =
    wrap(DataBag, data)

"""
    DataBags.@newtype T

creates a new data-bag type `T` which is a sub-type of
`DataBags.AbstractDataBag` with symbolic keys and values of `Any` type.

"""
macro newtype(sym)
    isa(sym, Symbol) || throw(ArgumentError("argument must be a symbol"))
    T = esc(sym)
    quote
        struct $T <: DataBags.AbstractDataBag{Symbol,Any,Dict{Symbol,Any}}
            data::Dict{Symbol,Any}
            $T(args...; kwds...) =
                new(DataBags.contents(Dict{Symbol,Any}, args...; kwds...))
        end
        @inline DataBags.contents(A::$T) = Base.getfield(A, :data)
    end
end

"""
    DataBags.propertyname(T, sym)

converts symbol `sym` to a suitable key for data-bag of type `T` (a sub-type of
`DataBags.AbstractDataBag`), throwing an error if this conversion is not
supported.

"""
propertyname(::Type{<:AbstractDataBag{Symbol}}, sym::Symbol) = sym
propertyname(::Type{<:AbstractDataBag{String}}, sym::Symbol) = String(sym)
@noinline propertyname(::Type{T}, sym::Symbol) where {K,T<:AbstractDataBag{K}} =
    error(string("Converting symbolic key to type `", K, "` is not ",
                 "implemented. As a result, syntax `obj.key` is not ",
                 "supported for objects of type `", T, "`."))

# Extend methods so that syntax `obj.field` can be used.
@inline Base.getproperty(A::T, sym::Symbol) where {T<:AbstractDataBag} =
    getindex(contents(A), propertyname(T, sym))
@inline Base.setproperty!(A::T, sym::Symbol, val) where {T<:AbstractDataBag} =
    setindex!(contents(A), val, propertyname(T, sym))

# FIXME: Should return `Tuple(keys(contents(A)))` to conform to the doc. of
#        `propertynames` but this is slower and for most purposes, an iterable
#        is usually needed.
Base.propertynames(A::AbstractDataBag, private::Bool=false) = keys(A)

Base.convert(::Type{T}, A::T) where {T<:AbstractDataBag} = A
Base.convert(::Type{T}, A::AbstractDataBag) where {T<:AbstractDataBag} =
    T(A)

Base.keytype(::T) where {T<:AbstractDataBag} = keytype(T)
Base.keytype(::Type{<:AbstractDataBag{K,V}}) where {K,V} = K

Base.valtype(::T) where {T<:AbstractDataBag} = valtype(T)
Base.valtype(::Type{<:AbstractDataBag{K,V}}) where {K,V} = V

Base.length(A::AbstractDataBag) = length(contents(A))

Base.iterate(A::AbstractDataBag) = iterate(contents(A))
Base.iterate(A::AbstractDataBag, state) = iterate(contents(A), state)

Base.haskey(A::AbstractDataBag, key) = haskey(contents(A), key)
Base.keys(A::AbstractDataBag) = keys(contents(A))
Base.values(A::AbstractDataBag) = values(contents(A))
Base.getkey(A::AbstractDataBag, key, def) = getkey(contents(A), key, def)
Base.get(A::AbstractDataBag, key, def) = get(contents(A), key, def)
Base.get!(A::AbstractDataBag, key, def) = get!(contents(A), key, def)
Base.getindex(A::AbstractDataBag, key) = getindex(contents(A), key)
Base.setindex!(A::AbstractDataBag, val, key) =
    (setindex!(contents(A), val, key); return A)
Base.delete!(A::AbstractDataBag, key) = begin
    delete!(contents(A), key)
    return A
end
Base.pop!(A::AbstractDataBag, key) = pop!(contents(A), key)
Base.pop!(A::AbstractDataBag, key, def) = pop!(contents(A), key, def)
Base.pairs(A::AbstractDataBag) = pairs(contents(A))

# Standard methods:
#
# - merge() and merge!() do not need to be specialized.
#
# - Specializing empty() and empty!() is sufficient for copy() and copy!()
#   to work.

Base.empty(A::DataBag{K,V}) where {K,V} =
    wrap(DataBag, empty(contents(A), K, V))
Base.empty(A::DataBag{<:Any,V}, ::Type{K}) where {K,V} =
    wrap(DataBag, empty(contents(A), K, V))
Base.empty(A::DataBag, ::Type{K}, ::Type{V}) where {K,V} =
    wrap(DataBag, empty(contents(A), K, V))

Base.empty!(A::AbstractDataBag) = begin
    empty!(contents(A))
    return A
end

function Base.show(io::IO, ::MIME"text/plain",
                   A::AbstractDataBag{K,V}) where {K,V}
    n = length(A)
    summary(io, A)
    println(io, ":")
    lstkeys = sort(collect(keys(A)))
    strkeys = repr.(lstkeys)
    maxlen = maximum(length, strkeys)
    spaces = [repeat(" ", r) for r in 0:maxlen]
    for i in 1:n
        key = lstkeys[i]
        str = strkeys[i]
        print(io, "  ", str, spaces[maxlen + 1 - length(str)], " => ")
        _showval(io, A[key])
        if (n -= 1) > 0
            println(io)
        end
    end
end

_showval(io::IO, val::Number) = print(io, val)
_showval(io::IO, val::AbstractString) = print(io, repr(val))
_showval(io::IO, val::AbstractRange) = print(io, repr(val))
_showval(io::IO, val::T) where {T} = summary(io, val)
_showval(io::IO, val::DateTime) = print(io, "DateTime(\"", repr(val), "\")")

end # module
