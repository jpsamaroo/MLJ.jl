# NOTE: there's a `kmeans!` function that updates centers, maybe a candidate
# for the `update` machinery.

module Clustering_

export KMeans

import MLJBase

import Clustering
using LinearAlgebra: norm

const C = Clustering

KMeansFitResultType = C.KmeansResult

mutable struct KMeans <: MLJBase.Unsupervised
    k::Int
end

function KMeans(;k=3)
    model = KMeans(k)
    message = MLJBase.clean!(model)
    isempty(message) || @warn message

    return model
end

function MLJBase.clean!(model::KMeans)
    warning = ""
    if model.k < 1
        warning *= "Need k > 1. Resetting k=1.\n"
        model.k = 1
    end
    return warning
end

function MLJBase.fit(model::KMeans
                   , verbosity::Int
                   , X)

    Xarray = MLJBase.matrix(X)

    # NOTE see https://github.com/JuliaStats/Clustering.jl/issues/136
    # there shouldn't be a need for collect here...
    fitresult = C.kmeans(collect(transpose(Xarray)), model.k)

    cache = nothing
    report = Dict{Symbol, Any}()
    report[:centers] = transpose(fitresult.centers)

    return fitresult, cache, report
end

function MLJBase.transform(model::KMeans
                         , fitresult::KMeansFitResultType
                         , X)

    Xarray = MLJBase.matrix(X)
    # X is n × d
    # centers is d × k
    # results is n × k
    (n, d), k = size(X), model.k
    X̃ = zeros(size(X, 1), k)

    @inbounds for i ∈ 1:n
        @inbounds for j ∈ 1:k
            X̃[i, j] = norm(view(Xarray, i, :) .- view(fitresult.centers, :, j))
        end
    end
    return X̃
end

# For finding the minimum the squared norm is enough (and faster)
_norm2(x) = sum(e->e^2, x)

function MLJBase.predict(model::KMeans
                       , fitresult::KMeansFitResultType
                       , Xnew)

    Xarray = MLJBase.matrix(Xnew)
    # similar to transform except we only care about the min distance
    (n, d), k = size(Xarray), model.k
    pred = zeros(Int, n)
    @inbounds for i ∈ 1:n
        minv = Inf
        @inbounds for j ∈ 1:k
            curv = _norm2(view(Xarray, i, :) .- view(fitresult.centers, :, j))
            # avoid branching (this is twice as fast as argmin because
            # the context is simpler and we have to do fewer checks)
            P       = curv < minv
            pred[i] =    j * P + pred[i] * !P # if P is true --> j
            minv    = curv * P +    minv * !P # if P is true --> curvalue
        end
    end
    return pred
end

# metadata:
MLJBase.package_name(::Type{KMeans}) = "Clustering"
MLJBase.package_uuid(::Type{KMeans}) = "aaaa29a8-35af-508c-8bc3-b662a17a0fe5"
MLJBase.is_pure_julia(::Type{KMeans}) = :yes
MLJBase.inputs_can_be(::Type{KMeans}) = [:numeric,]
MLJBase.target_kind(::Type{KMeans}) = :multiclass
MLJBase.target_quantity(::Type{KMeans}) = :univariate

end # module

using .Clustering_
export KMeans