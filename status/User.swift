import Foundation

struct User: Identifiable {
    var id: String // Firebase의 고유 ID
    var name: String // 사용자 이름
    var status: String // 사용자 상태 (출근 완료, 수업 중 등)
    var timestamp: String // 출근시간
    var checkoutTimestamp: String? // 퇴근시간
}
