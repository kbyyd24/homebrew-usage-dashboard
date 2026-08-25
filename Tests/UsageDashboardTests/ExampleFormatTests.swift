import Testing
@testable import UsageDashboard

@Test func formatsRealExampleExtractor() {
    let input = """
    function(response){
      var w = response.windowLimits;
      return {
        status: 'ok',
        message: '',
        rows: [ { kind: 'window', label: '5 小时', used: w.fiveHour.used, cap: w.fiveHour.cap, resetAt: w.fiveHour.resetAt }, { kind: 'balance', label: '月度余额', balance: response.credits.monthlyCredits, unit: 'credits' } ]
      };
    }
    """
    let output = JSFormatter.format(input, indentSize: 2)

    #expect(output.contains("function(response) {"))
    #expect(output.contains("w.fiveHour.used"))
    #expect(output.contains("response.credits.monthlyCredits"))
    #expect(output.contains("kind: 'window'"))
    #expect(output.contains("kind: 'balance'"))
}
