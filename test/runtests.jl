module DataBagsTests
using Test, DataBags, Dates
using DataBags: AbstractDataBag, propertyname, withspecificvaluetype

function samevalues(A::AbstractArray, B::AbstractArray)
    @assert has_standard_indexing(A, B)
    @assert size(A) == size(B)
    for i ∈ eachindex(A, B)
        A[i] != B[i] && return false
    end
    return true
end

function maxabsdif(A::AbstractArray, B::AbstractArray)
    @assert has_standard_indexing(A, B)
    @assert size(A) == size(B)
    T = promote_type(eltype(A), eltype(B))
    res = zero(T)
    for i ∈ eachindex(A, B)
        res = max(res, abs(A[i] - B[i]))
    end
    return res
end

keywords(args...; kwds...) = kwds
arguments(args...; kwds...) = args

# UnfinishedDataBag does not extend DataBags.contents()
struct UnfinishedDataBag{K,V,D<:AbstractDict{K,V}} <: AbstractDataBag{K,V,D}
    data::D
    UnfinishedDataBag{K,V,D}(data::D) where {K,V,D<:AbstractDict{K,V}} =
        new{K,V,D}(data)
end
UnfinishedDataBag(data::D) where {K,V,D<:AbstractDict{K,V}} =
    UnfinishedDataBag{K,V,D}(data)

# Create our own data-bag with provided macro.
DataBags.@newtype SmallDB

# Check show().
show(stdout, MIME"text/plain"(),
     DataBag(a=21, b=π, c="hello", d=-1.8:0.1:14, e=rand(5), date=now()))
println()

