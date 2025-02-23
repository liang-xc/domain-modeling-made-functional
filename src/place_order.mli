open! Core
open! Async

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
  [ `PricingError of string
  | `RemoteServiceError of remote_service_error
  | `ValidationError
  ]

val validation_error : 'a -> [> `ValidationError of 'a ]
val pricing_error : string -> [> `PricingError of string ]

module Unvalidated_customer_info : sig
  type t =
    { first_name : string
    ; last_name : string
    ; email_address : string
    }

  val to_customer_info
    :  t
    -> (Common.customer_info, [> `ValidationError of string ]) result
end

module Unvalidated_address : sig
  type t =
    { address_line1 : string
    ; address_line2 : string
    ; address_line3 : string
    ; address_line4 : string
    ; city : string
    ; zipcode : string
    }
end

module Checked_address : sig
  type t = CheckedAddress of Unvalidated_address.t

  val from_unvalidated_address
    :  ('a -> ('b, address_validation_error) Deferred.Result.t)
    -> 'a
    -> ('b, [> `ValidationError of string ]) Deferred.Result.t

  val to_address : t -> (Common.address, [> `ValidationError of string ]) result
end

module Unvalidated_order : sig
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

module Validated_order : sig
  type validated_orderline =
    { orderline_id : Common.Order_line_id.t
    ; product_code : Common.Product_code.t
    ; quantity : Common.Order_quantity.t
    }

  type t =
    { order_id : Common.Order_id.t
    ; customer_info : Common.customer_info
    ; shipping_address : Common.address
    ; billing_address : Common.address
    ; lines : validated_orderline list
    }

  val to_orderid : string -> (Common.Order_id.t, [> `ValidationError of string ]) result

  val to_order_line_id
    :  string
    -> (Common.Order_line_id.t, [> `ValidationError of string ]) result

  val to_product_code
    :  (Common.Product_code.t -> bool)
    -> string
    -> (Common.Product_code.t, [> `ValidationError of string ]) result

  val to_order_quantity
    :  Common.Product_code.t
    -> float
    -> (Common.Order_quantity.t, [> `ValidationError of string ]) result

  val to_validated_order_line
    :  (Common.Product_code.t -> bool)
    -> Unvalidated_order.unvalidated_orderline
    -> (validated_orderline, [> `ValidationError of string ]) result

  val validate_order
    :  (Common.Product_code.t -> bool)
    -> (Unvalidated_address.t
        -> (Checked_address.t, address_validation_error) Deferred.Result.t)
    -> Unvalidated_order.t
    -> (t, [> `ValidationError of string ]) Deferred.Result.t
end

module Priced_order : sig
  type priced_order_line =
    { orderline_id : Common.Order_line_id.t
    ; product_code : Common.Product_code.t
    ; quantity : Common.Order_quantity.t
    ; line_price : Common.Price.t
    }

  type t =
    { order_id : Common.Order_id.t
    ; customer_info : Common.customer_info
    ; shipping_address : Common.address
    ; billing_address : Common.address
    ; amount_to_bill : Common.Billing_amount.t
    ; lines : priced_order_line list
    }

  val to_priced_order_line
    :  (Common.Product_code.t -> Common.Price.t)
    -> Validated_order.validated_orderline
    -> (priced_order_line, [> `PricingError of string ]) result

  val price_order
    :  (Common.Product_code.t -> Common.Price.t)
    -> Validated_order.t
    -> (t, [> `PricingError of string ]) result
end

type html_string = HtmlString of string

type order_acnknowledgement =
  { email_address : Common.Email_address.t
  ; letter : html_string
  }

type order_acknowledgement_sent =
  { order_id : Common.Order_id.t
  ; email_address : Common.Email_address.t
  }

type sent_result =
  | Sent
  | NotSent

val acknowledge_order
  :  (Priced_order.t -> html_string)
  -> (order_acnknowledgement -> sent_result)
  -> Priced_order.t
  -> order_acknowledgement_sent option

val create_order_placed_event : 'a -> 'a

type billable_order_placed =
  { order_id : Common.Order_id.t
  ; billing_address : Common.address
  ; amount_to_bill : Common.Billing_amount.t
  }

val create_billing_event : Priced_order.t -> billable_order_placed option
val list_of_option : 'a option -> 'a list

type place_order_event =
  [ `AcknowledgementSent of order_acknowledgement_sent
  | `BillableOrderPlaced of billable_order_placed
  | `OrderPlaced of Priced_order.t
  ]

val order_placed : 'a -> [> `OrderPlaced of 'a ]
val billable_placed : 'a -> [> `BillableOrderPlaced of 'a ]
val acknowledgement_sent : 'a -> [> `AcknowledgementSent of 'a ]

val create_events
  :  Priced_order.t
  -> 'a option
  -> [> `AcknowledgementSent of 'a
     | `BillableOrderPlaced of billable_order_placed
     | `OrderPlaced of Priced_order.t
     ]
       list

val place_order
  :  check_product_exists:(Common.Product_code.t -> bool)
  -> check_address_exists:
       (Unvalidated_address.t
        -> (Checked_address.t, address_validation_error) Deferred.Result.t)
  -> get_product_price:(Common.Product_code.t -> Common.Price.t)
  -> create_order_acknowledgement_letter:(Priced_order.t -> html_string)
  -> send_order_acknowledgement:(order_acnknowledgement -> sent_result)
  -> Unvalidated_order.t
  -> ( [> `AcknowledgementSent of order_acknowledgement_sent
       | `BillableOrderPlaced of billable_order_placed
       | `OrderPlaced of Priced_order.t
       ]
         list
       , [> `PricingError of [> `PricingError of string ]
         | `ValidationError of [> `ValidationError of string ]
         ] )
       Deferred.Result.t
