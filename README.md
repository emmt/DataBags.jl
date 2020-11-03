# Flexible data containers for Julia

| **License**                     | **Build Status**                                                | **Code Coverage**                                                   |
|:--------------------------------|:----------------------------------------------------------------|:--------------------------------------------------------------------|
| [![][license-img]][license-url] | [![][travis-img]][travis-url] [![][appveyor-img]][appveyor-url] | [![][coveralls-img]][coveralls-url] [![][codecov-img]][codecov-url] |

`Containers` is a small [Julia][julia-url] package which combines properties
and dictionaries to associate keys (preferably symbols or strings) with values
(of any types) in a flexible way.  From the user viewpoint, containers behave
like dynamic structures whose fields can be modified or created with the syntax
of structured objects, *i.e.* `obj.key`.  They can also be deleted by calling
`delete!(obj,key)`.  As an example:

```julia
using Containers, Dates
A = Container(date = now(), Δx = 0.1, x = -3:0.1:5)
A.Δx              # get value of key `Δx`
A.y = sin.(A.x)   # creates new key `y`
```

which shows how easy it is to create a container and access its fields.
Containers can also be indexed by their keys like dictionaries:

```julia
A[:Δx]              # is the same as `A.Δx`
A[:y] = cos.(A[:x]) # is the same as `A.y = cos.(A.x)`
```

but this is, to my opinion, less readable and boring to type especially in an
interactive session.  More generally, container types are sub-types of
`AbstractDict` so you can expect that containers can be used like dictionaries.
For instance, you can apply `pop`, `merge`, `merge!`, `delete!`, *etc.* on a
container.

Admittedly, containers are less efficient than true Julia structures (there is
some overhead for retrieving a field of a container) but they can be very
handful in interactive sessions or when designing new code: when the exact
contents of your data structures is not yet determined, containers let you
extend their contents without the pain of redefining your structures,
re-including your code and recreating your objects, *etc.* Tools such as
[`Revise`][revise-url] can help but cannot automatically determine what to do
with new members of existing objects if their type definition has changed.


## Creation of containers

Containers are created by calling the `Container(...)` constructor.  The
initial contents of containers can be specified by keywords, by key-value
pairs, or as a dictionary (`AbstractDict`).  To avoid ambiguities, these
different styles cannot be mixed.  Below are a few examples:

```julia
using Containers
A = Container( units  =  "µm",  Δx  =  0.1,  Δy  =  0.2)
B = Container(:units  => "µm", :Δx  => 0.1, :Δy  => 0.2)
C = Container("units" => "µm", "Δx" => 0.1, "Δy" => 0.2)
D = Container(1 => 0.9, 2 => sqrt(2), 3 => 4)
```

These statements yield two containers, `A` and `B`, with symbolic keys (of type
`Symbol`), a container, `C`, with textual keys (of type `String`) and a
container, `D`, with integer keys (of type `Int`).  All these containers can
store values of `Any` type.

Accessing a value is possible via the syntax `obj[key]` or, for symbolic and
textual keys, via the syntax `obj.key`.  Accessing values via the syntax
`obj.key` is faster for symbolic keys than for textual keys (because it
involves converting a symbol into a string).

Container constructors attempt to favor symbolic or string keys (to exploit the
`obj.key` syntax) and enforce unspecific values of `Any` type (for
flexibility).  In order to override these rules, the parametric versions of the
`Container` constructor can be called instead:

```julia
E = Container{Integer}(1 => 0.9, 2 => sqrt(2), 3 => 4)
F = Container{Integer,Real}(1 => 0.9, 2 => sqrt(2), 3 => 4)
```

yield two containers, `E` and `F`, with integer keys (of any `Integer` type),
the values of `E` are unspecific while the values of `F` are restricted to be
`Real`.

The same rules apply if the container is built out of an existing dictionary
(do not forget that containers are themselves abstract dictionaries).  So
`Container(F)` yields a container with keys of the same type as those of `F`
(that is `Integer` in that case) but values of `Any` type.

