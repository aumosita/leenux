#!/usr/bin/env python3
"""
Simple RISC-V 64I Assembler
Converts RISC-V assembly to binary format for the emulator
"""

import sys
import re
import struct

def encode_r(opcode, rd, funct3, rs1, rs2, funct7):
    return struct.pack('<I', (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode)

def encode_i(opcode, rd, funct3, rs1, imm):
    return struct.pack('<I', ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode)

def encode_s(opcode, funct3, rs1, rs2, imm):
    imm = imm & 0xFFF
    return struct.pack('<I', ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | ((imm & 0x1F) << 7) | opcode)

def encode_b(opcode, funct3, rs1, rs2, imm):
    imm = imm & 0x1FFF
    bit12 = (imm >> 12) & 1
    bit11 = (imm >> 11) & 1
    bit10_5 = (imm >> 5) & 0x3F
    bit4_1 = (imm >> 1) & 0xF
    return struct.pack('<I', (bit12 << 31) | (bit10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (bit4_1 << 8) | (bit11 << 7) | opcode)

def encode_u(opcode, rd, imm):
    return struct.pack('<I', (imm & 0xFFFFF000) | (rd << 7) | opcode)

def encode_j(opcode, rd, imm):
    imm = imm & 0x1FFFFF
    bit20 = (imm >> 20) & 1
    bit19_12 = (imm >> 12) & 0xFF
    bit11 = (imm >> 11) & 1
    bit10_1 = (imm >> 1) & 0x3FF
    return struct.pack('<I', (bit20 << 31) | (bit10_1 << 21) | (bit11 << 20) | (bit19_12 << 12) | (rd << 7) | opcode)

REG_MAP = {
    'zero': 0, 'ra': 1, 'sp': 2, 'gp': 3, 'tp': 4,
    't0': 5, 't1': 6, 't2': 7,
    's0': 8, 'fp': 8, 's1': 9,
    'a0': 10, 'a1': 11, 'a2': 12, 'a3': 13, 'a4': 14, 'a5': 15, 'a6': 16, 'a7': 17,
    's2': 18, 's3': 19, 's4': 20, 's5': 21, 's6': 22, 's7': 23, 's8': 24, 's9': 25, 's10': 26, 's11': 27,
    't3': 28, 't4': 29, 't5': 30, 't6': 31
}

CSR_MAP = {
    'mstatus': 0x300, 'mie': 0x304, 'mtvec': 0x305, 'mscratch': 0x340,
    'mepc': 0x341, 'mcause': 0x342, 'mtval': 0x343, 'mip': 0x344,
    'sstatus': 0x100, 'sie': 0x104, 'stvec': 0x105, 'scause': 0x142,
    'stval': 0x143, 'sip': 0x144, 'satp': 0x180,
    'pmpcfg0': 0x3A0, 'pmpaddr0': 0x3B0, 'cycle': 0xC00, 'time': 0xC01, 'instret': 0xC02,
    'mhartid': 0xF14
}

LABELS = {}

def parse_reg(s):
    s = s.strip().lower()
    if s in REG_MAP: return REG_MAP[s]
    if s.startswith('x'): return int(s[1:])
    raise ValueError(f"Invalid reg: {s}")

def parse_imm(s, pc, labels):
    s = s.strip()
    is_hi = s.startswith('%hi('); is_lo = s.startswith('%lo(')
    if is_hi or is_lo: s = s[4:-1]
    
    # Handle simple arithmetic
    if '*' in s:
        parts = s.split('*')
        val = 1
        for p in parts: val *= parse_imm(p.strip(), 0, labels)
        return val

    if labels and s in labels: val = labels[s]
    else:
        try: val = int(s, 0)
        except: return 0
    if is_hi: return (val + 0x800) >> 12
    if is_lo: return val - (((val + 0x800) >> 12) << 12)
    return val

def get_tokens(s):
    tokens = []; current = ""; in_q = False
    for c in s:
        if c in "'\"": in_q = not in_q; current += c
        elif c == ',' and not in_q: tokens.append(current.strip()); current = ""
        else: current += c
    tokens.append(current.strip())
    return [t for t in tokens if t]

def assemble_line(line, pc, labels):
    line = re.sub(r'#.*', '', line).strip()
    if not line: return b""
    if ':' in line: line = line.split(':', 1)[1].strip()
    if not line or '=' in line or line.startswith('.equ'): return b""

    if line.startswith('.'):
        if line.startswith('.asciz'):
            data = b""; tokens = get_tokens(line[7:])
            for t in tokens:
                if t.startswith('"') or t.startswith("'"):
                    s = t[1:-1].encode().decode('unicode_escape')
                    data += s.encode()
                else: data += bytes([int(t, 0)])
            return data + b"\0"
        if line.startswith('.byte'):
            data = b""; tokens = get_tokens(line[6:])
            for t in tokens:
                if t.startswith('"') or t.startswith("'"): data += t[1:-1].encode().decode('unicode_escape').encode()
                else: data += bytes([int(t, 0)])
            return data
        if line.startswith('.word'):
            data = b""; tokens = get_tokens(line[6:])
            for t in tokens: data += struct.pack('<i', parse_imm(t, 0, labels))
            return data
        if line.startswith('.space'):
            size_expr = line[7:].strip()
            return bytes(parse_imm(size_expr, 0, labels))
        if line.startswith('.align') or line.startswith('.balign'):
            align = int(line.split()[1])
            if align <= 0: return b""
            return bytes((align - (pc % align)) % align)
        return b""

    # Instructions
    m = re.match(r'(\w+)\s*(.*)', line)
    if not m: return b""
    op, rest = m.groups(); op = op.lower()
    rest = rest.replace('(', ',').replace(')', '')
    args = [a.strip() for a in get_tokens(rest)]

    if op in ['add', 'sub', 'and', 'or', 'xor', 'sll', 'srl', 'sra', 'slt', 'sltu', 'mul', 'div', 'rem', 'mulh', 'divu', 'remu']:
        f3 = {'add':0,'sub':0,'sll':1,'slt':2,'sltu':3,'xor':4,'srl':5,'sra':5,'or':6,'and':7,'mul':0,'mulh':1,'div':4,'divu':5,'rem':6,'remu':7}[op]
        f7 = 0x20 if op in ['sub', 'sra'] else (1 if op in ['mul','mulh','div','divu','rem','remu'] else 0)
        return encode_r(0x33, parse_reg(args[0]), f3, parse_reg(args[1]), parse_reg(args[2]), f7)
    if op in ['addi', 'andi', 'ori', 'xori', 'slli', 'srli', 'srai', 'slti', 'sltiu']:
        f3 = {'addi':0,'slli':1,'slti':2,'sltiu':3,'xori':4,'srli':5,'srai':5,'ori':6,'andi':7}[op]
        imm = parse_imm(args[2], pc, labels)
        if op == 'srai': imm |= 0x400
        return encode_i(0x13, parse_reg(args[0]), f3, parse_reg(args[1]), imm)
    if op in ['lb', 'lh', 'lw', 'ld', 'lbu', 'lhu', 'lwu']:
        f3 = {'lb':0,'lh':1,'lw':2,'ld':3,'lbu':4,'lhu':5,'lwu':6}[op]
        return encode_i(0x03, parse_reg(args[0]), f3, parse_reg(args[2]), parse_imm(args[1], pc, labels))
    if op in ['sb', 'sh', 'sw', 'sd']:
        f3 = {'sb':0,'sh':1,'sw':2,'sd':3}[op]
        return encode_s(0x23, f3, parse_reg(args[2]), parse_reg(args[0]), parse_imm(args[1], pc, labels))
    if op in ['beq', 'bne', 'blt', 'bge', 'bltu', 'bgeu']:
        f3 = {'beq':0,'bne':1,'blt':4,'bge':5,'bltu':6,'bgeu':7}[op]
        return encode_b(0x63, f3, parse_reg(args[0]), parse_reg(args[1]), parse_imm(args[2], pc, labels) - pc)
    if op == 'beqz': return encode_b(0x63, 0, parse_reg(args[0]), 0, parse_imm(args[1], pc, labels) - pc)
    if op == 'bnez': return encode_b(0x63, 1, parse_reg(args[0]), 0, parse_imm(args[1], pc, labels) - pc)
    if op == 'blez': return encode_b(0x63, 5, 0, parse_reg(args[0]), parse_imm(args[1], pc, labels) - pc)
    if op == 'bgez': return encode_b(0x63, 5, parse_reg(args[0]), 0, parse_imm(args[1], pc, labels) - pc)
    if op == 'bltz': return encode_b(0x63, 4, parse_reg(args[0]), 0, parse_imm(args[1], pc, labels) - pc)
    if op == 'bgtz': return encode_b(0x63, 4, 0, parse_reg(args[0]), parse_imm(args[1], pc, labels) - pc)
    if op == 'j': return encode_j(0x6F, 0, parse_imm(args[0], pc, labels) - pc)
    if op == 'jal':
        if len(args) == 1: return encode_j(0x6F, 1, parse_imm(args[0], pc, labels) - pc)
        return encode_j(0x6F, parse_reg(args[0]), parse_imm(args[1], pc, labels) - pc)
    if op == 'jalr': return encode_i(0x67, parse_reg(args[0]), 0, parse_reg(args[1]), 0)
    if op == 'ret': return encode_i(0x67, 0, 0, 1, 0)
    if op == 'call': return encode_j(0x6F, 1, parse_imm(args[0], pc, labels) - pc)
    if op == 'lui': return encode_u(0x37, parse_reg(args[0]), parse_imm(args[1], pc, labels) << 12)
    if op == 'auipc': return encode_u(0x17, parse_reg(args[0]), parse_imm(args[1], pc, labels) << 12)
    if op == 'mv': return encode_i(0x13, parse_reg(args[0]), 0, parse_reg(args[1]), 0)
    if op == 'li':
        rd = parse_reg(args[0]); imm_str = args[1]
        try:
            val = int(imm_str, 0)
            if -2048 <= val <= 2047: return encode_i(0x13, rd, 0, 0, val)
        except: pass
        val = parse_imm(imm_str, 0, labels)
        hi = (val + 0x800) >> 12; lo = val - (hi << 12)
        return encode_u(0x37, rd, hi << 12) + encode_i(0x13, rd, 0, rd, lo)
    if op == 'la':
        rd = parse_reg(args[0]); val = parse_imm(args[1], 0, labels)
        hi = (val + 0x800) >> 12; lo = val - (hi << 12)
        return encode_u(0x37, rd, hi << 12) + encode_i(0x13, rd, 0, rd, lo)
    if op in ['csrrw', 'csrrs', 'csrrc']:
        f3 = {'csrrw':1, 'csrrs':2, 'csrrc':3}[op]
        return struct.pack('<I', (CSR_MAP.get(args[1].lower(), 0) << 20) | (parse_reg(args[2]) << 15) | (f3 << 12) | (parse_reg(args[0]) << 7) | 0x73)
    if op == 'csrr': return assemble_line(f"csrrs {args[0]}, {args[1]}, zero", pc, labels)
    if op == 'csrw': return assemble_line(f"csrrw zero, {args[0]}, {args[1]}", pc, labels)
    if op == 'csrs': return assemble_line(f"csrrs zero, {args[0]}, {args[1]}", pc, labels)
    if op == 'ecall': return struct.pack('<I', 0x00000073)
    if op == 'ebreak': return struct.pack('<I', 0x00100073)
    if op == 'mret': return struct.pack('<I', 0x30200073)
    
    # Atomic
    if op in ['lr.w', 'lr.d']:
        rd = parse_reg(args[0]); rs1 = parse_reg(args[1])
        f3 = 2 if op == 'lr.w' else 3
        return struct.pack('<I', (0x02 << 27) | (rs1 << 15) | (f3 << 12) | (rd << 7) | 0x2F)
    if op in ['sc.w', 'sc.d']:
        rd = parse_reg(args[0]); rs2 = parse_reg(args[1]); rs1 = parse_reg(args[2])
        f3 = 2 if op == 'sc.w' else 3
        return struct.pack('<I', (0x03 << 27) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | 0x2F)
        
    return b""

def assemble(src, dst, base=0):
    global LABELS
    with open(src, 'r') as f: lines = f.readlines()
    LABELS = {}; pc = base
    for line in lines:
        raw = re.sub(r'#.*', '', line).strip()
        if not raw: continue
        if '=' in raw:
            parts = raw.split('='); LABELS[parts[0].strip()] = parse_imm(parts[1].strip(), 0, LABELS); continue
        if raw.startswith('.equ'):
            parts = raw.split('.equ')[1].split(','); LABELS[parts[0].strip()] = parse_imm(parts[1].strip(), 0, LABELS); continue
        if ':' in raw:
            label, rest = raw.split(':', 1); LABELS[label.strip()] = pc; raw = rest.strip()
        if raw:
            chunk = assemble_line(raw, pc, LABELS)
            # print(f"PASS1: pc={pc:04X} line='{raw}' len={len(chunk)}")
            pc += len(chunk)
    
    binary = b""; pc = base
    for line in lines:
        raw = re.sub(r'#.*', '', line).strip()
        if not raw or '=' in raw or raw.startswith('.equ'): continue
        if ':' in raw: raw = raw.split(':', 1)[1].strip()
        if raw:
            chunk = assemble_line(raw, pc, LABELS)
            binary += chunk; pc += len(chunk)
    with open(dst, 'wb') as f: f.write(binary)
    return len(binary)

if __name__ == '__main__':
    if len(sys.argv) < 3: sys.exit(1)
    base = int(sys.argv[3], 0) if len(sys.argv) > 3 else 0
    sz = assemble(sys.argv[1], sys.argv[2], base)
    print(f"Success! Generated {sz} bytes at base {hex(base)}")
