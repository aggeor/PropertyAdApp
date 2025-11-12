
struct Place: Identifiable, Codable, Equatable {
    let placeId: String
    let mainText: String
    let secondaryText: String

    var id: String { placeId }
}
