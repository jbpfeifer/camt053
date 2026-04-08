# camt

A modern, lightweight ISO 20022 (camt.053) banking statement parser for Elixir.

This library is designed to be fast, dependency-friendly, and robust against various bank-specific XML dialects (e.g., Sparkasse, Raiffeisen, Goldman Sachs). It uses `Saxy` for efficient XML parsing and `Decimal` for precision-safe financial calculations.

## Features

- Namespace Agnostic: Handles `camt:Ntry`, `ns2:Ntry`, or plain `Ntry` tags automatically.
- Multi-Statement Support: Correctly parses files containing multiple bank accounts (`<Stmt>` blocks).
- Robust Data Types: Converts amounts to `Decimal` and dates to Elixir `Date` structs.
- Clean Data: Automatically sanitizes unstructured remittance information (Verwendungszweck).

## Installation

Add `camt053` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:camt053, github: "jbpfeifer/camt053"}
  ]
end
```

## Usage

Simply pass a string containing the CAMT.053 XML to `Camt053.parse/1`:

```elixir
xml_content = File.read!("path/to/statement.xml")

case Camt053.parse(xml_content) do
  {:ok, statements} ->
    for stmt <- statements do
      IO.inspect(stmt.iban) # "AT1234..."

      for entry <- stmt.entries do
        IO.inspect(entry.amount) # %Decimal{coef: 12050, exp: -2, sign: 1}
        IO.inspect(entry.info)   # "RE-2024-001"
      end
    end

  {:error, reason} ->
    IO.puts("Failed to parse XML: #{inspect(reason)}")
end
```

## Data Structures

The parser returns a list of `%Camt053.Statement{}` structs:

- `iban`: The bank account's IBAN (normalized, no spaces) or `nil`.
- `currency`: The ISO currency code (e.g., "EUR") or `nil`.
- `entries`: A list of `%Camt053.Entry{}`:

  - `amount`: `Decimal` (negative for debits, positive for credits).
  - `type`: `:credit` or `:debit`.
  - `booking_date`: Elixir `Date` or `nil`.
  - `info`: Sanitized remittance information (Verwendungszweck).
  - `counterparty_name`: Name of the sender/receiver.

## Development

Run tests with:

```bash
mix test
```

