ArrowName = Symbol
# Need ProxyPort because julia has no cyclical types, otherwise use `Port`
ProxyPort = Tuple{ArrowName, Integer}
VertexId = Integer

mutable struct CompArrow{I, O} <: Arrow{I, O}
  name::ArrowName
  edges::LG.DiGraph
  port_to_vtx_id::Dict{ProxyPort, VertexId} # name(sarr) => vtxid of first port
  sarr_name_to_arrow::Dict{ArrowName, Arrow}
  port_props::Vector{PortProps}

  function CompArrow{I, O}(name::Symbol,
                           port_props::Vector{PortProps}) where {I, O}
    if !is_valid(port_props, I, O)
      throw(DomainError())
    end
    c = new()
    nports = I + O
    g = LG.DiGraph(nports)
    c.name = name
    c.edges = g
    c.port_to_vtx_id = Dict((name, i) => i for i = 1:I+O)
    c.sarr_name_to_arrow = Dict(name => c)
    c.port_props = port_props
    c
  end
end

"A component within a `CompArrow`"
struct SubArrow{I, O} <: ArrowRef{I, O}
  parent::CompArrow
  name::ArrowName
  function SubArrow{I, O}(parent::CompArrow, name::ArrowName) where {I, O}
    sarr = new{I, O}(parent, name)
    if !is_valid(sarr)
      throw(DomainError())
    end
    sarr
  end
end

"sarr is valid if its name exists in its parent and `I` `O`"
function is_valid{I, O}(sarr::SubArrow{I, O})::Bool
  arr = deref(sarr)
  I == num_in_ports(arr) && O == num_out_ports(arr)
end

function SubArrow(carr::CompArrow, name::ArrowName)
  arr = arrow(carr, name)
  SubArrow{num_in_ports(arr), num_out_ports(arr)}(carr, name)
end

"A `Port` on a `SubArrow`"
struct SubPort <: AbstractPort
  sub_arrow::SubArrow  # Parent arrow of arrow sport is attached to
  port_id::Integer     # this is ith `port` of parent
  function SubPort(sarr::SubArrow, port_id::Integer)
    if 0 < port_id <= num_ports(sarr)
      new(sarr, port_id)
    else
      println("Invalid port_id: ", port_id)
      throw(DomainError())
    end
  end
end

Link = Tuple{SubPort, SubPort}

## CompArrow constructors
"Constructs CompArrow with where all input and output types are `Any`"
function CompArrow{I, O}(name::Symbol,
                        inp_names=[Symbol(:inp_, i) for i=1:I],
                        out_names=[Symbol(:out_, i) for i=1:O]) where {I, O}
  # Default is for first I ports to be in_ports then next O oout_ports
  in_port_props = [PortProps(true, inp_names[i], Any) for i = 1:I]
  out_port_props = [PortProps(false, out_names[i], Any) for i = 1:O]
  port_props = vcat(in_port_props, out_port_props)
  CompArrow{I, O}(name, port_props)
end

port_props(arr::CompArrow) = arr.port_props
port_props(sarr::SubArrow) = port_props(deref(sarr))

"Not a reference"
deref(sport::SubPort)::Port = port(deref(sport.sub_arrow), port_id(sport))
deref(sarr::SubArrow)::Arrow = arrow(parent(sarr), sarr.name)
"Get `Arrow` in `arr` with name `n`"
arrow(arr::CompArrow, n::ArrowName)::Arrow = arr.sarr_name_to_arrow[n]

## Naming ##
unique_sub_arrow_name()::ArrowName = gen_id()
name(arr::CompArrow)::ArrowName = arr.name
"Names of all `SubArrows` in `arr`, inclusive"
all_names(arr::CompArrow)::Vector{ArrowName} =
  collect(keys(arr.sarr_name_to_arrow))
"Names of all `SubArrows` in `arr`, exclusive of `arr`"
names(arr::CompArrow)::Vector{ArrowName} = setdiff(all_names(arr), [name(arr)])

SubPort(arr::CompArrow, pxport::ProxyPort)::SubPort =
  SubPort(SubArrow(arr, pxport[1]), pxport[2])

## SubPort(s) constructors

"`SubPort` of `arr` with vertex id `vtx_id`"
sub_port_vtx(arr::CompArrow, vtx_id::VertexId)::SubPort =
  SubPort(arr, rev(arr.port_to_vtx_id, vtx_id))

"`SubPort`s on boundary of `arr`"
sub_ports(arr::CompArrow) = sub_ports(sub_arrow(arr))

"`SubPort`s connected to `sarr`"
sub_ports(sarr::SubArrow)::Vector{SubPort} =
  [SubPort(sarr, i) for i=1:num_ports(sarr)]

"`SubPort` of `sarr` of number `port_id`"
sub_port(sarr::SubArrow, port_id::Integer) = SubPort(sarr, port_id)

"All the `SubPort`s of all `SubArrow`s on and within `arr`"
all_sub_ports(arr::CompArrow)::Vector{SubPort} =
  [SubPort(SubArrow(arr, n), id) for (n, id) in keys(arr.port_to_vtx_id)]

"`SubPort`s from `SubArrow`s within `arr` but not boundary"
inner_sub_ports(arr::CompArrow)::Vector{SubPort} =
  filter(sport -> !on_boundary(sport), all_sub_ports(arr))

"Number `SubPort`s within on on `arr`"
num_all_sub_ports(arr::CompArrow) = length(arr.port_to_vtx_id)

