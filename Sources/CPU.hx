package;

import haxe.ds.Vector;


/**
 * ...
 * @author Krtolica Vujadin
 */
// ported from vNES
class CPU {
	
	public static inline var CPU_FREQ_NTSC:Float = 1789772.5;
	public static inline var CPU_FREQ_PAL:Float = 1773447.4;
	
	public static inline var IRQ_NORMAL:Int = 0;
    public static inline var IRQ_NMI:Int = 1;
    public static inline var IRQ_RESET:Int = 2;
	
	static var cycTable:Array<Int> = [
		/*0x00*/ 7,6,2,8,3,3,5,5,3,2,2,2,4,4,6,6,
		/*0x10*/ 2,5,2,8,4,4,6,6,2,4,2,7,4,4,7,7,
		/*0x20*/ 6,6,2,8,3,3,5,5,4,2,2,2,4,4,6,6,
		/*0x30*/ 2,5,2,8,4,4,6,6,2,4,2,7,4,4,7,7,
		/*0x40*/ 6,6,2,8,3,3,5,5,3,2,2,2,3,4,6,6,
		/*0x50*/ 2,5,2,8,4,4,6,6,2,4,2,7,4,4,7,7,
		/*0x60*/ 6,6,2,8,3,3,5,5,4,2,2,2,5,4,6,6,
		/*0x70*/ 2,5,2,8,4,4,6,6,2,4,2,7,4,4,7,7,
		/*0x80*/ 2,6,2,6,3,3,3,3,2,2,2,2,4,4,4,4,
		/*0x90*/ 2,6,2,6,4,4,4,4,2,5,2,5,5,5,5,5,
		/*0xA0*/ 2,6,2,6,3,3,3,3,2,2,2,2,4,4,4,4,
		/*0xB0*/ 2,5,2,5,4,4,4,4,2,4,2,4,4,4,4,4,
		/*0xC0*/ 2,6,2,8,3,3,5,5,2,2,2,2,4,4,6,6,
		/*0xD0*/ 2,5,2,8,4,4,6,6,2,4,2,7,4,4,7,7,
		/*0xE0*/ 2,6,3,8,3,3,5,5,2,2,2,2,4,4,6,6,
		/*0xF0*/ 2,5,2,8,4,4,6,6,2,4,2,7,4,4,7,7
    ];
	
	static var instname:Array<String> = [
		"ADC", "AND", "ASL", "BCC", "BCS", "BEQ",
		"BIT", "BMI", "BNE", "BPL", "BRK", "BVC",
		"BVS", "CLC", "CLD", "CLI", "CLV", "CMP",
		"CPX", "CPY", "DEC", "DEX", "DEY", "EOR",
		"INC", "INX", "INY", "JMP", "JSR", "LDA",
		"LDX", "LDY", "LSR", "NOP", "ORA", "PHA",
		"PHP", "PLA", "PLP", "ROL", "ROR", "RTI",
		"RTS", "SBC", "SEC", "SED", "SEI", "STA",
		"STX", "STY", "TAX", "TAY", "TSX", "TXA",
		"TXS", "TYA"
	];
	
	static var addrDesc:Array<String> = [
        "Zero Page           ",
        "Relative            ",
        "Implied             ",
        "Absolute            ",
        "Accumulator         ",
        "Immediate           ",
        "Zero Page,X         ",
        "Zero Page,Y         ",
        "Absolute,X          ",
        "Absolute,Y          ",
        "Preindexed Indirect ",
        "Postindexed Indirect",
        "Indirect Absolute   "
    ];
	
	static var opDATA:Map<String, Int> = [
		"INS_ADC" => 0,  "INS_AND" => 1,  "INS_ASL" => 2,
		"INS_BCC" => 3,  "INS_BCS" => 4,  "INS_BEQ" => 5,
		"INS_BIT" => 6,  "INS_BMI" => 7,  "INS_BNE" => 8,
		"INS_BPL" => 9,  "INS_BRK" => 10, "INS_BVC" => 11,
		"INS_BVS" => 12, "INS_CLC" => 13, "INS_CLD" => 14,
		"INS_CLI" => 15, "INS_CLV" => 16, "INS_CMP" => 17,
		"INS_CPX" => 18, "INS_CPY" => 19, "INS_DEC" => 20,
		"INS_DEX" => 21, "INS_DEY" => 22, "INS_EOR" => 23,
		"INS_INC" => 24, "INS_INX" => 25, "INS_INY" => 26,
		"INS_JMP" => 27, "INS_JSR" => 28, "INS_LDA" => 29,
		"INS_LDX" => 30, "INS_LDY" => 31, "INS_LSR" => 32,    
		"INS_NOP" => 33, "INS_ORA" => 34, "INS_PHA" => 35,
		"INS_PHP" => 36, "INS_PLA" => 37, "INS_PLP" => 38,
		"INS_ROL" => 39, "INS_ROR" => 40, "INS_RTI" => 41,
		"INS_RTS" => 42, "INS_SBC" => 43, "INS_SEC" => 44,
		"INS_SED" => 45, "INS_SEI" => 46, "INS_STA" => 47,
		"INS_STX" => 48, "INS_STY" => 49, "INS_TAX" => 50,
		"INS_TAY" => 51, "INS_TSX" => 52, "INS_TXA" => 53,
		"INS_TXS" => 54, "INS_TYA" => 55, "INS_DUMMY" => 56, // dummy instruction used for 'halting' the processor some cycles
    
		// Addressing modes:
		"ADDR_ZP" => 0, "ADDR_REL" => 1, "ADDR_IMP" => 2,
		"ADDR_ABS" => 3, "ADDR_ACC" => 4, "ADDR_IMM" => 5,
		"ADDR_ZPX" => 6, "ADDR_ZPY" => 7, "ADDR_ABSX" => 8,
		"ADDR_ABSY" => 9, "ADDR_PREIDXIND" => 10, "ADDR_POSTIDXIND" => 11,
		"ADDR_INDABS" => 12
	];
		
	public var mem:Vector<Int>;
	public var cyclesToHalt:Int;
	
	var nes:NES;	
    var REG_ACC:Int;
    var REG_X:Int;
    var REG_Y:Int;
    var REG_SP:Int;
    var REG_PC:Int;
    var REG_PC_NEW:Int;
    var REG_STATUS:Int;
    var F_CARRY:Int;
    var F_DECIMAL:Int;
    var F_INTERRUPT:Int;
    var F_INTERRUPT_NEW:Int;
    var F_OVERFLOW:Int;
    var F_SIGN:Int;
    var F_ZERO:Int;
    var F_NOTUSED:Int;
    var F_NOTUSED_NEW:Int;
    var F_BRK:Int;
    var F_BRK_NEW:Int;
    var opdata:Array<Int>;    
    var crash:Bool;
    var irqRequested:Bool;
    var irqType:Int;

