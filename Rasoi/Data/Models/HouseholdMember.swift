import Foundation
import SwiftData

/// Who eats at this table (SPEC §3).
///
/// Enum-valued columns are stored as their raw `String` throughout Rasoi and exposed through a
/// computed property. Raw storage keeps `#Predicate` queries simple and makes the store readable
/// in an export.
@Model
final class HouseholdMember {
    var name: String = ""
    var dateOfBirth: Date = Date.distantPast
    var roleRaw: String = MemberRole.adult.rawValue
    var likes: [String] = []
    var dislikes: [String] = []
    var avatarSymbol: String = "person.circle"
    var colorHex: String = "E8A33D"
    var sortOrder: Int = 0
    var isActive: Bool = true

    init(
        name: String,
        dateOfBirth: Date,
        role: MemberRole,
        likes: [String] = [],
        dislikes: [String] = [],
        avatarSymbol: String = "person.circle",
        colorHex: String = "E8A33D",
        sortOrder: Int = 0,
        isActive: Bool = true
    ) {
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.roleRaw = role.rawValue
        self.likes = likes
        self.dislikes = dislikes
        self.avatarSymbol = avatarSymbol
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.isActive = isActive
    }

    var role: MemberRole {
        get { MemberRole(rawValue: roleRaw) ?? .adult }
        set { roleRaw = newValue.rawValue }
    }

    var isChild: Bool { role == .child }

    func ageYears(on date: Date = .now) -> Int {
        AgeBand.years(dob: dateOfBirth, on: date)
    }

    func ageBand(on date: Date = .now) -> AgeBand {
        AgeBand.band(dob: dateOfBirth, on: date)
    }
}

/// Adults and children are planned for differently: children drive kid scores and the
/// minimum-age filter; adults do not.
enum MemberRole: String, Codable, CaseIterable, Sendable {
    case adult
    case child

    var label: String {
        switch self {
        case .adult: return "Adult"
        case .child: return "Child"
        }
    }
}
