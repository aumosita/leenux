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
    
    # Handle aliases
    aliases = {
        'zero': 0, 'ra': 1, 'sp': 2, 'gp': 3, 'tp': 4,
        't0': 5, 't1': 6, 't2': 7,
        's0': 8, 'fp': 8, 's1': 9,
        'a0': 10, 'a1': 11, 'a2': 12, 'a3': 13, 'a4': 14, 'a5': 15, 'a6': 16, 'a7': 17,
        's2': 18, 's3': 19, 's4': 20, 's5': 21, 's6': 22, 's7': 23, 's8': 24, 's9': 25, 's10': 26, 's11': 27,
        't3': 28, 't4': 29, 't5': 30, 't6': 31,
        # Floating point aliases
        'ft0': 0, 'ft1': 1, 'ft2': 2, 'ft3': 3, 'ft4': 4, 'ft5': 5, 'ft6': 6, 'ft7': 7,
        'fs0': 8, 'fs1': 9,
        'fa0': 10, 'fa1': 11, 'fa2': 12, 'fa3': 13, 'fa4': 14, 'fa5': 15, 'fa6': 16, 'fa7': 17,
        'fs2': 18, 'fs3': 19, 'fs4': 20, 'fs5': 21, 'fs6': 22, 'fs7': 23, 'fs8': 24, 'fs9': 25, 'fs10': 26, 'fs11': 27,
        'ft8': 28, 'ft9': 29, 'ft10': 30, 'ft11': 31
    }
    
    if reg_str in aliases:
        return aliases[reg_str]
    
    # Handle x notation
    if reg_str.startswith('x'):
        try:
            return int(reg_str[1:])
        except:
            pass
            
    # Handle f notation
    if reg_str.startswith('f'):
        try:
            return int(reg_str[1:])
        except:
            pass
    
    raise ValueError(f"Invalid register: {reg_str}")

def parse_immediate(imm_str, pc=0, labels=None):
    """Parse immediate value"""
    imm_str = imm_str.strip()
    
    # Check for labels
    if labels and imm_str in labels:
        return labels[imm_str] - pc
    
    # Parse hex
    if imm_str.startswith('0x'):
        return int(imm_str, 16)
    
    # Parse decimal
    try:
        return int(imm_str)
    except:
        # If it's a label reference that we don't know yet, return 0
        return 0