	public function new(nes:NES) {
		this.nes = nes;
		initOpData();
		reset();
	}
	
	public function reset() {		
        // Main memory 
        mem = new Vector<Int>(0x10000);
        
        for (i in 0...0x2000) {
            mem[i] = 0xFF;
        }
		
        for (p in 0...4) {
            var i = p * 0x800;
            mem[i + 0x008] = 0xF7;
            mem[i + 0x009] = 0xEF;
            mem[i + 0x00A] = 0xDF;
            mem[i + 0x00F] = 0xBF;
        }
		
        for (i in 0x2001...0x10000) {
            mem[i] = 0;
        }
        
        // CPU Registers:
        REG_ACC = 0;
        REG_X = 0;
        REG_Y = 0;
        // Reset Stack pointer:
        REG_SP = 0x01FF;
        // Reset Program counter:
        REG_PC = 0x8000 - 1;
        REG_PC_NEW = 0x8000 - 1;
        // Reset Status register:
        REG_STATUS = 0x28;
        
        setStatus(0x28);
        
        // Set flags:
        F_CARRY = 0;
        F_DECIMAL = 0;
        F_INTERRUPT = 1;
        F_INTERRUPT_NEW = 1;
        F_OVERFLOW = 0;
        F_SIGN = 0;
        F_ZERO = 1;

        F_NOTUSED = 1;
        F_NOTUSED_NEW = 1;
        F_BRK = 1;
        F_BRK_NEW = 1;
        
        cyclesToHalt = 0;
        
        // Reset crash flag:
        crash = false;
        
        // Interrupt notification:
        irqRequested = false;
        irqType = -1;
    }
	
