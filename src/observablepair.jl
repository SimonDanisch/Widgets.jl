struct ObservablePair{S, T}
    first::Observable{S}
    second::Observable{T}
    f
    g
    first2second
    second2first
    excluded::Vector{<:Function}
    function ObservablePair(first::Observable{S}, second::Observable{T}; f = identity, g = identity, force = false) where {S, T}
        excluded = Function[]
        first2second = on(first) do val
            fval = f(val)
            (force || second[] != fval) && Observables.setexcludinghandlers(second, fval, x -> !(x in excluded))
        end
        push!(excluded, first2second)
        second2first = on(second) do val
            gval = g(val)
            (force || first[] != gval) && Observables.setexcludinghandlers(first, gval, x -> !(x in excluded))
        end
        push!(excluded, second2first)
        new{S, T}(first, second, f, g, first2second, second2first, excluded)
    end
end

ObservablePair(first::Observable; f = identity, g = identity) =
    ObservablePair(first, Observable{Any}(f(first[])); f = f, g = g)

off(o::ObservablePair) = (off(o.first, o.first2second); off(o.second, o.second2first))

unwrap(x) = x
function unwrap(obs::Observable)
    obs1 = obs[]
    obs1 isa Observable || return obs
    obs2 = Observable{Any}(obs1[])
    p = ObservablePair(obs1, obs2)
    on(obs) do val
        off(p)
        (val[] != obs2[]) && (obs2[] = val[])
        p = ObservablePair(val, obs2)
    end
    obs2
end

Base.start(s::ObservablePair) = 1
Base.next(s::ObservablePair, i) = i == 1 ? (s.first, 2) : (s.second, 3)
Base.done(s::ObservablePair, i) = i >= 3