def assemble_instruction(line, pc, labels):
    """Assemble a single instruction"""
    # Remove comments
    line = re.sub(r'#.*', '', line).strip()
    if not line:
        return None
    
    # Handle offset(register) format for loads/stores
    # Convert "ld x1, 8(x2)" to parts: ['ld', 'x1', '8', 'x2']
    load_store_match = re.match(r'(\w+)\s+(\w+),\s*(-?\d+)\((\w+)\)', line)
    if load_store_match:
        parts = [load_store_match.group(1), load_store_match.group(2), 
                 load_store_match.group(3), load_store_match.group(4)]
    else:
        parts = re.split(r'[,\s()]+', line)
        parts = [p for p in parts if p]
    
    if not parts:
        return None
    
    mnemonic = parts[0].lower()
    
    # R-type instructions
    if mnemonic in ['add', 'sub', 'and', 'or', 'xor', 'sll', 'srl', 'sra', 'slt', 'sltu',
                     'mul', 'mulh', 'mulhsu', 'mulhu', 'div', 'divu', 'rem', 'remu']:
        rd = parse_register(parts[1])
        rs1 = parse_register(parts[2])
        rs2 = parse_register(parts[3])
        
        funct3_map = {
            'add': 0, 'sub': 0, 'sll': 1, 'slt': 2, 'sltu': 3, 
            'xor': 4, 'srl': 5, 'sra': 5, 'or': 6, 'and': 7,
            # M extension
            'mul': 0, 'mulh': 1, 'mulhsu': 2, 'mulhu': 3,
            'div': 4, 'divu': 5, 'rem': 6, 'remu': 7
        }
        funct7_map = {
            'add': 0, 'sub': 0x20, 'sll': 0, 'slt': 0, 'sltu': 0, 
            'xor': 0, 'srl': 0, 'sra': 0x20, 'or': 0, 'and': 0,
            # M extension (funct7 = 0x01)
            'mul': 0x01, 'mulh': 0x01, 'mulhsu': 0x01, 'mulhu': 0x01,
            'div': 0x01, 'divu': 0x01, 'rem': 0x01, 'remu': 0x01
        }
        
        return encode_r_type(0x33, rd, funct3_map[mnemonic], rs1, rs2, funct7_map[mnemonic])
    
    # I-type arithmetic instructions
    elif mnemonic in ['addi', 'andi', 'ori', 'xori', 'slli', 'srli', 'srai', 'slti', 'sltiu']:
        rd = parse_register(parts[1])
        rs1 = parse_register(parts[2])
        imm = parse_immediate(parts[3], pc, labels)
        
        funct3_map = {'addi': 0, 'slli': 1, 'slti': 2, 'sltiu': 3, 'xori': 4, 'srli': 5, 'srai': 5, 'ori': 6, 'andi': 7}
        
        # For shifts, encode funct7 in upper bits
        if mnemonic == 'srai':
            imm = (0x400 | (imm & 0x3F))
        elif mnemonic in ['slli', 'srli']:
            imm = imm & 0x3F
        
        return encode_i_type(0x13, rd, funct3_map[mnemonic], rs1, imm)
    
    # Load instructions (Integer & Float)
    elif mnemonic in ['ld', 'lw', 'lwu', 'lh', 'lhu', 'lb', 'lbu', 'flw', 'fld']:
        rd = parse_register(parts[1])
        # Parts are now: ['ld', 'x1', '8', 'x2'] for "ld x1, 8(x2)"
        if len(parts) >= 4:
            imm = parse_immediate(parts[2], pc, labels)
            rs1 = parse_register(parts[3])
        elif len(parts) == 3:
            imm = parse_immediate(parts[2], pc, labels)
            rs1 = 0  # x0
        else:
            imm = 0
            rs1 = parse_register(parts[2])
        
        if mnemonic in ['flw', 'fld']:
            opcode = 0x07
            funct3_map = {'flw': 2, 'fld': 3}
        else:
            opcode = 0x03
            funct3_map = {'lb': 0, 'lh': 1, 'lw': 2, 'ld': 3, 'lbu': 4, 'lhu': 5, 'lwu': 6}
            
        return encode_i_type(opcode, rd, funct3_map[mnemonic], rs1, imm)
    
    # Store instructions (Integer & Float)
    elif mnemonic in ['sd', 'sw', 'sh', 'sb', 'fsw', 'fsd']:
        rs2 = parse_register(parts[1])
        # Parts are now: ['sd', 'x1', '8', 'x2'] for "sd x1, 8(x2)"
        if len(parts) >= 4:
            imm = parse_immediate(parts[2], pc, labels)
            rs1 = parse_register(parts[3])
        elif len(parts) == 3:
            imm = parse_immediate(parts[2], pc, labels)
            rs1 = 0  # x0
        else:
            imm = 0
            rs1 = parse_register(parts[2])
        
        if mnemonic in ['fsw', 'fsd']:
            opcode = 0x27
            funct3_map = {'fsw': 2, 'fsd': 3}
        else:
            opcode = 0x23
            funct3_map = {'sb': 0, 'sh': 1, 'sw': 2, 'sd': 3}
            
        return encode_s_type(opcode, funct3_map[mnemonic], rs1, rs2, imm)
        
    # R-type Floating Point Operations
    elif mnemonic in ['fadd.s', 'fsub.s', 'fmul.s', 'fdiv.s', 'fsqrt.s', 'fsgnj.s', 'fsgnjn.s', 'fsgnjx.s',
                      'fmin.s', 'fmax.s', 'feq.s', 'flt.s', 'fle.s', 'fcvt.w.s', 'fcvt.wu.s', 'fcvt.s.w',
                      'fcvt.s.wu', 'fmv.x.w', 'fmv.w.x',
                      'fadd.d', 'fsub.d', 'fmul.d', 'fdiv.d', 'fsqrt.d', 'fsgnj.d', 'fsgnjn.d', 'fsgnjx.d',
                      'fmin.d', 'fmax.d', 'feq.d', 'flt.d', 'fle.d', 'fcvt.w.d', 'fcvt.wu.d', 'fcvt.d.w',
                      'fcvt.d.wu', 'fmv.x.d', 'fmv.d.x', 'fcvt.s.d', 'fcvt.d.s']:
        rd = parse_register(parts[1])
        rs1 = parse_register(parts[2])
        if len(parts) > 3:
            rs2 = parse_register(parts[3])
        else:
            rs2 = 0 # For single operand instructions like fsqrt
            
        funct3 = 0  # Rounding Mode: RNE (0) as default
        
        # Base funct7 values
        # Add .d versions by adding 0x01 if needed (but handled individually for safety)
        
        f7_map = {
            'fadd.s': 0x00, 'fsub.s': 0x04, 'fmul.s': 0x08, 'fdiv.s': 0x0C, 'fsqrt.s': 0x2C,
            'fsgnj.s': 0x10, 'fsgnjn.s': 0x10, 'fsgnjx.s': 0x10,
            'fmin.s': 0x14, 'fmax.s': 0x14,
            'feq.s': 0x50, 'flt.s': 0x50, 'fle.s': 0x50,
            'fcvt.w.s': 0x60, 'fcvt.wu.s': 0x60,
            'fcvt.s.w': 0x68, 'fcvt.s.wu': 0x68,
            'fmv.x.w': 0x70, 'fmv.w.x': 0x78,
            
            # Double precision (usually single + 1, but verifying)
            'fadd.d': 0x01, 'fsub.d': 0x05, 'fmul.d': 0x09, 'fdiv.d': 0x0D, 'fsqrt.d': 0x2D,
            'fsgnj.d': 0x11, 'fsgnjn.d': 0x11, 'fsgnjx.d': 0x11,
            'fmin.d': 0x15, 'fmax.d': 0x15,
            'feq.d': 0x51, 'flt.d': 0x51, 'fle.d': 0x51,
            'fcvt.w.d': 0x61, 'fcvt.wu.d': 0x61,
            'fcvt.d.w': 0x69, 'fcvt.d.wu': 0x69,
            'fmv.x.d': 0x71, 'fmv.d.x': 0x79,
            'fcvt.s.d': 0x20, 'fcvt.d.s': 0x21
        }
        
        # Adjust assignments for special cases
        if mnemonic in ['fsgnjn.s', 'fsgnjn.d', 'fmax.s', 'fmax.d', 'flt.s', 'flt.d', 'fcvt.wu.s', 'fcvt.wu.d', 'fcvt.s.wu', 'fcvt.d.wu']:
            funct3 = 1
        elif mnemonic in ['fsgnjx.s', 'fsgnjx.d', 'feq.s', 'feq.d', 'flw', 'fsw']: # wait flw/fsw handled above
            funct3 = 2
            
        # rs2 special cases for conversion/move
        if mnemonic in ['fcvt.w.s', 'fcvt.wu.s', 'fcvt.w.d', 'fcvt.wu.d', 'fcvt.l.s', 'fcvt.lu.s', 'fcvt.l.d', 'fcvt.lu.d', 'fmv.x.w', 'fmv.x.d']:
            # rs2 is 0 or 1 based on signed/unsigned but map handles opcode. 
            # Actually rs2 field is often used for aux info (like W/L in some archs, but here it's 0/1/2/3 in rs2 field for conversions?)
            # Wait, RISC-V spec:
            # FCVT.W.S: rs2=0
            # FCVT.WU.S: rs2=1
            # I handled this with rs2 parse, but these instructions take 2 args: rd, rs1.
            # So parts will be longer than 3? No, "fcvt.w.s rd, rs1".
            # My generic parser sets rs2=0 if not present.
            pass

        # Override rs2 for specific instructions if it was set to 0 by default but needs to be something else?
        # FCVT.WU.S: rs2 field acts as w/wu selector? No, opcode is the same.
        # Opcode 0x53, flt.s vs feq.s is distinguished by funct3.
        # fcvt.w.s vs fcvt.wu.s is distinguished by rs2 field.
        
        if mnemonic == 'fcvt.wu.s' or mnemonic == 'fcvt.wu.d' or mnemonic == 'fcvt.s.wu' or mnemonic == 'fcvt.d.wu':
             rs2 = 1
             
        return encode_r_type(0x53, rd, funct3, rs1, rs2, f7_map[mnemonic])

    
    # Branch instructions
    elif mnemonic in ['beq', 'bne', 'blt', 'bge', 'bltu', 'bgeu']:
        rs1 = parse_register(parts[1])
        rs2 = parse_register(parts[2])
        imm = parse_immediate(parts[3], pc, labels)
        
        funct3_map = {'beq': 0, 'bne': 1, 'blt': 4, 'bge': 5, 'bltu': 6, 'bgeu': 7}
        return encode_b_type(0x63, funct3_map[mnemonic], rs1, rs2, imm)
    
    # JAL
    elif mnemonic == 'jal':
        if len(parts) == 2:
            rd = 1  # Default to ra
            imm = parse_immediate(parts[1], pc, labels)
        else:
            rd = parse_register(parts[1])
            imm = parse_immediate(parts[2], pc, labels)
        return encode_j_type(0x6F, rd, imm)
    
    # J pseudo-instruction (jal x0, offset)
    elif mnemonic == 'j':
        imm = parse_immediate(parts[1], pc, labels)
        return encode_j_type(0x6F, 0, imm)
    
    # JALR
    elif mnemonic == 'jalr':
        rd = parse_register(parts[1])
        # Handle jalr x0, 0(x1) format
        if len(parts) >= 4:
            imm = parse_immediate(parts[2], pc, labels)
            rs1 = parse_register(parts[3])
        elif len(parts) == 3:
            # Could be: jalr rd, rs1 (no offset) or jalr rd, offset
            try:
                # Try to parse as offset
                imm = parse_immediate(parts[2], pc, labels)
                rs1 = 0
            except:
                # Parse as rs1
                imm = 0
                rs1 = parse_register(parts[2])
        else:
            imm = 0
            rs1 = parse_register(parts[2])
        return encode_i_type(0x67, rd, 0, rs1, imm)
    
    # LUI
    elif mnemonic == 'lui':
        rd = parse_register(parts[1])
        imm = parse_immediate(parts[2], pc, labels) << 12
        return encode_u_type(0x37, rd, imm)
    
    # AUIPC
    elif mnemonic == 'auipc':
        rd = parse_register(parts[1])
        imm = parse_immediate(parts[2], pc, labels) << 12
        return encode_u_type(0x17, rd, imm)
    
    # EBREAK
    elif mnemonic == 'ebreak':
        return encode_i_type(0x73, 0, 0, 0, 1)
    
    # ECALL
    elif mnemonic == 'ecall':
        return encode_i_type(0x73, 0, 0, 0, 0)
    
    return None