	// Emulates a single CPU instruction, returns the number of cycles
    public function emulate():Int {
        var temp:Int = 0;
        var add:Int = 0;
	 
        // Check interrupts:
        if (irqRequested) {
            temp =
                (F_CARRY) |
                ((F_ZERO == 0 ? 1 : 0) << 1) |
                (F_INTERRUPT << 2) |
                (F_DECIMAL << 3) |
                (F_BRK << 4) |
                (F_NOTUSED << 5) |
                (F_OVERFLOW << 6) |
                (F_SIGN << 7);
				
            REG_PC_NEW = REG_PC;
            F_INTERRUPT_NEW = F_INTERRUPT;
            switch (irqType) {
                case 0: 
                    // Normal IRQ:
                    if (F_INTERRUPT == 0) {
						doIrq(temp);
                    }                    
					
                case 1:
                    // NMI:
                    doNonMaskableInterrupt(temp);
					
                case 2:
                    // Reset:
                    doResetInterrupt();                
            }
			
            REG_PC = REG_PC_NEW;
            F_INTERRUPT = F_INTERRUPT_NEW;
            F_BRK = F_BRK_NEW;
            irqRequested = false;
        }
		
        var opinf:Int = opdata[nes.mmap.load(REG_PC + 1)];
        var cycleCount:Int = (opinf >> 24);
        var cycleAdd:Int = 0;
		
        // Find address mode:
        var addrMode:Int = (opinf >> 8) & 0xFF;
		
        // Increment PC by number of op bytes:
        var opaddr:Int = REG_PC;
        REG_PC += ((opinf >> 16) & 0xFF);
        
        var addr:Int = 0;
        switch (addrMode) {
            case 0:
                // Zero Page mode. Use the address given after the opcode, 
                // but without high byte.
                addr = load(opaddr + 2);
				
            case 1:
                // Relative mode.
                addr = load(opaddr + 2);
                if (addr < 0x80) {
                    addr += REG_PC;
                } 
				else {
                    addr += REG_PC - 256;
                }
               
            case 2:
                // Ignore. Address is implied in instruction.
				
            case 3:
                // Absolute mode. Use the two bytes following the opcode as 
                // an address.
                addr = load16bit(opaddr + 2);
				
            case 4:
                // Accumulator mode. The address is in the accumulator 
                // register.
                addr = REG_ACC;
				
            case 5:
                // Immediate mode. The value is given after the opcode.
                addr = REG_PC;
				
            case 6:
                // Zero Page Indexed mode, X as index. Use the address given 
                // after the opcode, then add the
                // X register to it to get the final address.
                addr = (load(opaddr + 2) + REG_X) & 0xFF;
				
            case 7:
                // Zero Page Indexed mode, Y as index. Use the address given 
                // after the opcode, then add the
                // Y register to it to get the final address.
                addr = (load(opaddr + 2) + REG_Y) & 0xFF;
               
            case 8:
                // Absolute Indexed Mode, X as index. Same as zero page 
                // indexed, but with the high byte.
                addr = load16bit(opaddr + 2);
                if ((addr & 0xFF00) != ((addr + REG_X) & 0xFF00)) {
                    cycleAdd = 1;
                }
                addr += REG_X;
             
            case 9:
                // Absolute Indexed Mode, Y as index. Same as zero page 
                // indexed, but with the high byte.
                addr = load16bit(opaddr + 2);
                if ((addr & 0xFF00) != ((addr + REG_Y) & 0xFF00)) {
                    cycleAdd = 1;
                }
                addr += REG_Y;
                
            case 10:
                // Pre-indexed Indirect mode. Find the 16-bit address 
                // starting at the given location plus
                // the current X register. The value is the contents of that 
                // address.
                addr = load(opaddr + 2);
                if ((addr & 0xFF00) != ((addr + REG_X) & 0xFF00)) {
                    cycleAdd = 1;
                }
                addr += REG_X;
                addr &= 0xFF;
                addr = load16bit(addr);
				
			case 11:
                // Post-indexed Indirect mode. Find the 16-bit address 
                // contained in the given location
                // (and the one following). Add to that address the contents 
                // of the Y register. Fetch the value
                // stored at that adress.
                addr = load16bit(load(opaddr + 2));
                if ((addr & 0xFF00) != ((addr + REG_Y) & 0xFF00)) {
                    cycleAdd = 1;
                }
                addr += REG_Y;
				
            case 12:
                // Indirect Absolute mode. Find the 16-bit address contained 
                // at the given location.
                addr = load16bit(opaddr + 2);// Find op
                if (addr < 0x1FFF) {
					// Read from address given in op
                    addr = mem[addr] + (mem[(addr & 0xFF00) | (((addr & 0xFF) + 1) & 0xFF)] << 8);
                } 
				else {
                    addr = nes.mmap.load(addr) + (nes.mmap.load((addr & 0xFF00) | (((addr & 0xFF) + 1) & 0xFF)) << 8);
                } 			
        }
        // Wrap around for addresses above 0xFFFF:
        addr &= 0xFFFF;
		
        // ----------------------------------------------------------------------------------------------------
        // Decode & execute instruction:
        // ----------------------------------------------------------------------------------------------------
		
        // This should be compiled to a jump table.
        switch (opinf & 0xFF) {
            case 0: // * ADC * 
                // Add with carry.
                temp = REG_ACC + load(addr) + F_CARRY;
                F_OVERFLOW = ((!(((REG_ACC ^ load(addr)) & 0x80) != 0) && (((REG_ACC ^ temp) & 0x80)) != 0) ? 1 : 0);
                F_CARRY = (temp > 255 ? 1 : 0);
                F_SIGN = (temp >> 7) & 1;
                F_ZERO = temp & 0xFF;
                REG_ACC = (temp & 255);
                cycleCount += cycleAdd;
				
            case 1: // * AND *   
                // AND memory with accumulator.
                REG_ACC = REG_ACC & load(addr);
                F_SIGN = (REG_ACC >> 7) & 1;
                F_ZERO = REG_ACC;
                //REG_ACC = temp;
                if (addrMode != 11) {
					cycleCount += cycleAdd; // PostIdxInd = 11
				}
				
			case 2: // * ASL *
                // Shift left one bit
                if (addrMode == 4) { // ADDR_ACC = 4
                    F_CARRY = (REG_ACC >> 7) & 1;
                    REG_ACC = (REG_ACC << 1) & 255;
                    F_SIGN = (REG_ACC >> 7) & 1;
                    F_ZERO = REG_ACC;
                } 
				else {
                    temp = load(addr);
                    F_CARRY = (temp >> 7) & 1;
                    temp = (temp << 1) & 255;
                    F_SIGN = (temp >> 7) & 1;
                    F_ZERO = temp;
                    //write(addr, temp);
					addr < 0x2000 ? mem[addr & 0x7FF] = temp : nes.mmap.write(addr, temp);
                }
				
            case 3: // * BCC *
                // Branch on carry clear
                if (F_CARRY == 0) {
                    cycleCount += ((opaddr & 0xFF00) != (addr & 0xFF00) ? 2 : 1);
                    REG_PC = addr;
                }
				
            case 4: // * BCS *
                // Branch on carry set
                if (F_CARRY == 1) {
                    cycleCount += ((opaddr & 0xFF00) != (addr & 0xFF00) ? 2 : 1);
                    REG_PC = addr;
                }
				
            case 5: // * BEQ *
                // Branch on zero
                if (F_ZERO == 0) {
                    cycleCount += ((opaddr & 0xFF00) != (addr & 0xFF00) ? 2 : 1);
                    REG_PC = addr;
                }
				
            case 6: // * BIT *
                temp = load(addr);
                F_SIGN = (temp >> 7) & 1;
                F_OVERFLOW = (temp >> 6) & 1;
                temp &= REG_ACC;
                F_ZERO = temp;
				
            case 7: // * BMI *
                // Branch on negative result
                if (F_SIGN == 1) {
                    cycleCount++;
                    REG_PC = addr;
                }
				
            case 8: // * BNE *
                // Branch on not zero
                if (F_ZERO != 0) {
                    cycleCount += ((opaddr & 0xFF00) != (addr & 0xFF00) ? 2 : 1);
                    REG_PC = addr;
                }
				
            case 9: // * BPL *
                // Branch on positive result
                if (F_SIGN == 0) {
                    cycleCount += ((opaddr & 0xFF00) != (addr & 0xFF00) ? 2 : 1);
                    REG_PC = addr;
                }
				
            case 10: // * BRK *
                REG_PC += 2;
                push((REG_PC >> 8) & 255);
                push(REG_PC & 255);
                F_BRK = 1;
				
                push(
                    (F_CARRY) |
                    ((F_ZERO == 0 ? 1 : 0) << 1) |
                    (F_INTERRUPT << 2) |
                    (F_DECIMAL << 3) |
                    (F_BRK << 4) |
                    (F_NOTUSED << 5) |
                    (F_OVERFLOW << 6) |
                    (F_SIGN << 7)
                );
				
                F_INTERRUPT = 1;
                //REG_PC = load(0xFFFE) | (load(0xFFFF) << 8);
                REG_PC = load16bit(0xFFFE);
                REG_PC--;
				
            case 11: // * BVC *
                // Branch on overflow clear
                if (F_OVERFLOW == 0) {
                    cycleCount += ((opaddr & 0xFF00) != (addr & 0xFF00) ? 2 : 1);
                    REG_PC = addr;
                }
				
            case 12: // * BVS *
                // Branch on overflow set
                if (F_OVERFLOW == 1) {
                    cycleCount += ((opaddr & 0xFF00) != (addr & 0xFF00) ? 2 : 1);
                    REG_PC = addr;
                }
				
            case 13: // * CLC *
                // Clear carry flag
                F_CARRY = 0;
				
            case 14: // * CLD *
                // Clear decimal flag
                F_DECIMAL = 0;
				
            case 15: // * CLI *
                // Clear interrupt flag
                F_INTERRUPT = 0;
				
            case 16: // * CLV *
                // Clear overflow flag
                F_OVERFLOW = 0;
				
            case 17: // * CMP *
                // Compare memory and accumulator:
                temp = REG_ACC - load(addr);
                F_CARRY = (temp >= 0 ? 1 : 0);
                F_SIGN = (temp >> 7) & 1;
                F_ZERO = temp & 0xFF;
                cycleCount += cycleAdd;
				
            case 18: // * CPX *
                // Compare memory and index X:
                temp = REG_X - load(addr);
                F_CARRY = (temp >= 0 ? 1 : 0);
                F_SIGN = (temp >> 7) & 1;
                F_ZERO = temp & 0xFF;
				
            case 19: // * CPY *
                // Compare memory and index Y:
                temp = REG_Y - load(addr);
                F_CARRY = (temp >= 0 ? 1 : 0);
                F_SIGN = (temp >> 7) & 1;
                F_ZERO = temp & 0xFF;
				
            case 20: // * DEC *
                // Decrement memory by one:
                temp = (load(addr) - 1) & 0xFF;
                F_SIGN = (temp >> 7) & 1;
                F_ZERO = temp;
                //write(addr, temp);
				addr < 0x2000 ? mem[addr & 0x7FF] = temp : nes.mmap.write(addr, temp);
				
            case 21: // * DEX *
                // Decrement index X by one:
                REG_X = (REG_X - 1) & 0xFF;
                F_SIGN = (REG_X >> 7) & 1;
                F_ZERO = REG_X;
				
            case 22: // * DEY *
                // Decrement index Y by one:
                REG_Y = (REG_Y - 1) & 0xFF;
                F_SIGN = (REG_Y >> 7) & 1;
                F_ZERO = REG_Y;
				
            case 23: // * EOR *
                // XOR Memory with accumulator, store in accumulator:
                REG_ACC = (load(addr) ^ REG_ACC) & 0xFF;
                F_SIGN = (REG_ACC >> 7) & 1;
                F_ZERO = REG_ACC;
                cycleCount += cycleAdd;
				
            case 24: // * INC *
                // Increment memory by one:
                temp = (load(addr) + 1) & 0xFF;
                F_SIGN = (temp >> 7) & 1;
                F_ZERO = temp;
                //write(addr, temp & 0xFF);
				addr < 0x2000 ? mem[addr & 0x7FF] = (temp & 0xFF) : nes.mmap.write(addr, (temp & 0xFF));
				
            case 25: // * INX *
                // Increment index X by one:
                REG_X = (REG_X + 1) & 0xFF;
                F_SIGN = (REG_X >> 7) & 1;
                F_ZERO = REG_X;
				
            case 26: // * INY *
                // Increment index Y by one:
                REG_Y++;
                REG_Y &= 0xFF;
                F_SIGN = (REG_Y >> 7) & 1;
                F_ZERO = REG_Y;
				
            case 27: // * JMP *
                // Jump to new location:
                REG_PC = addr - 1;
				
            case 28: // * JSR *
                // Jump to new location, saving return address.
                // Push return address on stack:
                push((REG_PC >> 8) & 255);
                push(REG_PC & 255);
                REG_PC = addr - 1;
				
            case 29: // * LDA *
                // Load accumulator with memory:
                REG_ACC = load(addr);
                F_SIGN = (REG_ACC >> 7) & 1;
                F_ZERO = REG_ACC;
                cycleCount += cycleAdd;
				
            case 30: // * LDX *
                // Load index X with memory:
                REG_X = load(addr);
                F_SIGN = (REG_X >> 7) & 1;
                F_ZERO = REG_X;
                cycleCount += cycleAdd;
				
            case 31: // * LDY *
                // Load index Y with memory:
                REG_Y = load(addr);
                F_SIGN = (REG_Y >> 7) & 1;
                F_ZERO = REG_Y;
                cycleCount += cycleAdd;
				
            case 32: // * LSR *
                // Shift right one bit:
                if(addrMode == 4){ // ADDR_ACC
                    temp = (REG_ACC & 0xFF);
                    F_CARRY = temp & 1;
                    temp >>= 1;
                    REG_ACC = temp;
                } 
				else {
                    temp = load(addr) & 0xFF;
                    F_CARRY = temp & 1;
                    temp >>= 1;
                    //write(addr, temp);
					addr < 0x2000 ? mem[addr & 0x7FF] = temp : nes.mmap.write(addr, temp);
                }
                F_SIGN = 0;
                F_ZERO = temp;
				
            case 33: // * NOP *
                // No OPeration.  
				
            case 34: // * ORA *
                // OR memory with accumulator, store in accumulator.
                temp = (load(addr) | REG_ACC) & 255;
                F_SIGN = (temp >> 7) & 1;
                F_ZERO = temp;
                REG_ACC = temp;
                if (addrMode != 11) {
					cycleCount += cycleAdd; // PostIdxInd = 11
				}
				
            case 35: // * PHA *
                // Push accumulator on stack
                push(REG_ACC);
				
            case 36: // * PHP *
                // Push processor status on stack
                F_BRK = 1;
                push(
                    (F_CARRY) |
                    ((F_ZERO == 0 ? 1 : 0) << 1) |
                    (F_INTERRUPT << 2) |
                    (F_DECIMAL << 3) |
                    (F_BRK << 4) |
                    (F_NOTUSED << 5) |
                    (F_OVERFLOW << 6) |
                    (F_SIGN << 7)
                );
				
            case 37: // * PLA *
                // Pull accumulator from stack
                REG_ACC = pull();
                F_SIGN = (REG_ACC >> 7) & 1;
                F_ZERO = REG_ACC;
				
            case 38: // * PLP *
                // Pull processor status from stack
                temp = pull();
                F_CARRY     = (temp   ) & 1;
                F_ZERO      = (((temp >> 1) & 1) == 1) ? 0 : 1;
                F_INTERRUPT = (temp >> 2) & 1;
                F_DECIMAL   = (temp >> 3) & 1;
                F_BRK       = (temp >> 4) & 1;
                F_NOTUSED   = (temp >> 5) & 1;
                F_OVERFLOW  = (temp >> 6) & 1;
                F_SIGN      = (temp >> 7) & 1;
                F_NOTUSED = 1;
				
            case 39: // * ROL *
                // Rotate one bit left
                if (addrMode == 4) { // ADDR_ACC = 4
                    temp = REG_ACC;
                    add = F_CARRY;
                    F_CARRY = (temp >> 7) & 1;
                    temp = ((temp << 1) & 0xFF) + add;
                    REG_ACC = temp;
                } 
				else {
                    temp = load(addr);
                    add = F_CARRY;
                    F_CARRY = (temp >> 7) & 1;
                    temp = ((temp << 1) & 0xFF) + add;    
                    //write(addr, temp);
					addr < 0x2000 ? mem[addr & 0x7FF] = temp : nes.mmap.write(addr, temp);
                }
                F_SIGN = (temp >> 7) & 1;
                F_ZERO = temp;
				
            case 40: // * ROR *
                // Rotate one bit right
                if (addrMode == 4) { // ADDR_ACC = 4
                    add = F_CARRY << 7;
                    F_CARRY = REG_ACC & 1;
                    temp = (REG_ACC >> 1) + add;   
                    REG_ACC = temp;
                } 
				else {
                    temp = load(addr);
                    add = F_CARRY << 7;
                    F_CARRY = temp & 1;
                    temp = (temp >> 1) + add;
                    //write(addr, temp);
					addr < 0x2000 ? mem[addr & 0x7FF] = temp : nes.mmap.write(addr, temp);
                }
                F_SIGN = (temp >> 7) & 1;
                F_ZERO = temp;  
				
            case 41: // * RTI *
                // Return from interrupt. Pull status and PC from stack.                
                temp = pull();
                F_CARRY     = (temp   ) & 1;
                F_ZERO      = ((temp >> 1) & 1) == 0 ? 1 : 0;
                F_INTERRUPT = (temp >> 2) & 1;
                F_DECIMAL   = (temp >> 3) & 1;
                F_BRK       = (temp >> 4) & 1;
                F_NOTUSED   = (temp >> 5) & 1;
                F_OVERFLOW  = (temp >> 6) & 1;
                F_SIGN      = (temp >> 7) & 1;
				
                REG_PC = pull();
                REG_PC += (pull() << 8);
                if(REG_PC == 0xFFFF) {
                    return 0;
                }
                REG_PC--;
                F_NOTUSED = 1;
				
            case 42: // * RTS *
                // Return from subroutine. Pull PC from stack.                
                REG_PC = pull();
                REG_PC += (pull() << 8);
                
                if (REG_PC == 0xFFFF) {
                    return 0; // return from NSF play routine:
                }
				
            case 43: // * SBC *
                temp = REG_ACC - load(addr) - (1 - F_CARRY);
                F_SIGN = (temp >> 7) & 1;
                F_ZERO = temp & 0xFF;
                F_OVERFLOW = ((((REG_ACC ^ temp) & 0x80) != 0 && ((REG_ACC ^ load(addr)) & 0x80) != 0) ? 1 : 0);
                F_CARRY = temp < 0 ? 0 : 1;
                REG_ACC = temp & 0xFF;
                if (addrMode != 11) { 
					cycleCount += cycleAdd; // PostIdxInd = 11
				}
				
            case 44: // * SEC *
                // Set carry flag
                F_CARRY = 1;
				
            case 45: // * SED *
                // Set decimal mode
                F_DECIMAL = 1;
				
            case 46: // * SEI *
                // Set interrupt disable status
                F_INTERRUPT = 1;
				
            case 47: // * STA *
                // Store accumulator in memory
                //write(addr, REG_ACC);
				addr < 0x2000 ? mem[addr & 0x7FF] = REG_ACC : nes.mmap.write(addr, REG_ACC);
				
            case 48: // * STX *
                // Store index X in memory
                //write(addr, REG_X);
				addr < 0x2000 ? mem[addr & 0x7FF] = REG_X : nes.mmap.write(addr, REG_X);
				
            case 49: // * STY *
                // Store index Y in memory:
                //write(addr, REG_Y);
				addr < 0x2000 ? mem[addr & 0x7FF] = REG_Y : nes.mmap.write(addr, REG_Y);
				
            case 0x32: // * TAX *
                // Transfer accumulator to index X:
                REG_X = REG_ACC;
                F_SIGN = (REG_ACC >> 7) & 1;
                F_ZERO = REG_ACC;
				
            case 0x33: // * TAY *
                // Transfer accumulator to index Y:
                REG_Y = REG_ACC;
                F_SIGN = (REG_ACC >> 7) & 1;
                F_ZERO = REG_ACC;
				
            case 0x34: // * TSX *
                // Transfer stack pointer to index X:
                REG_X = (REG_SP - 0x0100);
                F_SIGN = (REG_SP >> 7) & 1;
                F_ZERO = REG_X;
				
            case 0x35: // * TXA *
                // Transfer index X to accumulator:
                REG_ACC = REG_X;
                F_SIGN = (REG_X >> 7) & 1;
                F_ZERO = REG_X;
				
            case 0x36: // * TXS *
                // Transfer index X to stack pointer:
                REG_SP = (REG_X + 0x0100);
                stackWrap();
				
            case 0x37: // * TYA *
                // Transfer index Y to accumulator:
                REG_ACC = REG_Y;
                F_SIGN = (REG_Y >> 7) & 1;
                F_ZERO = REG_Y;
				
            default: // * ??? *
                // unknown opcode
                nes.stop();
                //nes.crashMessage = "Game crashed, invalid opcode at address $" + opaddr;   
				
        }	// end of switch
		
        return cycleCount;
    }
	
