defmodule Camt053.Entry do
  defstruct [:amount, :currency, :type, :booking_date, :info, :counterparty_name, :raw_xml]

  @type t :: %__MODULE__{
          amount: Decimal.t(),
          currency: String.t(),
          type: :credit | :debit,
          booking_date: Date.t(),
          info: String.t(),
          counterparty_name: String.t()
        }
end
