module ContainersExamples

using Containers

export
    ContEx1,
    ContEx2,
    ContEx3

#------------------------------------------------------------------------------
# EXAMPLE 1

# Define a concrete sub-type of `Containers.AbstractContainer`.
struct ContEx1{K,V,D<:AbstractDict{K,V}} <: Containers.AbstractContainer{K,V,D}
    data::D # object used to store key-value pairs
end

# Override `Containers.contents` to yield the dictionary that stores the data.
Containers.contents(A::ContEx1) = Base.getfield(A, :data)

#------------------------------------------------------------------------------
# EXAMPLE 2

# Define a concrete sub-type of `Containers.AbstractContainer`.
struct ContEx2{K,V,D<:AbstractDict{K,V}} <: Containers.AbstractContainer{K,V,D}
    # Object used to store key-value pairs.
    data::D

    # Explicitely define inner constructor to avoid outer constructor
    # automatically created by Julia.
    ContEx2{K,V,D}(data::D) where {K,V,D<:AbstractDict{K,V}} = new{K,V,D}(data)
end

# Override `Containers.contents` to yield the dictionary that stores the data.
Containers.contents(A::ContEx2) = Base.getfield(A, :data)

# Override `Containers.wrap` to create an instance of `ContEx2` that stores
# its data in a given dictionary.
Containers.wrap(::Type{ContEx2}, data::D) where {K,V,D<:AbstractDict{K,V}} =
    ContEx2{K,V,D}(data)

# Outer constructor.
ContEx2(args...; kdws...) =
    wrap(ContEx2, contents(Dict{Any,Any}, args...; kdws...))

#------------------------------------------------------------------------------
# EXAMPLE 3

struct ContEx3 <: Containers.AbstractContainer{Symbol,Any,Dict{Symbol,Any}}
    data::Dict{Symbol,Any}
    ContEx3(args...; kwds...) =
        new(Containers.contents(Dict{Symbol,Any}, args...; kwds...))
end
Containers.contents(A::ContEx3) = Base.getfield(A, :data)

end
