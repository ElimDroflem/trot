import Foundation

extension Int {
    /// Pluralises a noun based on the integer's value.
    ///
    /// Examples:
    ///   `1.pluralised("day")` → `"1 day"`
    ///   `5.pluralised("day")` → `"5 days"`
    ///   `1.pluralised("walk")` → `"1 walk"`
    ///   `2.pluralised("walk")` → `"2 walks"`
    ///   `1.pluralised("foot", "feet")` → `"1 foot"`
    ///   `2.pluralised("foot", "feet")` → `"2 feet"`
    ///
    /// Default plural appends "s". Pass `plural` for irregulars.
    func pluralised(_ singular: String, _ plural: String? = nil) -> String {
        let noun: String
        if self == 1 {
            noun = singular
        } else {
            noun = plural ?? "\(singular)s"
        }
        return "\(self) \(noun)"
    }
}
