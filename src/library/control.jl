"Takes no input simple emits a `value::T`"
struct CondArrow <: PrimArrow end
props(::CondArrow) =   [Props(true, :i, Bool),
                             Props(true, :t, Real),
                             Props(true, :e, Real),
                             Props(false, :e, Real)]
name(::CondArrow) = :cond

"Duplicates input `O` times dupl_n_(x) = (x,...x)"
struct DuplArrow{O} <: PrimArrow end

props{O}(::DuplArrow{O}) =
  [Props(true, :x, Any),
   [Props(false, Symbol(:y, i), Any) for i=1:O]...]

name{O}(::DuplArrow{O}) = Symbol(:dupl_, O)
DuplArrow(n::Integer) = DuplArrow{n}()
abinterprets(::DuplArrow) = [sizeprop]

"`(x, x, ..., x)` `n` times"
dupl(x, n)::Tuple = tuple((x for i = 1:n)...)

"f(x) = (x,)"
struct IdentityArrow <: PrimArrow end

props(::IdentityArrow) =
  [Props(true, :x, Any), Props(false, :y, Any)]

name(::IdentityArrow) = :identity

"ifelse(i, t, e)`"
struct IfElseArrow <: PrimArrow end
props(::IfElseArrow) =   [Props(true, :i, Bool),
                          Props(true, :t, Real),
                          Props(true, :e, Real),
                          Props(false, :y, Real)]
name(::IfElseArrow) = :ifelse

function inv(arr::Arrows.IfElseArrow, sarr::SubArrow, abvals::IdAbValues)
  carr = CompArrow(:inv_ite, [:y, :θi, :θmissing], [:i, :t, :e])
  y, θi, θmissing, i, t, e = ⬨(carr)
  θi ⥅ i
  ifelse(θi, y, θmissing) ⥅ t
  ifelse(θi, θmissing, y) ⥅ e
  @assert is_wired_ok(carr)
  carr, Dict(:i => :i, :t => :t, :e => :e, :y => :y)
end
