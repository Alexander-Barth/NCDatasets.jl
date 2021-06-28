using NCDatasets
using Test

new_cache_size = 32000000
new_cache_nelems = 2000
new_cache_preemption = .75

NCDatasets.nc_set_chunk_cache(new_cache_size,new_cache_nelems,new_cache_preemption)
new_cache_size2,new_cache_nelems2,new_cache_preemption2 = NCDatasets.get_chunk_cache()

@test new_cache_size2 == new_cache_size
@test new_cache_nelems2 == new_cache_nelems
@test new_cache_preemption2 ≈ new_cache_preemption


newest_cache_size = 32000001
NCDatasets.set_chunk_cache(size = newest_cache_size)
new_cache_size2,new_cache_nelems2,new_cache_preemption2 = NCDatasets.get_chunk_cache()

@test new_cache_size2 == newest_cache_size
# should not change
@test new_cache_nelems2 == new_cache_nelems
@test new_cache_preemption2 ≈ new_cache_preemption
