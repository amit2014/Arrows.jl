## Composite Arrows
## ================

"Composite Arrow"
immutable CompArrow{I, O} <: Arrow{I, O}
  name::Symbol
  edges::LightGraphs.Graph  # Each port has a unique index
  port_map::Vector{Port}    # Mapping from port indices in edges to Port
  port_attr::Vector{Set{PortAttribute}}
end

function CompArrow(name::Symbol)
  CompArrow(name, LightGraphs.Graph(), Port[], [])
end

"Find the index of this port in c edges"
function port_index(arr::CompArrow, port::Port)::Integer
  if !is_sub_arrow(arr, port.arrow)
    throw(DomainError())
  else
    res = findfirst(c.port_map, port)
    @assert res > 0
    res
  end
end

function num_all_ports(arr::CompArrow)::Integer
  length(arr.port_map)
end

"Add a port to the composite arrow"
function add_port!(arr::CompArrow)::Port
  push!(arr.port_attr, Set{PortAttribute}())
  p = Port(c, num_all_ports(c))
  push!(arr.port_map, p)
  add_vertex!(arr.edges)
  p
end

"Add an edge in CompArrow from port `l` to port `r`"
function link_ports!(c::CompArrow, l::Port, r::Port)
  l_idx = port_index(c, l)
  r_idx = port_index(c, r)
  add_edge!(c.edges, l_idx, r_idx)
end

## External Interface
function is_sub_arrow(ctx::CompArrow, arrow::Arrow)::Bool
  arrow == ctx || arrow.parent == ctx
end

"How many ports does `arr` have"
function num_ports(arr::CompArrow)::Integer
  return length(arr.port_map)
end

function port(arr::CompArrow, i::Integer)::Port
  if 1 <= i <= num_ports(arr)
    Port(arr, i)
  else
    throw(DomainError())
  end
end

function ports(arr::CompArrow)::Vector{Port}
  [port(arr, i) for i = 1:num_ports(arr)]
end

function out_ports(arr::CompArrow)::Vector{Port}
  filter(p -> is_out_port(p), ports(c))
end

function out_port(arr::CompArrow, i::Integer)::Port
  out_ports(arr)[i]
end

# "Number of dimensions of array at inport `p` of subarrow within `a`"
# function ndims{I, O}(a::CompositeArrow{I, O}, p::Port)
#   # @assert p.pinid <= I
#   @assert p.arrowid != 1 "Determining in/outport type at boundary unsupported"
#   subarr = nodes(a)[p.arrowid - 1] # FIXME: this minus 1 is error prone
#   ndims(subarr, p)
# end
#
# # Printing
# string{I,O}(x::CompositeArrow{I,O}) = "CompositeArrow{$I,$O} - $(nnodes(x)) subarrows"
#
# "The type of the `pinid`th inport of arrow `x`"
# function inppintype(x::CompositeArrow, pinid::PinId)
#   inport = edges(x)[OutPort(1,pinid)]
#   # This means edge is passing all the way through to output and therefore
#   # is Top (Any) type
#   if isboundary(inport)
#     error("Any type not supported")
#   else
#     inppintype(subarrow(x, inport.arrowid), inport.pinid)
#   end
# end
#
# "All the inports contained by subarrows in `a`"
# function subarrowinports(a::CompositeArrow)
#   ports = InPort[]
#   for i = 1:nnodes(a)
#     push!(ports, subinports(a, i+1)...)
#   end
#   ports
# end
#
# "All the outports contained by subarrows in `a`"
# function subarrowoutports(a::CompositeArrow)
#   ports = OutPort[]
#   for i = 1:nnodes(a)
#     push!(ports, suboutports(a, i+1)...)
#   end
#   ports
# end
#
# outasinports{I,O}(a::CompositeArrow{I,O}) = [InPort(1, i) for i = 1:O]
# inasoutports{I,O}(a::CompositeArrow{I,O}) = [OutPort(1, i) for i = 1:I]
#
# "Get the inner (extends within arrow) outport with pinid `n` if it exists"
# nthinneroutport{I,O}(::CompositeArrow{I,O}, n::PinId) =
#   (@assert n <= I "fail: n($n) <= I($I)"; OutPort(1, n))
#
# "Get the inner (extends within arrow) inport with pinid `n` if it exists"
# nthinnerinport{I,O}(::CompositeArrow{I,O}, n::PinId) =
#   (@assert n <= O "fail: n($n) <= O($O)"; InPort(1, n))
#
# "All inports, both nested and boundary"
# allinports(a::CompositeArrow) = vcat(outasinports(a), subarrowinports(a))::Vector{InPort}
#
# "All outports, both nested and boundary"
# alloutports(a::CompositeArrow) = vcat(inasoutports(a), subarrowoutports(a))::Vector{OutPort}
#
# "The subarrow contained within `a` with `arrowid`"
# subarrow(a::CompositeArrow, arrowid::ArrowId) =
#   (@assert arrowid != 1 "not subarrow, arrowid = $arrowid"; a.nodes[arrowid-1])
#
# "inports for a subarrow with ids relative to parent arrow, i.e. arrowids != 1"
# function subinports(a::CompositeArrow, arrowid::ArrowId)
#   @assert arrowid != 1
#   arr = subarrow(a, arrowid)
#   [InPort(arrowid, i) for i = 1:ninports(arr)]
# end
#
# "outports for a subarrow with ids relative to parent arrow, i.e. arrowids != 1"
# function suboutports(a::CompositeArrow, arrowid::ArrowId)
#   @assert arrowid != 1
#   arr = subarrow(a, arrowid)
#   [OutPort(arrowid, i) for i = 1:noutports(arr)]
# end
#
# "Is this arrow well formed? Are all its ports (and no others) connected?"
# function iswellformed{I,O}(c::CompositeArrow{I,O})
#   # println("Checking")
#   inpset = Set{InPort}(allinports(c))
#   outpset = Set{OutPort}(alloutports(c))
#
#   # @show inpset
#   # @show outpset
#   # @show edges(c)
#
#   for (outp, inp) in edges(c)
#     if (outp in outpset) && (inp in inpset)
#       # println("removing $outp")
#       # println("removing $inp")
#       delete!(outpset, outp)
#       delete!(inpset, inp)
#     else
#       # error("arrow not well formed")
#       println("not well formed $outp - $(outp in outpset) \n $inp - $(inp in inpset)")
#       return false
#     end
#   end
#
#   if isempty(inpset) && isempty(outpset)
#     return true
#   else
#     println("some unconnected ports")
#     return false
#   end
# end
#
# ## Type Stuff
# ## ==========
#
# "Expression for dimensionality type at outport `p` of arrow `x`"
# dimexpr(a::CompositeArrow, p::Port) = dimexpr(subarrow(a, p.arrowid), p)