def assemble(source_file, output_file):
    """Assemble a RISC-V assembly file"""
    with open(source_file, 'r') as f:
        lines = f.readlines()
    
    # First pass: find labels
    labels = {}
    pc = 0
    
    for line in lines:
        line = re.sub(r'#.*', '', line).strip()
        
        # Check for label
        if ':' in line:
            label_parts = line.split(':', 1)
            label_name = label_parts[0].strip()
            
            # Skip verify if it looks like a directive unless it's a data label
            if not label_name.startswith('.'):
                labels[label_name] = pc
                
            rest = label_parts[1].strip()
            if rest:
                if rest.startswith('.float'):
                    pc += 4 * len(rest.split('.float')[1].replace(',', ' ').split())
                elif rest.startswith('.word'):
                    pc += 4 * len(rest.split('.word')[1].replace(',', ' ').split())
                elif rest.startswith('.'):
                    pass # Other directives don't advance PC (e.g. .globl)
                else:
                    pc += 4
        elif line.startswith('.float'):
             pc += 4 * len(line.split('.float')[1].replace(',', ' ').split())
        elif line.startswith('.word'):
             pc += 4 * len(line.split('.word')[1].replace(',', ' ').split())
        elif line.startswith('.byte'):
             # Count bytes (characters in quotes or comma-separated values)
             rest = line.split('.byte')[1].strip()
             # Handle both quoted strings and comma-separated values
             if "'" in rest or '"' in rest:
                 # Count characters in quotes
                 in_quotes = False
                 for char in rest:
                     if char in ("'", '"'):
                         in_quotes = not in_quotes
                     elif in_quotes:
                         pc += 1
             else:
                 # Count comma-separated values
                 values = rest.replace(',', ' ').split()
                 pc += len([v for v in values if v])
        elif line and not line.startswith('.'):
             pc += 4
    
    # Second pass: generate code
    binary = bytearray()
    pc = 0
    
    for line in lines:
        original_line = line
        line = re.sub(r'#.*', '', line).strip()
        
        # Handle directives
        if line.startswith('.'):
            if line.startswith('.float') or line.startswith('.word'):
                parts = re.split(r'[,\s]+', line)
                directive = parts[0]
                values = parts[1:]
                
                for val_str in values:
                    if not val_str: continue
                    if directive == '.float':
                        try:
                            f_val = float(val_str)
                            # Pack float as 4 bytes (IEEE 754 single precision)
                            binary.extend(struct.pack('<f', f_val))
                            pc += 4
                        except:
                            print(f"Warning: Invalid float: {val_str}", file=sys.stderr)
                    elif directive == '.word':
                        try:
                            # Handle hex or decimal
                            if val_str.startswith('0x'):
                                i_val = int(val_str, 16)
                            else:
                                i_val = int(val_str)
                            binary.extend(struct.pack('<i', i_val))
                            pc += 4
                        except:
                             print(f"Warning: Invalid word: {val_str}", file=sys.stderr)
            elif line.startswith('.byte'):
                # Handle .byte directive
                rest = line.split('.byte')[1].strip()
                
                # Handle both quoted strings and comma-separated values
                if "'" in rest or '"' in rest:
                    # Parse quoted string
                    in_quotes = False
                    current_quote = None
                    for char in rest:
                        if char in ("'", '"'):
                            if not in_quotes:
                                in_quotes = True
                                current_quote = char
                            elif char == current_quote:
                                in_quotes = False
                                current_quote = None
                        elif in_quotes:
                            binary.append(ord(char))
                            pc += 1
                else:
                    # Parse comma-separated numeric values
                    values = re.split(r'[,\s]+', rest)
                    for val_str in values:
                        if not val_str:
                            continue
                        try:
                            if val_str.startswith('0x'):
                                byte_val = int(val_str, 16) & 0xFF
                            else:
                                byte_val = int(val_str) & 0xFF
                            binary.append(byte_val)
                            pc += 1
                        except ValueError:
                            print(f"Warning: Invalid byte value: {val_str}", file=sys.stderr)
            continue
        
        # Skip labels (but process instruction on same line)
        if ':' in line:
            parts = line.split(':', 1)
            if len(parts) > 1:
                line = parts[1].strip()
            else:
                continue
        
        if not line:
            continue
        
        try:
            instr_bytes = assemble_instruction(line, pc, labels)
            if instr_bytes:
                binary.extend(instr_bytes)
                pc += 4
        except Exception as e:
            print(f"Error assembling line: {original_line.strip()}", file=sys.stderr)
            print(f"  Error: {e}", file=sys.stderr)
    
    # Write binary file
    with open(output_file, 'wb') as f:
        f.write(binary)
    
    print(f"Assembled {len(binary)} bytes to {output_file}")
    return len(binary)

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python3 simple_assembler.py <input.s> <output.bin>")
        sys.exit(1)
    
    source = sys.argv[1]
    output = sys.argv[2]
    
    try:
        size = assemble(source, output)
        print(f"Success! Generated {size} bytes")
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
