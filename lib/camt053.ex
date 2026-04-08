defmodule Camt053 do
  @moduledoc """
  Modern Camt053 (ISO 20022) parser for Elixir.
  """
  alias Camt053.Entry

  def parse(xml_string) do
    case Saxy.SimpleForm.parse_string(xml_string) do
      {:ok, doc} -> {:ok, process_document(doc)}
      {:error, _} = error -> error
    end
  end

  defp process_document(doc) do
    # Wir suchen alle <Stmt> Blöcke (Statements); falls keine vorhanden sind,
    # behandeln wir das gesamte Dokument als ein einzelnes Statement.
    statements = find_tags(doc, "Stmt")

    statements =
      if statements == [] and find_tags(doc, "Ntry") != [] do
        [doc]
      else
        statements
      end

    Enum.map(statements, fn stmt ->
      %Camt053.Statement{
        iban: extract_iban(stmt),
        currency: get_statement_currency(stmt),
        entries: find_tags(stmt, "Ntry") |> Enum.map(&build_entry/1)
      }
    end)
  end

  # Extrahiert die IBAN aus einem Statement-Block. Sucht zuerst im <Acct>-Teil,
  # fällt sonst auf direkte <IBAN> oder <Id> Tags im Statement zurück.
  defp extract_iban(stmt_tree) do
    case find_tags(stmt_tree, "Acct") do
      [acct_node | _] ->
        get_text(acct_node, "IBAN") || get_text(acct_node, "Id")

      _ ->
        get_text(stmt_tree, "IBAN")
    end
  end

  defp build_entry(ntry) do
    type_str = get_text(ntry, "CdtDbtInd")
    type = if type_str == "DBIT", do: :debit, else: :credit

    %Entry{
      amount: format_amount(get_text(ntry, "Amt"), type),
      currency: get_attr(ntry, "Amt", "Ccy"),
      type: type,
      booking_date: get_text(ntry, "BookgDt") |> parse_date(),
      info: get_text(ntry, "Ustrd") |> clean_info(),
      counterparty_name: get_text(ntry, "Nm")
    }
  end

  # --- Hilfsfunktionen für die XML-Navigation ---

  # Extrahiert den Textinhalt eines Tags innerhalb eines Unterbaums
  defp get_text(tree, tag_name) do
    case find_tags(tree, tag_name) do
      [{_name, _attrs, content} | _] ->
        find_first_text(content)

      _ ->
        nil
    end
  end

  defp find_first_text(content) when is_binary(content) do
    case String.trim(content) do
      "" -> nil
      text -> text
    end
  end

  defp find_first_text({_, _, content}), do: find_first_text(content)

  defp find_first_text(content) when is_list(content) do
    Enum.find_value(content, &find_first_text/1)
  end

  defp find_first_text(_), do: nil

  # Extrahiert ein Attribut eines Tags (z.B. Ccy="EUR")
  defp get_attr(tree, tag_name, attr_name) do
    case find_tags(tree, tag_name) do
      [{_name, attrs, _content} | _] ->
        Enum.find_value(attrs, fn {k, v} -> if k == attr_name, do: v end)

      _ ->
        nil
    end
  end

  # Findet alle Tags mit einem bestimmten Namen rekursiv.
  # Unterstützt Elementnamen mit Namespaces wie "Camt053:Ntry" und Atom-Namen.
  defp find_tags({name, attrs, content}, target) do
    name_str = to_string(name)

    if tag_matches?(name_str, target) do
      [{name, attrs, content} | find_tags_in_list(content, target)]
    else
      find_tags_in_list(content, target)
    end
  end

  defp find_tags(_, _), do: []

  defp find_tags_in_list(content, target) when is_list(content) do
    Enum.flat_map(content, fn
      child when is_tuple(child) -> find_tags(child, target)
      _binary -> []
    end)
  end

  defp find_tags_in_list(_, _), do: []

  defp tag_matches?(name_str, target) do
    case String.split(name_str, ":") do
      [local_name] -> local_name == target
      parts -> List.last(parts) == target
    end
  end

  defp get_statement_currency(stmt) do
    get_text(stmt, "Ccy") || get_attr(stmt, "Amt", "Ccy")
  end

  defp parse_date(nil), do: nil

  defp parse_date(str) when is_binary(str) do
    str = String.trim(str)

    if str == "" do
      nil
    else
      case Regex.run(~r/(\d{4}-\d{2}-\d{2})/, str) do
        [date | _] ->
          case Date.from_iso8601(date) do
            {:ok, parsed_date} -> parsed_date
            _ -> nil
          end

        _ ->
          nil
      end
    end
  end

  # --- Daten-Formatierung ---

  defp format_amount(nil, _), do: Decimal.new("0.00")
  defp format_amount(str, :debit), do: Decimal.negate(Decimal.new(str))
  defp format_amount(str, :credit), do: Decimal.new(str)

  # Bereinigt Texte wie Verwendungszweck: entfernt Mehrfach-Leerzeichen und trimmt
  defp clean_info(nil), do: nil

  defp clean_info(text) when is_binary(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