	inline function load(addr:Int):Int {
        return addr < 0x2000 ? mem[addr & 0x7FF] : nes.mmap.load(addr);
    }
    
    inline function load16bit(addr:Int):Int {
		return addr < 0x1FFF ? mem[addr & 0x7FF] | (mem[(addr + 1) & 0x7FF] << 8) : nes.mmap.load(addr) | (nes.mmap.load(addr + 1) << 8);        
    }
    
    inline function write(addr:Int, val:Int) {
        addr < 0x2000 ? mem[addr & 0x7FF] = val : nes.mmap.write(addr, val);       
    }

    public function requestIrq(type:Int) {
        if(irqRequested){
            if(type == CPU.IRQ_NORMAL){
                return;
            }
        }
        irqRequested = true;
        irqType = type;
    }

    inline function push(value:Int) {
        nes.mmap.write(REG_SP, value);
        REG_SP = 0x0100 | (--REG_SP & 0xFF);
    }

    inline function stackWrap() {
        REG_SP = 0x0100 | (REG_SP & 0xFF);
    }

    inline function pull():Int {
        REG_SP = 0x0100 | (++REG_SP & 0xFF);
        return nes.mmap.load(REG_SP);
    }

    inline function pageCrossed(addr1:Int, addr2:Int):Bool {
        return ((addr1 & 0xFF00) != (addr2 & 0xFF00));
    }