"Number `SubPort`s within on on `arr`"
num_sub_ports(arr::CompArrow) = num_all_sub_ports(arr) - num_ports(arr)

in_sub_ports(sarr::AbstractArrow)::Vector{SubPort} = filter(is_in_port, sub_ports(sarr))
out_sub_ports(sarr::AbstractArrow)::Vector{SubPort} = filter(is_out_port, sub_ports(sarr))
in_sub_port(sarr::AbstractArrow, i) = in_sub_ports(sarr)[i]
out_sub_port(sarr::AbstractArrow, i) = out_sub_ports(sarr)[i]

"is `sport` a boundary port?"
on_boundary(sport::SubPort)::Bool = name(parent(sport)) == name(sub_arrow(sport))

## Add link remove SubArrs / Links ##

"Add a `SubArrow` `arr` to `CompArrow` `carr`"
function add_sub_arr!(carr::CompArrow, arr::Arrow)::SubArrow
  # TODO: FINISH!
  newname = unique_sub_arrow_name()
  carr.sarr_name_to_arrow[newname] = arr
  for (i, port) in enumerate(ports(arr))
    LG.add_vertex!(carr.edges)
    vtx_id = LG.nv(carr.edges)
    pxport = (newname, i)
    carr.port_to_vtx_id[pxport] = vtx_id
  end
  SubArrow(carr, newname)
end

"Remove a `SubArrow` from a `CompArrow`"
function rem_sub_arr!(carr::CompArrow, sarr::SubArrow)::CompArrow
  if sarr ∉ sub_arrows(carr)
    println("Cannot remove subarrow because its not in composition")
  end
  delete!(carr.sub_arrow_index[sarr.name])
  delete!(carr.sarr_name_to_arrow[sarr.name])
  # Delete the edges sub_arrow_index[sarr.name] .. + ndhada
  carr
end

"All directed `Link`s (src_port, dst_port)"
function links(arr::CompArrow)::Vector{Link}
  es = LG.edges(arr.edges)
  map(e -> (sub_port_vtx(arr, e.src), sub_port_vtx(arr, e.dst)), LG.edges(arr.edges))
end

"Add an edge in CompArrow from port `l` to port `r`"
function link_ports!(l::SubPort, r::SubPort)
  c = anyparent(l, r)
  l_idx = vertex_id(l)
  r_idx = vertex_id(r)
  LG.add_edge!(c.edges, l_idx, r_idx)
  # TODO: error handling
end

"Remove an edge in CompArrow from port `l` to port `r`"
function unlink_ports!(l::SubPort, r::SubPort)
  c = anyparent(l, r)
  l_idx = vertex_id(l)
  r_idx = vertex_id(r)
  LG.rem_edge!(c.edges, l_idx, r_idx)
  # TODO: error handling
end

"Is there a path between `SubPort`s `sport1` and `sport2`?"
function is_linked(sport1::SubPort, sport2::SubPort)::Bool
  same_parent = parent(sport1) == parent(sport2)
  if same_parent
    v1 = vertex_id(sport1)
    v2 = vertex_id(sport2)
    v1_component = weakly_connected_component(parent(sport1).edges, v1)
    v2 ∈ v1_component
  else
    false
  end
end

## Sub Arrow ##
num_all_sub_arrows(arr::CompArrow) = length(all_sub_arrows(arr))
num_sub_arrows(arr::CompArrow) = length(sub_arrows(arr))

name(sarr::SubArrow)::ArrowName = sarr.name
"`SubArrow` of `arr` with name `n`"
sub_arrow(arr::CompArrow, n::ArrowName)::SubArrow = SubArrow(arr, n)
"All `SubArrows` within `arr`, inclusive"
all_sub_arrows(arr::CompArrow)::Vector{SubArrow} =
  [SubArrow(arr, n) for n in all_names(arr)]
"All `SubArrow`s within `arr` exlusive of `arr`"
sub_arrows(arr::CompArrow)::Vector{SubArrow} =
  [SubArrow(arr, n) for n in names(arr)]
"`SubArrow` which `sport` is 'attached' to"
sub_arrow(sport::SubPort)::SubArrow = sport.sub_arrow
"(self) sub_arrow reference to `arr`"
sub_arrow(arr::CompArrow) = sub_arrow(arr, name(arr))

parent(sarr::SubArrow)::CompArrow = sarr.parent
parent(sarr::SubPort)::CompArrow = parent(sub_arrow(sarr))

"""
Helper function to translate LightGraph functions to Port functions
  f: LightGraph API function f(g::Graph, v::VertexId)
  port: port corresponding to vertex to which f(v) is applied
  arr: Parent Composite arrow
"""
function lg_to_p(f::Function, port::SubPort)
  f(parent(port).edges, vertex_id(port))
end

"Helper for LightGraph API methods which return Vector{Port}, see `lg_to_p`"
function v_to_p(f::Function, port::SubPort)::Vector{SubPort}
  arr = parent(port)
  map(i->sub_port_vtx(arr, i), lg_to_p(f, port))
end

"`sport` is number `port_id(sport)` `SubPort` on `sub_arrow(sport)`"
port_id(sport::SubPort)::Integer = sport.port_id

# Not in minimal integeral #########################################
vertex_id(sport::SubPort)::VertexId =
  parent(sport).port_to_vtx_id[(sport.sub_arrow.name, sport.port_id)]