(** A type that represents values with two possibilities.

    [Either] can be seen as a generic sum type, the dual of [Tuple].  [First] is neither
    more important nor less important than [Second].

    Many functions in [Either] focus on just one constructor.  The [Focused] signature
    abstracts over which constructor is the focus.  To use these functions, use the
    [First] or [Second] modules in [S].  *)

open! Import

module type Focused = sig
  type (+'focus, +'other) t

  include Monad.S2_local with type ('a, 'b) t := ('a, 'b) t
  include Applicative.S2_local with type ('a, 'b) t := ('a, 'b) t

  val value : ('a, _) t -> default:'a -> 'a
  val to_option : ('a, _) t -> 'a option
  val with_return : ((('a With_return.return[@local]) -> 'b)[@local]) -> ('a, 'b) t

  val combine
    :  ('a, 'd) t
    -> ('b, 'd) t
    -> f:(('a -> 'b -> 'c)[@local])
    -> other:(('d -> 'd -> 'd)[@local])
    -> ('c, 'd) t

  val combine_all : ('a, 'b) t list -> f:(('b -> 'b -> 'b)[@local]) -> ('a list, 'b) t
  val combine_all_unit : (unit, 'b) t list -> f:(('b -> 'b -> 'b)[@local]) -> (unit, 'b) t
end

module type Either = sig
  type ('f, 's) t = ('f, 's) Either0.t =
    | First of 'f
    | Second of 's
  [@@deriving_inline compare ~localize, hash, sexp, sexp_grammar]

  include Ppx_compare_lib.Comparable.S2 with type ('f, 's) t := ('f, 's) t
  include Ppx_compare_lib.Comparable.S_local2 with type ('f, 's) t := ('f, 's) t
  include Ppx_hash_lib.Hashable.S2 with type ('f, 's) t := ('f, 's) t
  include Sexplib0.Sexpable.S2 with type ('f, 's) t := ('f, 's) t

  val t_sexp_grammar
    :  'f Sexplib0.Sexp_grammar.t
    -> 's Sexplib0.Sexp_grammar.t
    -> ('f, 's) t Sexplib0.Sexp_grammar.t

  [@@@end]

  include Invariant.S2 with type ('a, 'b) t := ('a, 'b) t

  val swap : ('f, 's) t -> ('s, 'f) t
  val value : ('a, 'a) t -> 'a

  val iter
    :  ('a, 'b) t
    -> first:(('a -> unit)[@local])
    -> second:(('b -> unit)[@local])
    -> unit

  val value_map
    :  ('a, 'b) t
    -> first:(('a -> 'c)[@local])
    -> second:(('b -> 'c)[@local])
    -> 'c

  val map
    :  ('a, 'b) t
    -> first:(('a -> 'c)[@local])
    -> second:(('b -> 'd)[@local])
    -> ('c, 'd) t

  val equal : ('f -> 'f -> bool) -> ('s -> 's -> bool) -> ('f, 's) t -> ('f, 's) t -> bool

  val local_equal
    :  (('f[@local]) -> ('f[@local]) -> bool)
    -> (('s[@local]) -> ('s[@local]) -> bool)
    -> (('f, 's) t[@local])
    -> (('f, 's) t[@local])
    -> bool

  module type Focused = Focused

  module First : Focused with type ('a, 'b) t = ('a, 'b) t
  module Second : Focused with type ('a, 'b) t = ('b, 'a) t

  val is_first : (_, _) t -> bool
  val is_second : (_, _) t -> bool

  (** [first] and [second] are [First.return] and [Second.return]. *)
  val first : 'f -> ('f, _) t

  val second : 's -> (_, 's) t

  (**/**)

  module Export : sig
    type ('f, 's) _either = ('f, 's) t =
      | First of 'f
      | Second of 's
  end
end