    inline public function haltCycles(cycles:Int) {
        cyclesToHalt += cycles;
    }

    function doNonMaskableInterrupt(status:Int) {
        if((nes.mmap.load(0x2000) & 128) != 0) { // Check whether VBlank Interrupts are enabled
            push((++REG_PC_NEW >> 8) & 0xFF);
            push(REG_PC_NEW & 0xFF);
            //F_INTERRUPT_NEW = 1;
            push(status);
			
            REG_PC_NEW = nes.mmap.load(0xFFFA) | (nes.mmap.load(0xFFFB) << 8);
            REG_PC_NEW--;
        }
    }

    inline function doResetInterrupt() {
        REG_PC_NEW = nes.mmap.load(0xFFFC) | (nes.mmap.load(0xFFFD) << 8);
        REG_PC_NEW--;
    }

    inline function doIrq(status:Int) {
        push((++REG_PC_NEW >> 8) & 0xFF);
        push(REG_PC_NEW & 0xFF);
        push(status);
        F_INTERRUPT_NEW = 1;
        F_BRK_NEW = 0;
		
        REG_PC_NEW = nes.mmap.load(0xFFFE) | (nes.mmap.load(0xFFFF) << 8);
        REG_PC_NEW--;
    }

    inline function getStatus():Int {
        return    (F_CARRY)
                | (F_ZERO << 1)
                | (F_INTERRUPT << 2)
                | (F_DECIMAL << 3)
                | (F_BRK << 4)
                | (F_NOTUSED << 5)
                | (F_OVERFLOW << 6)
                | (F_SIGN << 7);
    }

    inline function setStatus(st:Int) {
        F_CARRY     = (st     ) & 1;
        F_ZERO      = (st >> 1) & 1;
        F_INTERRUPT = (st >> 2) & 1;
        F_DECIMAL   = (st >> 3) & 1;
        F_BRK       = (st >> 4) & 1;
        F_NOTUSED   = (st >> 5) & 1;
        F_OVERFLOW  = (st >> 6) & 1;
        F_SIGN      = (st >> 7) & 1;
    }
    	
	function setOp(inst:Int, op:Int, addr:Int, size:Int, cycles:Int) {
        opdata[op] = 
            ((inst   & 0xFF)      ) | 
            ((addr   & 0xFF) <<  8) | 
            ((size   & 0xFF) << 16) | 
            ((cycles & 0xFF) << 24);
    }
	
