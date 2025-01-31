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

module Email_address : sig
  type t

  (** return the string value inside t *)
  val value : t -> string

  (** create t from string
      return Error if input is empty or doesn't have an "@" in it *)
  val create : string -> string -> (t, string) result
end

module Zipcode : sig
  type t

  (** return the string value inside t *)
  val value : t -> string

  (** create t from string
      return Error if input is empty or doesn't have 5 digits *)
  val create : string -> string -> (t, string) result
end

module Order_line_id : sig
  type t

  (** return the string value inside t *)
  val value : t -> string

  (** create t from string
      return Error if input is empty or length > 50 *)
  val create : string -> string -> (t, string) result
end

module Order_id : sig
  (** Constrained to be a non-empty string < 10 chars *)
  type t

  (** return the string value inside t *)
  val value : t -> string

  (** create t from string
      return Error if input is empty or length > 50 *)
  val create : string -> string -> (t, string) result
end

module Widget_code : sig
  (** the code for widgets, starts with a "W" and then four digits *)
  type t

  (** return the string value inside t *)
  val value : t -> string

  (** create t from string
      return Error if input is empty or does not match pattern *)
  val create : string -> string -> (t, string) result
end

module Gizmo_code : sig
  (** the code for gizmos, starts with a "G" and then three digits *)
  type t

  (** return the string value inside t *)
  val value : t -> string

  (** create t from string
      return Error if input is empty or does not match pattern *)
  val create : string -> string -> (t, string) result
end

module Product_code : sig
  (** a product code is either a widget or a gizmo *)
  type t =
    | Widget of Widget_code.t
    | Gizmo of Gizmo_code.t

  (** return the string value inside t *)
  val value : t -> string

  (** create t from string
      return Error if input is empty or does not match pattern *)
  val create : string -> string -> (t, string) result
end

module Unit_quantity : sig
  (** constrained to be an integer between 1 and 1000 *)
  type t

  (** return the value inside t *)
  val value : t -> int

  (** create t from a int
      return Error if input is not an integer between 1 and 1000 *)
  val create : string -> int -> (t, string) result
end

module Kilogram_quantity : sig
  (** constrained to be a float between 0.05 and 100.00 *)
  type t

  (** return the value inside t *)
  val value : t -> float

  (** create t from a float
      return Error if input is not an float between 0.05 and 100.00 *)
  val create : string -> float -> (t, string) result
end

module Order_quantity : sig
  type t

  (** return the value inside t *)
  val value : t -> float

  (** create t from a product code and a quantity *)
  val create : string -> Product_code.t -> float -> (t, string) result
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

module Billing_amount : sig
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
  ; email_address : Email_address.t
  }

type address =
  { address_line1 : String50.t
  ; address_line2 : String50.t option
  ; address_line3 : String50.t option
  ; address_line4 : String50.t option
  ; city : String50.t
  ; zipcode : Zipcode.t
  }
