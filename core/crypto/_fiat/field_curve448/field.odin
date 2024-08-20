package field_curve448

import "core:mem"

fe_relax_cast :: #force_inline proc "contextless" (
	arg1: ^Tight_Field_Element,
) -> ^Loose_Field_Element {
	return (^Loose_Field_Element)(arg1)
}

fe_tighten_cast :: #force_inline proc "contextless" (
	arg1: ^Loose_Field_Element,
) -> ^Tight_Field_Element {
	return (^Tight_Field_Element)(arg1)
}

fe_clear :: proc "contextless" (
	arg1: $T,
) where T == ^Tight_Field_Element || T == ^Loose_Field_Element {
	mem.zero_explicit(arg1, size_of(arg1^))
}

fe_clear_vec :: proc "contextless" (
	arg1: $T,
) where T == []^Tight_Field_Element || T == []^Loose_Field_Element {
	for fe in arg1 {
		fe_clear(fe)
	}
}

fe_carry_mul_small :: proc "contextless" (
	out1: ^Tight_Field_Element,
	arg1: ^Loose_Field_Element,
	arg2: u64,
) {
	arg2_ := Loose_Field_Element{arg2, 0, 0, 0, 0, 0, 0, 0}
	fe_carry_mul(out1, arg1, &arg2_)
}

fe_carry_pow2k :: proc "contextless" (
	out1: ^Tight_Field_Element,
	arg1: ^Loose_Field_Element,
	arg2: uint,
) {
	// Special case: `arg1^(2 * 0) = 1`, though this should never happen.
	if arg2 == 0 {
		fe_one(out1)
		return
	}

	fe_carry_square(out1, arg1)
	for _ in 1 ..< arg2 {
		fe_carry_square(out1, fe_relax_cast(out1))
	}
}

fe_carry_inv :: proc "contextless" (
	out1: ^Tight_Field_Element,
	arg1: ^Loose_Field_Element,
) {
	// Inversion computation is derived from the addition chain:
	//
	//	_10     = 2*1
	//	_11     = 1 + _10
	//	_110    = 2*_11
	//	_111    = 1 + _110
	//	_111000 = _111 << 3
	//	_111111 = _111 + _111000
	//	x12     = _111111 << 6 + _111111
	//	x24     = x12 << 12 + x12
	//	i34     = x24 << 6
	//	x30     = _111111 + i34
	//	x48     = i34 << 18 + x24
	//	x96     = x48 << 48 + x48
	//	x192    = x96 << 96 + x96
	//	x222    = x192 << 30 + x30
	//	x223    = 2*x222 + 1
	//	return    (x223 << 223 + x222) << 2 + 1
	//
	// Operations: 447 squares 13 multiplies
	//
	// Generated by github.com/mmcloughlin/addchain v0.4.0.

	t0, t1, t2: Tight_Field_Element = ---, ---, ---

	// Step 1: t0 = x^0x2
	fe_carry_square(&t0, arg1)

	// Step 2: t0 = x^0x3
	fe_carry_mul(&t0, arg1, fe_relax_cast(&t0))

	// t0.Sqr(t0)
	fe_carry_square(&t0, fe_relax_cast(&t0))

	// Step 4: t0 = x^0x7
	fe_carry_mul(&t0, arg1, fe_relax_cast(&t0))

	// Step 7: t1 = x^0x38
	fe_carry_pow2k(&t1, fe_relax_cast(&t0), 3)

	// Step 8: t0 = x^0x3f
	fe_carry_mul(&t0, fe_relax_cast(&t0), fe_relax_cast(&t1))

	// Step 14: t1 = x^0xfc0
	fe_carry_pow2k(&t1, fe_relax_cast(&t0), 6)

	// Step 15: t1 = x^0xfff
	fe_carry_mul(&t1, fe_relax_cast(&t0), fe_relax_cast(&t1))

	// Step 27: t2 = x^0xfff000
	fe_carry_pow2k(&t2, fe_relax_cast(&t1), 12)

	// Step 28: t1 = x^0xffffff
	fe_carry_mul(&t1, fe_relax_cast(&t1), fe_relax_cast(&t2))

	// Step 34: t2 = x^0x3fffffc0
	fe_carry_pow2k(&t2, fe_relax_cast(&t1), 6)

	// Step 35: t0 = x^0x3fffffff
	fe_carry_mul(&t0, fe_relax_cast(&t0), fe_relax_cast(&t2))

	// Step 53: t2 = x^0xffffff000000
	fe_carry_pow2k(&t2, fe_relax_cast(&t2), 18)

	// Step 54: t1 = x^0xffffffffffff
	fe_carry_mul(&t1, fe_relax_cast(&t1), fe_relax_cast(&t2))

	// Step 102: t2 = x^0xffffffffffff000000000000
	fe_carry_pow2k(&t2, fe_relax_cast(&t1), 48)

	// Step 103: t1 = x^0xffffffffffffffffffffffff
	fe_carry_mul(&t1, fe_relax_cast(&t1), fe_relax_cast(&t2))

	// Step 199: t2 = x^0xffffffffffffffffffffffff000000000000000000000000
	fe_carry_pow2k(&t2, fe_relax_cast(&t1), 96)

	// Step 200: t1 = x^0xffffffffffffffffffffffffffffffffffffffffffffffff
	fe_carry_mul(&t1, fe_relax_cast(&t1), fe_relax_cast(&t2))

	// Step 230: t1 = x^0x3fffffffffffffffffffffffffffffffffffffffffffffffc0000000
	fe_carry_pow2k(&t1, fe_relax_cast(&t1), 30)

	// Step 231: t0 = x^0x3fffffffffffffffffffffffffffffffffffffffffffffffffffffff
	fe_carry_mul(&t0, fe_relax_cast(&t0), fe_relax_cast(&t1))

	// Step 232: t1 = x^0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffe
	fe_carry_square(&t1, fe_relax_cast(&t0))

	// Step 233: t1 = x^0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffff
	fe_carry_mul(&t1, arg1, fe_relax_cast(&t1))

	// Step 456: t1 = x^0x3fffffffffffffffffffffffffffffffffffffffffffffffffffffff80000000000000000000000000000000000000000000000000000000
	fe_carry_pow2k(&t1, fe_relax_cast(&t1), 223)

	// Step 457: t0 = x^0x3fffffffffffffffffffffffffffffffffffffffffffffffffffffffbfffffffffffffffffffffffffffffffffffffffffffffffffffffff
	fe_carry_mul(&t0, fe_relax_cast(&t0), fe_relax_cast(&t1))

	// Step 459: t0 = x^0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffffffffffffffffffffffffffffffffffffffffffffffffffffc
	fe_carry_pow2k(&t0, fe_relax_cast(&t0), 2)

	// Step 460: z = x^0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffffffffffffffffffffffffffffffffffffffffffffffffffffd
	fe_carry_mul(out1, arg1, fe_relax_cast(&t0))

	fe_clear_vec([]^Tight_Field_Element{&t0, &t1, &t2})
}

