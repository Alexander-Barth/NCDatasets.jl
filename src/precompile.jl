
for T in (Float16, Float32, Float64, Int16, Int32, Int64, UInt8, UInt16, UInt32)
    DS = NCDataset{Nothing}
    precompile(defVar, (DS, String, T))
    for N in (1, 2, 3, 4, 5)
        A = Attributes{DS}
        Var = Variable{T,N,DS}
        St = Dict{Symbol,Any}
        CF = CFVariable{T,N,Var,A,St}
        precompile(Var, (DS, Cint, NTuple{N,Cint}, A))
        precompile(CF, (Var, A, St))
        precompile(dimsize, (CF,))
        precompile(getindex, (CF, Colon))
        precompile(getindex, (CF, Int))
        precompile(getindex, (CF, ntuple(Int, N)...))
        precompile(Array, (CF,))
        precompile(Array, (Var,))
        precompile(show, (IO, Var,))
        precompile(show, (IO, CF,))
        precompile(show, (IO, MIME"text/plain", Var,))
        precompile(show, (IO, MIME"text/plain", CF,))
    end
end

precompile(NCDataset{Nothing}, (String,))
precompile(keys, (NCDataset{Nothing},))
precompile(show, (IO, NCDataset{Nothing},))
precompile(getindex, (NCDataset{Nothing}, String))
precompile(getindex, (NCDataset{Nothing}, Symbol))
