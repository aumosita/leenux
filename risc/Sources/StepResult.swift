import Foundation

/// 결과값: 코어의 step()가 반환하는 이유
enum StepResult {
    case `continue`   // 계속 실행 가능
    case yield        // syscall/유휴로 커널 개입 요구
    case blocked      // 메모리 등으로 블록됨
    case exit         // 프로세스/스레드 종료 (EBREAK 등)
}
