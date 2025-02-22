(** The purpose of [Type_equal] is to represent type equalities that the type checker
    otherwise would not know, perhaps because the type equality depends on dynamic data,
    or perhaps because the type system isn't powerful enough.

    A value of type [(a, b) Type_equal.t] represents that types [a] and [b] are equal.
    One can think of such a value as a proof of type equality.  The [Type_equal] module
    has operations for constructing and manipulating such proofs.  For example, the
    functions [refl], [sym], and [trans] express the usual properties of reflexivity,
    symmetry, and transitivity of equality.

    If one has a value [t : (a, b) Type_equal.t] that proves types [a] and [b] are equal,
    there are two ways to use [t] to safely convert a value of type [a] to a value of type
    [b]: [Type_equal.conv] or pattern matching on [Type_equal.T]:

    {[
      let f (type a) (type b) (t : (a, b) Type_equal.t) (a : a) : b =
        Type_equal.conv t a

      let f (type a) (type b) (t : (a, b) Type_equal.t) (a : a) : b =
        let Type_equal.T = t in a
    ]}

    At runtime, conversion by either means is just the identity -- nothing is changing
    about the value.  Consistent with this, a value of type [Type_equal.t] is always just
    a constructor [Type_equal.T]; the value has no interesting semantic content.
    [Type_equal] gets its power from the ability to, in a type-safe way, prove to the type
    checker that two types are equal.  The [Type_equal.t] value that is passed is
    necessary for the type-checker's rules to be correct, but the compiler could, in
    principle, not pass around values of type [Type_equal.t] at runtime.
*)

open! Import
open T

