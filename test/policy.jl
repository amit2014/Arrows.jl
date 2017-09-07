import Arrows: name, is_valid, interpret, pol_to_julia
using Arrows.TestArrows
using Base.Test

include("common.jl")


rand_input(arr) = rand(Arrows.num_in_ports(arr))

function test_policy()
  for arr in Arrows.TestArrows.plain_arrows()
    println("Testing policy: ", name(arr))
    pol = Arrows.DetPolicy(arr)
    @test is_valid(pol)
  end
end

test_pol_to_julia(arr) = pol_to_julia(Arrows.DetPolicy(arr))

function test_interpret()
  for arr in Arrows.TestArrows.plain_arrows()
    println("Testing interpret: ", name(arr))
    pol = Arrows.DetPolicy(arr)
    output = interpret(pol, rand_input(arr)...)
    println("Got: ", output)
  end
end

foreach(test_pol_to_julia ∘ pre_test, plain_arrows())
test_policy()
test_interpret()
