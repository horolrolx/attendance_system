import SwiftUI
import FirebaseDatabase
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    @State private var todaysPassword: String = "" // 오늘의 비밀번호
    @State private var users: [User] = [] // 사용자 리스트
    @State private var timer: Timer? = nil // @State로 관리되는 타이머
    @State private var qrImage: UIImage? = nil
    private let ref = Database.database().reference() // Firebase Realtime Database 참조
    private let passwordKey = "todaysPassword" // Firebase에 저장될 키
    private let qrURL = "https://greenorange-caf82.web.app"

    var body: some View {
        VStack(spacing: 20) {
            // 오늘의 비밀번호 섹션
            VStack(spacing: 10) {
                Text("오늘의 비밀번호")
                    .font(.headline)
                    .foregroundColor(.gray)
                Text(todaysPassword.isEmpty ? "비밀번호를 가져오는 중..." : todaysPassword)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .padding(.horizontal)
            }
            .padding(.bottom)

            Divider()

            // QR 코드 섹션
                        VStack(spacing: 10) {
                            if let qrImage = qrImage {
                                Image(uiImage: qrImage)
                                    .resizable()
                                    .interpolation(.none)
                                    .scaledToFit()
                                    .frame(width: 200, height: 200)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(radius: 5)
                            } else {
                                Text("QR 코드를 생성하는 중...")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                        }
            Divider()
            
            // 실시간 사용자 상태 섹션
            VStack(spacing: 10) {
                Text("실시간 사용자 상태")
                    .font(.title2)
                    .bold()

                if users.isEmpty {
                    Text("등록된 사용자가 없습니다.")
                        .foregroundColor(.gray)
                        .font(.caption)
                } else {
                    List(users) { user in
                        VStack(alignment: .leading, spacing: 10) {
                            // 사용자 정보 표시
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(user.name)
                                        .font(.headline)
                                    Text("출근 시간: \(formatKoreanTimestamp(user.timestamp))")
                                        .font(.caption)
                                        .foregroundColor(.gray)

                                    // 퇴근 시간이 있을 경우에만 표시
                                    if let checkoutTime = user.checkoutTimestamp, !checkoutTime.isEmpty {
                                        Text("퇴근 시간: \(formatKoreanTimestamp(checkoutTime))")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                }
                                Spacer()
                                Text(user.status)
                                    .font(.subheadline)
                                    .padding(5)
                                    .background(user.status == "퇴근" ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                                    .foregroundColor(user.status == "퇴근" ? .red : .blue)
                                    .cornerRadius(5)
                            }

                            // 버튼 섹션
                            if user.status != "퇴근" { // 퇴근 상태가 아닐 때만 상태 변경 가능
                                HStack {
                                    Spacer()

                                    // 상태 변경 메뉴
                                    Menu {
                                        Button("재실") {
                                            updateUserStatus(user: user, newStatus: "재실")
                                        }
                                        Button("회의") {
                                            updateUserStatus(user: user, newStatus: "회의")
                                        }
                                        Button("식사") {
                                            updateUserStatus(user: user, newStatus: "식사")
                                        }
                                        Button("수업") {
                                            updateUserStatus(user: user, newStatus: "수업")
                                        }
                                        Button("기타") {
                                            updateUserStatus(user: user, newStatus: "기타")
                                        }
                                    } label: {
                                        Text("상태 변경")
                                            .font(.caption)
                                            .padding(8)
                                            .background(Color(.systemBlue))
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }

                                    // 퇴근 버튼
                                    Button(action: {
                                        updateUserStatus(user: user, newStatus: "퇴근")
                                        updateCheckoutTime(user: user)
                                    }) {
                                        Text("퇴근")
                                            .font(.caption)
                                            .padding(8)
                                            .background(Color(.systemRed))
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle()) // 버튼의 클릭 가능 영역 명확히 정의
                                }
                                .padding(.top, 5) // 버튼 섹션과 사용자 정보 간격 조정
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .onAppear {
            initializePassword() // 초기 비밀번호 생성 또는 가져오기
            observePassword() // 수시로 비밀번호 체크
            fetchUserData() // 사용자 리스트 가져오기
            generateQRCode() // QR 코드 생성 가져오기
        }
    }
    
    // QR 코드 생성
        private func generateQRCode() {
            let context = CIContext()
            let filter = CIFilter.qrCodeGenerator()
            let data = qrURL.data(using: .ascii)

            filter.setValue(data, forKey: "inputMessage")
            filter.setValue("H", forKey: "inputCorrectionLevel") // 오류 수정 레벨

            if let outputImage = filter.outputImage,
               let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                let uiImage = UIImage(cgImage: cgImage)
                self.qrImage = uiImage
            } else {
                print("QR 코드 생성 실패")
            }
        }

    // 초기 비밀번호 생성 또는 가져오기
    private func initializePassword() {
        ref.child(passwordKey).observeSingleEvent(of: .value) { snapshot in
            if let password = snapshot.value as? String {
                self.todaysPassword = password
            } else {
                generateAndSavePassword()
            }
        } withCancel: { error in
            print("Firebase에서 데이터를 가져오는 중 오류 발생: \(error.localizedDescription)")
        }
    }

    // 비밀번호 생성 및 Firebase에 저장
    private func generateAndSavePassword() {
        let password = generatePassword()
        self.todaysPassword = password
        ref.child(passwordKey).setValue(password) { error, _ in
            if let error = error {
                print("비밀번호 저장 실패: \(error.localizedDescription)")
            }
        }
    }

    // 실시간 비밀번호 감시
    private func observePassword() {
        ref.child(passwordKey).observe(.value) { snapshot in
            if let password = snapshot.value as? String {
                self.todaysPassword = password
            }
        }
    }

    // 4자리 비밀번호 생성
    private func generatePassword() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<4).map { _ in characters.randomElement()! })
    }

    // Firebase에서 사용자 데이터 가져오기
    private func fetchUserData() {
        ref.child("users").observe(.value) { snapshot in
            var newUsers: [User] = []
            for child in snapshot.children {
                if let snapshot = child as? DataSnapshot,
                   let value = snapshot.value as? [String: Any],
                   let name = value["name"] as? String,
                   let status = value["status"] as? String,
                   let timestamp = value["timestamp"] as? String {
                    let checkoutTimestamp = value["checkoutTimestamp"] as? String
                    let user = User(id: snapshot.key, name: name, status: status, timestamp: timestamp, checkoutTimestamp: checkoutTimestamp)
                    newUsers.append(user)
                }
            }
            self.users = newUsers
        } withCancel: { error in
            print("사용자 데이터를 가져오는 중 오류 발생: \(error.localizedDescription)")
        }
    }

    // 사용자 상태 변경
    private func updateUserStatus(user: User, newStatus: String) {
        ref.child("users").child(user.id).updateChildValues(["status": newStatus]) { error, _ in
            if let error = error {
                print("사용자 상태 업데이트 실패: \(error.localizedDescription)")
            } else {
                if newStatus == "퇴근" {
                    updateCheckoutTime(user: user)
                }
                fetchUserData()
            }
        }
    }

    // 퇴근 시간 업데이트
    private func updateCheckoutTime(user: User) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'hh:mm:ssa"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        let checkoutTime = formatter.string(from: Date()) // 현재 시간 포맷 적용

        ref.child("users").child(user.id).updateChildValues(["checkoutTimestamp": checkoutTime]) { error, _ in
            if let error = error {
                print("퇴근 시간 업데이트 실패: \(error.localizedDescription)")
            }
        }
    }

    // 한국 시간 타임스탬프 형식화
    private func formatKoreanTimestamp(_ rawTimestamp: String) -> String {
        // 공백 및 잘못된 형식 정리
        let cleanedTimestamp = rawTimestamp
            .replacingOccurrences(of: "a.m.", with: "AM")
            .replacingOccurrences(of: "p.m.", with: "PM")
            .trimmingCharacters(in: .whitespacesAndNewlines) // 공백 제거

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'hh:mm:ssa" // 정확한 입력 형식
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")

        // cleanedTimestamp를 사용하여 파싱 시도
        if let date = formatter.date(from: cleanedTimestamp) {
            let koreanFormatter = DateFormatter()
            koreanFormatter.dateFormat = "yyyy년 MM월 dd일 a h시 m분" // 한국어 형식
            koreanFormatter.locale = Locale(identifier: "ko_KR")
            koreanFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")
            return koreanFormatter.string(from: date)
        } else {
            return "시간 형식 오류" // 실패 시
        }
    }
}
