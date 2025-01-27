open! Core

(** Useful functions for constrained types *)
module ConstrainedType = struct
  (** create a constrained string
      return Error if input is empty or length > [max_len] *)
  let create_string field_name max_len str =
    if String.is_empty str
    then (
      let msg = field_name ^ " must not be empty" in
      Error msg)
    else if String.length str > max_len
    then (
      let msg =
        field_name ^ " must not be more than " ^ Int.to_string max_len ^ " chars"
      in
      Error msg)
    else Ok str
  ;;

  (** create a optional constrained string
      return None if input is empty
      return Error if length > [max_len]
      return Some if the input is valid *)
  let create_string_opt field_name max_len str =
    if String.is_empty str
    then Ok None
    else if String.length str > max_len
    then (
      let msg =
        field_name ^ " must not be more than " ^ Int.to_string max_len ^ " chars"
      in
      Error msg)
    else Ok (Some str)
  ;;

  (** create a constrained int
      return Error if input less than [min_val] or more than [max_val] *)
  let create_int field_name min_val max_val i =
    if i < min_val
    then (
      let msg = field_name ^ ": Must not be less than " ^ Int.to_string min_val in
      Error msg)
    else if i > max_val
    then (
      let msg = field_name ^ ": Must not be greater than " ^ Int.to_string max_val in
      Error msg)
    else Ok i
  ;;

  (** create a constrained float
      return Error if input less than [min_val] or more than [max_val] *)
  let create_decimal field_name min_val max_val i =
    let open Float in
    if i < min_val
    then (
      let msg = field_name ^ ": Must not be less than " ^ to_string min_val in
      Error msg)
    else if i > max_val
    then (
      let msg = field_name ^ ": Must not be greater than " ^ to_string max_val in
      Error msg)
    else Ok i
  ;;

  (** create a constrained string
      return Error if input is empty or does not match the regex pattern *)
  let create_like field_name pattern str =
    if String.is_empty str
    then (
      let msg = field_name ^ " must not be empty" in
      Error msg)
    else if Re.execp (Re.Perl.compile_pat pattern) str
    then Ok str
    else (
      let msg = field_name ^ ": " ^ str ^ " must match patter: '" ^ pattern ^ "'" in
      Error msg)
  ;;
end

module String50 = struct
  type t = string

  let value str = str
  let create field_name str = ConstrainedType.create_string field_name 50 str
  let create_opt field_name str = ConstrainedType.create_string_opt field_name 50 str
end

module EmailAddress = struct
  type t = string

  let value str = str

  let create field_name str =
    let pattern = {|.+@.+|} in
    ConstrainedType.create_like field_name pattern str
  ;;
end

module ZipCode = struct
  type t = string

  let value str = str

  let create field_name str =
    let pattern = {|\d{5}|} in
    ConstrainedType.create_like field_name pattern str
  ;;
end

module OrderLineId = struct
  type t = string
end

module OrderId = struct
  type t = string

  let value str = str
  let create field_name str = ConstrainedType.create_string field_name 50 str
end

module WidgetCode = struct
  type t = string

  let value code = code

  let create field_name code =
    let pattern = {|W\d{4}|} in
    ConstrainedType.create_like field_name pattern code
  ;;
end

module GizmoCode = struct
  type t = string

  let value code = code

  let create field_name code =
    let pattern = {|G\d{3}|} in
    ConstrainedType.create_like field_name pattern code
  ;;
end

module ProductCode = struct
  type t =
    | Widget of WidgetCode.t
    | Gizmo of GizmoCode.t

  let value product_code =
    match product_code with
    | Widget wc -> wc
    | Gizmo gc -> gc
  ;;

  let create field_name code =
    let open Result.Let_syntax in
    if String.is_empty code
    then (
      let msg = field_name ^ ": must not be empty" in
      Error msg)
    else if String.is_prefix code ~prefix:"W"
    then (
      let%map wc = WidgetCode.create field_name code in
      Widget wc)
    else if String.is_prefix code ~prefix:"G"
    then (
      let%map gc = GizmoCode.create field_name code in
      Gizmo gc)
    else (
      let msg = field_name ^ ": Format does not recognized '" ^ code ^ "'" in
      Error msg)
  ;;
end

module UnitQuantity = struct
  type t = int

  let value v = v
  let create field_name v = ConstrainedType.create_int field_name 1 1000 v
end

module KilogramQuantity = struct
  type t = float

  let value v = v
  let create field_name v = ConstrainedType.create_decimal field_name 0.05 100. v
end

module OrderQuantity = struct
  type t =
    | Unit of UnitQuantity.t
    | Kilogram of KilogramQuantity.t

  let value qty =
    match qty with
    | Unit uq -> uq |> UnitQuantity.value |> Float.of_int
    | Kilogram kq -> kq |> KilogramQuantity.value
  ;;

  let create field_name product_code quantity =
    let open Result.Let_syntax in
    match product_code with
    | ProductCode.Widget _ ->
      let%map u = UnitQuantity.create field_name (Int.of_float quantity) in
      Unit u
    | ProductCode.Gizmo _ ->
      let%map k = KilogramQuantity.create field_name quantity in
      Kilogram k
  ;;
end

module Price = struct
  type t = float

  let value v = v
  let create v = ConstrainedType.create_decimal "Price" 0. 100. v

  let unsafe_create v =
    match create v with
    | Ok price -> price
    | Error err -> failwith ("Not expecting Price to be out of bound: " ^ err)
  ;;

  let multiply qty p = create (qty *. p)
end

module BillingAmount = struct
  type t = float

  let value v = v
  let create v = ConstrainedType.create_decimal "BillingAmount" 0. 10000. v

  let sum_prices prices =
    prices |> List.map ~f:Price.value |> List.fold ~init:0. ~f:Float.( + ) |> create
  ;;
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
