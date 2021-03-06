
(*
copyright (c) 2013, simon cruanes
all rights reserved.

redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.  redistributions in binary
form must reproduce the above copyright notice, this list of conditions and the
following disclaimer in the documentation and/or other materials provided with
the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*)

(** {1 Rational Terms} *)

module type SYMBOL = sig
  type t
  val compare : t -> t -> int
  val to_string : t -> string
end

module type S = sig
  module Symbol : SYMBOL

  type t = private
    | Var of int
    | Ref of int
    | App of Symbol.t * t list

  type term = t

  type 'a env = 'a RAL.t
  
  (** Structural equality and comparisons. Two terms being different
      for {!eq} may still be equal, but with distinct representations.
      For instance [r:f(f(r))] and [r:f(r)] are the same term but they
      are not equal structurally. *)

  val eq : t -> t -> bool
  val cmp : t -> t -> int

  val eq_set : t -> t -> bool
  (** Proper equality on terms. This returns [true] if the two terms represent
      the same infinite tree, not only if they have the same shape. *)

  val var : unit -> t
    (** free variable, with a fresh name *)

  val mk_ref : int -> t
    (** Back-ref of [n] levels down (see De Bruijn indices) *)

  val app : Symbol.t -> t list -> t
    (** Application of a symbol to a list, possibly with a unique label *)

  val const : Symbol.t -> t
    (** Shortcut for [app s []] *)

  val pp : Buffer.t -> t -> unit
  val fmt : Format.formatter -> t -> unit
  val to_string : t -> string

  val rename : t -> t
    (** Rename all variables and references to fresh ones *)

  module Subst : sig
    type t
    val empty : t
    val bind : t -> int -> term -> t
    val deref : t -> term -> term
    val apply : ?depth:int -> t -> term -> term

    val pp : Buffer.t -> t -> unit
    val fmt : Format.formatter -> t -> unit
    val to_string : t -> string
  end

  val matching : ?subst:Subst.t -> term -> term -> Subst.t option
  val unify : ?subst:Subst.t -> term -> term -> Subst.t option
end

module Make(Sym : SYMBOL) : S with module Symbol = Sym

module Str : SYMBOL with type t = string

module Default : sig
  include S with module Symbol = Str

  (* TODO
  val of_string : string -> t option
  val of_string_exn : string -> t   (** @raise Failure possibly *)
  *)
end