(**/**)

module Type_equal_defns (Type_equal : T.T2) = struct
  (** The [Lift*] module types are used by the [Lift*] functors. See below. *)

  module type Lift = sig
    type 'a t

    val lift : ('a, 'b) Type_equal.t -> ('a t, 'b t) Type_equal.t
  end

  module type Lift2 = sig
    type ('a, 'b) t

    val lift
      :  ('a1, 'b1) Type_equal.t
      -> ('a2, 'b2) Type_equal.t
      -> (('a1, 'a2) t, ('b1, 'b2) t) Type_equal.t
  end

  module type Lift3 = sig
    type ('a, 'b, 'c) t

    val lift
      :  ('a1, 'b1) Type_equal.t
      -> ('a2, 'b2) Type_equal.t
      -> ('a3, 'b3) Type_equal.t
      -> (('a1, 'a2, 'a3) t, ('b1, 'b2, 'b3) t) Type_equal.t
  end

  (** [Injective] is an interface that states that a type is injective, where the type is
      viewed as a function from types to other types. It predates OCaml's support for
      explicit injectivity annotations in the type system.

      The typical prior usage was:

      {[
        type 'a t
        include Injective with type 'a t := 'a t
      ]}

      For example, ['a list] is an injective type, because whenever ['a list = 'b list],
      we know that ['a] = ['b]. On the other hand, if we define:

      {[
        type 'a t = unit
      ]}

      then clearly [t] isn't injective, because, e.g., [int t = bool t], but
      [int <> bool].

      If [module M : Injective], then [M.strip] provides a way to get a proof that two
      types are equal from a proof that both types transformed by [M.t] are equal. A
      typical implementation looked like this:

      {[
        let strip (type a) (type b)
              (Type_equal.T : (a t, b t) Type_equal.t) : (a, b) Type_equal.t =
          Type_equal.T
      ]}

      This will not type check for all type constructors (certainly not for non-injective
      ones!), but it's always safe to try the above implementation if you are unsure. If
      OCaml accepts this definition, then the type is injective. On the other hand, if
      OCaml doesn't, then the type may or may not be injective. For example, if the
      definition of the type depends on abstract types that match [Injective], OCaml will
      not automatically use their injectivity, and one will have to write a more
      complicated definition of [strip] that causes OCaml to use that fact. For example:

      {[
        module F (M : Type_equal.Injective) : Type_equal.Injective = struct
          type 'a t = 'a M.t * int

          let strip (type a) (type b)
                (e : (a t, b t) Type_equal.t) : (a, b) Type_equal.t =
            let e1, _ = Type_equal.detuple2 e in
            M.strip e1
          ;;
        end
      ]}

      If in the definition of [F] we had written the simpler implementation of [strip] that
      didn't use [M.strip], then OCaml would have reported a type error.
  *)
  module type Injective = sig
    type 'a t

    val strip : ('a t, 'b t) Type_equal.t -> ('a, 'b) Type_equal.t
  end
  [@@deprecated
    "[since 2023-08] OCaml now supports injectivity annotations. [type !'a t] declares \
     that ['a t] is injective with respect to ['a]."]

  (** [Injective2] is for a binary type that is injective in both type arguments. *)
  module type Injective2 = sig
    type ('a1, 'a2) t

    val strip
      :  (('a1, 'a2) t, ('b1, 'b2) t) Type_equal.t
      -> ('a1, 'b1) Type_equal.t * ('a2, 'b2) Type_equal.t
  end
  [@@deprecated
    "[since 2023-08] OCaml now supports injectivity annotations. [type !'a t] declares \
     that ['a t] is injective with respect to ['a]."]

  (** [Composition_preserves_injectivity] is a functor that proves that composition of
      injective types is injective. *)
  module Composition_preserves_injectivity (M1 : Injective) (M2 : Injective) :
    Injective with type 'a t = 'a M1.t M2.t = struct
    type 'a t = 'a M1.t M2.t

    let strip e = M1.strip (M2.strip e)
  end
  [@@alert "-deprecated"]
  [@@deprecated
    "[since 2023-08] OCaml now supports injectivity annotations. [type !'a t] declares \
     that ['a t] is injective with respect to ['a]."]
end

module Type_equal_id_defns (Id : sig
  type 'a t
end) =
struct
  module type Arg0 = sig
    type t [@@deriving_inline sexp_of]

    val sexp_of_t : t -> Sexplib0.Sexp.t

    [@@@end]

    val name : string
  end

  module type Arg1 = sig
    type !'a t [@@deriving_inline sexp_of]

    val sexp_of_t : ('a -> Sexplib0.Sexp.t) -> 'a t -> Sexplib0.Sexp.t

    [@@@end]

    val name : string
  end

  module type Arg2 = sig
    type (!'a, !'b) t [@@deriving_inline sexp_of]

    val sexp_of_t
      :  ('a -> Sexplib0.Sexp.t)
      -> ('b -> Sexplib0.Sexp.t)
      -> ('a, 'b) t
      -> Sexplib0.Sexp.t

    [@@@end]

    val name : string
  end

  module type Arg3 = sig
    type (!'a, !'b, !'c) t [@@deriving_inline sexp_of]

    val sexp_of_t
      :  ('a -> Sexplib0.Sexp.t)
      -> ('b -> Sexplib0.Sexp.t)
      -> ('c -> Sexplib0.Sexp.t)
      -> ('a, 'b, 'c) t
      -> Sexplib0.Sexp.t

    [@@@end]

    val name : string
  end

  module type S0 = sig
    type t

    val type_equal_id : t Id.t
  end

  module type S1 = sig
    type 'a t

    val type_equal_id : 'a Id.t -> 'a t Id.t
  end

  module type S2 = sig
    type ('a, 'b) t

    val type_equal_id : 'a Id.t -> 'b Id.t -> ('a, 'b) t Id.t
  end

  module type S3 = sig
    type ('a, 'b, 'c) t

    val type_equal_id : 'a Id.t -> 'b Id.t -> 'c Id.t -> ('a, 'b, 'c) t Id.t
  end
end

(**/**)