@testset "DataBags" begin
    # Check missing specialization of DataBags.contents().
    Q = UnfinishedDataBag(Dict{Symbol,Any}())
    @test_throws ErrorException Q.units

    # Check impossible indexing of weird key type.
    R = DataBag(Dict{Int,Int}())
    @test_throws ErrorException propertyname(typeof(R), Symbol(42))

    # DataBag with string keys.
    D1 = Dict("units" => "km", "Δx" => 0.20, "Δy" => 0.15)
    A1 = DataBag(D1)
    T1 = typeof(A1)
    B1 = wrap(DataBag, D1)
    @test length(A1) == length(D1)
    @test keytype(T1) == keytype(D1)
    @test valtype(T1) == valtype(D1)
    @test keytype(A1) == keytype(D1)
    @test valtype(A1) == valtype(D1)
    for (k,v) in zip(keys(A1), values(A1))
        @test D1[k] == v
    end
    for (k,v) in pairs(A1)
        @test D1[k] == v
    end
    # A1 and D1 should be different, B1 abd D1 should be the same:
    @test A1.units == A1["units"] == D1["units"]
    A1.units = 50
    @test contents(D1) === D1
    @test contents(B1) === D1
    @test contents(A1) !== D1
    @test propertyname(T1, :gizmo) == "gizmo"
    @test A1.units == A1["units"] != D1["units"]
    @test B1.units == B1["units"] == D1["units"]
    @test haskey(A1, "Δx") == true
    delete!(A1, "Δx")
    @test haskey(A1, "Δx") == false
    merge!(A1, D1)
    @test haskey(A1, "Δx") == true
    @test A1.Δx == A1["Δx"] == D1["Δx"]
    @test getkey(A1, :foo, π) == π
    @test getkey(A1, "units", π) == "units"
    @test get(A1, :foo, π) == π
    @test get(A1, "units", π) == "km"
    @test (!haskey(A1, "foo") && get!(A1, "foo", π) == π &&
           haskey(A1, "foo") && A1.foo == π)
    @test pop!(A1, "foo", π) == π && !haskey(A1, "foo")
    @test pop!(A1, "foo", :bar) == :bar
    @test pop!(A1, "units") == "km"
    @test_throws KeyError pop!(A1, "units")
    C1 = convert(DataBag, A1) # should yield A1
    C1.bar = "foo"
    @test haskey(A1, "bar") && A1.bar == "foo"
    delete!(delete!(A1, "units"), "bar")
    C1 = convert(DataBag{String,Float32}, A1) # should not yield A1
    C1.bar = π
    @test !haskey(A1, "bar") && C1.bar ≈ π

    # DataBag with symbolic keys.
    D2 = Dict(:units => "µm", :Δx => 0.20, :Δy => 0.15)
    D3 = Dict(:name => "Mr. Doe", :Δx => 0.30, :Δy => 0.20)
    A2 = DataBag(D2)
    T2 = typeof(A2)
    @test length(A2) == length(D2)
    @test keytype(T2) == keytype(D2)
    @test keytype(A2) == keytype(D2)
    @test keytype(A2) == keytype(D2)
    @test valtype(A2) == valtype(D2)
    @test propertyname(T2, :gizmo) == :gizmo
    @test propertynames(A2) == keys(A2)
    @test A2.units == A2[:units] == D2[:units]
    A2.units = 50
    @test A2.units == A2[:units] != D2[:units]
    @test haskey(A2, :Δx) == true
    delete!(A2, :Δx)
    @test haskey(A2, :Δx) == false
    merge!(A2, D2)
    @test haskey(A2, :Δx) == true
    @test A2.units == A2[:units] == D2[:units]
    A3 = empty(A2)
    @test length(A3) == 0 && length(A2) > 0
    @test keytype(A3) == keytype(A2)
    @test valtype(A3) == valtype(A2)
    A4 = empty(A2, String)
    @test length(A4) == 0
    @test keytype(A4) == String
    @test valtype(A4) == valtype(A2)
    A5 = empty(A2, String, Int32)
    @test length(A5) == 0
    @test keytype(A5) == String
    @test valtype(A5) == Int32
    empty!(A2)
    @test length(A2) == 0
    merge!(A2, D2)
    merge!(A3, D3)
    A6 = empty(A3)
    merge!(A6, D2, D3)
    @test length(A6) == 4
    @test A6.units == A2.units
    @test A6.name == A3.name
    @test A6.Δx == A3.Δx && A6.Δy == A3.Δy
    merge!(empty!(A6), A3, A2)
    @test length(A6) == 4
    @test A6.units == A2.units
    @test A6.name == A3.name
    @test A6.Δx == A2.Δx && A6.Δy == A2.Δy

    # Test different constructors and combination of values.
    B0 = DataBag()
    @test keytype(B0) == Symbol && valtype(B0) == Any
    B1 = DataBag( a  =  1,  b  =  2,  c  =  3,  d  =  "µm",  e  =  :dif)
    @test keytype(B1) == Symbol && valtype(B1) == Any
    B2 = DataBag(:a  => 1, :b  => 2, :c  => 3, :d  => "µm", :e  => :dif)
    @test keytype(B2) == Symbol && valtype(B2) == Any
    B3 = DataBag("a" => 1, "b" => 2, "c" => 3, "d" => "µm", "e" => :dif)
    @test keytype(B3) == String && valtype(B3) == Any
    N1 = Dict{Symbol,Number}() # to store the numerical values of A1
    N2 = Dict{Symbol,Number}() # to store computed values
    for (k,v) in B1
        if isa(v, Number)
            N1[k] = v
            N2[k] = 1 - v
        end
    end
    B4 = DataBag(N1)
    @test keytype(B4) == keytype(N1) && valtype(B4) == Any
    B5 = DataBag{Symbol}(N2)
    @test keytype(B5) == Symbol && valtype(B5) == Any
    B6 = DataBag{Symbol,Float64}(N1)
    @test keytype(B6) == Symbol && valtype(B6) == Float64
    @test all(x -> x == 1, values(merge(+, B5, B4)))
    @test all(x -> x == 1, values(merge(+, N2, B4)))
    @test all(x -> x == 1, values(merge!(+, B6, B5)))

    # Explictely check wrap() and check that the 2 objects share the same data.
    W1 = wrap(DataBag, D1)
    @test keytype(W1) == keytype(D1) && valtype(W1) == valtype(D1)
    @test !haskey(W1, "newkey") && !haskey(D1, "newkey")
    W1.newkey = 12345
    @test haskey(W1, "newkey") && haskey(D1, "newkey")
    @test W1.newkey == pop!(D1, "newkey")
    @test !haskey(W1, "newkey") && !haskey(D1, "newkey")
    #
    W2 = wrap(DataBag, D2)
    @test keytype(W2) == keytype(D2) && valtype(W2) == valtype(D2)
    @test !haskey(W2, :newkey) && !haskey(D2, :newkey)
    W2.newkey = 12345
    @test haskey(W2, :newkey) && haskey(D2, :newkey)
    @test W2.newkey == pop!(D2, :newkey)
    @test !haskey(W2, :newkey) && !haskey(D2, :newkey)
    #
    W3 = wrap(DataBag{keytype(D2)}, D2)
    @test keytype(W3) == keytype(D2) && valtype(W3) == valtype(D2)
    @test !haskey(W3, :newkey) && !haskey(D2, :newkey)
    W3.newkey = 12345
    @test haskey(W3, :newkey) && haskey(D2, :newkey)
    @test W3.newkey == pop!(D2, :newkey)
    @test !haskey(W3, :newkey) && !haskey(D2, :newkey)
    #
    W4 = wrap(DataBag{keytype(N2),valtype(N2)}, N2)
    @test keytype(W4) == keytype(N2) && valtype(W4) == valtype(N2)
    @test !haskey(W4, :newkey) && !haskey(N2, :newkey)
    W4.newkey = 12345
    @test haskey(W4, :newkey) && haskey(N2, :newkey)
    @test W4.newkey == pop!(N2, :newkey)
    @test !haskey(W4, :newkey) && !haskey(N2, :newkey)
    #
    W5 = wrap(DataBag{keytype(N1),valtype(N1),typeof(N1)}, N1)
    @test keytype(W5) == keytype(N1) && valtype(W5) == valtype(N1)
    @test !haskey(W5, :newkey) && !haskey(N1, :newkey)
    W5.newkey = 12345
    @test haskey(W5, :newkey) && haskey(N1, :newkey)
    @test W5.newkey == pop!(N1, :newkey)
    @test !haskey(W5, :newkey) && !haskey(N1, :newkey)

    # Check contents(Dict{...}, ...)
    @test isa(contents(Dict{Any,Any},     D1), Dict{String,Any})
    @test isa(contents(Dict{String,Any},  D1), Dict{String,Any})
    @test isa(contents(Dict{Any,Any},     N1), Dict{Symbol,Any})
    @test isa(contents(Dict{Any,Number},  N1), Dict{Symbol,Number})
    @test isa(contents(Dict{Any,Integer}, N1), Dict{Symbol,Integer})
    @test isa(contents(Dict{Any,Int16},   N1), Dict{Symbol,Int16})
    kwds = keywords(i8=Int8(1), i16=Int16(2), i32=Int32(3), i64=Int64(4))
    @test isa(contents(Dict{Any,Any};      kwds...), Dict{Symbol,Any})
    @test isa(contents(Dict{Symbol,Any};   kwds...), Dict{Symbol,Any})
    @test isa(contents(Dict{Any,Integer};  kwds...), Dict{Symbol,Integer})
    @test isa(contents(Dict{Symbol,Int16}; kwds...), Dict{Symbol,Int16})
    @test_throws MethodError contents(Dict{String,Int16}; kwds...)
    args1 = (:i8=>Int8(1), :i16=>Int16(2), :i32=>Int32(3), :i64=>Int64(4))
    @test isa(contents(Dict{Any,Any},      args1...), Dict{Symbol,Any})
    @test isa(contents(Dict{Symbol,Any},   args1...), Dict{Symbol,Any})
    @test isa(contents(Dict{Any,Integer},  args1...), Dict{Symbol,Integer})
    @test isa(contents(Dict{Symbol,Int16}, args1...), Dict{Symbol,Int16})
    args2 = map(kv -> String(kv[1]) => kv[2], args1)
    @test isa(contents(Dict{Any,Any},      args2...), Dict{String,Any})
    @test isa(contents(Dict{String,Any},   args2...), Dict{String,Any})
    @test isa(contents(Dict{Any,Integer},  args2...), Dict{String,Integer})
    @test isa(contents(Dict{String,Int16}, args2...), Dict{String,Int16})
    args3 = ("i8"=>Int8(1), :i16=>Int16(2), :"32"=>Int32(3), :i64=>Int64(4))
    @test isa(contents(Dict{Any,Any},      args3...), Dict{Any,Any})
    @test isa(contents(Dict{Any,Integer},  args3...), Dict{Any,Integer})
    @test isa(contents(Dict{Any,Int16},    args3...), Dict{Any,Int16})

    # Test data-bag type created by DataBags.@newtype.
    X = SmallDB(date=now(), value=π, arr=rand(3))
    @test isa(X, SmallDB)
    @test isa(X, DataBags.AbstractDataBag{Symbol,Any})
    @test isa(X, AbstractDict)
    @test length(X) == 3
    X.more = "some thing else"
    @test length(X) == 4
    merge!(X, D2)
    @test X.Δx == D2[:Δx]

    # Miscellaneaous.
    @test withspecificvaluetype(valtype(D2), D2) == D2
    @test withspecificvaluetype(Real, N2) == Dict{keytype(N2),Real}(N2)
end

end # module
