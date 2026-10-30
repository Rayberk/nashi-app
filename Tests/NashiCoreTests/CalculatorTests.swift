import XCTest
@testable import NashiCore

final class CalculatorTests:XCTestCase {
    private let locale=Locale(identifier:"en_US")
    private let rates=CurrencyRates(base:"USD",rates:["USD":1,"AED":3.6725,"EUR":0.92,"TRY":34.25,"GBP":0.79],updated:Date(timeIntervalSince1970:1_793_318_551))

    private func answer(_ query:String,local:String="TRY",file:StaticString=#filePath,line:UInt=#line)->Calculator.Answer? {
        guard case .answer(let answer)? = Calculator.evaluate(query,rates:rates,localCurrency:local,locale:locale) else { return nil }
        return answer
    }

    func testArithmetic() {
        XCTAssertEqual(answer("10+10")?.text,"20")
        XCTAssertEqual(answer("10+10")?.kind,.math)
        XCTAssertEqual(answer("2 + 3 * 4")?.value,14)
        XCTAssertEqual(answer("(2+3)*4")?.value,20)
        XCTAssertEqual(answer("2^10")?.value,1024)
        XCTAssertEqual(answer("2**3")?.value,8)
        XCTAssertEqual(answer("-2^2")?.value,-4)
        XCTAssertEqual(answer("10/4")?.text,"2.5")
        XCTAssertEqual(answer("0.1+0.2")?.text,"0.3")
        XCTAssertEqual(answer("7 × 6")?.value,42)
        XCTAssertEqual(answer("9 ÷ 3")?.value,3)
        XCTAssertEqual(answer("3x4")?.value,12)
        XCTAssertEqual(answer("10 mod 3")?.value,1)
        XCTAssertEqual(answer("5!")?.value,120)
        XCTAssertEqual(answer("1,000 * 3")?.text,"3,000")
        XCTAssertEqual(answer("1,5 * 2")?.value,3)
        XCTAssertEqual(answer("2(3+4)")?.value,14)
    }

    func testFunctionsConstantsAndPercentages() {
        XCTAssertEqual(answer("sqrt(16)")?.value,4)
        XCTAssertEqual(answer("√9")?.value,3)
        XCTAssertEqual(answer("log(1000)")?.value,3)
        XCTAssertEqual(answer("round(2.6)")?.value,3)
        XCTAssertEqual(answer("2pi")?.text,"6.2831853072")
        XCTAssertEqual(answer("50 + 10%")?.value,55)
        XCTAssertEqual(answer("80 - 25%")?.value,60)
        XCTAssertEqual(answer("20% of 50")?.value,10)
        XCTAssertEqual(answer("15%")?.value,0.15)
    }

    func testPlainTextAndInvalidInputShowNothing() {
        for query in ["","  ","42","hello","10/0","2+","(1+2","USD","Nashi","report.pdf","sqrt(-1)","171!","√-4"] {
            XCTAssertNil(Calculator.evaluate(query,rates:rates,localCurrency:"TRY",locale:locale),query)
        }
    }

    func testCurrencyConvertsToLocalCurrencyAndExplicitTargets() throws {
        let local=try XCTUnwrap(answer("1 USD"))
        XCTAssertEqual(local.kind,.currency)
        XCTAssertEqual(local.text,"34.25 TRY")
        XCTAssertEqual(local.copyText,"34.25")
        XCTAssertEqual(local.detail,"1.00 USD =")
        XCTAssertEqual(local.ratesUpdated,rates.updated)
        XCTAssertEqual(answer("1 USD to AED")?.text,"3.67 AED")
        XCTAssertEqual(try XCTUnwrap(answer("1 usd to aed")?.value),3.6725,accuracy:1e-9)
        XCTAssertEqual(answer("usd to aed")?.text,"3.67 AED")
        XCTAssertEqual(answer("100 aed in usd")?.text,"27.23 USD")
        XCTAssertEqual(answer("$20")?.text,"685.00 TRY")
        XCTAssertEqual(answer("€10 to gbp")?.text,"8.59 GBP")
        XCTAssertEqual(answer("10 dollars to euros")?.text,"9.20 EUR")
        XCTAssertEqual(answer("2*5 USD → EUR")?.text,"9.20 EUR")
        XCTAssertEqual(answer("1,000 TRY to USD")?.text,"29.20 USD")
        // The local currency itself shows its US dollar value.
        XCTAssertEqual(answer("100 TRY")?.text,"2.92 USD")
        XCTAssertEqual(answer("1 USD",local:"USD")?.text,"0.92 EUR")
        XCTAssertNil(answer("1 USD to XYZ"))
    }

    func testCurrencyWithoutRatesAsksForThem() {
        XCTAssertEqual(Calculator.evaluate("1 USD to AED",rates:nil,localCurrency:"TRY",locale:locale),.needsRates(from:"USD",to:"AED"))
        XCTAssertEqual(Calculator.evaluate("5 eur",rates:nil,localCurrency:"TRY",locale:locale),.needsRates(from:"EUR",to:"TRY"))
    }

