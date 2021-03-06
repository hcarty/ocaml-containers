(*
Copyright (c) 2013, Simon Cruanes
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.  Redistributions in binary
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

(** {1 Simple and efficient S-expression parsing/printing}

@since 0.4 *)

type 'a or_error = [ `Ok of 'a | `Error of string ]
type 'a sequence = ('a -> unit) -> unit
type 'a gen = unit -> 'a option

(** {2 Basics} *)

type t = [
  | `Atom of string
  | `List of t list
  ]

val equal : t -> t -> bool
val compare : t -> t -> int
val hash : t -> int

val atom : string -> t  (** Build an atom directly from a string *)

val of_int : int -> t
val of_bool : bool -> t
val of_list : t list -> t
val of_rev_list : t list -> t  (** Reverse the list *)
val of_float : float -> t
val of_unit : t
val of_pair : t * t -> t
val of_triple : t * t * t -> t
val of_quad : t * t * t * t -> t

val of_variant : string -> t list -> t
(** [of_variant name args] is used to encode algebraic variants
    into a S-expr. For instance [of_variant "some" [of_int 1]]
    represents the value [Some 1] *)

val of_field : string -> t -> t
(** Used to represent one record field *)

val of_record : (string * t) list -> t
(** Represent a record by its named fields *)

(** {2 Serialization (encoding)} *)

val to_buf : Buffer.t -> t -> unit

val to_string : t -> string

val to_file : string -> t -> unit

val to_file_seq : string -> t sequence -> unit
(** Print the given sequence of expressions to a file *)

val to_chan : out_channel -> t -> unit

val print : Format.formatter -> t -> unit
(** Pretty-printer nice on human eyes (including indentation) *)

val print_noindent : Format.formatter -> t -> unit
(** Raw, direct printing as compact as possible *)

(** {2 Deserialization (decoding)} *)

type 'a parse_result = ['a or_error | `End ]
type 'a partial_result = [ 'a parse_result | `Await ]

(** {6 Source of characters} *)
module Source : sig
  type individual_char =
    | NC_yield of char
    | NC_end
    | NC_await
  (** An individual character returned by a source *)

  type t = unit -> individual_char
  (** A source of characters can yield them one by one, or signal the end,
      or signal that some external intervention is needed *)

  type source = t

  (** A manual source of individual characters. When it has exhausted its
      own input, it asks its caller to provide more or signal that none remains
      This is especially useful when the source of data is monadic IO *)
  module Manual : sig
    type t

    val make : unit -> t
    (** Make a new manual source. It needs to be fed input manually,
        using {!feed} *)

    val to_src : t -> source
    (** The manual source contains a source! *)

    val feed : t -> string -> int -> int -> unit
    (** Feed a chunk of input to the manual source *)

    val reached_end : t -> unit
    (** Tell the decoder that end of input has been reached. From now
        the source will only yield [NC_end] *)
  end

  val of_string : string -> t
  (** Use a single string as the source *)

  val of_chan : ?bufsize:int -> in_channel -> t
  (** Use a channel as the source *)

  val of_gen : string gen -> t
end

(** {6 Streaming Lexer}
splits the input into opening parenthesis, closing ones, and atoms *)
module Lexer : sig
  type t
  (** A streaming lexer, that parses atomic chunks of S-expressions (atoms
      and delimiters) *)

  val make : Source.t -> t
  (** Create a lexer that uses the given source of characters as an input *)

  val of_string : string -> t

  val of_chan : in_channel -> t

  val line : t -> int
  val col : t -> int

  (** Obtain next token *)

  type token =
    | Open
    | Close
    | Atom of string
  (** An individual S-exp token *)

  val next : t -> token partial_result
  (** Obtain the next token, an error, or block/end stream *)
end

(** {6 Generator with errors} *)
module ParseGen : sig
  type 'a t = unit -> 'a parse_result
  (** A generator-like structure, but with the possibility of errors.
      When called, it can yield a new element, signal the end of stream,
      or signal an error. *)

  val to_list : 'a t -> 'a list or_error

  val head : 'a t -> 'a or_error

  val head_exn : 'a t -> 'a

  val take : int -> 'a t -> 'a t
end

(** {6 Stream Parser}
Returns a lazy stream of S-expressions. *)

val parse_string : string -> t ParseGen.t
(** Parse a string *)

val parse_chan : ?bufsize:int -> in_channel -> t ParseGen.t
(** Parse a channel *)

val parse_gen : string gen -> t ParseGen.t
(** Parse chunks of string *)

(** {6 Blocking API}
Parse one S-expression from some source.  *)

val of_chan : in_channel -> t or_error
(** Parse a S-expression from the given channel. Can read more data than
    necessary, so don't use this if you need finer-grained control (e.g.
    to read something else {b after} the S-exp) *)

val of_string : string -> t or_error

val of_file : string -> t or_error
(** Open the file and read a S-exp from it *)

(** {6 Lists of S-exps} *)

module L : sig
  val to_buf : Buffer.t -> t list -> unit

  val to_string : t list -> string

  val to_file : string -> t list -> unit

  val to_chan : out_channel -> t list -> unit

  val of_chan : ?bufsize:int -> in_channel -> t list or_error

  val of_file : ?bufsize:int -> string -> t list or_error

  val of_string : string -> t list or_error

  val of_gen : string gen -> t list or_error

  val of_seq : string sequence -> t list or_error
end

(** {6 Traversal of S-exp}

Example: serializing 2D points
{[
type pt = {x:int; y:int };;

let pt_of_sexp e =
  Sexp.Traverse.(
    field "x" to_int e >>= fun x ->
    field "y" to_int e >>= fun y ->
    return {x;y}
  );;

let sexp_of_pt pt = Sexp.(of_record ["x", of_int pt.x; "y", of_int pt.y]);;

let l = [{x=1;y=1}; {x=2;y=10}];;

let sexp = Sexp.(of_list (List.map sexp_of_pt l));;

Sexp.Traverse.list_all pt_of_sexp sexp;;
]}

*)

module Traverse : sig
  type 'a conv = t -> 'a option
  (** A converter from S-expressions to 'a is a function [sexp -> 'a option].
      @since 0.5 *)

  val map_opt : ('a -> 'b option) -> 'a list -> 'b list option
  (** Map over a list, failing as soon as the function fails on any element
      @since 0.5 *)

  val list_any : 'a conv -> t -> 'a option
  (** [list_any f (List l)] tries [f x] for every element [x] in [List l],
      and returns the first non-None result (if any). *)

  val list_all : 'a conv -> t -> 'a list
  (** [list_all f (List l)] returns the list of all [y] such that [x] in [l]
      and [f x = Some y] *)

  val to_int : int conv
  (** Expect an integer *)

  val to_string : string conv
  (** Expect a string (an atom) *)

  val to_bool : bool conv
  (** Expect a boolean *)

  val to_float : float conv
  (** Expect a float *)

  val to_list : t list conv
  (** Expect a list *)

  val to_list_with : (t -> 'a option) -> 'a list conv
  (** Expect a list, applies [f] to all the elements of the list, and succeeds
      only if [f] succeeded on every element 
      @since 0.5 *)

  val to_pair : (t * t) conv
  (** Expect a list of two elements *)

  val to_pair_with : 'a conv -> 'b conv -> ('a * 'b) conv
  (** Same as {!to_pair} but applies conversion functions
      @since 0.5 *)

  val to_triple : (t * t * t) conv

  val to_triple_with : 'a conv -> 'b conv -> 'c conv -> ('a * 'b * 'c) conv
      (* @since 0.5 *)

  val get_field : string -> t conv
  (** [get_field name e], when [e = List [(n1,x1); (n2,x2) ... ]], extracts
      the [xi] such that [name = ni], if it can find it. *)

  val field : string -> 'a conv -> 'a conv
  (** Enriched version of {!get_field}, with a converter as argument *)

  val get_variant : (string * (t list -> 'a option)) list -> 'a conv
  (** [get_variant l e] checks whether [e = List (Atom s :: args)], and
      if some pair of [l] is [s, f]. In this case, it calls [f args]
      and returns its result, otherwise it returns None. *)

  val field_list : string -> (t list -> 'a option) -> 'a conv
  (** [field_list name f  "(... (name a b c d) ...record)"]
      will look for a field based on the given [name], and expect it to have a
      list of arguments dealt with by [f] (here, "a b c d").
      @since 0.5 *)

  val (>>=) : 'a option -> ('a -> 'b option) -> 'b option

  val (>|=) : 'a option -> ('a -> 'b) -> 'b option

  val return : 'a -> 'a option

  val get_exn : 'a option -> 'a
  (** Unwrap an option, possibly failing.
      @raise Invalid_argument if the argument is [None] *)
end
