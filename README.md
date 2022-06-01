# Flexible data containers for Julia

[![License][license-img]][license-url]
[![Build Status][github-ci-img]][github-ci-url]
[![Build Status][appveyor-img]][appveyor-url]
[![Coverage][codecov-img]][codecov-url]

`DataBags` is a small [Julia][julia-url] package providing *data-bags* which
are a quick way to store structured data.  Data-bags combine properties and
dictionaries to associate keys (preferably symbols or strings) with values (of
any types) in a flexible way.  From the user viewpoint, data-bags behave like
dynamic structures whose fields can be modified or created with the syntax of
structured objects, *i.e.* `obj.key`.  They can also be deleted by calling
`delete!(obj,key)`.  As an example:

```julia
using DataBags, Dates
A = DataBag(date = now(), Δx = 0.1, x = -3:0.1:5)
A.Δx              # get value of key `Δx`
A.y = sin.(A.x)   # creates new key `y`
```

which shows how easy it is to create a data-bag and access its fields.
Data-bags can also be indexed by their keys like dictionaries:

```julia
A[:Δx]              # is the same as `A.Δx`
A[:y] = cos.(A[:x]) # is the same as `A.y = cos.(A.x)`
```

but this is, to my opinion, less readable and boring to type especially in an
interactive session.  More generally, data-bag types are sub-types of
`AbstractDict` so you can expect that data-bags can be used like dictionaries.
For instance, you can apply `pop`, `merge`, `merge!`, `delete!`, *etc.* on a
data-bag.

Admittedly, data-bags are less efficient than true Julia structures (there is
some overhead for retrieving a field of a data-bag) but they can be very
handful in interactive sessions or when designing new code: when the exact
contents of your data structures is not yet determined, data-bags let you
extend their contents without the pain of redefining your structures,
re-including your code and recreating your objects, *etc.* Tools such as
[`Revise`][revise-url] can help but cannot automatically determine what to do
with new members of existing objects if their type definition has changed.


## Creation of data-bags

Data-bags are created by calling the `DataBag(...)` constructor.  The initial
contents of data-bags can be specified by keywords, by key-value pairs, or as a
dictionary (`AbstractDict`).  To avoid ambiguities, these different styles
cannot be mixed.  Below are a few examples:

```julia
using DataBags
A = DataBag( units  =  "µm",  Δx  =  0.1,  Δy  =  0.2)
B = DataBag(:units  => "µm", :Δx  => 0.1, :Δy  => 0.2)
C = DataBag("units" => "µm", "Δx" => 0.1, "Δy" => 0.2)
D = DataBag(1 => 0.9, 2 => sqrt(2), 3 => 4)
```

These statements yield two data-bags, `A` and `B`, with symbolic keys (of type
`Symbol`), a data-bag, `C`, with textual keys (of type `String`) and a
data-bag, `D`, with integer keys (of type `Int`).  All these data-bags can
store values of `Any` type.

Accessing a value is possible via the syntax `obj[key]` or, for symbolic and
textual keys, via the syntax `obj.key`.  Accessing values via the syntax
`obj.key` is faster for symbolic keys than for textual keys (because it
involves converting a symbol into a string).

Data-bag constructors attempt to favor symbolic or string keys (to exploit the
`obj.key` syntax) and enforce unspecific values of `Any` type (for
flexibility).  In order to override these rules, the parametric versions
`DataBag{K}` or `DataBag{K,V}` of the constructor, with `K` the key type and
`V` the value type, can be called instead.  For example:

```julia
E = DataBag{Integer}(1 => 0.9, 2 => sqrt(2), 3 => 4)
F = DataBag{Integer,Real}(1 => 0.9, 2 => sqrt(2), 3 => 4)
```

yield two data-bags, `E` and `F`, both with integer keys (of any `Integer`
type), the values of `E` are unspecific while the values of `F` are restricted
to be `Real`.

The same rules apply if the data-bag is built out of an existing dictionary
(remember that data-bags are themselves abstract dictionaries).  So
`DataBag(F)` yields a data-bag with keys of the same type as those of `F` (that
is `Integer` in that case) but values of `Any` type.