module type Type_equal = sig
  type ('a, 'b) t = T : ('a, 'a) t [@@deriving_inline sexp_of]

  val sexp_of_t
    :  ('a -> Sexplib0.Sexp.t)
    -> ('b -> Sexplib0.Sexp.t)
    -> ('a, 'b) t
    -> Sexplib0.Sexp.t

  [@@@end]

  (** just an alias, needed when [t] gets shadowed below *)
  type ('a, 'b) equal = ('a, 'b) t

  (** @inline *)
  include module type of Type_equal_defns (struct
    type ('a, 'b) t = ('a, 'b) equal
  end)

  (** [refl], [sym], and [trans] construct proofs that type equality is reflexive,
      symmetric, and transitive. *)

  val refl : ('a, 'a) t
  val sym : ('a, 'b) t -> ('b, 'a) t
  val trans : ('a, 'b) t -> ('b, 'c) t -> ('a, 'c) t

  (** [conv t x] uses the type equality [t : (a, b) t] as evidence to safely cast [x]
      from type [a] to type [b].  [conv] is semantically just the identity function.

      In a program that has [t : (a, b) t] where one has a value of type [a] that one
      wants to treat as a value of type [b], it is often sufficient to pattern match on
      [Type_equal.T] rather than use [conv]. However, there are situations where OCaml's
      type checker will not use the type equality [a = b], and one must use [conv]. For
      example:

      {[
        module F (M1 : sig type t end) (M2 : sig type t end) : sig
          val f : (M1.t, M2.t) equal -> M1.t -> M2.t
        end = struct
          let f equal (m1 : M1.t) = conv equal m1
        end
      ]}

      If one wrote the body of [F] using pattern matching on [T]:

      {[
        let f (T : (M1.t, M2.t) equal) (m1 : M1.t) = (m1 : M2.t)
      ]}

      this would give a type error. *)
  val conv : ('a, 'b) t -> 'a -> 'b

  (** It is always safe to conclude that if type [a] equals [b], then for any type ['a t],
      type [a t] equals [b t]. The OCaml type checker uses this fact when it can. However,
      sometimes, e.g., when using [conv], one needs to explicitly use this fact to
      construct an appropriate [Type_equal.t]. The [Lift*] functors do this. *)

  module Lift (T : T1) : Lift with type 'a t := 'a T.t
  module Lift2 (T : T2) : Lift2 with type ('a, 'b) t := ('a, 'b) T.t
  module Lift3 (T : T3) : Lift3 with type ('a, 'b, 'c) t := ('a, 'b, 'c) T.t

  (** [tuple2] and [detuple2] convert between equality on a 2-tuple and its components. *)

  val detuple2 : ('a1 * 'a2, 'b1 * 'b2) t -> ('a1, 'b1) t * ('a2, 'b2) t
  val tuple2 : ('a1, 'b1) t -> ('a2, 'b2) t -> ('a1 * 'a2, 'b1 * 'b2) t

  (** [Id] provides identifiers for types, and the ability to test (via [Id.same]) at
      runtime if two identifiers are equal, and if so to get a proof of equality of their
      types.  Unlike values of type [Type_equal.t], values of type [Id.t] do have semantic
      content and must have a nontrivial runtime representation. *)
  module Id : sig
    type 'a t [@@deriving_inline sexp_of]

    val sexp_of_t : ('a -> Sexplib0.Sexp.t) -> 'a t -> Sexplib0.Sexp.t

    [@@@end]

    (** @inline *)
    include module type of Type_equal_id_defns (struct
      type nonrec 'a t = 'a t
    end)

    (** Every [Id.t] contains a unique id that is distinct from the [Uid.t] in any other
        [Id.t]. *)
    module Uid : sig
      type t [@@deriving_inline hash, sexp_of]

      include Ppx_hash_lib.Hashable.S with type t := t

      val sexp_of_t : t -> Sexplib0.Sexp.t

      [@@@end]

      include Comparable.S with type t := t
    end

    val uid : _ t -> Uid.t

    (** [create ~name] defines a new type identity. Two calls to [create] will result in
        two distinct identifiers, even for the same arguments with the same type. If the
        type ['a] doesn't support sexp conversion, then a good practice is to have the
        converter be [[%sexp_of: _]], (or [sexp_of_opaque], if not using ppx_sexp_conv).
    *)
    val create : name:string -> ('a -> Sexp.t) -> 'a t

    (** Accessors *)

    val hash : _ t -> int
    val name : _ t -> string
    val to_sexp : 'a t -> 'a -> Sexp.t
    val hash_fold_t : Hash.state -> _ t -> Hash.state

    (** [same_witness t1 t2] and [same_witness_exn t1 t2] return a type equality proof iff
        the two identifiers are the same (i.e., physically equal, resulting from the same
        call to [create]).  This is a useful way to achieve a sort of dynamic typing.
        [same_witness] does not allocate a [Some] every time it is called.

        [same t1 t2 = is_some (same_witness t1 t2)].
    *)

    val same : _ t -> _ t -> bool
    val same_witness : 'a t -> 'b t -> ('a, 'b) equal option
    val same_witness_exn : 'a t -> 'b t -> ('a, 'b) equal

    module Register0 (T : Arg0) : S0 with type t := T.t
    module Register1 (T : Arg1) : S1 with type 'a t := 'a T.t
    module Register2 (T : Arg2) : S2 with type ('a, 'b) t := ('a, 'b) T.t
    module Register3 (T : Arg3) : S3 with type ('a, 'b, 'c) t := ('a, 'b, 'c) T.t
  end
end
