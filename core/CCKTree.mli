
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

(** {1 Lazy Tree Structure}
This structure can be used to represent trees and directed
graphs (as infinite trees) in a lazy fashion. Like {!CCKList}, it
is a structural type. *)

type 'a sequence = ('a -> unit) -> unit
type 'a gen = unit -> 'a option
type 'a klist = unit -> [`Nil | `Cons of 'a * 'a klist]
type 'a printer = Buffer.t -> 'a -> unit

(** {2 Basics} *)

type +'a t = unit -> [`Nil | `Node of 'a * 'a t list]

val empty : 'a t

val is_empty : _ t -> bool

val singleton : 'a -> 'a t
(** Tree with only one label *)

val node : 'a -> 'a t list -> 'a t
(** Build a node from a label and a list of children *)

val node1 : 'a -> 'a t -> 'a t
(** Node with one child *)

val node2 : 'a -> 'a t -> 'a t -> 'a t
(** Node with two children *)

val fold : ('a -> 'b -> 'a) -> 'a -> 'b t -> 'a
(** Fold on values in no specified order. May not terminate if the
    tree is infinite. *)

val iter : ('a -> unit) -> 'a t -> unit

val size : _ t -> int
(** Number of elements *)

val height : _ t -> int
(** Length of the longest path to empty leaves *)

val map : ('a -> 'b) -> 'a t -> 'b t

val (>|=) : 'a t -> ('a -> 'b) -> 'b t

val cut_depth : int -> 'a t -> 'a t
(** Cut the tree at the given depth, so it becomes finite. *)

(** {2 Graph Traversals} *)

(** Abstract Set structure *)
class type ['a] pset = object
  method add : 'a -> 'a pset
  method mem : 'a -> bool
end

val set_of_cmp : ?cmp:('a -> 'a -> int) -> unit -> 'a pset
(** Build a set structure given a total ordering *)

val dfs : ?pset:'a pset -> 'a t -> [ `Enter of 'a | `Exit of 'a ] klist
(** Depth-first traversal of the tree *)

val bfs : ?pset:'a pset -> 'a t -> 'a klist
(** Breadth first traversal of the tree *)

val find : ?pset:'a pset -> ('a -> 'b option) -> 'a t -> 'b option
(** Look for an element that maps to [Some _] *)

(** {2 Pretty printing in the DOT (graphviz) format} *)

module Dot : sig
  type attribute = [
  | `Color of string
  | `Shape of string
  | `Weight of int
  | `Style of string
  | `Label of string
  | `Id of string  (** Unique ID in the graph. Allows sharing. *)
  | `Other of string * string
  ] (** Dot attributes for nodes *)

  type graph = (string * attribute list t list)
  (** A dot graph is a name, plus a list of trees labelled with attributes *)

  val mk_id : ('a, Buffer.t, unit, attribute) format4 -> 'a
  (** Using a formatter string, build an ID *)

  val mk_label : ('a, Buffer.t, unit, attribute) format4 -> 'a
  (** Using a formatter string, build a label *)

  val make : name:string -> attribute list t list -> graph

  val singleton : name:string -> attribute list t -> graph

  val pp : graph printer
  (** Print the graph in DOT *)

  val pp_single : string -> attribute list t printer
end