When a container is built out of an existing dictionary, the container creates
a new dictionary to store its values and initializes it with the contents of
the dictionary passed in argument.  After the creation of the container, the
container and the original dictionary are independent.  Their values, which may
be references to other objects, may not be independent though.  If you want to
make a container that stores its contents in a given dictionary, say `dict`,
call:

```julia
wrap(Container, dict)
```

instead of:

```julia
Container(dict)
```

If no arguments nor keywords are specified, the container created by
`Container()` is initially empty and has symbolic keys with any type of values,
*i.e.* an instance of `Dict{Symbol,Any}` is used for storing the key-value
pairs.

Unless `iterate` is overridden, iterating on an `AbstractContainer` is
iterating on its key-value pairs.

Calling the `contents` method on an `AbstractContainer` yields the internal
object, an `AbstractDict`, used to store the data of the container.


## Defining custom container types

The `Containers` package provides simple means to facilitate creating new
sub-types of `Containers.AbstractContainer` so as to benefit from the common
interface implemented for containers.  The following steps are needed:

1. Make your type inherit from `Containers.AbstractContainer{K,V,D}` with `K`
   the key type, `V` the value type and `D<:AbstractDict{K,V}` the type of the
   dictionary storing the key-value pairs.

2. Extend the `Containers.contents(A::T)` method for your custom type `T` so
   that it returns the dictionary storing the key-value pairs in an instance
   `A`.

3. Optionally provide some constructor(s) to facilitate creation of objects of
   type `T`.  You may also consider extending the `Containers.wrap` method if.

Here is a first example:

```julia
using Containers

# Define a concrete sub-type of `Containers.AbstractContainer`.
struct ContEx1{K,V,D<:AbstractDict{K,V}} <: Containers.AbstractContainer{K,V,D}
    data::D # object used to store key-value pairs
    ...     # another member
    ...     # yet another member
    ...     # etc.
end

# Override `Containers.contents` to yield the dictionary that stores the data.
Containers.contents(A::ContEx1) = Base.getfield(A, :data)
```

Note that `Base.getfield` has to be used to retrieve a member of objects
whose type is derived from `Containers.AbstractContainer` as for the member
`data` of the object `A` in the above example.  This is because the
`getproperty` and `setproperty!` methods are overridden to implement the
`obj.key` syntax for sub-types of `Containers.AbstractContainer`.

In the above example, it is only possible to create a container of type
`ContEx1` out of a dictionary which is shared by the container.  The only
advantage over a simple dictionary is the `obj.key` syntax provided keys have
type `Symbol` or `String`.

To improve over this first example, we want to implement the same kind of
creation rules as `Container`.  This leads to the following code:

```julia
using Containers

# Define a concrete sub-type of `Containers.AbstractContainer`.
struct ContEx2{K,V,D<:AbstractDict{K,V}} <: Containers.AbstractContainer{K,V,D}
    data::D # object used to store key-value pairs
    ...     # another member
    ...     # yet another member
    ...     # etc.
    # Explicitely define inner constructor to avoid outer constructor
    # automatically created by Julia.
    ContEx2{K,V,D}(data::D) where {K,V,D<:AbstractDict{K,V}} = new{K,V,D}(data)
end

# Outer constructor.
ContEx2(args...; kdws...) =
    wrap(ContEx2, contents(Dict{Any,Any}, args...; kdws...))

# Override `Containers.contents` to yield the dictionary that stores the data.
Containers.contents(A::ContEx2) = Base.getfield(A, :data)

# Override `Containers.wrap` to create an instance of `ContEx2` that stores
# its data in a given dictionary.
Containers.wrap(::Type{ContEx2}, data::D) where {K,V,D<:AbstractDict{K,V}} =
    ContEx2{K,V,D}(data)
```

In this second example, we have:

* Explictely defined an inner constructor so as to forbid creating a container
  that shares an existing dictionary, say `dict`, by calling the constructor
  `ContEx2`.  This is however possible by calling `wrap(ContEx2,dict)`.

* Defined an outer constructor that calls the `wrap` method over the dictionary
  created by the `Containers.contents` method called with `Dict{K,V}` as a
  first argument, followed by all arguments and keywords passed to your
  constructor:

