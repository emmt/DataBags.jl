module DataBagsExamples

using DataBags

export
    BagEx1,
    BagEx2,
    BagEx3

#------------------------------------------------------------------------------
# EXAMPLE 1

# Define a concrete sub-type of `DataBags.AbstractDataBag`.
struct BagEx1{K,V,D<:AbstractDict{K,V}} <: DataBags.AbstractDataBag{K,V,D}
    data::D # object used to store key-value pairs
end

# Override `DataBags.contents` to yield the dictionary that stores the data.
DataBags.contents(A::BagEx1) = Base.getfield(A, :data)

#------------------------------------------------------------------------------
# EXAMPLE 2

# Define a concrete sub-type of `DataBags.AbstractDataBag`.
struct BagEx2{K,V,D<:AbstractDict{K,V}} <: DataBags.AbstractDataBag{K,V,D}
    # Object used to store key-value pairs.
    data::D

    # Explicitely define inner constructor to avoid outer constructor
    # automatically created by Julia.
    BagEx2{K,V,D}(data::D) where {K,V,D<:AbstractDict{K,V}} = new{K,V,D}(data)
end

# Override `DataBags.contents` to yield the dictionary that stores the data.
DataBags.contents(A::BagEx2) = Base.getfield(A, :data)

# Override `DataBags.wrap` to create an instance of `BagEx2` that stores
# its data in a given dictionary.
DataBags.wrap(::Type{BagEx2}, data::D) where {K,V,D<:AbstractDict{K,V}} =
    BagEx2{K,V,D}(data)

# Outer constructor.
BagEx2(args...; kdws...) =
    wrap(BagEx2, contents(Dict{Any,Any}, args...; kdws...))

#------------------------------------------------------------------------------
# EXAMPLE 3

struct BagEx3 <: DataBags.AbstractDataBag{Symbol,Any,Dict{Symbol,Any}}
    data::Dict{Symbol,Any}
    BagEx3(args...; kwds...) =
        new(DataBags.contents(Dict{Symbol,Any}, args...; kwds...))
end
DataBags.contents(A::BagEx3) = Base.getfield(A, :data)

end
