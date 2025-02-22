(** Unicode character operations.

    A [Uchar.t] represents a Unicode code point -- that is, an integer identifying the
    character in abstract. This module does not provide any utilties for converting
    [Uchar.t]s to and from strings -- in order to do so, one needs to settle on a
    particular encoding, such as UTF-8 or UTF-16. See, for instance, the [utf8_text]
    library for converting to and from UTF-8.
*)

open! Import

type t = Uchar0.t [@@deriving_inline hash, sexp, sexp_grammar]

include Ppx_hash_lib.Hashable.S with type t := t
include Sexplib0.Sexpable.S with type t := t

val t_sexp_grammar : t Sexplib0.Sexp_grammar.t

[@@@end]

include Comparable.S with type t := t
include Ppx_compare_lib.Comparable.S_local with type t := t
include Ppx_compare_lib.Equal.S_local with type t := t
include Pretty_printer.S with type t := t
include Invariant.S with type t := t

(** [succ_exn t] is the scalar value after [t] in the set of Unicode scalar values, and
    raises if [t = max_value]. *)
val succ : t -> t option

val succ_exn : t -> t

(** [pred_exn t] is the scalar value before [t] in the set of Unicode scalar values, and
    raises if [t = min_value]. *)
val pred : t -> t option

val pred_exn : t -> t

(** [is_char t] is [true] iff [n] is in the latin-1 character set. *)
val is_char : t -> bool

(** [to_char_exn t] is [t] as a [char] if it is in the latin-1 character set, and raises
    otherwise. *)
val to_char : t -> char option

val to_char_exn : t -> char

(** [of_char c] is [c] as a Unicode character. *)
val of_char : char -> t

(** [int_is_scalar n] is [true] iff [n] is an Unicode scalar value (i.e., in the ranges
    [0x0000]...[0xD7FF] or [0xE000]...[0x10FFFF]). *)
val int_is_scalar : int -> bool

(** [of_scalar_exn n] is [n] as a Unicode character.  Raises if [not (int_is_scalar
    i)]. *)
val of_scalar : int -> t option

val of_scalar_exn : int -> t

(** [to_scalar t] is [t] as an integer scalar value. *)
val to_scalar : t -> int

(** [utf8_byte_width t] returns the number of bytes needed to represent [t] in the UTF-8
    encoding (https://en.wikipedia.org/wiki/UTF-8).

*)
val utf8_byte_length : t -> int

val min_value : t
val max_value : t