* Overridden methods `Containers.contents` (as in the first example) and
  `Containers.wrap`.  The latter is to wrap a dictionary in a new `ContEx2`
  instance taking care of supplying the correct type parameters `{K,V,D}`.

To add constructors with constraints on the type of keys and values, you may
have a look at the complete implementation of the `Container` type which is
summarized below:

```julia
struct Container{K,V,D<:AbstractDict{K,V}} <: AbstractContainer{K,V,D}
    data::D # data container
    # Provide inner constructor to let outer constructors deal with type
    # parameters.
    Container{K,V,D}(data::D) where {K,V,D<:AbstractDict{K,V}} =
        new{K,V,D}(data)
end

# Outer constructors.
Container(args...; kwds...) =
    wrap(Container, contents(Dict{Any,Any}, args...; kwds...))
Container{K}(args...; kwds...) where {K} =
    wrap(Container, contents(Dict{K,Any}, args...; kwds...))
Container{K,V}(args...; kwds...) where {K,V} =
    wrap(Container, contents(Dict{K,V}, args...; kwds...))

# Extends the `contents` method to benefit from the API of `AbstractContainer`.
@inline contents(A::Container) = Base.getfield(A, :data)

# Extend the `wrap` method to create instances of `Container`.
wrap(::Type{Container}, data::D) where {K,V,D<:AbstractDict{K,V}} =
    Container{K,V,D}(data)
wrap(::Type{Container{K}}, data::D) where {K,V,D<:AbstractDict{K,V}} =
    wrap(Container, data)
wrap(::Type{Container{K,V}}, data::D) where {K,V,D<:AbstractDict{K,V}} =
    wrap(Container, data)
wrap(::Type{Container{K,V,D}}, data::D) where {K,V,D<:AbstractDict{K,V}} =
    wrap(Container, data)
```

## A useful minimalist example

The `Container` type provided by `Containers` may be sufficient for your needs
but you may want to specialize it a bit to exploit the power of *type
dispatching* in Julia and to implement some specific behavior.  The most simple
example of creating such a sub-type takes about half a dozen of lines of code:

```julia
using Containers
struct ContEx3 <: Containers.AbstractContainer{Symbol,Any,Dict{Symbol,Any}}
    data::Dict{Symbol,Any}
    ContEx3(args...; kwds...) =
        new(Containers.contents(Dict{Symbol,Any}, args...; kwds...))
end
Containers.contents(A::ContEx3) = Base.getfield(A, :data)
```

*Et voilà!* That is all you need to create a new type, `ContEx3`, whose
instances behave like a dictionary with symbolic keys and any type of values,
implement the `obj.key` syntax to get/set the value of `key` (as a shortcut of
`obj[:key]`) and which can be constructed using keywords, *e.g.* `obj =
ContEx3(id=1, x=-3.14:0.1:3.14, units="µm")`.

This usage is so common that a macro is provided by the `Containers` package
and the above statements can be reduced to:

```julia
using Containers
Containers.@newtype ContEx3
```

using the macro not only saves typing (to encourage creating such container
types) but also warrants that the implementation is correct and follows further
evolutions of the `Containers` package.


[doc-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[doc-dev-url]: https://emmt.github.io/Containers.jl/dev

[license-url]: ./LICENSE.md
[license-img]: http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat

[travis-img]: https://travis-ci.com/emmt/Containers.jl.svg?branch=master
[travis-url]: https://travis-ci.com/emmt/Containers.jl

[appveyor-img]: https://ci.appveyor.com/api/projects/status/github/emmt/Containers.jl?branch=master
[appveyor-url]: https://ci.appveyor.com/project/emmt/Containers-jl/branch/master

[coveralls-img]: https://coveralls.io/repos/github/emmt/Containers.jl/badge.svg?branch=master
[coveralls-url]: https://coveralls.io/github/emmt/Containers.jl?branch=master

[codecov-img]: https://codecov.io/gh/emmt/Containers.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/emmt/Containers.jl

[julia-url]: https://julialang.org/

[revise-url]: https://github.com/timholy/Revise.jl
