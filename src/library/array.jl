"Gather"
struct GatherNdArrow <: PrimArrow end
name(::GatherNdArrow)::Symbol = :gather_nd
function props(::GatherNdArrow)
  [Props(true, :x, Any),
   Props(true, :y, Any),
   Props(true, :w, Any),
   Props(false, :z, Any)]
 end

"Reshape"
struct ReshapeArrow <: PrimArrow end
name(::ReshapeArrow)::Symbol = :reshape
props(::ReshapeArrow) = bin_arith_props()

"GatherND, from TensorFlow"
function gather_nd(params, indices, shape)
  indices = indices + 1
  answer = [params[indices[rr,:]...] for rr in
                        CartesianRange(size(indices)[1:end-1])]
  answer
end
# struct GetIndexArrow <: PrimArrow end
# name(::GetIndexArrow)::Symbol = :getindex
# props(::GetIndexArrow) = bin_arith_props()

# statically compute the shape of the target port
struct ScatterNdArrow <: PrimArrow end
name(::ScatterNdArrow)::Symbol = :scatter_nd
function props(::ScatterNdArrow)
  [Props(true, :x, Any),
   Props(true, :y, Any),
   Props(true, :w, Any),
   Props(true, :v, Any),
   Props(false, :z, Any)]
 end


function scatter_nd(params, indices, shape, missing_values)
  answer = Array{Any, length(shape)}(shape...)
  indices = indices + 1
  for (idx,rr) in enumerate(CartesianRange(size(indices)[1:end-1]))
    answer[indices[rr,:]...] = params[idx]
  end
  i = 1
  for iter in eachindex(answer)
    if !isassigned(answer, iter)
      answer[iter] = missing_values[i]
      i += 1
    end
  end
  answer
end
