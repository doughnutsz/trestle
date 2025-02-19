/-
Copyright (c) 2024 The Trestle Contributors.
Released under the Apache License v2.0; see LICENSE for full text.

Authors: Wojciech Nawrocki, Jeremy Avigad
-/

import Trestle.Upstream.ToStd
import Trestle.Upstream.ToMathlib
import Trestle.Model.PropFun
import Trestle.Model.PropVars
import Trestle.Model.Subst

namespace Trestle

open Model

/-! ### Literals -/

/-- The type `L` is a representation of literals over variables of type `ν`. -/
@[specialize]
class LitVar (L : Type u) (ν : outParam $ Type v) where
  negate : L → L
  mkPos : ν → L
  mkNeg : ν → L := fun x => negate (mkPos x)
  toVar : L → ν
  /-- true if positive -/
  polarity : L → Bool
  -- TODO: ν moreover needs to biject with PNat (perhaps in a separate typeclass)
  -- so that we can use variable names as array indices

namespace LitVar

def mkLit (L : Type u) {ν : Type v} [LitVar L ν] (x : ν) (p : Bool) : L :=
  if p then mkPos x else mkNeg x

variable {L : Type u} {ν : Type v} [LitVar L ν]

-- controversial maybe?
instance : Coe ν L :=
  ⟨mkPos⟩

instance : Neg L :=
  ⟨negate⟩

@[simp] theorem negate_eq (l : L) : negate l = -l := rfl

instance [ToString ν] : ToString L where
  toString l := if polarity l then s!"{toVar l}" else s!"-{toVar l}"

def toPropForm (l : L) : PropForm ν :=
  if polarity l then .var (toVar l) else .neg (.var $ toVar l)

instance : CoeHead L (PropForm ν) := ⟨toPropForm⟩

def toPropFun (l : L) : PropFun ν :=
  if polarity l then .var (toVar l) else (.var $ toVar l)ᶜ

instance : CoeHead L (PropFun ν) := ⟨toPropFun⟩

open PropFun in
theorem satisfies_iff {τ : PropAssignment ν} {l : L} :
    τ ⊨ toPropFun l ↔ τ (toVar l) = polarity l := by
  dsimp [toPropFun, polarity]
  aesop

end LitVar

/-! ### Lawful literals -/

-- TODO: see if a shorter list of axioms implies this one
open LitVar in
class LawfulLitVar (L : Type u) (ν : outParam (Type v)) [LitVar L ν] where
  toVar_negate (l : L) : toVar (-l) = toVar l
  toVar_mkPos (x : ν) : toVar (mkPos (L := L) x) = x
  toVar_mkNeg (x : ν) : toVar (mkNeg (L := L) x) = x
  polarity_negate (l : L) : polarity (-l) = !polarity l
  polarity_mkPos (x : ν) : polarity (mkPos (L := L) x) = true
  polarity_mkNeg (x : ν) : polarity (mkNeg (L := L) x) = false
  protected ext (l₁ l₂ : L) : toVar l₁ = toVar l₂ → polarity l₁ = polarity l₂ → l₁ = l₂

open LawfulLitVar in
attribute [simp] toVar_negate toVar_mkPos toVar_mkNeg polarity_negate polarity_mkPos polarity_mkNeg

open LawfulLitVar in
attribute [ext] LawfulLitVar.ext

namespace LitVar

variable {L : Type u} {ν : Type v} [LitVar L ν]

-- Some theorems can be proven on `LitVar`s, without the `Lawful` laws.

@[simp]
theorem mk_toPropForm (l : L) : ⟦toPropForm l⟧ = toPropFun l := by
  dsimp [toPropForm, toPropFun]
  cases polarity l <;> simp

@[simp]
theorem vars_toPropForm [DecidableEq ν] (l : L) : (toPropForm l).vars = {toVar l} := by
  dsimp [toPropForm]
  cases polarity l <;> simp [PropForm.vars]

@[simp]
theorem semVars_toPropFun [DecidableEq ν] (l : L) : (toPropFun l).semVars = {toVar l} := by
  dsimp [toPropFun]
  cases polarity l <;> simp

-- The rest of the theorems need the laws

variable [LawfulLitVar L ν]

open LawfulLitVar

@[simp] theorem var_mkLit (x : ν) (p : Bool) : toVar (mkLit L x p) = x := by
  dsimp [mkLit]; split <;> simp
