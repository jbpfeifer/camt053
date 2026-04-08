defmodule Camt053.Statement do
  defstruct [:iban, :currency, :entries]

  @type t :: %__MODULE__{
          iban: String.t() | nil,
          currency: String.t() | nil,
          entries: [Camt053.Entry.t()]
        }
end
