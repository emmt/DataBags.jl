module Containers

export
    Container,
    contents,
    wrap

using Dates

"""

`AbstractContainer{K,V,D}` is the super-type of containers.

"""
abstract type AbstractContainer{K,V,D<:AbstractDict{K,V}} <: AbstractDict{K,V} end

struct Container{K,V,D<:AbstractDict{K,V}} <: AbstractContainer{K,V,D}
    data::D
    Container{K,V,D}(data::D) where {K,V,D<:AbstractDict{K,V}} =
        new{K,V,D}(data)
end

# Generic outer constructors relying on `contents(Dict{K,V},...)` to build
# their contents.
Container(args...; kwds...) =
    wrap(Container, contents(Dict{Any,Any}, args...; kwds...))
Container{K}(args...; kwds...) where {K} =
    wrap(Container, contents(Dict{K,Any}, args...; kwds...))
Container{K,V}(args...; kwds...) where {K,V} =
    wrap(Container, contents(Dict{K,V}, args...; kwds...))

# Extends the `contents` methods to benefit from the API of `AbstractContainer`.
@inline contents(A::Container) = Base.getfield(A, :data)

"""

```julia
Containers.contents(A)
```

yields the contents associated with an instance `A` of a sub-type of
`Containers.AbstractContainer` or of `AbstractDict`.

This method should be specialized by types derived from
`Containers.AbstractContainer`, this is the most simple way to inherit of
the common behavior implemented by this abstract type.

The `contents` method is also meant to be called by container constructors
to create a new dictionary out of their arguments.  For that usage, the
syntax is:

```julia
content(Dict{K,V}, args...; kwds...) -> Dict
```

which yields a new dictionary built out of arguments `args` and keywords
`kwds` and accounting for type constraints set by `K` and `V` for
respectively the keys and values of the returned dictionary.  Types `K`
and/or `V` can be ``Any` if no type constraints are imposed.

""" contents

@noinline contents(::T) where {T<:AbstractContainer} =
    error(string("method Containers.contents has not been specialized for ", T))
@inline contents(A::AbstractDict) = A

# Methods for initial contents set from an existing dictionary data
# (e.g. another container).  We create a new empty dictionary with proper
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

```julia
wrap(T::Type, arg) -> obj::T
```

wraps argument `arg` in an object of type `T` which is returned.  The
returned object shares its contents with `arg`.

This method can be used to build a container from an existing dictionary
without duplicating the dictionary.  As an example:

```julia
dict = Dict{Symbol,Any}(:a => 1, :foo => "bar")
cont = wrap(Container, dict)
cont.b = 33
dict["b"] == 33
```

yields `true`. If the statement `wrap(Container, dict)` is replaced
by `Container(dict)`, the result of the final test is `false`.

"""
wrap(::Type{Container}, data::D) where {K,V,D<:AbstractDict{K,V}} =
    Container{K,V,D}(data)
wrap(::Type{Container{K}}, data::D) where {K,V,D<:AbstractDict{K,V}} =
    wrap(Container, data)
wrap(::Type{Container{K,V}}, data::D) where {K,V,D<:AbstractDict{K,V}} =
    wrap(Container, data)
wrap(::Type{Container{K,V,D}}, data::D) where {K,V,D<:AbstractDict{K,V}} =
    wrap(Container, data)

"""

```julia
Containers.propertyname(T, sym)
```

converts symbol `sym` to a suitable key for container of type `T` (a
sub-type of `Containers.AbstractContainer`), throwing an error if this
conversion is not supported.

"""
propertyname(::Type{<:AbstractContainer{Symbol}}, sym::Symbol) = sym
propertyname(::Type{<:AbstractContainer{String}}, sym::Symbol) = String(sym)
@noinline propertyname(::Type{T}, sym::Symbol) where {K,T<:AbstractContainer{K}} =
    error(string("Converting symbolic key to type `", K, "` is not ",
                 "implemented. As a result, syntax `obj.key` is not ",
                 "supported for objects of type `", T, "`."))

# Extend methods so that syntax `obj.field` can be used.
@inline Base.getproperty(A::T, sym::Symbol) where {T<:AbstractContainer} =
    getindex(contents(A), propertyname(T, sym))
@inline Base.setproperty!(A::T, sym::Symbol, val) where {T<:AbstractContainer} =
    setindex!(contents(A), val, propertyname(T, sym))

# FIXME: Should return `Tuple(keys(contents(A)))` to conform to the doc. of
#        `propertynames` but this is slower and for most purposes, an iterable
#        is usually needed.
Base.propertynames(A::AbstractContainer, private::Bool=false) = keys(A)

Base.convert(::Type{T}, A::T) where {T<:AbstractContainer} = A
Base.convert(::Type{T}, A::AbstractContainer) where {T<:AbstractContainer} =
    T(A)

Base.keytype(::T) where {T<:AbstractContainer} = keytype(T)
Base.keytype(::Type{<:AbstractContainer{K,V}}) where {K,V} = K

Base.valtype(::T) where {T<:AbstractContainer} = valtype(T)
Base.valtype(::Type{<:AbstractContainer{K,V}}) where {K,V} = V

Base.length(A::AbstractContainer) = length(contents(A))

Base.iterate(A::AbstractContainer) = iterate(contents(A))
Base.iterate(A::AbstractContainer, state) = iterate(contents(A), state)

Base.haskey(A::AbstractContainer, key) = haskey(contents(A), key)
Base.keys(A::AbstractContainer) = keys(contents(A))
Base.values(A::AbstractContainer) = values(contents(A))
Base.getkey(A::AbstractContainer, key, def) = getkey(contents(A), key, def)
Base.get(A::AbstractContainer, key, def) = get(contents(A), key, def)
Base.get!(A::AbstractContainer, key, def) = get!(contents(A), key, def)
Base.getindex(A::AbstractContainer, key) = getindex(contents(A), key)
Base.setindex!(A::AbstractContainer, val, key) = setindex!(contents(A), val, key)
Base.delete!(A::AbstractContainer, key) = begin
    delete!(contents(A), key)
    return A
end
Base.pop!(A::AbstractContainer, key) = pop!(contents(A), key)
Base.pop!(A::AbstractContainer, key, def) = pop!(contents(A), key, def)
Base.pairs(A::AbstractContainer) = pairs(contents(A))

# Standard methods:
#
# - merge() and merge!() do not need to be specialized.
#
# - Specializing empty() and empty!() is sufficient for copy() and copy!()
#   to work.

Base.empty(A::Container{K,V}) where {K,V} =
    wrap(Container, empty(contents(A), K, V))
Base.empty(A::Container{<:Any,V}, ::Type{K}) where {K,V} =
    wrap(Container, empty(contents(A), K, V))
Base.empty(A::Container, ::Type{K}, ::Type{V}) where {K,V} =
    wrap(Container, empty(contents(A), K, V))

Base.empty!(A::AbstractContainer) = begin
    empty!(contents(A))
    return A
end

function Base.show(io::IO, ::MIME"text/plain",
                   A::AbstractContainer{K,V}) where {K,V}
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
