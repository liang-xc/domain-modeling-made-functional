open! Core
open Async
open Common

type service_info =
  { name : string
  ; endpoint : Uri.t
  }

type remote_service_error =
  { service : service_info
  ; except : Error.t
  }

type address_validation_error =
  | InvalidFormat
  | AddressNotFound

type place_order_error =
  [ `ValidationError
  | `PricingError of string
  | `RemoteServiceError of remote_service_error
  ]

let validation_error e = `ValidationError e
let pricing_error e = `PricingError e

module Unvalidated_customer_info = struct
  type t =
    { first_name : string
    ; last_name : string
    ; email_address : string
    }

  let to_customer_info unvalidated_customer_info =
    let open Result.Let_syntax in
    let%bind first_name =
      unvalidated_customer_info.first_name
      |> String50.create "FirstName"
      |> Result.map_error ~f:validation_error
    in
    let%bind last_name =
      unvalidated_customer_info.last_name
      |> String50.create "LastName"
      |> Result.map_error ~f:validation_error
    in
    let%map email_address =
      unvalidated_customer_info.email_address
      |> Email_address.create "EmailAddress"
      |> Result.map_error ~f:validation_error
    in
    { name = { first_name; last_name }; email_address }
  ;;
end

module Unvalidated_address = struct
  type t =
    { address_line1 : string
    ; address_line2 : string
    ; address_line3 : string
    ; address_line4 : string
    ; city : string
    ; zipcode : string
    }
end

module Checked_address = struct
  type t = CheckedAddress of Unvalidated_address.t

  let from_unvalidated_address check_address address =
    address
    |> check_address
    |> Deferred.Result.map_error ~f:(function
      | AddressNotFound -> validation_error "Address Not Found"
      | InvalidFormat -> validation_error "Invalid Format")
  ;;

  let to_address (CheckedAddress checked_address) =
    let open Result.Let_syntax in
    let%bind address_line1 =
      checked_address.address_line1
      |> String50.create "AddressLine1"
      |> Result.map_error ~f:validation_error
    in
    let%bind address_line2 =
      checked_address.address_line2
      |> String50.create_opt "AddressLine2"
      |> Result.map_error ~f:validation_error
    in
    let%bind address_line3 =
      checked_address.address_line3
      |> String50.create_opt "AddressLine3"
      |> Result.map_error ~f:validation_error
    in
    let%bind address_line4 =
      checked_address.address_line4
      |> String50.create_opt "AddressLine4"
      |> Result.map_error ~f:validation_error
    in
    let%bind city =
      checked_address.city
      |> String50.create "City"
      |> Result.map_error ~f:validation_error
    in
    let%map zipcode =
      checked_address.zipcode
      |> Zipcode.create "Zipcode"
      |> Result.map_error ~f:validation_error
    in
    let address : address =
      { address_line1; address_line2; address_line3; address_line4; city; zipcode }
    in
    address
  ;;
end

module Unvalidated_order = struct
  type unvalidated_orderline =
    { orderline_id : string
    ; product_code : string
    ; quantity : float
    }

  type t =
    { order_id : string
    ; customer_info : Unvalidated_customer_info.t
    ; shipping_address : Unvalidated_address.t
    ; billing_address : Unvalidated_address.t
    ; lines : unvalidated_orderline list
    }
end

module Validated_order = struct
  type validated_orderline =
    { orderline_id : Order_line_id.t
    ; product_code : Product_code.t
    ; quantity : Order_quantity.t
    }

  type t =
    { order_id : Order_id.t
    ; customer_info : customer_info
    ; shipping_address : address
    ; billing_address : address
    ; lines : validated_orderline list
    }

  let to_orderid id =
    id |> Order_id.create "OrderId" |> Result.map_error ~f:validation_error
  ;;

  let to_order_line_id id =
    id |> Order_line_id.create "OrderLineId" |> Result.map_error ~f:validation_error
  ;;

  let to_product_code check_product_code_exists code =
    let check_product product_code =
      if check_product_code_exists product_code
      then Ok product_code
      else (
        let msg = sprintf "Invalid: %s" (Product_code.value product_code) in
        Error (validation_error msg))
    in
    code
    |> Product_code.create "ProductCode"
    |> Result.map_error ~f:validation_error
    |> Result.bind ~f:check_product
  ;;

  let to_order_quantity product_code quantity =
    Order_quantity.create "OrderQuantity" product_code quantity
    |> Result.map_error ~f:validation_error
  ;;

  let to_validated_order_line
    check_product_code_exists
    (unvalidated_orderline : Unvalidated_order.unvalidated_orderline)
    =
    let open Result.Let_syntax in
    let%bind orderline_id = unvalidated_orderline.orderline_id |> to_order_line_id in
    let%bind product_code =
      unvalidated_orderline.product_code |> to_product_code check_product_code_exists
    in
    let%map quantity = unvalidated_orderline.quantity |> to_order_quantity product_code in
    { orderline_id; product_code; quantity }
  ;;

  let validate_order
    check_product_code_exists
    check_address_exists
    (unvalidated_order : Unvalidated_order.t)
    =
    let open Deferred.Result.Let_syntax in
    let%bind order_id = unvalidated_order.order_id |> to_orderid |> Deferred.return in
    let%bind customer_info =
      unvalidated_order.customer_info
      |> Unvalidated_customer_info.to_customer_info
      |> Deferred.return
    in
    let%bind checked_shipping_address =
      unvalidated_order.shipping_address
      |> Checked_address.from_unvalidated_address check_address_exists
    in
    let%bind shipping_address =
      checked_shipping_address |> Checked_address.to_address |> Deferred.return
    in
    let%bind checked_billing_address =
      unvalidated_order.billing_address
      |> Checked_address.from_unvalidated_address check_address_exists
    in
    let%bind billing_address =
      checked_billing_address |> Checked_address.to_address |> Deferred.return
    in
    let%map lines =
      unvalidated_order.lines
      |> List.map ~f:(to_validated_order_line check_product_code_exists)
      |> Result.all
      |> Deferred.return
    in
    { order_id; customer_info; shipping_address; billing_address; lines }
  ;;
end

(** Outputs from the work flow (success cases) *)

module Priced_order = struct
  type priced_order_line =
    { orderline_id : Order_line_id.t
    ; product_code : Product_code.t
    ; quantity : Order_quantity.t
    ; line_price : Price.t
    }

  type t =
    { order_id : Order_id.t
    ; customer_info : customer_info
    ; shipping_address : address
    ; billing_address : address
    ; amount_to_bill : Billing_amount.t
    ; lines : priced_order_line list
    }

  let to_priced_order_line
    get_product_price
    (validated_order_line : Validated_order.validated_orderline)
    =
    let qty = validated_order_line.quantity |> Order_quantity.value in
    let price = validated_order_line.product_code |> get_product_price in
    let open Result.Let_syntax in
    let%map line_price = Price.multiply qty price |> Result.map_error ~f:pricing_error in
    { orderline_id = validated_order_line.orderline_id
    ; product_code = validated_order_line.product_code
    ; quantity = validated_order_line.quantity
    ; line_price
    }
  ;;

  let price_order get_product_price (validated_order : Validated_order.t) =
    let open Result.Let_syntax in
    let%bind lines =
      validated_order.lines
      |> List.map ~f:(to_priced_order_line get_product_price)
      |> Result.all
    in
    let%map amount_to_bill =
      lines
      |> List.map ~f:(fun line -> line.line_price)
      |> Billing_amount.sum_prices
      |> Result.map_error ~f:pricing_error
    in
    { order_id = validated_order.order_id
    ; customer_info = validated_order.customer_info
    ; shipping_address = validated_order.shipping_address
    ; billing_address = validated_order.billing_address
    ; lines
    ; amount_to_bill
    }
  ;;
end

type html_string = HtmlString of string

type order_acnknowledgement =
  { email_address : Email_address.t
  ; letter : html_string
  }

type order_acknowledgement_sent =
  { order_id : Order_id.t
  ; email_address : Email_address.t
  }

type sent_result =
  | Sent
  | NotSent

let acknowledge_order
  create_acknowledgement_letter
  send_acknowledgement
  (priced_order : Priced_order.t)
  =
  let letter = create_acknowledgement_letter priced_order in
  let acknowledgement =
    { email_address = priced_order.customer_info.email_address; letter }
  in
  match send_acknowledgement acknowledgement with
  | Sent ->
    let event =
      { order_id = priced_order.order_id
      ; email_address = priced_order.customer_info.email_address
      }
    in
    Some event
  | NotSent -> None
;;

let create_order_placed_event priced_order = priced_order

type billable_order_placed =
  { order_id : Order_id.t
  ; billing_address : address
  ; amount_to_bill : Billing_amount.t
  }

let create_billing_event (priced_order : Priced_order.t) =
  let billing_amount = priced_order.amount_to_bill |> Billing_amount.value in
  if Float.compare billing_amount 0.0 > 0
  then
    Some
      { order_id = priced_order.order_id
      ; billing_address = priced_order.billing_address
      ; amount_to_bill = priced_order.amount_to_bill
      }
  else None
;;

let list_of_option = function
  | Some x -> [ x ]
  | None -> []
;;

type place_order_event =
  [ `OrderPlaced of Priced_order.t
  | `BillableOrderPlaced of billable_order_placed
  | `AcknowledgementSent of order_acknowledgement_sent
  ]

