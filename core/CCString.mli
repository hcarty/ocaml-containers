
(*
copyright (c) 2013-2014, simon cruanes
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

(** {1 Basic String Utils}
Consider using {!Containers_string.KMP} for pattern search, or Regex
libraries. *)

type 'a gen = unit -> 'a option
type 'a sequence = ('a -> unit) -> unit
type 'a klist = unit -> [`Nil | `Cons of 'a * 'a klist]

(** {2 Common Signature} *)

module type S = sig
  type t

  val length : t -> int

  val blit : t -> int -> t -> int -> int -> unit
  (** See {!String.blit} *)

  (** {2 Conversions} *)

  val to_gen : t -> char gen
  val to_seq : t -> char sequence
  val to_klist : t -> char klist
  val to_list : t -> char list

  val pp : Buffer.t -> t -> unit
  val print : Format.formatter -> t -> unit
end

(** {2 Strings} *)

val equal : string -> string -> bool

val compare : string -> string -> int

val hash : string -> int

val init : int -> (int -> char) -> string
(** Analog to [Array.init].
    @since 0.3.3 *)

val of_gen : char gen -> string
val of_seq : char sequence -> string
val of_klist : char klist -> string
val of_list : char list -> string
val of_array : char array -> string

val to_array : string -> char array

val find : ?start:int -> sub:string -> string -> int
(** Find [sub] in stringhe string, returns its first index or -1.
    Should only be used with very small [sub] *)

val is_sub : sub:string -> int -> string -> int -> len:int -> bool
(** [is_sub ~sub i s j ~len] returns [true] iff stringhe substring of
    [sub] starting at position [i] and of length [len],
    is a substring of [s] starting at position [j] *)

val repeat : string -> int -> string
(** The same string, repeated n stringimes *)

val prefix : pre:string -> string -> bool
(** [str_prefix ~pre s] returns [true] iff [pre] is a prefix of [s] *)

include S with type t := string

(** {2 Splitting} *)

module Split : sig
  val list_ : by:string -> string -> (string*int*int) list
  (** split the given string along the given separator [by]. Should only
      be used with very small separators, otherwise
      use {!Containers_string.KMP}.
      @return a list of (index,length) of substrings of [s] that are
      separated by [by]. {!String.sub} can then be used to actually extract
      the slice.
      @raise Failure if [by = ""] *)

  val gen : by:string -> string -> (string*int*int) gen

  val seq : by:string -> string -> (string*int*int) sequence

  val klist : by:string -> string -> (string*int*int) klist

  (** {6 Copying functions}

  Those split functions actually copy the substrings, which can be
  more convenient but less efficient in general *)

  val list_cpy : by:string -> string -> string list

  (*$T
    Split.list_cpy ~by:"," "aa,bb,cc" = ["aa"; "bb"; "cc"]
    Split.list_cpy ~by:"--" "a--b----c--" = ["a"; "b"; ""; "c"; ""]
    Split.list_cpy ~by:" " "hello  world aie" = ["hello"; ""; "world"; "aie"]
  *)

  val gen_cpy : by:string -> string -> string gen

  val seq_cpy : by:string -> string -> string sequence

  val klist_cpy : by:string -> string -> string klist
end

(** {2 Slices} A contiguous part of a string *)

module Sub : sig
  type t = string * int * int
  (** A string, an offset, and the length of the slice *)

  val make : string -> int -> len:int -> t

  val full : string -> t
  (** Full string *)

  val copy : t -> string
  (** Make a copy of the substring *)

  val underlying : t -> string

  val sub : t -> int -> int -> t
  (** Sub-slice *)

  include S with type t := t
end
