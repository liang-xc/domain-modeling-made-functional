open! Core
open Async
open Common

(** Inputs to the workflow *)

type unvalidated_customer_info =
  { first_name : string
  ; last_name : string
  ; email_address : string
  }

type unvalidated_address =
  { address_line1 : string
  ; address_line2 : string
  ; address_line3 : string
  ; address_line4 : string
  ; city : string
  ; zipcode : string
  }

type unvalidated_orderline =
  { orderline_id : string
  ; product_code : string
  ; quantity : string
  }

type unvalidated_order =
  { order_id : string
  ; customer_info : unvalidated_customer_info
  ; shipping_address : unvalidated_address
  ; billing_address : unvalidated_address
  ; lines : unvalidated_orderline list
  }

(** Outputs from the work flow (success cases) *)

type order_acknowledgement_sent =
  { order_id : OrderId.t
  ; email_address : EmailAddress.t
  }

type priced_order_line =
  { order_line_id : OrderLineId.t
  ; product_code : ProductCode.t
  ; quantity : OrderQuantity.t
  ; line_price : Price.t
  }

type priced_order =
  { order_id : OrderId.t
  ; customer_info : customer_info
  ; shipping_address : address
  ; billing_address : address
  ; amount_to_bill : BillingAmount.t
  ; lines : priced_order_line list
  }

type order_placed = priced_order

type billable_order_placed =
  { order_id : OrderId.t
  ; billing_address : address
  ; amount_to_bill : BillingAmount.t
  }

type place_order_event =
  | OrderPlaced of order_placed
  | BillableOrderPlaced of billable_order_placed
  | AcknowledgmentSent of order_acknowledgement_sent

(** Error outputs *)

type validation_error = ValidationError of string
type pricing_error = PricingError of string

type service_info =
  { name : string
  ; endpoint : Uri.t
  }

type remote_service_error =
  { service : service_info
  ; except : Error.t
  }

type place_order_error =
  | Validation of validation_error
  | Pricing of pricing_error
  | RemoteService of remote_service_error

(** the workflow itself *)
type place_order =
  unvalidated_order -> (place_order_event list, place_order_error) Deferred.Result.t