@[simp] theorem polarity_mkLit (x : ν) (p : Bool) : polarity (mkLit L x p) = p := by
  dsimp [mkLit]; split <;> simp_all

@[simp] theorem eta (l : L) : mkLit L (toVar l) (polarity l) = l := by
  ext <;> simp
@[simp] theorem eta_neg (l : L) : mkLit L (toVar l) (!polarity l) = -l := by
  ext <;> simp

theorem mkPos_or_mkNeg (l : L) : l = mkPos (toVar l) ∨ l = mkNeg (toVar l) := by
  rw [← eta l]
  cases polarity l
  . apply Or.inr
    simp [mkLit]
  . apply Or.inl
    simp [mkLit]

@[simp] theorem toPropForm_mkPos (x : ν) : toPropForm (mkPos (L := L) x) = .var x := by
  simp [toPropForm]
@[simp] theorem toPropForm_mkNeg (x : ν) : toPropForm (mkNeg (L := L) x) = .neg (.var x) := by
  simp [toPropForm]

@[simp] theorem toPropFun_mkPos (x : ν) : toPropFun (mkPos (L := L) x) = .var x := by
  simp [toPropFun]
@[simp] theorem toPropFun_mkNeg (x : ν) : toPropFun (mkNeg (L := L) x) = (.var x)ᶜ := by
  simp [toPropFun]
@[simp] theorem toPropFun_mkLit_true : toPropFun (mkLit L v true) = .var v := by
  simp [toPropFun]
@[simp] theorem toPropFun_mkLit_false : toPropFun (mkLit L v false) = (.var v)ᶜ := by
  simp [toPropFun]
@[simp] theorem toPropFun_neg (l : L) : toPropFun (-l) = (toPropFun l)ᶜ := by
  dsimp [toPropFun]
  aesop

theorem ext_iff (l1 l2 : L) : l1 = l2 ↔ toVar l1 = toVar l2 ∧ polarity l1 = polarity l2 := by
  constructor
  · rintro rfl; simp
  · aesop

@[simp] theorem neg_eq_neg (l1 l2 : L) : -l1 = -l2 ↔ l1 = l2 := by
  constructor
  · rw [ext_iff, ext_iff (L := L)]; simp
  · rintro rfl; rfl

@[simp] theorem neg_neg (l : L) : - (- l) = l := by
  rw [ext_iff]; simp


open PropFun

theorem satisfies_neg {τ : PropAssignment ν} {l : L} :
    τ ⊨ toPropFun (-l) ↔ τ ⊭ toPropFun l := by
  simp [satisfies_iff]

omit [LawfulLitVar L ν] in
theorem satisfies_set [DecidableEq ν] (τ : PropAssignment ν) (l : L) :
    τ.set (toVar l) (polarity l) ⊨ toPropFun l := by
  simp [satisfies_iff, τ.set_get]

theorem eq_of_flip [DecidableEq ν] {τ : PropAssignment ν} {l : L} {x : ν} {p : Bool} :
    τ ⊭ toPropFun l → τ.set x p ⊨ toPropFun l → l = mkLit L x p := by
  simp only [satisfies_iff]
  intro h hSet
  by_cases hEq : x = toVar l
  . rw [hEq, τ.set_get] at hSet
    simp [hSet, hEq]
  . exfalso; exact h (τ.set_get_of_ne p hEq ▸ hSet)

theorem eq_of_flip' [DecidableEq ν] {τ : PropAssignment ν} {l : L} {x : ν} {p : Bool} :
    τ ⊨ toPropFun l → τ.set x p ⊭ toPropFun l → l = mkLit L x !p := by
  simp only [satisfies_iff]
  intro h hSet
  by_cases hEq : x = toVar l
  . rw [hEq, τ.set_get] at hSet
    have : (!p) = polarity l := by
      simp [Bool.eq_bnot, hSet]
    simp [hEq, this]
  . exfalso; exact hSet (τ.set_get_of_ne p hEq ▸ h)

