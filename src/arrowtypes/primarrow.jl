## Primitive Arrow
## ===============

abstract PrimArrow{I, O} <: Arrow{I, O}

"Parameters of a primitive arrow"
parameters(x::PrimArrow) = Dict{Symbol, Any}()

"number of arrows"
nnodes(a::PrimArrow) = 1
nodes(a::PrimArrow) = Arrow[a]

eleminppintype(x::PrimArrow, pinid::PinId) = typ(x).elemtype.inptypes[pinid]
elemoutpintype(x::PrimArrow, pinid::PinId) = typ(x).elemtype.outtypes[pinid]
diminppintype(x::PrimArrow, pinid::PinId) = typ(x).dimtype.inptypes[pinid]
dimoutpintype(x::PrimArrow, pinid::PinId) = typ(x).dimtype.outtypes[pinid]
shapeinppintype(x::PrimArrow, pinid::PinId) = typ(x).shapetype.inptypes[pinid]
shapeoutpintype(x::PrimArrow, pinid::PinId) = typ(x).shapetype.outtypes[pinid]
valueinppintype(x::PrimArrow, pinid::PinId) = typ(x).valuetype.inptypes[pinid]
valueoutpintype(x::PrimArrow, pinid::PinId) = typ(x).valuetype.outtypes[pinid]

# Intercace methods
name(x::PrimArrow) = error("interface: children should implement name")
typ(x::PrimArrow) = error("interface: children should implement typ")
dimtyp(x::PrimArrow) = error("interface: children should implement dimtyp")

"Expression for dimensionality type at inport `p` of arrow `x`"
dimexpr(x::PrimArrow, p::InPort) = dimtyp(x).inptypes[p.pinid]

"Expression for dimensionality type at outport `p` of arrow `x`"
dimexpr(x::PrimArrow, p::OutPort) = dimtyp(x).outtypes[p.pinid]

"Number of dimensions of array at inport `p` of arrow `a`"
function ndims{I, O}(a::PrimArrow{I, O}, p::InPort)
  @assert p.pinid <= I
  t::ArrowType = typ(a)
  ndims(t.inptypes[p.pinid])
end

"Number of dimensions of array at inport `p` of arrow `a`"
function ndims{I, O}(a::PrimArrow{I, O}, p::OutPort)
  @assert p.pinid <= O
  t::ArrowType = typ(a)
  ndims(t.outtypes[p.pinid])
end

# Printing
function string{I,O}(x::PrimArrow{I,O})
  """$(name(x))\t:: PrimArrow{$I,$O}
  eltyp\t:: $(go(typ(x), eltype))
  ndims\t:: $(go(typ(x), ndims))
  shape\t:: $(go(typ(x), shape; postprocess = parens))"""
end
