# 메모리 관리 구현 설명

## Phase 4에서 구현한 것

### 1. Page Tables (sv39) - Virtual Memory

**목적**: 가상 메모리 주소를 물리 메모리로 변환

**구조**:
```
가상 주소 (39비트):
[38:30] VPN[2] - Level 2 인덱스 (9비트)
[29:21] VPN[1] - Level 1 인덱스 (9비트)  
[20:12] VPN[0] - Level 0 인덱스 (9비트)
[11:0]  Offset  - 페이지 내 오프셋 (4KB)

3단계 테이블 탐색:
Root[VPN[2]] → L1[VPN[1]] → L0[VPN[0]] → Physical Page
```

**실제 매핑**:
- 0x10000000 → 0x10000000 (프레임버퍼, RW)
- 0x10400000 → 0x10400000 (커널, RWX)
- 0x14000000 → 0x14000000 (키보드 MMIO, RW)

**코드**: `kernel/mmu.s`
- `init_page_tables()`: 테이블 생성
- `enable_paging()`: SATP 레지스터 설정, TLB flush

---

### 2. Heap Allocator - Dynamic Memory

**목적**: 런타임에 메모리 할당/해제

**알고리즘**: First-Fit with Free List

**메모리 블록**:
```
[Header: 16바이트][사용자 데이터...][Header: 16바이트]...

Header 구조:
- size (4B): 전체 블록 크기
- free (4B): 1=free, 0=allocated
- next (4B): 다음 블록 포인터
- magic (4B): 0xABCD1234 (검증용)
```

**kmalloc(size) 동작**:
1. 크기를 16바이트로 정렬
2. 헤더 크기(16B) 추가
3. Free list를 순회하며 충분한 블록 찾기 (first-fit)
4. 블록이 크면 분할:
   ```
   [A: 1000B free] → [A: 64B alloc][B: 936B free]
   ```
5. free=0으로 마크
6. (block + 16) 반환 (사용자는 데이터 영역만 받음)

**kfree(ptr) 동작**:
1. ptr - 16 = 헤더 주소
2. Magic 검증 (0xABCD1234)
3. free=1로 마크
4. 다음 블록이 free면 병합:
   ```
   [A: free][B: free] → [AB: free--------]
   ```

**코드**: `kernel/heap.s`
- `heap_init()`: 초기 free block 생성
- `kmalloc(size)`: 메모리 할당
- `kfree(ptr)`: 메모리 해제
- `heap_stats()`: 통계 조회

---

## 메모리 레이아웃

```
0x10000000   ┌──────────────────┐
             │  Framebuffer     │ 3 MB (RW)
0x10300000   ├──────────────────┤
             │  Kernel Code     │ 5 KB (RWX)
0x10400000   ├──────────────────┤
             │  Heap Start      │
             │  [free: 252MB]   │ ← kmalloc 여기서 할당
             │  ...             │
0x1FFFFFFF   └──────────────────┘
```

---

## 실제 사용 예시

```assembly
# 128바이트 할당
li a0, 128
call kmalloc
# a0 = 0x10400010 (헤더 다음 주소)

# 메모리 사용
mv s0, a0
li t0, 42
sw t0, 0(s0)

# 해제
mv a0, s0
call kfree
# 블록이 free list로 돌아감
```

---

## 왜 이게 중요한가?

**Virtual Memory**:
- 각 프로세스가 자신만의 주소 공간 가질 수 있음
- 보호: 커널 메모리를 프로세스가 못 건드림
- 유연성: 물리 메모리 위치와 독립적

**Heap Allocator**:
- 동적 데이터 구조 (리스트, 트리 등)
- 프로세스마다 PCB 할당
- 파일 버퍼, 네트워크 패킷 버퍼 등

**Phase 5 File System에서 사용**:
- 파일 디스크립터 구조체 할당
- 디렉토리 엔트리 버퍼
- 읽기/쓰기 임시 버퍼