theorem toPropFun.inj [DecidableEq ν] : (toPropFun (L := L)).Injective := by
  intro l₁ l₂ h; simp [toPropFun] at h
  split_ifs at h
  · rename_i h₁ h₂
    rw [var_eq_var] at h
    apply LawfulLitVar.ext _ _ h
    rw [h₁, h₂]
  · simp only [var_ne_var_compl] at h
  · simp only [var_compl_ne_var] at h
  · rename_i h₁ h₂
    simp only [Bool.not_eq_true] at h₁ h₂
    simp only [compl_inj_iff, var_eq_var] at h
    apply LawfulLitVar.ext _ _ h
    rw [h₁, h₂]

def map [LitVar L V] [LitVar L' V'] (f : V → V') (l : L) : L' :=
  LitVar.mkLit _ (f (LitVar.toVar l)) (LitVar.polarity l)

@[simp]
theorem satisfies_map [LitVar L V] [LitVar L' V']
    [LawfulLitVar L' V'] (f : V → V') (l : L) (τ : PropAssignment V')
  : τ ⊨ LitVar.toPropFun (LitVar.map f l : L') ↔ τ.map f ⊨ LitVar.toPropFun l
  := by
  simp [map, toPropFun]
  split <;> simp

@[simp]
theorem toPropFun_map [LitVar L V] [LitVar L' V'] [LawfulLitVar L' V'] (f : V → V') (l : L)
    : LitVar.toPropFun (LitVar.map f l : L') = (LitVar.toPropFun l).map f := by
  ext τ; simp


/-! #### Sums as valid literals -/

variable [LitVar L1 V1] [LitVar L2 V2]

instance : LitVar (L1 ⊕ L2) (V1 ⊕ V2) where
  mkPos := Sum.map (LitVar.mkPos) (LitVar.mkPos)
  mkNeg := Sum.map (LitVar.mkNeg) (LitVar.mkNeg)
  toVar := Sum.map (LitVar.toVar) (LitVar.toVar)
  polarity := fun | .inl l => LitVar.polarity l | .inr l => LitVar.polarity l
  negate := Sum.map (LitVar.negate) (LitVar.negate)

instance [LawfulLitVar L1 V1] [LawfulLitVar L2 V2]
    : LawfulLitVar (L1 ⊕ L2) (V1 ⊕ V2) where
  toVar_mkPos     := by rintro (_ | _) <;> simp [toVar, mkPos]
  toVar_mkNeg     := by rintro (_ | _) <;> simp [toVar, mkNeg]
  toVar_negate    := by rintro (_ | _) <;> simp_rw [Neg.neg, negate] <;> simp [toVar]
  polarity_mkPos  := by rintro (_ | _) <;> simp [polarity, mkPos]
  polarity_mkNeg  := by rintro (_ | _) <;> simp [polarity, mkNeg]
  polarity_negate := by rintro (_ | _) <;> simp_rw [Neg.neg, negate] <;> simp [polarity]
  ext := by
    rintro (l₁ | l₁) (l₂ | l₂)
    <;> rcases mkPos_or_mkNeg l₁ with (h₁ | h₁)
    <;> rcases mkPos_or_mkNeg l₂ with (h₂ | h₂)
    all_goals (
      rw [h₁, h₂]
      simp [toVar, polarity]
      try intro h
      try rw [h]
    )

@[simp] theorem polarity_inl (l : L1)
  : polarity (L := L1 ⊕ L2) (ν := V1 ⊕ V2) (Sum.inl l) = polarity l := rfl

@[simp] theorem polarity_inr (l : L2)
  : polarity (L := L1 ⊕ L2) (ν := V1 ⊕ V2) (Sum.inr l) = polarity l := rfl

@[simp] theorem toVar_inl (l : L1)
  : toVar (L := L1 ⊕ L2) (ν := V1 ⊕ V2) (Sum.inl l) = .inl (toVar l) := rfl

@[simp] theorem toVar_inr (l : L2)
  : toVar (L := L1 ⊕ L2) (ν := V1 ⊕ V2) (Sum.inr l) = .inr (toVar l) := rfl

end LitVar

/-! ### Clauses -/

abbrev Clause (L : Type u) := Array L

namespace Clause

instance [ToString L] : ToString (Clause L) where
  toString C := s!"({String.intercalate " ∨ " (C.map toString).toList})"

variable {L : Type u} {ν : Type v} [LitVar L ν]

def toPropFun (C : Clause L) : PropFun ν :=
  .any (Multiset.ofList C.toList |>.map LitVar.toPropFun)

instance : CoeHead (Clause L) (PropFun ν) := ⟨toPropFun⟩

theorem mem_semVars_toPropFun [DecidableEq ν] (x : ν) (C : Clause L)
  : x ∈ C.toPropFun.semVars → ∃ l, l ∈ C ∧ LitVar.toVar l = x := by
  intro h
  rcases C with ⟨data⟩
  have ⟨τ,hpos,hneg⟩ := (PropFun.mem_semVars _ _).mp h; clear h
  simp_all [toPropFun, Array.mem_def]
  rcases hpos with ⟨l,hl,h⟩
  have := (PropFun.mem_semVars _ _).mpr ⟨τ,h,hneg l hl⟩; clear hneg h
  aesop

open PropFun

theorem satisfies_iff {τ : PropAssignment ν} {C : Clause L} :
    τ ⊨ C.toPropFun ↔ ∃ l ∈ C, τ ⊨ LitVar.toPropFun l := by
  simp_rw [toPropFun, Array.mem_def]
  simp

theorem tautology_iff [DecidableEq ν] [LawfulLitVar L ν] (C : Clause L) :
    C.toPropFun = ⊤ ↔ ∃ l₁ ∈ C, ∃ l₂ ∈ C, l₁ = -l₂ := by
  constructor
  · intro h
    rcases C with ⟨lits⟩
    simp_all [toPropFun, Array.mem_def]
    induction lits with
    | nil => rw [PropFun.ext_iff] at h; simp [Array.mem_def] at h
    | cons hd tl ih =>
    classical
    refine if hr : any _ = ⊤ then have := ih hr; ?_ else ?_
    · aesop
    · clear ih
      rw [PropFun.ext_iff] at hr h
      simp at hr h
      rcases hr with ⟨τ,hr⟩
      replace h := h (τ.set (LitVar.toVar hd) (!LitVar.polarity hd))
      simp [LitVar.satisfies_iff, Bool.not_ne_self] at h
      rcases h with ⟨hd',hd'_mem,h⟩
      · replace hr := hr hd' hd'_mem
        simp [LitVar.satisfies_iff, PropAssignment.set] at hr h
        use hd, (List.mem_cons_self _ _), hd', (List.mem_cons_of_mem _ hd'_mem)
        split at h
        · ext
          · rw [LawfulLitVar.toVar_negate]; symm; assumption
          · rw [LawfulLitVar.polarity_negate]; exact Bool.not_eq_eq_eq_not.mp h
        · exact absurd h hr
  · rintro ⟨_,hl1,l,hl2,rfl⟩
    ext τ; simp [satisfies_iff]
    by_cases τ ⊨ LitVar.toPropFun l <;> aesop

def or (c1 c2 : Clause L) : Clause L :=
  c1 ++ c2

@[simp] theorem toPropFun_or (c1 c2 : Clause L)
  : (c1.or c2).toPropFun = c1.toPropFun ⊔ c2.toPropFun := by
  ext τ
  simp [or, satisfies_iff]
  apply Iff.intro
  · rintro ⟨l,h1,h2⟩
    cases h1
    · refine Or.inl ⟨l,?_⟩
      simp [*]
    · refine Or.inr ⟨l,?_⟩
      simp [*]
  · rintro (⟨l,h1,h2⟩|⟨l,h1,h2⟩)
    · refine ⟨l,?_⟩
      simp [*]
    · refine ⟨l,?_⟩
      simp [*]

nonrec def map (L') [LitVar L' ν'] (f : ν → ν') (c : Clause L) : Clause L' :=
  c.map (LitVar.map f)

@[simp] theorem toPropFun_map [LitVar L' ν'] [LawfulLitVar L' ν'] (f : ν → ν') (c : Clause L)
  : (c.map L' f).toPropFun = c.toPropFun.map f
  := by
  ext τ
  simp [map, satisfies_iff]

end Clause

/-! ### CNF -/

abbrev Cnf (L : Type u) := Array (Clause L)

namespace Cnf

instance [ToString L] : ToString (Cnf L) where
  toString C := s!"{String.intercalate " ∧ " (C.map toString).toList}"

variable {L : Type u} {ν : Type v} [LitVar L ν]

def toPropFun (φ : Cnf L) : PropFun ν :=
  .all (φ.toList.map Clause.toPropFun)

theorem semVars_toPropFun [DecidableEq ν] (F : Cnf L)
  : v ∈ (toPropFun F).semVars → ∃ C, C ∈ F ∧ ∃ l, l ∈ C ∧ LitVar.toVar l = v := by
  rcases F with ⟨F⟩; simp_rw [Array.mem_def]; simp [toPropFun, PropFun.all]
  induction F <;> simp
  next hd tl ih =>
  intro hv
  have := PropFun.semVars_conj _ _ hv
  simp at this
  rcases this with (h|h)
  · have := Clause.mem_semVars_toPropFun _ _ h
    simp_rw [Array.mem_def] at this
    aesop
  · have := ih h
    simp_rw [Array.mem_def] at *
    simp_all

instance : CoeHead (Cnf L) (PropFun ν) := ⟨toPropFun⟩

theorem mem_semVars_toPropFun [DecidableEq ν] (x : ν) (F : Cnf L)
  : x ∈ F.toPropFun.semVars → ∃ C, C ∈ F ∧ x ∈ C.toPropFun.semVars := by
  intro h
  rcases F with ⟨data⟩
  simp [Array.mem_def]
  induction data <;> simp_all [toPropFun, PropFun.all]
  replace h := PropFun.semVars_conj _ _ h
  aesop

open PropFun

theorem satisfies_iff {τ : PropAssignment ν} {φ : Cnf L} :
    τ ⊨ φ.toPropFun ↔ ∀ C ∈ φ, τ ⊨ C.toPropFun := by
  rw [toPropFun]
  rcases φ with ⟨φ⟩
  induction φ <;> simp_all [Array.mem_def]

def addClause (C : Clause L) (f : Cnf L) : Cnf L := f.push C

@[simp]
theorem toPropFun_addClause (C : Clause L) (f : Cnf L)
    : (f.addClause C).toPropFun = f.toPropFun ⊓ C.toPropFun := by
  have ⟨C⟩ := C
  have ⟨f⟩ := f
  ext τ
  simp [satisfies_iff, addClause]
  constructor
  · intro h
    constructor
    · intro C' hC'
      exact h C' (Or.inl hC')
    · exact h _ (Or.inr rfl)
  · rintro ⟨hF, hC⟩ C' (hC' | rfl)
    · exact hF _ hC'
    · exact hC

def and (f1 f2 : Cnf L) : Cnf L := f1 ++ f2

@[simp]
theorem toPropFun_and (f1 f2 : Cnf L)
    : (f1.and f2).toPropFun = f1.toPropFun ⊓ f2.toPropFun := by
  have ⟨f1⟩ := f1
  have ⟨f2⟩ := f2
  ext τ
  simp [satisfies_iff, and]
  constructor
  · intro h
    constructor
    <;> intro C hC
    · exact h C (Or.inl hC)
    · exact h C (Or.inr hC)
  · rintro ⟨h₁, h₂⟩ C (hC | hC)
    · exact h₁ _ hC
    · exact h₂ _ hC

def not (c : Clause L) : Cnf L :=
  Array.map (fun l => #[-l]) c

@[simp]
theorem toPropFun_not (c : Clause L) [LawfulLitVar L ν]
    : (not c).toPropFun = (c.toPropFun)ᶜ := by
  have ⟨c⟩ := c
  ext τ
  simp [not, satisfies_iff, Clause.satisfies_iff, LitVar.satisfies_iff]
  constructor
  · intro h l h_mem hl
    simp [h _ h_mem] at hl
  · intro h l h_mem
    exact Bool.eq_not.mpr (h l h_mem)

def any (ls : Array L) : Cnf L := #[ls]

@[simp]
theorem toPropFun_any (ls : Array L)
    : (any ls).toPropFun = .any (ls.toList.map LitVar.toPropFun) := by
  have ⟨ls⟩ := ls
  ext τ
  simp [any, toPropFun, Clause.toPropFun]

def all (ls : Array L) : Cnf L :=
  Array.map (fun l => #[l]) ls

@[simp]
theorem toPropFun_all (ls : Array L)
    : (all ls).toPropFun = .all (ls.toList.map LitVar.toPropFun) := by
  have ⟨ls⟩ := ls
  ext τ
  simp [satisfies_iff, Clause.satisfies_iff, LitVar.satisfies_iff, all]

end Cnf
