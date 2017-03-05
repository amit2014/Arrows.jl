## Composite Arrows
## ================


"Directed Composite Arrow"
immutable CompArrow{I, O} <: Arrow{I, O}
  name::Symbol
  edges::LightGraphs.DiGraph  # Each port has a unique index
  port_map::Vector{Integer}   # Mapping from port indices in edges to Port
  port_attrs::Vector{PortAttrs}
  parent::Nullable{CompArrow}

  "Constructs CompArrow with Any"
  function CompArrow(name::Symbol)
    nports = I + O
    g = LightGraphs.DiGraph(nports)
    port_map = [i for i = 1:nports]
    in_port_attrs = [PortAttrs(true, Symbol(:inp_, i), Any) for i = 1:I]
    out_port_attrs = [PortAttrs(false, Symbol(:out_, i), Any) for i = 1:O]
    port_attrs = vcat(in_port_attrs, out_port_attrs)
    new(name, g, port_map, port_attrs, Nullable{CompArrow}())
  end
end

"Does the arrow have a parent? (is it within a composition)?"
is_parentless(arr::Arrow)::Bool = isnull(arr.parent)

"Find the index of this port in c edges"
function port_index(arr::CompArrow, port::Port)::Integer
  if !is_sub_arrow(arr, port.arrow)
    throw(DomainError())
  else
    res = findfirst(arr.port_map, port.index)
    @assert res > 0
    res
  end
end

# FIXME: Could specialize this to avoid check from port_index above
port_index(port::Port)::Integer = port_index(port.arrow, port)

"The Port with index `i` in arr.edges"
port_index(arr::CompArrow, i::Integer)::Port = arr.port_map[i]

function port_attrs(arr::CompArrow, port::Port)
  arr.port_attrs[port_index(port.arrow, port)]
end

"Number of all the ports in of all the arrows in the composition"
num_all_ports(arr::CompArrow)::Integer = length(arr.port_map)

"Add a port to the composite arrow"
function add_port!(arr::CompArrow, port_attrs::PortAttrs)::Port
  push!(arr.port_attrs, port_attrs)
  p = Port(c, num_all_ports(c))
  push!(arr.port_map, p)
  add_vertex!(arr.edges)
  p
end

"Add a port to the composite arrow"
function add_port!(arr::CompArrow, is_in_port::Bool, name::Symbol, typ::Any,
                   labels::Set{Symbol})::Port
  add_port!(arr, PortAttrs(input, name, typ, labels))
end

"Add an in_port to `arr`"
function add_in_port!(arr::CompArrow, name::Symbol, typ::Any,
                      labels::Set{Symbol})::Port
  add_port!(arr, PortAttrs(true, name, typ, labels))
end

"Add an out_port to `arr`"
function add_out_port!(arr::CompArrow, name::Symbol, typ::Any,
                       labels::Set{Symbol})::Port
  add_port!(arr, PortAttrs(false, name, typ, labels))
end

"Add a port to `arr` with same attributes as `port`"
add_port_like!(arr::CompArrow, port::Port)::Port = add_port!(arr, port_attrs(port))

"Add an edge in CompArrow from port `l` to port `r`"
function link_ports!(c::CompArrow, l::Port, r::Port)
  l_idx = port_index(c, l)
  r_idx = port_index(c, r)
  add_edge!(c.edges, l_idx, r_idx)
end

"is `arr` a sub_arrow of `ctx`"
function is_sub_arrow(ctx::CompArrow, arr::Arrow)::Bool
  arr == ctx || arr.parent == ctx
end

# Graph traversal
function neighbors(port::Port)::List{Port}
  neigh_indices = neighbors(port.arrow.edges, port_index(port))
  [port_index(port.arrow, i) for i in neigh_indices]
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
