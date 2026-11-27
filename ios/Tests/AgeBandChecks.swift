import Foundation

@main
struct AgeBandChecks {
    static func main() {
        let year = 2030
        let cases: [(Int?, Bool?, AgeBand)] = [
            (nil, nil, .unknown), (2031, nil, .unknown), (1909, nil, .unknown),
            (2030, nil, .under18), (2013, true, .under18), (2012, nil, .unknown),
            (2012, false, .under18), (2012, true, .adult), (2011, nil, .adult)
        ]
        for (birthYear, birthday, expected) in cases {
            precondition(AgeBand.classify(birthYear: birthYear, currentYear: year, birthdayPassed: birthday) == expected)
        }
    }
}
