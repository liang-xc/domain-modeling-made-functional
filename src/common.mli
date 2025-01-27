open! Core

(** Constrained to be 50 chars or less *)
module String50 : sig
  type t

  (** return the value inside t *)
  val value : t -> string

  (** create t from a string
      return Error if input is empty or length > 50 *)
  val create : string -> string -> (t, string) result

  (** create t from a string
      return None if input is empty
      return Error if length > 50
      return Some if the input is valid *)
  val create_opt : string -> string -> (t option, string) result
end

module EmailAddress : sig
  type t

  (** return the string value inside t *)
  val value : t -> string

  (** create t from string
      return Error if input is empty or doesn't have an "@" in it *)
  val create : string -> string -> (t, string) result
end

module ZipCode : sig
  type t

  (** return the string value inside t *)
  val value : t -> string

  (** create t from string
      return Error if input is empty or doesn't have 5 digits *)
  val create : string -> string -> (t, string) result
end

module OrderLineId : sig
  type t = string
end

module OrderId : sig
  (** Constrained to be a non-empty string < 10 chars *)
  type t

  (** return the string value inside t *)
  val value : t -> string

  (** create t from string
      return Error if input is empty or length > 50 *)
  val create : string -> string -> (t, string) result
end

module WidgetCode : sig
  (** the code for widgets, starts with a "W" and then four digits *)
  type t

  (** return the string value inside t *)
  val value : t -> string

  (** create t from string
      return Error if input is empty or does not match pattern *)
  val create : string -> string -> (t, string) result
end

module GizmoCode : sig
  (** the code for gizmos, starts with a "G" and then three digits *)
  type t

  (** return the string value inside t *)
  val value : t -> string

  (** create t from string
      return Error if input is empty or does not match pattern *)
  val create : string -> string -> (t, string) result
end

module ProductCode : sig
  (** a product code is either a widget or a gizmo *)
  type t =
    | Widget of WidgetCode.t
    | Gizmo of GizmoCode.t

  (** return the string value inside t *)
  val value : t -> string

  (** create t from string
      return Error if input is empty or does not match pattern *)
  val create : string -> string -> (t, string) result
end

module UnitQuantity : sig
  (** constrained to be an integer between 1 and 1000 *)
  type t

  (** return the value inside t *)
  val value : t -> int

  (** create t from a int
      return Error if input is not an integer between 1 and 1000 *)
  val create : string -> int -> (t, string) result
end

module KilogramQuantity : sig
  (** constrained to be a float between 0.05 and 100.00 *)
  type t

  (** return the value inside t *)
  val value : t -> float

  (** create t from a float
      return Error if input is not an float between 0.05 and 100.00 *)
  val create : string -> float -> (t, string) result
end

module OrderQuantity : sig
  type t =
    | Unit of UnitQuantity.t
    | Kilogram of KilogramQuantity.t

  (** return the value inside t *)
  val value : t -> float

  (** create t from a product code and a quantity *)
  val create : string -> ProductCode.t -> float -> (t, string) result
end

module Price : sig
  (** constrained to be a float between 0.0 and 1000.0 *)
  type t

  (** return the value inside t *)
  val value : t -> float

  (** create t from a float
      return Error if input is not a float between 0.0 and 1000 *)
  val create : float -> (t, string) result

  (** create t from a float
      throws an exception if out of bound *)
  val unsafe_create : float -> t

  (** [multiply] a t by a float [qty]
      return Error if new price is out of bounds *)
  val multiply : float -> t -> (t, string) result
end

module BillingAmount : sig
  (** constrained to be a float between 0.0 and 10000.0 *)
  type t

  (** return the value inside t *)
  val value : t -> float

  (** create t from a float
      return Error if input is not a float between 0.0 and 10000.0 *)
  val create : float -> (t, string) result

  (** [sum] a list of [prices] to make a billing amount 
      return Error if total is out of bounds *)
  val sum_prices : Price.t list -> (t, string) result
end

type pdf_attachment =
  { name : string
  ; byte : Bytes.t
  }

type person_name =
  { first_name : String50.t
  ; last_name : String50.t
  }

type customer_info =
  { name : person_name
  ; email_address : EmailAddress.t
  }

type address =
  { address_line1 : String50.t
  ; address_line2 : String50.t option
  ; address_line3 : String50.t option
  ; address_line4 : String50.t option
  ; city : String50.t
  ; zipcode : ZipCode.t
  }
