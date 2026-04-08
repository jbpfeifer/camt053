defmodule Camt053GSTest do
  use ExUnit.Case

  test "parst camt_053.xml von Goldman Sachs" do
    xml = File.read!("camt_053.xml")

    {:ok, stmts} = Camt053.parse(xml)

    # Eine Statement-Gruppe im File
    assert length(stmts) >= 1

    stmt = hd(stmts)
    entries = stmt.entries
    # Erwartet 15 <Ntry> Einträge im File
    assert length(entries) == 15

    first = hd(entries)
    assert first.currency == "USD"
    assert Decimal.equal?(first.amount, Decimal.new("10.00"))
    assert first.type == :credit
    assert first.info =~ "Sample Unstructured Remittance"
  end
end
