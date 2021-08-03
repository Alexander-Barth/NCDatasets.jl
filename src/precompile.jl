
precompile(NCDataset{Nothing}, (String,))
precompile(getindex, (NCDataset{Nothing}, String))
precompile(getindex, (NCDataset{Nothing}, Symbol))
precompile(variable, (NCDataset{Nothing}, String))

for N in (1, 2, 3, 4, 5), 
    T in (Float16, Float32, Float64, Int16, Int32, Int64, UInt8, UInt16, UInt32)
    DS = NCDataset{Nothing}
    A = NCDatasets.Attributes{DS}
    Var = NCDatasets.Variable{T,N,DS,A}
    St = Dict{Symbol,Any}
    precompile(Var, (DS, Cint, NTuple{N,Cint}, A))
    precompile(NCDatasets.CFVariable{T,N,Var,A,St}, (Var, A, St))
end
