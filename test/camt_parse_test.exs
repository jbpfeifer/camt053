defmodule Camt053ParseTest do
  use ExUnit.Case

  test "parst eine einfache Buchung korrekt" do
    xml = """
    <Document>
      <Ntry>
        <Amt Ccy="EUR">120.50</Amt>
        <CdtDbtInd>DBIT</CdtDbtInd>
        <BookgDt><Dt>2023-10-27</Dt></BookgDt>
        <NtryDtls><TxDtls><RmtInf><Ustrd>Rechnung RE-12345</Ustrd></RmtInf></TxDtls></NtryDtls>
      </Ntry>
    </Document>
    """

    {:ok, [stmt]} = Camt053.parse(xml)
    [entry] = stmt.entries

    assert Decimal.equal?(entry.amount, Decimal.new("-120.50"))
    assert entry.type == :debit
    assert entry.info =~ "RE-12345"
  end

  test "parst booking_date aus verschachteltem BookgDt/Dt" do
    xml = """
    <Document>
      <Ntry>
        <Amt Ccy="EUR">1.00</Amt>
        <CdtDbtInd>CRDT</CdtDbtInd>
        <BookgDt><Dt>2023-10-27</Dt></BookgDt>
      </Ntry>
    </Document>
    """

    {:ok, [stmt]} = Camt053.parse(xml)
    [entry] = stmt.entries

    assert entry.booking_date == ~D[2023-10-27]
  end

  test "nutzt MsgId nicht als IBAN-Fallback" do
    xml = """
    <Document>
      <Stmt>
        <MsgId>MSG-999</MsgId>
        <Ntry>
          <Amt Ccy="EUR">1.00</Amt>
          <CdtDbtInd>CRDT</CdtDbtInd>
        </Ntry>
      </Stmt>
    </Document>
    """

    {:ok, [stmt]} = Camt053.parse(xml)
    assert stmt.iban == nil
  end

  test "liest statement currency aus Ccy oder Amt-Attribut" do
    xml = """
    <Document>
      <Stmt>
        <Acct><Ccy>CHF</Ccy></Acct>
        <Ntry>
          <Amt Ccy="EUR">1.00</Amt>
          <CdtDbtInd>CRDT</CdtDbtInd>
        </Ntry>
      </Stmt>
    </Document>
    """

    {:ok, [stmt]} = Camt053.parse(xml)
    assert stmt.currency == "CHF"
  end

  test "parst namespaced Camt053 tags korrekt" do
    xml = """
    <Camt053:Document xmlns:Camt053="urn:iso:std:iso:20022:tech:xsd:Camt053.053.001.02">
      <Camt053:BkToCstmrStmt>
        <Camt053:Stmt>
          <Camt053:Acct><Camt053:Id><Camt053:IBAN>DE44500105175407324931</Camt053:IBAN></Camt053:Id></Camt053:Acct>
          <Camt053:Ntry>
            <Camt053:Amt Ccy="EUR">10.50</Camt053:Amt>
            <Camt053:CdtDbtInd>CRDT</Camt053:CdtDbtInd>
            <Camt053:BookgDt><Camt053:Dt>2024-12-01</Camt053:Dt></Camt053:BookgDt>
            <Camt053:NtryDtls><Camt053:TxDtls><Camt053:RmtInf><Camt053:Ustrd>Namespace Test</Camt053:Ustrd></Camt053:RmtInf></Camt053:TxDtls></Camt053:NtryDtls>
          </Camt053:Ntry>
        </Camt053:Stmt>
      </Camt053:BkToCstmrStmt>
    </Camt053:Document>
    """

    {:ok, [stmt]} = Camt053.parse(xml)
    [entry] = stmt.entries

    assert stmt.iban == "DE44500105175407324931"
    assert entry.currency == "EUR"
    assert entry.booking_date == ~D[2024-12-01]
    assert entry.info == "Namespace Test"
  end

  test "parst mehrere statements getrennt" do
    xml = """
    <Document>
      <Stmt>
        <Acct><Id><IBAN>DE11111111111111111111</IBAN></Id></Acct>
        <Ntry>
          <Amt Ccy="EUR">10.00</Amt>
          <CdtDbtInd>CRDT</CdtDbtInd>
        </Ntry>
      </Stmt>
      <Stmt>
        <Acct><Id><IBAN>DE22222222222222222222</IBAN></Id></Acct>
        <Ntry>
          <Amt Ccy="USD">20.00</Amt>
          <CdtDbtInd>DBIT</CdtDbtInd>
        </Ntry>
      </Stmt>
    </Document>
    """

    {:ok, [stmt1, stmt2]} = Camt053.parse(xml)
    [entry1] = stmt1.entries
    [entry2] = stmt2.entries

    assert stmt1.iban == "DE11111111111111111111"
    assert stmt2.iban == "DE22222222222222222222"
    assert Decimal.equal?(entry1.amount, Decimal.new("10.00"))
    assert Decimal.equal?(entry2.amount, Decimal.new("-20.00"))
  end
end