let order_placed order = `OrderPlaced order
let billable_placed order = `BillableOrderPlaced order
let acknowledgement_sent order = `AcknowledgementSent order

let create_events priced_order acknowledgement_event_opt =
  let acknowledgement_events =
    acknowledgement_event_opt |> Option.map ~f:acknowledgement_sent |> list_of_option
  in
  let order_placed_events =
    priced_order |> create_order_placed_event |> order_placed |> List.singleton
  in
  let billing_events =
    priced_order
    |> create_billing_event
    |> Option.map ~f:billable_placed
    |> list_of_option
  in
  List.concat [ acknowledgement_events; order_placed_events; billing_events ]
;;

let place_order
  ~check_product_exists
  ~check_address_exists
  ~get_product_price
  ~create_order_acknowledgement_letter
  ~send_order_acknowledgement
  unvalidated_order
  =
  let open Deferred.Result.Let_syntax in
  let%bind validated_order =
    Validated_order.validate_order
      check_product_exists
      check_address_exists
      unvalidated_order
    |> Deferred.Result.map_error ~f:validation_error
  in
  let%bind priced_order =
    Priced_order.price_order get_product_price validated_order
    |> Deferred.return
    |> Deferred.Result.map_error ~f:pricing_error
  in
  let acknowledgement_opt =
    acknowledge_order
      create_order_acknowledgement_letter
      send_order_acknowledgement
      priced_order
  in
  let events = create_events priced_order acknowledgement_opt in
  return events
;;