	function initOpData() {
		opdata = [];
		
		// Set all to invalid instruction (to detect crashes):
		for (i in 0...256) {
			opdata[i] = 0xFF;
		}
		
		// Now fill in all valid opcodes:
		
		// ADC:
		setOp(opDATA.get("INS_ADC"), 0x69, opDATA.get("ADDR_IMM"), 2, 2);
		setOp(opDATA.get("INS_ADC"), 0x65, opDATA.get("ADDR_ZP"), 2, 3);
		setOp(opDATA.get("INS_ADC"), 0x75, opDATA.get("ADDR_ZPX"), 2, 4);
		setOp(opDATA.get("INS_ADC"), 0x6D, opDATA.get("ADDR_ABS"), 3, 4);
		setOp(opDATA.get("INS_ADC"), 0x7D, opDATA.get("ADDR_ABSX"), 3, 4);
		setOp(opDATA.get("INS_ADC"), 0x79, opDATA.get("ADDR_ABSY"), 3, 4);
		setOp(opDATA.get("INS_ADC"), 0x61, opDATA.get("ADDR_PREIDXIND"), 2, 6);
		setOp(opDATA.get("INS_ADC"), 0x71, opDATA.get("ADDR_POSTIDXIND"), 2, 5);
		
		// AND:
		setOp(opDATA.get("INS_AND"), 0x29, opDATA.get("ADDR_IMM"), 2, 2);
		setOp(opDATA.get("INS_AND"), 0x25, opDATA.get("ADDR_ZP"), 2, 3);
		setOp(opDATA.get("INS_AND"), 0x35, opDATA.get("ADDR_ZPX"), 2, 4);
		setOp(opDATA.get("INS_AND"), 0x2D, opDATA.get("ADDR_ABS"), 3, 4);
		setOp(opDATA.get("INS_AND"), 0x3D, opDATA.get("ADDR_ABSX"), 3, 4);
		setOp(opDATA.get("INS_AND"), 0x39, opDATA.get("ADDR_ABSY"), 3, 4);
		setOp(opDATA.get("INS_AND"), 0x21, opDATA.get("ADDR_PREIDXIND"), 2, 6);
		setOp(opDATA.get("INS_AND"), 0x31, opDATA.get("ADDR_POSTIDXIND"), 2, 5);
		
		// ASL:
		setOp(opDATA.get("INS_ASL"), 0x0A, opDATA.get("ADDR_ACC"), 1, 2);
		setOp(opDATA.get("INS_ASL"), 0x06, opDATA.get("ADDR_ZP"), 2, 5);
		setOp(opDATA.get("INS_ASL"), 0x16, opDATA.get("ADDR_ZPX"), 2, 6);
		setOp(opDATA.get("INS_ASL"), 0x0E, opDATA.get("ADDR_ABS"), 3, 6);
		setOp(opDATA.get("INS_ASL"), 0x1E, opDATA.get("ADDR_ABSX"), 3, 7);
		
		// BCC:
		setOp(opDATA.get("INS_BCC"), 0x90, opDATA.get("ADDR_REL"), 2, 2);
		
		// BCS:
		setOp(opDATA.get("INS_BCS"), 0xB0, opDATA.get("ADDR_REL"), 2, 2);
		
		// BEQ:
		setOp(opDATA.get("INS_BEQ"), 0xF0, opDATA.get("ADDR_REL"), 2, 2);
		
		// BIT:
		setOp(opDATA.get("INS_BIT"), 0x24, opDATA.get("ADDR_ZP"), 2, 3);
		setOp(opDATA.get("INS_BIT"), 0x2C, opDATA.get("ADDR_ABS"), 3, 4);
		
		// BMI:
		setOp(opDATA.get("INS_BMI"), 0x30, opDATA.get("ADDR_REL"), 2, 2);
		
		// BNE:
		setOp(opDATA.get("INS_BNE"), 0xD0, opDATA.get("ADDR_REL"), 2, 2);
		
		// BPL:
		setOp(opDATA.get("INS_BPL"), 0x10, opDATA.get("ADDR_REL"), 2, 2);
		
		// BRK:
		setOp(opDATA.get("INS_BRK"), 0x00, opDATA.get("ADDR_IMP"), 1, 7);
		
		// BVC:
		setOp(opDATA.get("INS_BVC"), 0x50, opDATA.get("ADDR_REL"), 2, 2);
		
		// BVS:
		setOp(opDATA.get("INS_BVS"), 0x70, opDATA.get("ADDR_REL"), 2, 2);
		
		// CLC:
		setOp(opDATA.get("INS_CLC"), 0x18, opDATA.get("ADDR_IMP"), 1, 2);
		
		// CLD:
		setOp(opDATA.get("INS_CLD"), 0xD8, opDATA.get("ADDR_IMP"), 1, 2);
		
		// CLI:
		setOp(opDATA.get("INS_CLI"), 0x58, opDATA.get("ADDR_IMP"), 1, 2);
		
		// CLV:
		setOp(opDATA.get("INS_CLV"), 0xB8, opDATA.get("ADDR_IMP"), 1, 2);
		
		// CMP:
		setOp(opDATA.get("INS_CMP"), 0xC9, opDATA.get("ADDR_IMM"), 2, 2);
		setOp(opDATA.get("INS_CMP"), 0xC5, opDATA.get("ADDR_ZP"), 2, 3);
		setOp(opDATA.get("INS_CMP"), 0xD5, opDATA.get("ADDR_ZPX"), 2, 4);
		setOp(opDATA.get("INS_CMP"), 0xCD, opDATA.get("ADDR_ABS"), 3, 4);
		setOp(opDATA.get("INS_CMP"), 0xDD, opDATA.get("ADDR_ABSX"), 3, 4);
		setOp(opDATA.get("INS_CMP"), 0xD9, opDATA.get("ADDR_ABSY"), 3, 4);
		setOp(opDATA.get("INS_CMP"), 0xC1, opDATA.get("ADDR_PREIDXIND"), 2, 6);
		setOp(opDATA.get("INS_CMP"), 0xD1, opDATA.get("ADDR_POSTIDXIND"), 2, 5);
		
		// CPX:
		setOp(opDATA.get("INS_CPX"), 0xE0, opDATA.get("ADDR_IMM"), 2, 2);
		setOp(opDATA.get("INS_CPX"), 0xE4, opDATA.get("ADDR_ZP"), 2, 3);
		setOp(opDATA.get("INS_CPX"), 0xEC, opDATA.get("ADDR_ABS"), 3, 4);
		
		// CPY:
		setOp(opDATA.get("INS_CPY"), 0xC0, opDATA.get("ADDR_IMM"), 2, 2);
		setOp(opDATA.get("INS_CPY"), 0xC4, opDATA.get("ADDR_ZP"), 2, 3);
		setOp(opDATA.get("INS_CPY"), 0xCC, opDATA.get("ADDR_ABS"), 3, 4);
		
		// DEC:
		setOp(opDATA.get("INS_DEC"), 0xC6, opDATA.get("ADDR_ZP"), 2, 5);
		setOp(opDATA.get("INS_DEC"), 0xD6, opDATA.get("ADDR_ZPX"), 2, 6);
		setOp(opDATA.get("INS_DEC"), 0xCE, opDATA.get("ADDR_ABS"), 3, 6);
		setOp(opDATA.get("INS_DEC"), 0xDE, opDATA.get("ADDR_ABSX"), 3, 7);
		
		// DEX:
		setOp(opDATA.get("INS_DEX"), 0xCA, opDATA.get("ADDR_IMP"), 1, 2);
		
		// DEY:
		setOp(opDATA.get("INS_DEY"), 0x88, opDATA.get("ADDR_IMP"), 1, 2);
		
		// EOR:
		setOp(opDATA.get("INS_EOR"), 0x49, opDATA.get("ADDR_IMM"), 2, 2);
		setOp(opDATA.get("INS_EOR"), 0x45, opDATA.get("ADDR_ZP"), 2, 3);
		setOp(opDATA.get("INS_EOR"), 0x55, opDATA.get("ADDR_ZPX"), 2, 4);
		setOp(opDATA.get("INS_EOR"), 0x4D, opDATA.get("ADDR_ABS"), 3, 4);
		setOp(opDATA.get("INS_EOR"), 0x5D, opDATA.get("ADDR_ABSX"), 3, 4);
		setOp(opDATA.get("INS_EOR"), 0x59, opDATA.get("ADDR_ABSY"), 3, 4);
		setOp(opDATA.get("INS_EOR"), 0x41, opDATA.get("ADDR_PREIDXIND"), 2, 6);
		setOp(opDATA.get("INS_EOR"), 0x51, opDATA.get("ADDR_POSTIDXIND"), 2, 5);
		
		// INC:
		setOp(opDATA.get("INS_INC"), 0xE6, opDATA.get("ADDR_ZP"), 2, 5);
		setOp(opDATA.get("INS_INC"), 0xF6, opDATA.get("ADDR_ZPX"), 2, 6);
		setOp(opDATA.get("INS_INC"), 0xEE, opDATA.get("ADDR_ABS"), 3, 6);
		setOp(opDATA.get("INS_INC"), 0xFE, opDATA.get("ADDR_ABSX"), 3, 7);
		
		// INX:
		setOp(opDATA.get("INS_INX"), 0xE8, opDATA.get("ADDR_IMP"), 1, 2);
		
		// INY:
		setOp(opDATA.get("INS_INY"), 0xC8, opDATA.get("ADDR_IMP"), 1, 2);
		
		// JMP:
		setOp(opDATA.get("INS_JMP"), 0x4C, opDATA.get("ADDR_ABS"), 3, 3);
		setOp(opDATA.get("INS_JMP"), 0x6C, opDATA.get("ADDR_INDABS"), 3, 5);
		
		// JSR:
		setOp(opDATA.get("INS_JSR"), 0x20, opDATA.get("ADDR_ABS"), 3, 6);
		
		// LDA:
		setOp(opDATA.get("INS_LDA"), 0xA9, opDATA.get("ADDR_IMM"), 2, 2);
		setOp(opDATA.get("INS_LDA"), 0xA5, opDATA.get("ADDR_ZP"), 2, 3);
		setOp(opDATA.get("INS_LDA"), 0xB5, opDATA.get("ADDR_ZPX"), 2, 4);
		setOp(opDATA.get("INS_LDA"), 0xAD, opDATA.get("ADDR_ABS"), 3, 4);
		setOp(opDATA.get("INS_LDA"), 0xBD, opDATA.get("ADDR_ABSX"), 3, 4);
		setOp(opDATA.get("INS_LDA"), 0xB9, opDATA.get("ADDR_ABSY"), 3, 4);
		setOp(opDATA.get("INS_LDA"), 0xA1, opDATA.get("ADDR_PREIDXIND"), 2, 6);
		setOp(opDATA.get("INS_LDA"), 0xB1, opDATA.get("ADDR_POSTIDXIND"), 2, 5);
		
		
		// LDX:
		setOp(opDATA.get("INS_LDX"), 0xA2, opDATA.get("ADDR_IMM"), 2, 2);
		setOp(opDATA.get("INS_LDX"), 0xA6, opDATA.get("ADDR_ZP"), 2, 3);
		setOp(opDATA.get("INS_LDX"), 0xB6, opDATA.get("ADDR_ZPY"), 2, 4);
		setOp(opDATA.get("INS_LDX"), 0xAE, opDATA.get("ADDR_ABS"), 3, 4);
		setOp(opDATA.get("INS_LDX"), 0xBE, opDATA.get("ADDR_ABSY"), 3, 4);
		
		// LDY:
		setOp(opDATA.get("INS_LDY"), 0xA0, opDATA.get("ADDR_IMM"), 2, 2);
		setOp(opDATA.get("INS_LDY"), 0xA4, opDATA.get("ADDR_ZP"), 2, 3);
		setOp(opDATA.get("INS_LDY"), 0xB4, opDATA.get("ADDR_ZPX"), 2, 4);
		setOp(opDATA.get("INS_LDY"), 0xAC, opDATA.get("ADDR_ABS"), 3, 4);
		setOp(opDATA.get("INS_LDY"), 0xBC, opDATA.get("ADDR_ABSX"), 3, 4);
		
		// LSR:
		setOp(opDATA.get("INS_LSR"), 0x4A, opDATA.get("ADDR_ACC"), 1, 2);
		setOp(opDATA.get("INS_LSR"), 0x46, opDATA.get("ADDR_ZP"), 2, 5);
		setOp(opDATA.get("INS_LSR"), 0x56, opDATA.get("ADDR_ZPX"), 2, 6);
		setOp(opDATA.get("INS_LSR"), 0x4E, opDATA.get("ADDR_ABS"), 3, 6);
		setOp(opDATA.get("INS_LSR"), 0x5E, opDATA.get("ADDR_ABSX"), 3, 7);
		
		// NOP:
		setOp(opDATA.get("INS_NOP"), 0xEA, opDATA.get("ADDR_IMP"), 1, 2);
		
		// ORA:
		setOp(opDATA.get("INS_ORA"), 0x09, opDATA.get("ADDR_IMM"), 2, 2);
		setOp(opDATA.get("INS_ORA"), 0x05, opDATA.get("ADDR_ZP"), 2, 3);
		setOp(opDATA.get("INS_ORA"), 0x15, opDATA.get("ADDR_ZPX"), 2, 4);
		setOp(opDATA.get("INS_ORA"), 0x0D, opDATA.get("ADDR_ABS"), 3, 4);
		setOp(opDATA.get("INS_ORA"), 0x1D, opDATA.get("ADDR_ABSX"), 3, 4);
		setOp(opDATA.get("INS_ORA"), 0x19, opDATA.get("ADDR_ABSY"), 3, 4);
		setOp(opDATA.get("INS_ORA"), 0x01, opDATA.get("ADDR_PREIDXIND"), 2, 6);
		setOp(opDATA.get("INS_ORA"), 0x11, opDATA.get("ADDR_POSTIDXIND"), 2, 5);
		
		// PHA:
		setOp(opDATA.get("INS_PHA"), 0x48, opDATA.get("ADDR_IMP"), 1, 3);
		
		// PHP:
		setOp(opDATA.get("INS_PHP"), 0x08, opDATA.get("ADDR_IMP"), 1, 3);
		
		// PLA:
		setOp(opDATA.get("INS_PLA"), 0x68, opDATA.get("ADDR_IMP"), 1, 4);
		
		// PLP:
		setOp(opDATA.get("INS_PLP"), 0x28, opDATA.get("ADDR_IMP"), 1, 4);
		
		// ROL:
		setOp(opDATA.get("INS_ROL"), 0x2A, opDATA.get("ADDR_ACC"), 1, 2);
		setOp(opDATA.get("INS_ROL"), 0x26, opDATA.get("ADDR_ZP"), 2, 5);
		setOp(opDATA.get("INS_ROL"), 0x36, opDATA.get("ADDR_ZPX"), 2, 6);
		setOp(opDATA.get("INS_ROL"), 0x2E, opDATA.get("ADDR_ABS"), 3, 6);
		setOp(opDATA.get("INS_ROL"), 0x3E, opDATA.get("ADDR_ABSX"), 3, 7);
		
		// ROR:
		setOp(opDATA.get("INS_ROR"), 0x6A, opDATA.get("ADDR_ACC"), 1, 2);
		setOp(opDATA.get("INS_ROR"), 0x66, opDATA.get("ADDR_ZP"), 2, 5);
		setOp(opDATA.get("INS_ROR"), 0x76, opDATA.get("ADDR_ZPX"), 2, 6);
		setOp(opDATA.get("INS_ROR"), 0x6E, opDATA.get("ADDR_ABS"), 3, 6);
		setOp(opDATA.get("INS_ROR"), 0x7E, opDATA.get("ADDR_ABSX"), 3, 7);
		
		// RTI:
		setOp(opDATA.get("INS_RTI"), 0x40, opDATA.get("ADDR_IMP"), 1, 6);
		
		// RTS:
		setOp(opDATA.get("INS_RTS"), 0x60, opDATA.get("ADDR_IMP"), 1, 6);
		
		// SBC:
		setOp(opDATA.get("INS_SBC"), 0xE9, opDATA.get("ADDR_IMM"), 2, 2);
		setOp(opDATA.get("INS_SBC"), 0xE5, opDATA.get("ADDR_ZP"), 2, 3);
		setOp(opDATA.get("INS_SBC"), 0xF5, opDATA.get("ADDR_ZPX"), 2, 4);
		setOp(opDATA.get("INS_SBC"), 0xED, opDATA.get("ADDR_ABS"), 3, 4);
		setOp(opDATA.get("INS_SBC"), 0xFD, opDATA.get("ADDR_ABSX"), 3, 4);
		setOp(opDATA.get("INS_SBC"), 0xF9, opDATA.get("ADDR_ABSY"), 3, 4);
		setOp(opDATA.get("INS_SBC"), 0xE1, opDATA.get("ADDR_PREIDXIND"), 2, 6);
		setOp(opDATA.get("INS_SBC"), 0xF1, opDATA.get("ADDR_POSTIDXIND"), 2, 5);
		
		// SEC:
		setOp(opDATA.get("INS_SEC"), 0x38, opDATA.get("ADDR_IMP"), 1, 2);
		
		// SED:
		setOp(opDATA.get("INS_SED"), 0xF8, opDATA.get("ADDR_IMP"), 1, 2);
		
		// SEI:
		setOp(opDATA.get("INS_SEI"), 0x78, opDATA.get("ADDR_IMP"), 1, 2);
		
		// STA:
		setOp(opDATA.get("INS_STA"), 0x85, opDATA.get("ADDR_ZP"), 2, 3);
		setOp(opDATA.get("INS_STA"), 0x95, opDATA.get("ADDR_ZPX"), 2, 4);
		setOp(opDATA.get("INS_STA"), 0x8D, opDATA.get("ADDR_ABS"), 3, 4);
		setOp(opDATA.get("INS_STA"), 0x9D, opDATA.get("ADDR_ABSX"), 3, 5);
		setOp(opDATA.get("INS_STA"), 0x99, opDATA.get("ADDR_ABSY"), 3, 5);
		setOp(opDATA.get("INS_STA"), 0x81, opDATA.get("ADDR_PREIDXIND"), 2, 6);
		setOp(opDATA.get("INS_STA"), 0x91, opDATA.get("ADDR_POSTIDXIND"), 2, 6);
		
		// STX:
		setOp(opDATA.get("INS_STX"), 0x86, opDATA.get("ADDR_ZP"), 2, 3);
		setOp(opDATA.get("INS_STX"), 0x96, opDATA.get("ADDR_ZPY"), 2, 4);
		setOp(opDATA.get("INS_STX"), 0x8E, opDATA.get("ADDR_ABS"), 3, 4);
		
		// STY:
		setOp(opDATA.get("INS_STY"), 0x84, opDATA.get("ADDR_ZP"), 2, 3);
		setOp(opDATA.get("INS_STY"), 0x94, opDATA.get("ADDR_ZPX"), 2, 4);
		setOp(opDATA.get("INS_STY"), 0x8C, opDATA.get("ADDR_ABS"), 3, 4);
		
		// TAX:
		setOp(opDATA.get("INS_TAX"), 0xAA, opDATA.get("ADDR_IMP"), 1, 2);
		
		// TAY:
		setOp(opDATA.get("INS_TAY"), 0xA8, opDATA.get("ADDR_IMP"), 1, 2);
		
		// TSX:
		setOp(opDATA.get("INS_TSX"), 0xBA, opDATA.get("ADDR_IMP"), 1, 2);
		
		// TXA:
		setOp(opDATA.get("INS_TXA"), 0x8A, opDATA.get("ADDR_IMP"), 1, 2);
		
		// TXS:
		setOp(opDATA.get("INS_TXS"), 0x9A, opDATA.get("ADDR_IMP"), 1, 2);
		
		// TYA:
		setOp(opDATA.get("INS_TYA"), 0x98, opDATA.get("ADDR_IMP"), 1, 2);
	}
	
}
