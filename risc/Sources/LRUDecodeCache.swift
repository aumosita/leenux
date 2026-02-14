import Foundation

/// LRU 캐시 노드
class LRUCacheNode {
    let key: UInt32
    let value: InstructionType
    var prev: LRUCacheNode?
    var next: LRUCacheNode?
    
    init(key: UInt32, value: InstructionType) {
        self.key = key
        self.value = value
    }
}

/// LRU Decode Cache
/// 
/// Doubly-linked list + Hash Map으로 O(1) 조회/삽입/삭제 구현
/// Most Recent (head) ←→ ... ←→ Least Recent (tail)
class LRUDecodeCache {
    private var cache: [UInt32: LRUCacheNode] = [:]
    private var head: LRUCacheNode?  // Most recent
    private var tail: LRUCacheNode?  // Least recent
    private let capacity: Int
    private(set) var hits: Int = 0
    private(set) var misses: Int = 0
    
    init(capacity: Int = 50000) {
        self.capacity = capacity
        self.cache.reserveCapacity(capacity)
    }
    
    /// 캐시 조회 (O(1))
    func get(_ key: UInt32) -> InstructionType? {
        guard let node = cache[key] else {
            misses += 1
            return nil
        }
        
        hits += 1
        moveToFront(node)
        return node.value
    }
    
    /// 캐시 삽입 (O(1))
    func put(_ key: UInt32, _ value: InstructionType) {
        // 이미 존재하면 갱신 (MRU로 이동)
        if let existing = cache[key] {
            moveToFront(existing)
            return
        }
        
        // 신규 노드 생성
        let newNode = LRUCacheNode(key: key, value: value)
        cache[key] = newNode
        addToFront(newNode)
        
        // Capacity 초과 시 LRU 제거
        if cache.count > capacity {
            removeTail()
        }
    }
    
    // MARK: - Private Helpers
    
    /// 노드를 리스트 맨 앞으로 이동 (Most Recently Used)
    private func moveToFront(_ node: LRUCacheNode) {
        guard node !== head else { return }
        
        remove(node)
        addToFront(node)
    }
    
    /// 노드를 리스트 맨 앞에 추가
    private func addToFront(_ node: LRUCacheNode) {
        node.next = head
        node.prev = nil
        
        head?.prev = node
        head = node
        
        if tail == nil {
            tail = node
        }
    }
    
    /// 노드를 리스트에서 제거 (연결 끊기)
    private func remove(_ node: LRUCacheNode) {
        if node === head {
            head = node.next
        }
        if node === tail {
            tail = node.prev
        }
        
        node.prev?.next = node.next
        node.next?.prev = node.prev
    }
    
    /// 가장 오래된 노드(tail) 제거
    private func removeTail() {
        guard let oldTail = tail else { return }
        cache.removeValue(forKey: oldTail.key)
        remove(oldTail)
    }
    
    // MARK: - Statistics
    
    /// 캐시 히트율 (%)
    var hitRate: Double {
        let total = hits + misses
        return total > 0 ? Double(hits) / Double(total) * 100 : 0
    }
    
    /// 현재 캐시 엔트리 수
    var count: Int { cache.count }
    
    /// 통계 초기화
    func resetStats() {
        hits = 0
        misses = 0
    }
}