    func testUnitConversions() {
        XCTAssertEqual(answer("5 km to mi")?.text,"3.106856 mi")
        XCTAssertEqual(answer("5 km to mi")?.kind,.unit)
        XCTAssertEqual(answer("5km in miles")?.text,"3.106856 mi")
        XCTAssertEqual(answer("6 ft to cm")?.text,"182.88 cm")
        XCTAssertEqual(answer("1 inch to mm")?.text,"25.4 mm")
        XCTAssertEqual(answer("100 c to f")?.text,"212 °F")
        XCTAssertEqual(answer("32 °F to °C")?.text,"0 °C")
        XCTAssertEqual(answer("0 kelvin to celsius")?.text,"-273.15 °C")
        XCTAssertEqual(answer("1 lb to kg")?.text,"0.453592 kg")
        XCTAssertEqual(answer("2 pounds in grams")?.text,"907.18474 g")
        XCTAssertEqual(answer("1 gallon to liters")?.text,"3.785412 l")
        XCTAssertEqual(answer("3 cups to ml")?.text,"709.76471 ml")
        XCTAssertEqual(answer("1 GB to MB")?.text,"1,000 MB")
        XCTAssertEqual(answer("1 GiB to MiB")?.text,"1,024 MiB")
        XCTAssertEqual(answer("8 bits to bytes")?.text,"1 B")
        XCTAssertEqual(answer("90 minutes to hours")?.text,"1.5 h")
        XCTAssertEqual(answer("1 week in days")?.text,"7 d")
        XCTAssertEqual(answer("100 km/h to mph")?.text,"62.137119 mph")
        XCTAssertEqual(answer("1 acre to m2")?.text,"4,046.856422 m²")
        XCTAssertEqual(answer("1000 square feet to square meters")?.text,"92.90304 m²")
        XCTAssertEqual(answer("180 degrees to radians")?.text,"3.141593 rad")
        XCTAssertEqual(answer("(2+3) km to m")?.text,"5,000 m")
        XCTAssertNil(answer("5 km to kg"))
        XCTAssertNil(answer("5 km"))
    }

    func testLocalizedNumbersAndCopyText() throws {
        guard case .answer(let answer)? = Calculator.evaluate("1234.5*2",locale:Locale(identifier:"tr_TR")) else { return XCTFail("No answer") }
        XCTAssertEqual(answer.text,"2.469")
        XCTAssertEqual(answer.copyText,"2469")
        guard case .answer(let money)? = Calculator.evaluate("1000 usd",rates:rates,localCurrency:"TRY",locale:Locale(identifier:"tr_TR")) else { return XCTFail("No answer") }
        XCTAssertEqual(money.text,"34.250,00 TRY")
        XCTAssertEqual(money.copyText,"34250,00")
        XCTAssertEqual(self.answer("2^60")?.text,"1.1529215E18")
    }

    func testCalculatorCopyIsTranslatedIncludingDatesWithSpaces() {
        XCTAssertEqual(AppLocalization.text("Exchange rates: 30 Eki 2026 12:56",language:"tr"),"Döviz kurları: 30 Eki 2026 12:56")
        XCTAssertEqual(AppLocalization.text("Exchange rates: 30 oct. 2026 à 13:00",language:"fr"),"Taux de change\u{00A0}: 30 oct. 2026 à 13:00")
        XCTAssertEqual(AppLocalization.text("Getting today’s exchange rates for USD → TRY…",language:"tr"),"USD → TRY için güncel döviz kurları alınıyor…")
        for source in ["Calculate or convert","Calculator","Local currency","Copied","Try again","Return copies the answer"] {
            XCTAssertNotEqual(AppLocalization.text(source,language:"tr"),source,source)
            XCTAssertNotEqual(AppLocalization.text(source,language:"fr"),source,source)
        }
    }

    func testRateServiceDecodesCachesAndConverts() throws {
        let json=#"{"result":"success","base_code":"USD","time_last_update_unix":1793318551,"rates":{"USD":1,"AED":3.6725,"TRY":34.25}}"#
        let decoded=try CurrencyRateService.decode(Data(json.utf8))
        XCTAssertEqual(decoded.base,"USD")
        XCTAssertEqual(decoded.updated,Date(timeIntervalSince1970:1_793_318_551))
        XCTAssertEqual(try XCTUnwrap(decoded.convert(3.6725,from:"AED",to:"USD")),1,accuracy:1e-12)
        XCTAssertEqual(try XCTUnwrap(decoded.convert(1,from:"AED",to:"TRY")),34.25/3.6725,accuracy:1e-12)
        XCTAssertNil(decoded.convert(1,from:"USD",to:"EUR"))
        XCTAssertThrowsError(try CurrencyRateService.decode(Data(#"{"result":"error","base_code":"USD","time_last_update_unix":0,"rates":{}}"#.utf8)))
        XCTAssertThrowsError(try CurrencyRateService.decode(Data(#"{"result":"success","base_code":"USD","time_last_update_unix":0,"rates":{"AED":-1}}"#.utf8)))

        let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        defer { try? FileManager.default.removeItem(at:directory) }
        let file=directory.appendingPathComponent("rates.json")
        XCTAssertNil(CurrencyRateService.cached(at:file))
        CurrencyRateService.store(decoded,at:file)
        XCTAssertEqual(CurrencyRateService.cached(at:file),decoded)
        XCTAssertFalse(CurrencyRateService.isStale(decoded,now:decoded.updated.addingTimeInterval(3600)))
        XCTAssertTrue(CurrencyRateService.isStale(decoded,now:decoded.updated.addingTimeInterval(3*86400)))
        XCTAssertTrue(CurrencyRateService.isStale(nil))
    }
}