fe_zero :: proc "contextless" (out1: ^Tight_Field_Element) {
	out1[0] = 0
	out1[1] = 0
	out1[2] = 0
	out1[3] = 0
	out1[4] = 0
	out1[5] = 0
	out1[6] = 0
	out1[7] = 0
}

fe_one :: proc "contextless" (out1: ^Tight_Field_Element) {
	out1[0] = 1
	out1[1] = 0
	out1[2] = 0
	out1[3] = 0
	out1[4] = 0
	out1[5] = 0
	out1[6] = 0
	out1[7] = 0
}

fe_set :: proc "contextless" (out1, arg1: ^Tight_Field_Element) {
	x1 := arg1[0]
	x2 := arg1[1]
	x3 := arg1[2]
	x4 := arg1[3]
	x5 := arg1[4]
	x6 := arg1[5]
	x7 := arg1[6]
	x8 := arg1[7]
	out1[0] = x1
	out1[1] = x2
	out1[2] = x3
	out1[3] = x4
	out1[4] = x5
	out1[5] = x6
	out1[6] = x7
	out1[7] = x8
}

@(optimization_mode = "none")
fe_cond_swap :: #force_no_inline proc "contextless" (out1, out2: ^Tight_Field_Element, arg1: int) {
	mask := (u64(arg1) * 0xffffffffffffffff)
	x := (out1[0] ~ out2[0]) & mask
	x1, y1 := out1[0] ~ x, out2[0] ~ x
	x = (out1[1] ~ out2[1]) & mask
	x2, y2 := out1[1] ~ x, out2[1] ~ x
	x = (out1[2] ~ out2[2]) & mask
	x3, y3 := out1[2] ~ x, out2[2] ~ x
	x = (out1[3] ~ out2[3]) & mask
	x4, y4 := out1[3] ~ x, out2[3] ~ x
	x = (out1[4] ~ out2[4]) & mask
	x5, y5 := out1[4] ~ x, out2[4] ~ x
	x = (out1[5] ~ out2[5]) & mask
	x6, y6 := out1[5] ~ x, out2[5] ~ x
	x = (out1[6] ~ out2[6]) & mask
	x7, y7 := out1[6] ~ x, out2[6] ~ x
	x = (out1[7] ~ out2[7]) & mask
	x8, y8 := out1[7] ~ x, out2[7] ~ x
	out1[0], out2[0] = x1, y1
	out1[1], out2[1] = x2, y2
	out1[2], out2[2] = x3, y3
	out1[3], out2[3] = x4, y4
	out1[4], out2[4] = x5, y5
	out1[5], out2[5] = x6, y6
	out1[6], out2[6] = x7, y7
	out1[7], out2[7] = x8, y8
}