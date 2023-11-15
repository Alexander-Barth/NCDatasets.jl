
DeferDataset(filename::AbstractString,mode::AbstractString = "r") = DeferDataset(NCDataset,filename::AbstractString,mode)

export DeferDataset


function NCDataset(f::Function, r::Resource)
    NCDataset(r.filename,r.mode) do ds
        f(ds)
    end
end

function NCDataset(f::Function, dds::DeferDataset)
    NCDataset(dds.r.filename,dds.r.mode) do ds
        f(ds)
    end
end