When a data-bag is built out of an existing dictionary, the data-bag creates a
new dictionary to store its values and initializes it with the contents of the
dictionary passed in argument.  After the creation of the data-bag, the
data-bag and the original dictionary are independent.  Their values, which may
be references to other objects, may not be independent though.  If you want to
make a data-bag that stores its contents in a given dictionary, say `dict`,
call:

```julia
wrap(DataBag, dict)
```

instead of:

```julia
DataBag(dict)
```

If no arguments nor keywords are specified, the data-bag created by `DataBag()`
is initially empty and has symbolic keys with any type of values, *i.e.* an
instance of `Dict{Symbol,Any}` is used for storing the key-value pairs.

Unless `iterate` is overridden, iterating on an `AbstractDataBag` is iterating
on its key-value pairs.

Calling the `contents` method on an `AbstractDataBag` yields the internal
object, an `AbstractDict`, used to store the data of the data-bag.


## Defining custom data-bag types

The `DataBags` package provides simple means to facilitate creating new
sub-types of `DataBags.AbstractDataBag` so as to benefit from the common
interface implemented for data-bags.  The following steps are needed:

1. Make your type inherit from `DataBags.AbstractDataBag{K,V,D}` with `K` the
   key type, `V` the value type and `D<:AbstractDict{K,V}` the type of the
   dictionary storing the key-value pairs.

2. Extend the `DataBags.contents(A::T)` method for your custom type `T` so that
   it returns the dictionary storing the key-value pairs in an instance `A`.

3. Optionally provide some constructor(s) to facilitate creation of objects of
   type `T`.  You may also consider extending the `DataBags.wrap` method if.

Here is a first example:

```julia
using DataBags

# Define a concrete sub-type of `DataBags.AbstractDataBag`.
struct BagEx1{K,V,D<:AbstractDict{K,V}} <: DataBags.AbstractDataBag{K,V,D}
    data::D # object used to store key-value pairs
    ...     # another member
    ...     # yet another member
    ...     # etc.
end

# Override `DataBags.contents` to yield the dictionary that stores the data.
DataBags.contents(A::BagEx1) = Base.getfield(A, :data)
```

Note that `Base.getfield` has to be used to retrieve a member of objects whose
type is derived from `DataBags.AbstractDataBag` as for the member `data` of the
object `A` in the above example.  This is because the `getproperty` and
`setproperty!` methods are overridden to implement the `obj.key` syntax for
sub-types of `DataBags.AbstractDataBag`.

In the above example, it is only possible to create a data-bag of type
`BagEx1` out of a dictionary which is shared by the data-bag.  The only
advantage over a simple dictionary is the `obj.key` syntax provided keys have
type `Symbol` or `String`.

To improve over this first example, we want to implement the same kind of
creation rules as `DataBag`.  This leads to the following code:

```julia
using DataBags

# Define a concrete sub-type of `DataBags.AbstractDataBag`.
struct BagEx2{K,V,D<:AbstractDict{K,V}} <: DataBags.AbstractDataBag{K,V,D}
    data::D # object used to store key-value pairs
    ...     # another member
    ...     # yet another member
    ...     # etc.
    # Explicitely define inner constructor to avoid outer constructor
    # automatically created by Julia.
    BagEx2{K,V,D}(data::D) where {K,V,D<:AbstractDict{K,V}} = new{K,V,D}(data)
end

# Outer constructor.
BagEx2(args...; kdws...) =
    wrap(BagEx2, contents(Dict{Any,Any}, args...; kdws...))

# Override `DataBags.contents` to yield the dictionary that stores the data.
DataBags.contents(A::BagEx2) = Base.getfield(A, :data)

# Override `DataBags.wrap` to create an instance of `BagEx2` that stores
# its data in a given dictionary.
DataBags.wrap(::Type{BagEx2}, data::D) where {K,V,D<:AbstractDict{K,V}} =
    BagEx2{K,V,D}(data)
```

In this second example, we have:

* Explictely defined an inner constructor so as to forbid creating a data-bag
  that shares an existing dictionary, say `dict`, by calling the constructor
  `BagEx2`.  This is however possible by calling `wrap(BagEx2,dict)`.

* Defined an outer constructor that calls the `wrap` method over the dictionary
  created by the `DataBags.contents` method called with `Dict{K,V}` as a first
  argument, followed by all arguments and keywords passed to your constructor:

