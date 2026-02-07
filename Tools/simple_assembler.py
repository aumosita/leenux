#!/usr/bin/env python3
"""
Simple RISC-V 64I Assembler
Converts RISC-V assembly to binary format for the emulator
"""

import sys
import re
import struct

def encode_r_type(opcode, rd, funct3, rs1, rs2, funct7):
    """Encode R-type instruction"""
    instr = (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode
    return struct.pack('<I', instr)

def encode_i_type(opcode, rd, funct3, rs1, imm):
    """Encode I-type instruction"""
    if imm < 0:
        imm = (1 << 12) + imm
    imm = imm & 0xFFF
    instr = (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode
    return struct.pack('<I', instr)

def encode_s_type(opcode, funct3, rs1, rs2, imm):
    """Encode S-type instruction"""
    imm = imm & 0xFFF
    imm_11_5 = (imm >> 5) & 0x7F
    imm_4_0 = imm & 0x1F
    instr = (imm_11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm_4_0 << 7) | opcode
    return struct.pack('<I', instr)

def encode_b_type(opcode, funct3, rs1, rs2, imm):
    """Encode B-type instruction"""
    imm = imm & 0x1FFF
    imm_12 = (imm >> 12) & 1
    imm_11 = (imm >> 11) & 1
    imm_10_5 = (imm >> 5) & 0x3F
    imm_4_1 = (imm >> 1) & 0xF
    instr = (imm_12 << 31) | (imm_10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm_4_1 << 8) | (imm_11 << 7) | opcode
    return struct.pack('<I', instr)

def encode_u_type(opcode, rd, imm):
    """Encode U-type instruction"""
    imm = imm & 0xFFFFF000
    instr = imm | (rd << 7) | opcode
    return struct.pack('<I', instr)

def encode_j_type(opcode, rd, imm):
    """Encode J-type instruction"""
    imm = imm & 0x1FFFFF
    imm_20 = (imm >> 20) & 1
    imm_10_1 = (imm >> 1) & 0x3FF
    imm_11 = (imm >> 11) & 1
    imm_19_12 = (imm >> 12) & 0xFF
    instr = (imm_20 << 31) | (imm_10_1 << 21) | (imm_11 << 20) | (imm_19_12 << 12) | (rd << 7) | opcode
    return struct.pack('<I', instr)

def parse_register(reg_str):
    """Parse register name to number"""
    reg_str = reg_str.strip().lower()
    
    aliases = {
        'zero': 0, 'ra': 1, 'sp': 2, 'gp': 3, 'tp': 4,
        't0': 5, 't1': 6, 't2': 7,
        's0': 8, 'fp': 8, 's1': 9,
        'a0': 10, 'a1': 11, 'a2': 12, 'a3': 13, 'a4': 14, 'a5': 15, 'a6': 16, 'a7': 17,
        's2': 18, 's3': 19, 's4': 20, 's5': 21, 's6': 22, 's7': 23, 's8': 24, 's9': 25, 's10': 26, 's11': 27,
        't3': 28, 't4': 29, 't5': 30, 't6': 31
    }
    
    if reg_str in aliases:
        return aliases[reg_str]
    
    if reg_str.startswith('x'):
        try: return int(reg_str[1:])
        except: pass
            
    if reg_str.startswith('f'):
         try: return int(reg_str[1:])
         except: pass
    
    raise ValueError(f"Invalid register: {reg_str}")

def parse_csr(csr_str):
    """Parse CSR name to number"""
    csr_str = csr_str.strip().lower()
    
    aliases = {
        'mstatus': 0x300, 'mie': 0x304, 'mtvec': 0x305, 'mscratch': 0x340,
        'mepc': 0x341, 'mcause': 0x342, 'mtval': 0x343, 'mip': 0x344,
        'sstatus': 0x100, 'sie': 0x104, 'stvec': 0x105, 'scause': 0x142,
        'stval': 0x143, 'sip': 0x144, 'satp': 0x180,
        'pmpcfg0': 0x3A0, 'pmpaddr0': 0x3B0,
        'cycle': 0xC00, 'time': 0xC01, 'instret': 0xC02
    }
    
    if csr_str in aliases:
        return aliases[csr_str]
        
    try:
        return int(csr_str, 16) if csr_str.startswith('0x') else int(csr_str)
    except:
        raise ValueError(f"Invalid CSR: {csr_str}")

def encode_system_type(opcode, rd, funct3, rs1, csr):
    """Encode System type instruction (CSRs)"""
    csr = csr & 0xFFF
    instr = (csr << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode
    return struct.pack('<I', instr)

def parse_immediate(imm_str, pc=0, labels=None):
    """Parse immediate value"""
    imm_str = imm_str.strip()
    
    # Handle %hi() an %lo()
    is_hi = False
    is_lo = False
    
    if imm_str.startswith('%hi(') and imm_str.endswith(')'):
        imm_str = imm_str[4:-1]
        is_hi = True
    elif imm_str.startswith('%lo(') and imm_str.endswith(')'):
        imm_str = imm_str[4:-1]
        is_lo = True
        
    val = 0
    if labels and imm_str in labels:
        # For %hi/%lo, we usually want ABSOLUTE value if it's a constant
        # If it's a label address, we subtract pc?
        # Standard RISC-V: %hi(sym) uses absolute address. 
        # PC-relative is usually implicit in auipc.
        # But 'labels' contains offsets relative to 0.
        # If instruction is 'lui', it expects immediate.
        # So we use label value directly.
        val = labels[imm_str]
        # BUT if it's not %hi/%lo, normal behavior is relative?
        # Check usage: 'beq t0, t1, label'. Here we need relative.
        # 'li t0, label'. Here we need absolute (handled by parse_immediate(..., 0, labels)).
        # If caller passes pc != 0, it asks for relative.
        # If %hi/%lo is used, it overrides relative? usually yes.
        if not (is_hi or is_lo) and pc != 0:
             val -= pc
    elif imm_str.startswith('0x'):
        val = int(imm_str, 16)
    else:
        try:
            val = int(imm_str)
        except:
            if labels is None: return 0 
            raise ValueError(f"Unknown label or immediate: {imm_str}")
            
    if is_hi:
        return (val + 0x800) >> 12
    if is_lo:
        # Sign extend 12-bit
        # Standard %lo: (val) & 0xFFF.
        # But for addi used with lui, we need to compensate if bit 11 is 1.
        # Our assembler's 'la' pseudo does this manually:
        # lo = val - (hi << 12).
        # THIS implicitly handles the sign.
        # If user writes: lui ... %hi(sym); addi ... %lo(sym).
        # We must ensure %lo returns the same compensated value.
        hi = (val + 0x800) >> 12
        return val - (hi << 12)
        
    return val

def get_instruction_size(line, pc):
    """Estimate size of instruction in bytes. Needs PC for alignment."""
    line = re.sub(r'#.*', '', line).strip()
    if not line: return 0
    if ':' in line: return 0 # Handled in loop
    if '=' in line: return 0

    if line.startswith('.'):
        if line.startswith('.float'):
             return 4 * len(line.split('.float')[1].replace(',', ' ').split())
        elif line.startswith('.word'):
             return 4 * len(line.split('.word')[1].replace(',', ' ').split())
        elif line.startswith('.byte'):
             rest = line.split('.byte')[1].strip()
             if "'" in rest or '"' in rest:
                 count = 0; in_q = False
                 for c in rest:
                     if c in "'\"": in_q = not in_q
                     elif in_q: count += 1
                 return count
             return len(rest.replace(',', ' ').split())
        elif line.startswith('.asciz'):
             rest = line.split('.asciz')[1].strip()
             count = 0; in_q = False
             for c in rest:
                 if c in "'\"": in_q = not in_q
                 elif in_q: count += 1
             return count + 1
        elif line.startswith('.space'):
             try: return int(line.split()[1])
             except: return 0
        elif line.startswith('.align') or line.startswith('.balign'):
             try:
                 align_pow = int(line.split()[1])
                 # If .align X where X is power of 2? Or byte alignment?
                 # GNU as: .align 2 = 2^2 = 4 bytes.
                 # But some use .align 4 = 4 bytes.
                 # We assume BYTES for simplicity (RISC-V convention often varies).
                 # Detailed check: RISC-V as defaults to power of 2?
                 # Let's assume bytes. If I write .align 4, I mean 4 bytes.
                 alignment = align_pow 
                 if alignment == 0: return 0
                 padding = (alignment - (pc % alignment)) % alignment
                 return padding
             except: return 0
                 
        return 0

    parts = re.split(r'[,\s()]+', line)
    mnemonic = parts[0].lower()
    
    if mnemonic == 'la': return 8
    
    if mnemonic == 'li':
        try:
            val_str = parts[2]
            if val_str.startswith('0x'): val = int(val_str, 16)
            else: val = int(val_str)
            if -2048 <= val <= 2047: return 4
            return 8
        except:
            return 8 # Symbol or error -> 8 bytes
            
    return 4 

def assemble_instruction(line, pc, labels):
    """Assemble a single instruction"""
    line = re.sub(r'#.*', '', line).strip()
    if not line: return None
    
    load_store_match = re.match(r'(\w+)\s+(\w+),\s*(-?\d+)\((\w+)\)', line)
    if load_store_match:
        parts = [load_store_match.group(1), load_store_match.group(2), 
                 load_store_match.group(3), load_store_match.group(4)]
    else:
        # Check for relocation functions (%hi, %lo) which contain parens but shouldn't be split
        if '%' in line and '(' in line and ')' in line:
             parts = re.split(r'[,\s]+', line)
        else:
             parts = re.split(r'[,\s()]+', line)
        parts = [p for p in parts if p]
    
    if not parts: return None
    
    mnemonic = parts[0].lower()
    
    # ... R-Type ...
    if mnemonic in ['add', 'sub', 'and', 'or', 'xor', 'sll', 'srl', 'sra', 'slt', 'sltu',
                      'mul', 'mulh', 'mulhsu', 'mulhu', 'div', 'divu', 'rem', 'remu']:
        rd = parse_register(parts[1])
        rs1 = parse_register(parts[2])
        rs2 = parse_register(parts[3])
        
        funct3_map = {'add': 0, 'sub': 0, 'sll': 1, 'slt': 2, 'sltu': 3, 'xor': 4, 'srl': 5, 'sra': 5, 'or': 6, 'and': 7,
                      'mul': 0, 'mulh': 1, 'mulhsu': 2, 'mulhu': 3, 'div': 4, 'divu': 5, 'rem': 6, 'remu': 7}
        funct7_map = {'add': 0, 'sub': 0x20, 'sll': 0, 'slt': 0, 'sltu': 0, 'xor': 0, 'srl': 0, 'sra': 0x20, 'or': 0, 'and': 0,
                      'mul': 1, 'mulh': 1, 'mulhsu': 1, 'mulhu': 1, 'div': 1, 'divu': 1, 'rem': 1, 'remu': 1}
        return encode_r_type(0x33, rd, funct3_map[mnemonic], rs1, rs2, funct7_map[mnemonic])
    
    # ... I-Type ...
    elif mnemonic in ['addi', 'andi', 'ori', 'xori', 'slli', 'srli', 'srai', 'slti', 'sltiu']:
        rd = parse_register(parts[1])
        rs1 = parse_register(parts[2])
        imm = parse_immediate(parts[3], pc, labels)
        funct3_map = {'addi': 0, 'slli': 1, 'slti': 2, 'sltiu': 3, 'xori': 4, 'srli': 5, 'srai': 5, 'ori': 6, 'andi': 7}
        if mnemonic == 'srai': imm = (0x400 | (imm & 0x3F))
        elif mnemonic in ['slli', 'srli']: imm = imm & 0x3F
        return encode_i_type(0x13, rd, funct3_map[mnemonic], rs1, imm)
    
    # ... Load ...
    elif mnemonic in ['ld', 'lw', 'lwu', 'lh', 'lhu', 'lb', 'lbu']:
        rd = parse_register(parts[1])
        if len(parts) >= 4:
            imm = parse_immediate(parts[2], pc, labels)
            rs1 = parse_register(parts[3])
        else:
            imm = parse_immediate(parts[2], pc, labels)
            rs1 = 0
        funct3_map = {'lb': 0, 'lh': 1, 'lw': 2, 'ld': 3, 'lbu': 4, 'lhu': 5, 'lwu': 6}
        return encode_i_type(0x03, rd, funct3_map[mnemonic], rs1, imm)

    # ... Store ...
    elif mnemonic in ['sd', 'sw', 'sh', 'sb']:
        rs2 = parse_register(parts[1])
        if len(parts) >= 4:
            imm = parse_immediate(parts[2], pc, labels)
            rs1 = parse_register(parts[3])
        else:
            imm = parse_immediate(parts[2], pc, labels)
            rs1 = 0
        funct3_map = {'sb': 0, 'sh': 1, 'sw': 2, 'sd': 3}
        return encode_s_type(0x23, funct3_map[mnemonic], rs1, rs2, imm)

    # ... Branch ...
    elif mnemonic in ['beq', 'bne', 'blt', 'bge', 'bltu', 'bgeu']:
        rs1 = parse_register(parts[1])
        rs2 = parse_register(parts[2])
        imm = parse_immediate(parts[3], pc, labels)
        funct3_map = {'beq': 0, 'bne': 1, 'blt': 4, 'bge': 5, 'bltu': 6, 'bgeu': 7}
        return encode_b_type(0x63, funct3_map[mnemonic], rs1, rs2, imm)
    
    # ... Jumps ...
    elif mnemonic == 'jal':
        if len(parts) == 2:
            rd = 1; imm = parse_immediate(parts[1], pc, labels)
        else:
            rd = parse_register(parts[1]); imm = parse_immediate(parts[2], pc, labels)
        return encode_j_type(0x6F, rd, imm)
        
    elif mnemonic == 'ret':
        return encode_i_type(0x67, 0, 0, 1, 0)
        
    elif mnemonic == 'jr':
        # jr rs -> jalr x0, rs, 0
        rs = parse_register(parts[1])
        return encode_i_type(0x67, 0, 0, rs, 0)
        
    elif mnemonic == 'jalr':
        rd = parse_register(parts[1])
        if len(parts) >= 4:
            imm = parse_immediate(parts[2], pc, labels)
            rs1 = parse_register(parts[3])
        else: # jalr rd, rs1
             rs1 = parse_register(parts[2]); imm = 0
        return encode_i_type(0x67, rd, 0, rs1, imm)
        
    elif mnemonic == 'beqz':
        # beqz rs, label -> beq rs, x0, label
        rs1 = parse_register(parts[1])
        imm = parse_immediate(parts[2], pc, labels)
        return encode_b_type(0x63, 0, rs1, 0, imm)
        
    elif mnemonic == 'bnez':
        # bnez rs, label -> bne rs, x0, label
        rs1 = parse_register(parts[1])
        imm = parse_immediate(parts[2], pc, labels)
        return encode_b_type(0x63, 1, rs1, 0, imm)
        
    elif mnemonic == 'blez':
        # blez rs, label -> bge x0, rs, label
        rs1 = parse_register(parts[1])
        imm = parse_immediate(parts[2], pc, labels)
        return encode_b_type(0x63, 5, 0, rs1, imm)
        
    elif mnemonic == 'bgez':
        # bgez rs, label -> bge rs, x0, label
        rs1 = parse_register(parts[1])
        imm = parse_immediate(parts[2], pc, labels)
        return encode_b_type(0x63, 5, rs1, 0, imm)
        
    elif mnemonic == 'bltz':
        # bltz rs, label -> blt rs, x0, label
        rs1 = parse_register(parts[1])
        imm = parse_immediate(parts[2], pc, labels)
        return encode_b_type(0x63, 4, rs1, 0, imm)
        
    elif mnemonic == 'bgtz':
        # bgtz rs, label -> blt x0, rs, label
        rs1 = parse_register(parts[1])
        imm = parse_immediate(parts[2], pc, labels)
        return encode_b_type(0x63, 4, 0, rs1, imm)
        
    elif mnemonic == 'call':
        if len(parts) > 1:
            imm = parse_immediate(parts[1], pc, labels)
            return encode_j_type(0x6F, 1, imm)

    # ... Pseudo ...
    elif mnemonic == 'la':
        rd = parse_register(parts[1])
        val = parse_immediate(parts[2], 0, labels) # Absolute value
        hi = (val + 0x800) >> 12
        lo = val - (hi << 12)
        instr1 = encode_u_type(0x37, rd, hi) # lui
        instr2 = encode_i_type(0x13, rd, 0, rd, lo) # addi
        return instr1 + instr2
        
    elif mnemonic == 'li':
        rd = parse_register(parts[1])
        val = parse_immediate(parts[2], 0, labels) # Absolute
        
        # Check if immediate string is a literal number
        # We must match Pass 1 logic: if it's a symbol, Pass 1 assumes 8 bytes.
        # So Pass 2 must emit 8 bytes even if value is small.
        raw_imm = parts[2].strip()
        is_literal = False
        try:
            if raw_imm.startswith('0x'): int(raw_imm, 16)
            else: int(raw_imm)
            is_literal = True
        except:
            is_literal = False
            
        if is_literal and (-2048 <= val <= 2047):
            return encode_i_type(0x13, rd, 0, 0, val)
        else:
            # Force 8 bytes (lui + addi) for symbols or large values
            hi = (val + 0x800) >> 12
            lo = val - (hi << 12)
            instr1 = encode_u_type(0x37, rd, hi)
            instr2 = encode_i_type(0x13, rd, 0, rd, lo)
            return instr1 + instr2
            
    elif mnemonic == 'mv':
        rd = parse_register(parts[1]); rs = parse_register(parts[2])
        return encode_i_type(0x13, rd, 0, rs, 0)
        
    elif mnemonic == 'neg':
        # neg rd, rs -> sub rd, x0, rs
        rd = parse_register(parts[1]); rs = parse_register(parts[2])
        return encode_r_type(0x33, rd, 0, 0, rs, 0x20)
        
    elif mnemonic == 'not':
        # not rd, rs -> xori rd, rs, -1
        rd = parse_register(parts[1]); rs = parse_register(parts[2])
        return encode_i_type(0x13, rd, 4, rs, -1)
        
    elif mnemonic == 'nop':
        return encode_i_type(0x13, 0, 0, 0, 0)
        
    elif mnemonic == 'lui':
        rd = parse_register(parts[1])
        imm = parse_immediate(parts[2], pc, labels) << 12
        return encode_u_type(0x37, rd, imm)

    elif mnemonic == 'auipc':
        rd = parse_register(parts[1])
        imm = parse_immediate(parts[2], pc, labels) << 12
        return encode_u_type(0x17, rd, imm)
        
    elif mnemonic in ['csrrw', 'csrrs', 'csrrc']:
        rd = parse_register(parts[1])
        csr = parse_csr(parts[2])
        rs1 = parse_register(parts[3])
        funct3_map = {'csrrw': 1, 'csrrs': 2, 'csrrc': 3}
        return encode_system_type(0x73, rd, funct3_map[mnemonic], rs1, csr)
        
    elif mnemonic == 'csrr':
        rd = parse_register(parts[1]); csr = parse_csr(parts[2])
        return encode_system_type(0x73, rd, 2, 0, csr)
    elif mnemonic == 'csrw':
        csr = parse_csr(parts[1]); rs = parse_register(parts[2])
        return encode_system_type(0x73, 0, 1, rs, csr)
    elif mnemonic == 'csrs':
        csr = parse_csr(parts[1]); rs = parse_register(parts[2])
        return encode_system_type(0x73, 0, 2, rs, csr)
    elif mnemonic == 'csrc':
        csr = parse_csr(parts[1]); rs = parse_register(parts[2])
        return encode_system_type(0x73, 0, 3, rs, csr)
        
    return None

def assemble(source_file, output_file):
    with open(source_file, 'r') as f:
        lines = f.readlines()
    
    # Pass 1
    labels = {}
    pc = 0
    for line in lines:
        line = re.sub(r'#.*', '', line).strip()
        
        # Check for assignment (Symbol = Value)
        if '=' in line:
            parts = line.split('=')
            if len(parts) == 2:
                name = parts[0].strip(); val_str = parts[1].strip()
                try:
                    val = int(val_str, 16) if val_str.startswith('0x') else int(val_str)
                    labels[name] = val
                    continue
                except: pass
                
        # Check for .equ directive
        if line.startswith('.equ'):
            parts = line.split('.equ')[1].split(',')
            if len(parts) == 2:
                name = parts[0].strip()
                val_str = parts[1].strip()
                try:
                    val = int(val_str, 16) if val_str.startswith('0x') else int(val_str)
                    labels[name] = val
                    continue
                except: pass
                
        if ':' in line:
            parts = line.split(':', 1)
            labels[parts[0].strip()] = pc
            line = parts[1].strip()
        
        if line:
            pc += get_instruction_size(line, pc)

    # Pass 2
    binary = bytearray()
    pc = 0
    for line in lines:
        original = line
        line = re.sub(r'#.*', '', line).strip()
        if ':' in line: line = line.split(':', 1)[1].strip()
        
        if not line: continue
        if '=' in line: continue
        
        if line.startswith('.'):
             if line.startswith('.word') or line.startswith('.float') or line.startswith('.byte') or line.startswith('.asciz') or line.startswith('.space') or line.startswith('.align') or line.startswith('.balign'):
                 # Reconstruct binary
                 if line.startswith('.asciz'):
                     rest = line.split('.asciz')[1].strip()
                     in_q = False
                     for c in rest:
                         if c in "'\"": in_q = not in_q; continue
                         if in_q: binary.append(ord(c)); pc+=1
                     binary.append(0); pc+=1
                 elif line.startswith('.byte'):
                     rest = line.split('.byte')[1].strip()
                     if "'" in rest or '"' in rest:
                         in_q = False
                         for c in rest:
                             if c in "'\"": in_q = not in_q; continue
                             if in_q: binary.append(ord(c)); pc+=1
                     else:
                         for v in re.split(r'[,\s]+', rest):
                             if v: binary.append(int(v, 0)); pc+=1
                 elif line.startswith('.word'):
                      for v in re.split(r'[,\s]+', line.split('.word')[1]): 
                          if v: binary.extend(struct.pack('<i', int(v, 0))); pc+=4
                 elif line.startswith('.space'):
                      try: count = int(line.split()[1]); binary.extend(bytes(count)); pc+=count
                      except: pass
                 elif line.startswith('.align') or line.startswith('.balign'):
                      try:
                          align = int(line.split()[1])
                          if align > 0:
                              padding = (align - (pc % align)) % align
                              binary.extend(bytes(padding))
                              pc += padding
                      except: pass
             continue
             
        try:
            ib = assemble_instruction(line, pc, labels)
            if ib: binary.extend(ib); pc += len(ib)
        except Exception as e:
            print(f"Error assembling: {original.strip()} -> {e}", file=sys.stderr)
            sys.exit(1)
            
    with open(output_file, 'wb') as f: f.write(binary)
    return len(binary)

if __name__ == '__main__':
    if len(sys.argv) != 3: sys.exit(1)
    try:
        sz = assemble(sys.argv[1], sys.argv[2])
        print(f"Success! Generated {sz} bytes")
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr); sys.exit(1)
