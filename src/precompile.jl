# julia 1.3 crashes with some precompile calls

if VERSION >= v"1.6"
    for T in (Float16, Float32, Float64, Int16, Int32, Int64, UInt8, UInt16, UInt32)
        DS = NCDataset{Nothing}
        precompile(defVar, (DS, String, T))
        for N in (1, 2, 3, 4, 5)
            Var = NCDatasets.Variable{T,N,DS}
            precompile(Var, (DS, Cint, NTuple{N,Cint}))
            precompile(Array, (Var,))
            precompile(show, (IO, Var,))
            precompile(show, (IO, MIME"text/plain", Var,))
        end
    end

    precompile(NCDataset{Nothing}, (String,))
    precompile(keys, (NCDataset{Nothing},))
    precompile(show, (IO, NCDataset{Nothing},))
    precompile(getindex, (NCDataset{Nothing}, String))
    precompile(getindex, (NCDataset{Nothing}, Symbol))
end