* Overridden methods `DataBags.contents` (as in the first example) and
  `DataBags.wrap`.  The latter is to wrap a dictionary in a new `BagEx2`
  instance taking care of supplying the correct type parameters `{K,V,D}`.

To add constructors with constraints on the type of keys and values, you may
have a look at the complete implementation of the `DataBag` type which is
summarized below:

```julia
struct DataBag{K,V,D<:AbstractDict{K,V}} <: AbstractDataBag{K,V,D}
    data::D # data data-bag
    # Provide inner constructor to let outer constructors deal with type
    # parameters.
    DataBag{K,V,D}(data::D) where {K,V,D<:AbstractDict{K,V}} =
        new{K,V,D}(data)
end

# Outer constructors.
DataBag(args...; kwds...) =
    wrap(DataBag, contents(Dict{Any,Any}, args...; kwds...))
DataBag{K}(args...; kwds...) where {K} =
    wrap(DataBag, contents(Dict{K,Any}, args...; kwds...))
DataBag{K,V}(args...; kwds...) where {K,V} =
    wrap(DataBag, contents(Dict{K,V}, args...; kwds...))

# Extends the `contents` method to benefit from the API of `AbstractDataBag`.
@inline contents(A::DataBag) = Base.getfield(A, :data)

# Extend the `wrap` method to create instances of `DataBag`.
wrap(::Type{DataBag}, data::D) where {K,V,D<:AbstractDict{K,V}} =
    DataBag{K,V,D}(data)
wrap(::Type{DataBag{K}}, data::D) where {K,V,D<:AbstractDict{K,V}} =
    wrap(DataBag, data)
wrap(::Type{DataBag{K,V}}, data::D) where {K,V,D<:AbstractDict{K,V}} =
    wrap(DataBag, data)
wrap(::Type{DataBag{K,V,D}}, data::D) where {K,V,D<:AbstractDict{K,V}} =
    wrap(DataBag, data)
```

## A useful minimalist example

The `DataBag` type provided by `DataBags` may be sufficient for your needs but
you may want to specialize it a bit to exploit the power of *type dispatching*
in Julia and to implement some specific behavior.  The most simple example of
creating such a sub-type takes about half a dozen of lines of code:

```julia
using DataBags
struct BagEx3 <: DataBags.AbstractDataBag{Symbol,Any,Dict{Symbol,Any}}
    data::Dict{Symbol,Any}
    BagEx3(args...; kwds...) =
        new(DataBags.contents(Dict{Symbol,Any}, args...; kwds...))
end
DataBags.contents(A::BagEx3) = Base.getfield(A, :data)
```

*Et voilà!* That is all you need to create a new type, `BagEx3`, whose
instances behave like a dictionary with symbolic keys and any type of values,
implement the `obj.key` syntax to get/set the value of `key` (as a shortcut of
`obj[:key]`) and which can be constructed using keywords, *e.g.* `obj =
BagEx3(id=1, x=-3.14:0.1:3.14, units="µm")`.

This usage is so common that a macro is provided by the `DataBags` package and
the above statements can be reduced to:

```julia
using DataBags
DataBags.@newtype BagEx3
```

using the macro not only saves typing (to encourage creating such data-bag
types) but also warrants that the implementation is correct and follows further
evolutions of the `DataBags` package.


[doc-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[doc-dev-url]: https://emmt.github.io/DataBags.jl/dev

[license-url]: ./LICENSE.md
[license-img]: http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat

[github-ci-img]: https://github.com/emmt/DataBags.jl/actions/workflows/CI.yml/badge.svg?branch=master
[github-ci-url]: https://github.com/emmt/DataBags.jl/actions/workflows/CI.yml?query=branch%3Amaster

[appveyor-img]: https://ci.appveyor.com/api/projects/status/github/emmt/DataBags.jl?branch=master
[appveyor-url]: https://ci.appveyor.com/project/emmt/DataBags-jl/branch/master

[codecov-img]: https://codecov.io/gh/emmt/DataBags.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/emmt/DataBags.jl

[julia-url]: https://julialang.org/

[revise-url]: https://github.com/timholy/Revise.jl
