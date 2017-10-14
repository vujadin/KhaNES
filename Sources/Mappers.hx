package;

/**
 * ...
 * @author Krtolica Vujadin
 */
// ported from vNES
class Mappers {
	public function new() {}
}

class Mapper001 extends MapperDefault {
	
	// 5-bit buffer:
    var regBuffer:Int;
    var regBufferCounter:Int;

    // Register 0:
    var mirroring:Int;
    var oneScreenMirroring:Int;
    var prgSwitchingArea:Int;
    var prgSwitchingSize:Int;
    var vromSwitchingSize:Int;

    // Register 1:
    var romSelectionReg0:Int;

    // Register 2:
    var romSelectionReg1:Int;

    // Register 3:
    var romBankSelect:Int;
	

	public function new(nes:NES) {
		super(nes);
		
		// 5-bit buffer:
		this.regBuffer = 0;
		this.regBufferCounter = 0;
		
		// Register 0:
		this.mirroring = 0;
		this.oneScreenMirroring = 0;
		this.prgSwitchingArea = 1;
		this.prgSwitchingSize = 1;
		this.vromSwitchingSize = 0;
		
		// Register 1:
		this.romSelectionReg0 = 0;
		
		// Register 2:
		this.romSelectionReg1 = 0;
		
		// Register 3:
		this.romBankSelect = 0;
	}
	
	public override function write(address:Int, value:Int) {
        // Writes to addresses other than MMC registers are handled by NoMapper.
		if (address < 0x8000) {
			super.write(address, value);
			return;
		}
		
		// See what should be done with the written value:
		if ((value & 128) != 0) {
			// Reset buffering:
			this.regBufferCounter = 0;
			this.regBuffer = 0;
					
			// Reset register:
			if (this.getRegNumber(address) == 0) {			
				this.prgSwitchingArea = 1;
				this.prgSwitchingSize = 1;			
			}
		}
		else {		
			// Continue buffering:
			//regBuffer = (regBuffer & (0xFF-(1<<regBufferCounter))) | ((value & (1<<regBufferCounter))<<regBufferCounter);
			this.regBuffer = (this.regBuffer & (0xFF - (1 << this.regBufferCounter))) | ((value & 1) << this.regBufferCounter);
			this.regBufferCounter++;
			
			if (this.regBufferCounter == 5) {
				// Use the buffered value:
				this.setReg(this.getRegNumber(address), this.regBuffer);
				
				// Reset buffer:
				this.regBuffer = 0;
				this.regBufferCounter = 0;
			}
		}
    }
	
	function setReg(reg:Int, value:Int) {
		var tmp:Int = 0;
		
		switch (reg) {
			case 0:
				// Mirroring:
				tmp = value & 3;
				if (tmp != this.mirroring) {
					// Set mirroring:
					this.mirroring = tmp;
					if ((this.mirroring & 2) == 0) {
						// SingleScreen mirroring overrides the other setting:
						this.nes.ppu.setMirroring(ROM.SINGLESCREEN_MIRRORING);
					}
					// Not overridden by SingleScreen mirroring.
					else if ((this.mirroring & 1) != 0) {
						this.nes.ppu.setMirroring(ROM.HORIZONTAL_MIRRORING);
					}
					else {
						this.nes.ppu.setMirroring(ROM.VERTICAL_MIRRORING);
					}
				}
				
				// PRG Switching Area;
				this.prgSwitchingArea = (value >> 2) & 1;
				
				// PRG Switching Size:
				this.prgSwitchingSize = (value >> 3) & 1;
				
				// VROM Switching Size:
				this.vromSwitchingSize = (value >> 4) & 1;
				
			case 1:
				// ROM selection:
				this.romSelectionReg0 = (value >> 4) & 1;
				
				// Check whether the cart has VROM:
				if (this.nes.rom.vromCount > 0) {					
					// Select VROM bank at 0x0000:
					if (this.vromSwitchingSize == 0) {			
						// Swap 8kB VROM:
						if (this.romSelectionReg0 == 0) {
							this.load8kVromBank((value & 0xF), 0x0000);
						}
						else {
							this.load8kVromBank(
								Math.floor(this.nes.rom.vromCount / 2) +
									(value & 0xF), 
								0x0000
							);
						}				
					}
					else {
						// Swap 4kB VROM:
						if (this.romSelectionReg0 == 0) {
							this.loadVromBank((value & 0xF), 0x0000);
						}
						else {
							this.loadVromBank(
								Math.floor(this.nes.rom.vromCount / 2) +
									(value & 0xF),
								0x0000
							);
						}
					}
				}
				
			case 2:
				// ROM selection:
				this.romSelectionReg1 = (value >> 4) & 1;
						
				// Check whether the cart has VROM:
				if (this.nes.rom.vromCount > 0) {					
					// Select VROM bank at 0x1000:
					if (this.vromSwitchingSize == 1) {
						// Swap 4kB of VROM:
						if (this.romSelectionReg1 == 0) {
							this.loadVromBank((value & 0xF), 0x1000);
						}
						else {
							this.loadVromBank(
								Math.floor(this.nes.rom.vromCount / 2) +
									(value & 0xF),
								0x1000
							);
						}
					}
				}
				
			default:
				// Select ROM bank:
				// -------------------------
				tmp = value & 0xF;
				var bank:Int = 0;
				var baseBank:Int = 0;
						
				if (this.nes.rom.romCount >= 32) {
					// 1024 kB cart
					if (this.vromSwitchingSize == 0) {
						if (this.romSelectionReg0 == 1) {
							baseBank = 16;
						}
					}
					else {
						baseBank = (this.romSelectionReg0 
									| (this.romSelectionReg1 << 1)) << 3;
					}
				}
				else if (this.nes.rom.romCount >= 16) {
					// 512 kB cart
					if (this.romSelectionReg0 == 1) {
						baseBank = 8;
					}
				}
				
				if (this.prgSwitchingSize == 0) {
					// 32kB
					bank = baseBank + (value & 0xF);
					this.load32kRomBank(bank, 0x8000);
				}
				else {
					// 16kB
					bank = baseBank * 2 + (value & 0xF);
					if (this.prgSwitchingArea == 0) {
						this.loadRomBank(bank, 0xC000);
					}
					else {
						this.loadRomBank(bank, 0x8000);
					}
				}  
		}
	}
	
	function getRegNumber(address:Int):Int {
		var ret:Int = 0;
		if (address >= 0x8000 && address <= 0x9FFF) {
			ret = 0;
		}
		else if (address >= 0xA000 && address <= 0xBFFF) {
			ret = 1;
		}
		else if (address >= 0xC000 && address <= 0xDFFF) {
			ret = 2;
		} 
		else {
			ret = 3;
		}
		
		return ret;
	}
	
	override function loadROM() {
		if (!this.nes.rom.valid) {
			trace("MMC1: Invalid ROM! Unable to load.");
			return;
		}
		
		// Load PRG-ROM:
		this.loadRomBank(0, 0x8000);                         //   First ROM bank..
		this.loadRomBank(this.nes.rom.romCount - 1, 0xC000); // ..and last ROM bank.
		
		// Load CHR-ROM:
		this.loadCHRROM();
		
		// Load Battery RAM (if present):
		this.loadBatteryRam();
		
		// Do Reset-Interrupt:
		this.nes.cpu.requestIrq(CPU.IRQ_RESET);
	}
	
	function switchLowHighPrgRom(oldSetting:Dynamic) {
		// not yet.
	}

	function switch16to32() {
		// not yet.
	}

	function switch32to16() {
		// not yet.
	}

	override function toJSON():Dynamic {
		var s = super.toJSON();
		s.mirroring = this.mirroring;
		s.oneScreenMirroring = this.oneScreenMirroring;
		s.prgSwitchingArea = this.prgSwitchingArea;
		s.prgSwitchingSize = this.prgSwitchingSize;
		s.vromSwitchingSize = this.vromSwitchingSize;
		s.romSelectionReg0 = this.romSelectionReg0;
		s.romSelectionReg1 = this.romSelectionReg1;
		s.romBankSelect = this.romBankSelect;
		s.regBuffer = this.regBuffer;
		s.regBufferCounter = this.regBufferCounter;
		return s;
	}

	override function fromJSON(s:Dynamic) {
		super.fromJSON(s);
		this.mirroring = s.mirroring;
		this.oneScreenMirroring = s.oneScreenMirroring;
		this.prgSwitchingArea = s.prgSwitchingArea;
		this.prgSwitchingSize = s.prgSwitchingSize;
		this.vromSwitchingSize = s.vromSwitchingSize;
		this.romSelectionReg0 = s.romSelectionReg0;
		this.romSelectionReg1 = s.romSelectionReg1;
		this.romBankSelect = s.romBankSelect;
		this.regBuffer = s.regBuffer;
		this.regBufferCounter = s.regBufferCounter;
	}
	
}

class Mapper002 extends MapperDefault {

	public function new(nes:NES) {
		super(nes);
	}
	
	override function write(address:Int, value:Int) {
		// Writes to addresses other than MMC registers are handled by NoMapper.
		if (address < 0x8000) {
			super.write(address, value);
			return;
		}

		// This is a ROM bank select command.
		// Swap in the given ROM bank at 0x8000:
		loadRomBank(value, 0x8000);
	}
	
	override function loadROM() {
		if (!nes.rom.valid) {
			trace("UNROM: Invalid ROM! Unable to load.");
			return;
		}

		// Load PRG-ROM:
		loadRomBank(0, 0x8000);
		loadRomBank(nes.rom.romCount - 1, 0xC000);

		// Load CHR-ROM:
		loadCHRROM();

		// Do Reset-Interrupt:
		nes.cpu.requestIrq(CPU.IRQ_RESET);
	}
	
}

class Mapper003 extends MapperDefault {

	public function new(nes:NES) {
		super(nes);
	}
	
	override public function write(address:Int, value:Int) {
        if (address < 0x8000) {
            // Let the base mapper take care of it.
            super.write(address, value);

        } else {
            // This is a VROM bank select command.
            // Swap in the given VROM bank at 0x0000:
            var bank = Std.int((value % (nes.rom.vromCount / 2)) * 2);
            loadVromBank(bank, 0x0000);
            loadVromBank(bank + 1, 0x1000);
            load8kVromBank(value * 2, 0x0000);
        }
    }
	
}

class Mapper004 extends MapperDefault {
	
	static inline var CMD_SEL_2_1K_VROM_0000:Int = 0;
	static inline var CMD_SEL_2_1K_VROM_0800:Int = 1;
	static inline var CMD_SEL_1K_VROM_1000:Int = 2;
	static inline var CMD_SEL_1K_VROM_1400:Int = 3;
	static inline var CMD_SEL_1K_VROM_1800:Int = 4;
	static inline var CMD_SEL_1K_VROM_1C00:Int = 5;
	static inline var CMD_SEL_ROM_PAGE1:Int = 6;
	static inline var CMD_SEL_ROM_PAGE2:Int = 7;
	
	var command:Int;
	var prgAddressSelect:Int;
	var chrAddressSelect:Int;
	var pageNumber:Int;
	var irqCounter:Int;
	var irqLatchValue:Int;
	var irqEnable:Int;
	var prgAddressChanged:Bool;

	public function new(nes:NES) {
		super(nes);		
		reset();
	}
	
	inline override public function write(address:Int, value:Int) {
		// Writes to addresses other than MMC registers are handled by NoMapper.
		if (address < 0x8000) {
			super.write(address, value);
			return;
		}

		switch (address) {
			case 0x8000:
				// Command/Address Select register
				command = value & 7;
				var tmp = (value >> 6) & 1;
				if (tmp != prgAddressSelect) {
					prgAddressChanged = true;
				}
				prgAddressSelect = tmp;
				chrAddressSelect = (value >> 7) & 1;
		
			case 0x8001:
				// Page number for command
				executeCommand(command, value);
		
			case 0xA000:        
				// Mirroring select
				if ((value & 1) != 0) {
					nes.ppu.setMirroring(ROM.HORIZONTAL_MIRRORING);
				}
				else {
					nes.ppu.setMirroring(ROM.VERTICAL_MIRRORING);
				}
			
			case 0xA001:
				// SaveRAM Toggle
				// TODO
				//nes.rom.setSaveState((value&1)!=0);
		
			case 0xC000:
				// IRQ Counter register
				irqCounter = value;
				//nes.ppu.mapperIrqCounter = 0;
		
			case 0xC001:
				// IRQ Latch register
				irqLatchValue = value;
		
			case 0xE000:
				// IRQ Control Reg 0 (disable)
				//irqCounter = irqLatchValue;
				irqEnable = 0;
		
			case 0xE001:        
				// IRQ Control Reg 1 (enable)
				irqEnable = 1;
		
			default:
				// Not a MMC3 register.
				// The game has probably crashed,
				// since it tries to write to ROM..
				// IGNORE.
		}
	}
	
	inline function executeCommand(cmd:Int, arg:Int) {
		switch (cmd) {
			case Mapper004.CMD_SEL_2_1K_VROM_0000:
				// Select 2 1KB VROM pages at 0x0000:
				if (chrAddressSelect == 0) {
					load1kVromBank(arg, 0x0000);
					load1kVromBank(arg + 1, 0x0400);
				}
				else {
					load1kVromBank(arg, 0x1000);
					load1kVromBank(arg + 1, 0x1400);
				}
			
			case Mapper004.CMD_SEL_2_1K_VROM_0800:           
				// Select 2 1KB VROM pages at 0x0800:
				if (chrAddressSelect == 0) {
					load1kVromBank(arg, 0x0800);
					load1kVromBank(arg + 1, 0x0C00);
				}
				else {
					load1kVromBank(arg, 0x1800);
					load1kVromBank(arg + 1, 0x1C00);
				}
		
			case Mapper004.CMD_SEL_1K_VROM_1000:         
				// Select 1K VROM Page at 0x1000:
				if (chrAddressSelect == 0) {
					load1kVromBank(arg, 0x1000);
				}
				else {
					load1kVromBank(arg, 0x0000);
				}
		
			case Mapper004.CMD_SEL_1K_VROM_1400:         
				// Select 1K VROM Page at 0x1400:
				if (chrAddressSelect == 0) {
					load1kVromBank(arg, 0x1400);
				}
				else {
					load1kVromBank(arg, 0x0400);
				}
		
			case Mapper004.CMD_SEL_1K_VROM_1800:
				// Select 1K VROM Page at 0x1800:
				if (chrAddressSelect == 0) {
					load1kVromBank(arg, 0x1800);
				}
				else {
					load1kVromBank(arg, 0x0800);
				}
		
			case Mapper004.CMD_SEL_1K_VROM_1C00:
				// Select 1K VROM Page at 0x1C00:
				if (chrAddressSelect == 0) {
					load1kVromBank(arg, 0x1C00);
				}else {
					load1kVromBank(arg, 0x0C00);
				}
		
			case Mapper004.CMD_SEL_ROM_PAGE1:
				if (prgAddressChanged) {
					// Load the two hardwired banks:
					if (prgAddressSelect == 0) { 
						load8kRomBank(((nes.rom.romCount - 1) * 2), 0xC000);
					}
					else {
						load8kRomBank(((nes.rom.romCount - 1) * 2), 0x8000);
					}
					prgAddressChanged = false;
				}
		
				// Select first switchable ROM page:
				if (prgAddressSelect == 0) {
					load8kRomBank(arg, 0x8000);
				}
				else {
					load8kRomBank(arg, 0xC000);
				}
			
			case Mapper004.CMD_SEL_ROM_PAGE2:
				// Select second switchable ROM page:
				load8kRomBank(arg, 0xA000);
		
				// hardwire appropriate bank:
				if (prgAddressChanged) {
					// Load the two hardwired banks:
					if (prgAddressSelect == 0) { 
						load8kRomBank(((nes.rom.romCount - 1) * 2), 0xC000);
					}
					else {              
						load8kRomBank(((nes.rom.romCount - 1) * 2), 0x8000);
					}
					prgAddressChanged = false;
				}
		}
	}
	
	override public function loadROM() {
		if (!nes.rom.valid) {
			trace("Mapper 004: Invalid ROM! Unable to load.");
			return;
		}

		// Load hardwired PRG banks (0xC000 and 0xE000):
		load8kRomBank(((nes.rom.romCount - 1) * 2), 0xC000);
		load8kRomBank(((nes.rom.romCount - 1) * 2) + 1, 0xE000);

		// Load swappable PRG banks (0x8000 and 0xA000):
		load8kRomBank(0, 0x8000);
		load8kRomBank(1, 0xA000);

		// Load CHR-ROM:
		loadCHRROM();

		// Load Battery RAM (if present):
		loadBatteryRam();

		// Do Reset-Interrupt:
		nes.cpu.requestIrq(CPU.IRQ_RESET);
	}
	
	inline override function clockIrqCounter() {
		if (irqEnable == 1) {
			irqCounter--;
			if (irqCounter < 0) {
				// Trigger IRQ:
				nes.cpu.requestIrq(CPU.IRQ_NORMAL);
				irqCounter = irqLatchValue;
			}
		}
	}
	
	override public function reset() {
		super.reset();
        command = 0;
        prgAddressSelect = 0;
        chrAddressSelect = 0;
        pageNumber = 0;
        irqCounter = 0;
        irqLatchValue = 0;
        irqEnable = 0;
        prgAddressChanged = false;
    }
	
	override public function toJSON():Dynamic {
		var s = super.toJSON();
		s.command = command;
		s.prgAddressSelect = prgAddressSelect;
		s.chrAddressSelect = chrAddressSelect;
		s.pageNumber = pageNumber;
		s.irqCounter = irqCounter;
		s.irqLatchValue = irqLatchValue;
		s.irqEnable = irqEnable;
		s.prgAddressChanged = prgAddressChanged;
		return s;
	}
	
	override public function fromJSON(s:Dynamic) {
		super.fromJSON(s);
		command = s.command;
		prgAddressSelect = s.prgAddressSelect;
		chrAddressSelect = s.chrAddressSelect;
		pageNumber = s.pageNumber;
		irqCounter = s.irqCounter;
		irqLatchValue = s.irqLatchValue;
		irqEnable = s.irqEnable;
		prgAddressChanged = s.prgAddressChanged;
	}
	
}

class Mapper007 extends MapperDefault {
	
	var currentOffset:Int;
    var currentMirroring:Int;
    var prgrom:Array<Int>;

	public function new(nes:NES) {
		super(nes);
		
		currentOffset = 0;
        currentMirroring = -1;

        // Read out all PRG rom:
        var bc = nes.rom.romCount;
        prgrom = [];
        for (i in 0...bc) {
			//Utils.copyArrayElements(nes.rom.rom[i], 0, prgrom, i * 16384, 16384);
			
			for (u in 0...16384) {
				prgrom[(i * 16384) + u] = nes.rom.rom[i][u];
			}
        }
	}
	
	override public function load(address:Int):Int {
        if (address < 0x8000) {
            // Register read
            return super.load(address);
        } else {
            if ((address + currentOffset) >= 262144) {
                return prgrom[(address + currentOffset) - 262144];
            } else {
                return prgrom[address + currentOffset];
            }
        }
    }

    override public function write(address:Int, value:Int) {
        if (address < 0x8000) {
            // Let the base mapper take care of it.
            super.write(address, value);
        } else {
            // Set PRG offset:
            currentOffset = ((value & 0xF) - 1) << 15;

            // Set mirroring:
            if (currentMirroring != (value & 0x10)) {
                currentMirroring = value & 0x10;
                if (currentMirroring == 0) {
                    nes.ppu.setMirroring(ROM.SINGLESCREEN_MIRRORING);
                } else {
                    nes.ppu.setMirroring(ROM.SINGLESCREEN_MIRRORING2);
                }
            }
        }
    }

    override function reset() {
        super.reset();
        currentOffset = 0;
        currentMirroring = -1;
    }
	
}

class Mapper009 extends MapperDefault {
	
	var latchLo:Int;
    var latchHi:Int;
    var latchLoVal1:Int;
    var latchLoVal2:Int;
    var latchHiVal1:Int;
    var latchHiVal2:Int;

	public function new(nes:NES) {
		super(nes);
		reset();
	}
	
	override public function write(address:Int, value:Int) {
        if (address < 0x8000) {
            // Handle normally.
            super.write(address, value);
        } else {
            // MMC2 write.
            value &= 0xFF;
            address &= 0xF000;
            switch (address >> 12) {
                case 0xA: 
                    // Select 8k ROM bank at 0x8000
                    load8kRomBank(value, 0x8000);
                
                case 0xB: 
                    // Select 4k VROM bank at 0x0000, $FD mode
                    latchLoVal1 = value;
                    if (latchLo == 0xFD) {
                        loadVromBank(value, 0x0000);
                    }
                
                case 0xC: 
                    // Select 4k VROM bank at 0x0000, $FE mode
                    latchLoVal2 = value;
                    if (latchLo == 0xFE) {
                        loadVromBank(value, 0x0000);
                    }

                
                case 0xD: 
                    // Select 4k VROM bank at 0x1000, $FD mode
                    latchHiVal1 = value;
                    if (latchHi == 0xFD) {
                        loadVromBank(value, 0x1000);
                    }
                
                case 0xE: 
                    // Select 4k VROM bank at 0x1000, $FE mode
                    latchHiVal2 = value;
                    if (latchHi == 0xFE) {
                        loadVromBank(value, 0x1000);
                    }
                
                case 0xF: 
                    // Select mirroring
                    if ((value & 0x1) == 0) {
                        // Vertical mirroring
                        nes.ppu.setMirroring(ROM.VERTICAL_MIRRORING);

                    } else {
                        // Horizontal mirroring
                        nes.ppu.setMirroring(ROM.HORIZONTAL_MIRRORING);
                    }
                
            }
        }
    }

    override public function loadROM() {
        if (!nes.rom.valid) {
            trace("MMC2: Invalid ROM! Unable to load.");
            return;
        }

        // Get number of 8K banks:
        var num_8k_banks = nes.rom.romCount * 2;

        // Load PRG-ROM:
        load8kRomBank(0, 0x8000);
        load8kRomBank(num_8k_banks - 3, 0xA000);
        load8kRomBank(num_8k_banks - 2, 0xC000);
        load8kRomBank(num_8k_banks - 1, 0xE000);

        // Load CHR-ROM:
        loadCHRROM();

        // Load Battery RAM (if present):
        loadBatteryRam();

        // Do Reset-Interrupt:
        nes.cpu.requestIrq(CPU.IRQ_RESET);
    }

    override public function latchAccess(address:Int) {
        if ((address & 0x1FF0) == 0x0FD0 && latchLo != 0xFD) {
            // Set $FD mode
            loadVromBank(latchLoVal1, 0x0000);
            latchLo = 0xFD;
        } else if ((address & 0x1FF0) == 0x0FE0 && latchLo != 0xFE) {
            // Set $FE mode
            loadVromBank(latchLoVal2, 0x0000);
            latchLo = 0xFE;
        } else if ((address & 0x1FF0) == 0x1FD0 && latchHi != 0xFD) {
            // Set $FD mode
            loadVromBank(latchHiVal1, 0x1000);
            latchHi = 0xFD;
        } else if ((address & 0x1FF0) == 0x1FE0 && latchHi != 0xFE) {
            // Set $FE mode
            loadVromBank(latchHiVal2, 0x1000);
            latchHi = 0xFE;
        }
    }

    override public function reset() {
        // Set latch to $FE mode:
        latchLo = 0xFE;
        latchHi = 0xFE;
        latchLoVal1 = 0;
        latchLoVal2 = 4;
        latchHiVal1 = 0;
        latchHiVal2 = 0;
    }
	
}

class Mapper010 extends MapperDefault { 
	
	var latchLo:Int;
    var latchHi:Int;
    var latchLoVal1:Int;
    var latchLoVal2:Int;
    var latchHiVal1:Int;
    var latchHiVal2:Int;

	public function new(nes:NES) {
		super(nes);
		reset();
	}
	
	override public function write(address:Int, value:Int) {
        if (address < 0x8000) {
            // Handle normally.
            super.write(address, value);
        } else {
            // MMC4 write.
            value &= 0xFF;
            switch (address >> 12) {
                case 0xA: 
                    // Select 8k ROM bank at 0x8000
                    loadRomBank(value, 0x8000);
                
                case 0xB: 
                    // Select 4k VROM bank at 0x0000, $FD mode
                    latchLoVal1 = value;
                    if (latchLo == 0xFD) {
                        loadVromBank(value, 0x0000);
                    }
                
                case 0xC: 
                    // Select 4k VROM bank at 0x0000, $FE mode
                    latchLoVal2 = value;
                    if (latchLo == 0xFE) {
                        loadVromBank(value, 0x0000);
                    }
                
                case 0xD: 
                    // Select 4k VROM bank at 0x1000, $FD mode
                    latchHiVal1 = value;
                    if (latchHi == 0xFD) {
                        loadVromBank(value, 0x1000);
                    }
                
                case 0xE: 
                    // Select 4k VROM bank at 0x1000, $FE mode
                    latchHiVal2 = value;
                    if (latchHi == 0xFE) {
                        loadVromBank(value, 0x1000);
                    }
                
                case 0xF: 
                    // Select mirroring
                    if ((value & 0x1) == 0) {
                        // Vertical mirroring
                        nes.ppu.setMirroring(ROM.VERTICAL_MIRRORING);
                    } else {
                        // Horizontal mirroring
                        nes.ppu.setMirroring(ROM.HORIZONTAL_MIRRORING);
                    }                
            }
        }
    }

    override public function loadROM() {
        if (!nes.rom.valid) {
            trace("MMC2: Invalid ROM! Unable to load.");
            return;
        }

        // Get number of 16K banks:
        var num_16k_banks = nes.rom.romCount * 4;

        // Load PRG-ROM:
        loadRomBank(0, 0x8000);
        loadRomBank(num_16k_banks - 1, 0xC000);

        // Load CHR-ROM:
        loadCHRROM();

        // Load Battery RAM (if present):
        loadBatteryRam();

        // Do Reset-Interrupt:
        nes.cpu.requestIrq(CPU.IRQ_RESET);
    }

    override public function latchAccess(address:Int) {
        var lo = address < 0x2000;
        address &= 0x0FF0;

        if (lo) {
            // Switch lo part of CHR
            if (address == 0xFD0) {
                // Set $FD mode
                latchLo = 0xFD;
                loadVromBank(latchLoVal1, 0x0000);

            } else if (address == 0xFE0) {
                // Set $FE mode
                latchLo = 0xFE;
                loadVromBank(latchLoVal2, 0x0000);
            }
        } else {
            // Switch hi part of CHR
            if (address == 0xFD0) {
                // Set $FD mode
                latchHi = 0xFD;
                loadVromBank(latchHiVal1, 0x1000);

            } else if (address == 0xFE0) {
                // Set $FE mode
                latchHi = 0xFE;
                loadVromBank(latchHiVal2, 0x1000);
            }
        }
    }

    override public function reset() {
        // Set latch to $FE mode:
        latchLo = 0xFE;
        latchHi = 0xFE;
        latchLoVal1 = 0;
        latchLoVal2 = 4;
        latchHiVal1 = 0;
        latchHiVal2 = 0;
    }
	
}

class Mapper011 extends MapperDefault {

	public function new(nes:NES) {
		super(nes);
	}
	
	override public function write(address:Int, value:Int) {

        if (address < 0x8000) {
            // Let the base mapper take care of it.
            super.write(address, value);

        } else {
            // Swap in the given PRG-ROM bank:
            var prgbank1 = ((value & 0xF) * 2) % nes.rom.romCount;
            var prgbank2 = ((value & 0xF) * 2 + 1) % nes.rom.romCount;

            loadRomBank(prgbank1, 0x8000);
            loadRomBank(prgbank2, 0xC000);


            if (nes.rom.romCount > 0) {
                // Swap in the given VROM bank at 0x0000:
                var bank = ((value >> 4) * 2) % nes.rom.romCount;
                loadVromBank(bank, 0x0000);
                loadVromBank(bank + 1, 0x1000);
            }
        }
    }
	
}

class Mapper015 extends MapperDefault {

	public function new(nes:NES) {
		super(nes);
	}
	
	override public function write(address:Int, value:Int) {

        if (address < 0x8000) {
            super.write(address, value);
        } else {
            switch (address) {
                case 0x8000:                     
					if ((value & 0x80) != 0) {
						load8kRomBank((value & 0x3F) * 2 + 1, 0x8000);
						load8kRomBank((value & 0x3F) * 2 + 0, 0xA000);
						load8kRomBank((value & 0x3F) * 2 + 3, 0xC000);
						load8kRomBank((value & 0x3F) * 2 + 2, 0xE000);
					} else {
						load8kRomBank((value & 0x3F) * 2 + 0, 0x8000);
						load8kRomBank((value & 0x3F) * 2 + 1, 0xA000);
						load8kRomBank((value & 0x3F) * 2 + 2, 0xC000);
						load8kRomBank((value & 0x3F) * 2 + 3, 0xE000);
					}
					if ((value & 0x40) != 0) {
						nes.ppu.setMirroring(ROM.HORIZONTAL_MIRRORING);
					} else {
						nes.ppu.setMirroring(ROM.VERTICAL_MIRRORING);
					}
                   
                case 0x8001:                     
					if ((value & 0x80) != 0) {
						load8kRomBank((value & 0x3F) * 2 + 1, 0xC000);
						load8kRomBank((value & 0x3F) * 2 + 0, 0xE000);
					} else {
						load8kRomBank((value & 0x3F) * 2 + 0, 0xC000);
						load8kRomBank((value & 0x3F) * 2 + 1, 0xE000);
					}
                  
                case 0x8002:                     
					if ((value & 0x80) != 0) {
						load8kRomBank((value & 0x3F) * 2 + 1, 0x8000);
						load8kRomBank((value & 0x3F) * 2 + 1, 0xA000);
						load8kRomBank((value & 0x3F) * 2 + 1, 0xC000);
						load8kRomBank((value & 0x3F) * 2 + 1, 0xE000);
					} else {
						load8kRomBank((value & 0x3F) * 2, 0x8000);
						load8kRomBank((value & 0x3F) * 2, 0xA000);
						load8kRomBank((value & 0x3F) * 2, 0xC000);
						load8kRomBank((value & 0x3F) * 2, 0xE000);
					}
                    
                case 0x8003:                     
					if ((value & 0x80) != 0) {
						load8kRomBank((value & 0x3F) * 2 + 1, 0xC000);
						load8kRomBank((value & 0x3F) * 2 + 0, 0xE000);
					} else {
						load8kRomBank((value & 0x3F) * 2 + 0, 0xC000);
						load8kRomBank((value & 0x3F) * 2 + 1, 0xE000);
					}
					if ((value & 0x40) != 0) {
						nes.ppu.setMirroring(ROM.HORIZONTAL_MIRRORING);
					} else {
						nes.ppu.setMirroring(ROM.VERTICAL_MIRRORING);
					}
                    
            }
        }
    }

    override public function loadROM() {
        if (!nes.rom.valid) {
            trace("015: Invalid ROM! Unable to load.");
            return;
        }

        // Load PRG-ROM:
        load8kRomBank(0, 0x8000);
        load8kRomBank(1, 0xA000);
        load8kRomBank(2, 0xC000);
        load8kRomBank(3, 0xE000);

        // Load CHR-ROM:
        loadCHRROM();

        // Load Battery RAM (if present):
        loadBatteryRam();

        // Do Reset-Interrupt:
        nes.cpu.requestIrq(CPU.IRQ_RESET);
    }
	
}

class Mapper018 extends MapperDefault {
	
	var irq_counter:Int = 0;
    var irq_latch:Int = 0;
    var irq_enabled:Bool = false;
    var regs:Array<Int>;
    var num_8k_banks:Int;
    var patch:Int = 0;

	public function new(nes:NES) {
		super(nes);
		reset();
	}
	
    override public function write(address:Int, value:Int) {

        if (address < 0x8000) {
            super.write(address, value);
        } else {
            switch (address) {
                case 0x8000:
                    regs[0] = (regs[0] & 0xF0) | (value & 0x0F);
                    load8kRomBank(regs[0], 0x8000);

                case 0x8001:
                    regs[0] = (regs[0] & 0x0F) | ((value & 0x0F) << 4);
                    load8kRomBank(regs[0], 0x8000);

                case 0x8002:
                    regs[1] = (regs[1] & 0xF0) | (value & 0x0F);
                    load8kRomBank(regs[1], 0xA000);

                case 0x8003:
                    regs[1] = (regs[1] & 0x0F) | ((value & 0x0F) << 4);
                    load8kRomBank(regs[1], 0xA000);

                case 0x9000:
                    regs[2] = (regs[2] & 0xF0) | (value & 0x0F);
                    load8kRomBank(regs[2], 0xC000);

                case 0x9001:
                    regs[2] = (regs[2] & 0x0F) | ((value & 0x0F) << 4);
                    load8kRomBank(regs[2], 0xC000);

                case 0xA000:
                    regs[3] = (regs[3] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[3], 0x0000);

                case 0xA001:
                    regs[3] = (regs[3] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[3], 0x0000);

                case 0xA002:
                    regs[4] = (regs[4] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[4], 0x0400);

                case 0xA003:
                    regs[4] = (regs[4] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[4], 0x0400);

                case 0xB000:
                    regs[5] = (regs[5] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[5], 0x0800);

                case 0xB001:
                    regs[5] = (regs[5] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[5], 0x0800);

                case 0xB002:
                    regs[6] = (regs[6] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[6], 0x0C00);

                case 0xB003:
                    regs[6] = (regs[6] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[6], 0x0C00);

                case 0xC000:
                    regs[7] = (regs[7] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[7], 0x1000);

                case 0xC001:
                    regs[7] = (regs[7] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[7], 0x1000);

                case 0xC002:
                    regs[8] = (regs[8] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[8], 0x1400);

                case 0xC003:
                    regs[8] = (regs[8] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[8], 0x1400);

                case 0xD000:
                    regs[9] = (regs[9] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[9], 0x1800);

                case 0xD001:
                    regs[9] = (regs[9] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[9], 0x1800);

                case 0xD002:
                    regs[10] = (regs[10] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[10], 0x1C00);

                case 0xD003:
                    regs[10] = (regs[10] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[10], 0x1C00);

                case 0xE000:
                    irq_latch = (irq_latch & 0xFFF0) | (value & 0x0F);

                case 0xE001:
                    irq_latch = (irq_latch & 0xFF0F) | ((value & 0x0F) << 4);

                case 0xE002:
                    irq_latch = (irq_latch & 0xF0FF) | ((value & 0x0F) << 8);

                case 0xE003:
                    irq_latch = (irq_latch & 0x0FFF) | ((value & 0x0F) << 12);
                    
                case 0xF000:
                    irq_counter = irq_latch;                    

                case 0xF001:
                    irq_enabled = (value & 0x01) != 0;                    

                case 0xF002:                     
					value &= 0x03;

					if (value == 0) {
						nes.ppu.setMirroring(ROM.HORIZONTAL_MIRRORING);
					} else if (value == 1) {
						nes.ppu.setMirroring(ROM.VERTICAL_MIRRORING);
					} else {
						nes.ppu.setMirroring(ROM.SINGLESCREEN_MIRRORING);
					}

            }
        }
    }

    override public function loadROM() {
        if (!nes.rom.valid) {
            trace("VRC2: Invalid ROM! Unable to load.");
            return;
        }

        // Get number of 8K banks:
        num_8k_banks = nes.rom.romCount * 2;

        // Load PRG-ROM:
        load8kRomBank(0, 0x8000);
        load8kRomBank(1, 0xA000);
        load8kRomBank(num_8k_banks - 2, 0xC000);
        load8kRomBank(num_8k_banks - 1, 0xE000);

        // Load CHR-ROM:
        loadCHRROM();

        loadBatteryRam();

        // Do Reset-Interrupt:
        nes.cpu.requestIrq(CPU.IRQ_RESET);
    }

    public function syncH(scanline:Int) {
        if (irq_enabled) {
            if (irq_counter <= 113) {
                irq_counter = (patch == 1) ? 114 : 0;
                irq_enabled = false;
                return 3;
				
            } else {
                irq_counter -= 113;
            }
        }

        return 0;
    }

    override public function reset() {
		regs = [];
        regs[0] = 0;
        regs[1] = 1;
        regs[2] = num_8k_banks - 2;
        regs[3] = num_8k_banks - 1;
        regs[4] = 0;
        regs[5] = 0;
        regs[6] = 0;
        regs[7] = 0;
        regs[8] = 0;
        regs[9] = 0;
        regs[10] = 0;

        // IRQ Settings
        irq_enabled = false;
        irq_latch = 0;
        irq_counter = 0;
    }
	
}

class Mapper021 extends MapperDefault {
	
	private var irq_counter:Int = 0;
    private var irq_latch:Int = 0;
    private var irq_enabled:Int = 0;
    private var regs:Array<Int>;

	public function new(nes:NES) {
		super(nes);
		reset();
	}
	
	override public function write(address:Int, value:Int) {
        if (address < 0x8000) {
            super.write(address, value);
        } else {
            switch (address & 0xF0CF) {
                case 0x8000:                    
					if ((regs[8] & 0x02) != 0) {
						load8kRomBank(value, 0xC000);
					} else {
						load8kRomBank(value, 0x8000);
					}
                    
                case 0xA000:
                    load8kRomBank(value, 0xA000);
                   
                case 0x9000:
                    value &= 0x03;
					if (value == 0) {
						nes.ppu.setMirroring(ROM.VERTICAL_MIRRORING);
					} else if (value == 1) {
						nes.ppu.setMirroring(ROM.HORIZONTAL_MIRRORING);
					} else if (value == 2) {
						nes.ppu.setMirroring(ROM.SINGLESCREEN_MIRRORING);
					} else {
						nes.ppu.setMirroring(ROM.SINGLESCREEN_MIRRORING2);
					}
                    
                case 0x9002, 0x9080:
                    regs[8] = value;
                    
                case 0xB000:
                    regs[0] = (regs[0] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[0], 0x0000);
                    
                case 0xB002, 0xB040:
                    regs[0] = (regs[0] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[0], 0x0000);
                    
                case 0xB001, 0xB004, 0xB080:
                    regs[1] = (regs[1] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[1], 0x0400);
                    
                case 0xB003, 0xB006, 0xB0C0:
                    regs[1] = (regs[1] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[1], 0x0400);
                    
                case 0xC000:
                    regs[2] = (regs[2] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[2], 0x0800);
                    
                case 0xC002, 0xC040:
                    regs[2] = (regs[2] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[2], 0x0800);
                    
                case 0xC001, 0xC004, 0xC080:
                    regs[3] = (regs[3] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[3], 0x0C00);
                    
                case 0xC003, 0xC006, 0xC0C0:
                    regs[3] = (regs[3] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[3], 0x0C00);
                    
                case 0xD000:
                    regs[4] = (regs[4] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[4], 0x1000);
                    
                case 0xD040, 0xD002:
                    regs[4] = (regs[4] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[4], 0x1000);
                    
                case 0xD080, 0xD004, 0xD001:
                    regs[5] = (regs[5] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[5], 0x1400);
                    
                case 0xD0C0, 0xD006, 0xD003:
                    regs[5] = (regs[5] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[5], 0x1400);
                    
                case 0xE000:
                    regs[6] = (regs[6] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[6], 0x1800);
                    
                case 0xE040, 0xE002:
                    regs[6] = (regs[6] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[6], 0x1800);
                                        
                case 0xE080, 0xE004, 0xE001:
                    regs[7] = (regs[7] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[7], 0x1C00);
                                        
                case 0xE0C0, 0xE003, 0xE006:
                    regs[7] = (regs[7] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[7], 0x1C00);
                    
                case 0xF000:
                    irq_latch = (irq_latch & 0xF0) | (value & 0x0F);
                    
                case 0xF040, 0xF002:
                    irq_latch = (irq_latch & 0x0F) | ((value & 0x0F) << 4);
                    
                case 0xF0C0, 0xF003:
                    irq_enabled = (irq_enabled & 0x01) * 3;

                case 0xF080, 0xF004:                     
					irq_enabled = value & 0x03;
					if ((irq_enabled & 0x02) != 0) {
						irq_counter = irq_latch;
					}
                    
            }
        }
    }

    override public function loadROM() {
        if (!nes.rom.valid) {
            trace("VRC4: Invalid ROM! Unable to load.");
            return;
        }

        // Get number of 8K banks:
        var num_8k_banks = nes.rom.romCount * 2;

        // Load PRG-ROM:
        load8kRomBank(0, 0x8000);
        load8kRomBank(1, 0xA000);
        load8kRomBank(num_8k_banks - 2, 0xC000);
        load8kRomBank(num_8k_banks - 1, 0xE000);

        // Load CHR-ROM:
        loadCHRROM();

        // Load Battery RAM (if present):
        loadBatteryRam();

        // Do Reset-Interrupt:
        nes.cpu.requestIrq(CPU.IRQ_RESET);
    }

    public function syncH(scanline:Int):Int {
        if ((irq_enabled & 0x02) != 0) {
            if (irq_counter == 0) {
                irq_counter = irq_latch;
                irq_enabled = (irq_enabled & 0x01) * 3;
                return 3;
            } else {
                irq_counter++;
            }
        }

        return 0;
    }

    override public function reset() {
		regs = [];
        regs[0] = 0;
        regs[1] = 1;
        regs[2] = 2;
        regs[3] = 3;
        regs[4] = 4;
        regs[5] = 5;
        regs[6] = 6;
        regs[7] = 7;
        regs[8] = 0;

        // IRQ Settings
        irq_enabled = 0;
        irq_latch = 0;
        irq_counter = 0;
    }
	
}

class Mapper022 extends MapperDefault {

	public function new(nes:NES) {
		super(nes);
		reset();
	}
	
	override public function write(address:Int, value:Int) {
        if (address < 0x8000) {
            super.write(address, value);
        } else {
            //VRC2 write.
            switch (address) {
                case 0x8000:
                    load8kRomBank(value, 0x8000);
                    
                case 0x9000:
                    value &= 0x03;
					if (value == 0) {
						nes.ppu.setMirroring(ROM.VERTICAL_MIRRORING);
					} else if (value == 1) {
						nes.ppu.setMirroring(ROM.HORIZONTAL_MIRRORING);
					} else if (value == 2) {
						nes.ppu.setMirroring(ROM.SINGLESCREEN_MIRRORING);
					} else {
						nes.ppu.setMirroring(ROM.SINGLESCREEN_MIRRORING2);
					}
                    
                case 0xA000:
                    load8kRomBank(value, 0xA000);
                    
                case 0xB000:
                    load1kVromBank((value >> 1), 0x0000);
                    
                case 0xB001:
                    load1kVromBank((value >> 1), 0x0400);
                    
                case 0xC000:
                    load1kVromBank((value >> 1), 0x0800);
                    
                case 0xC001:
                    load1kVromBank((value >> 1), 0x0C00);
                    
                case 0xD000:
                    load1kVromBank((value >> 1), 0x1000);
                    
                case 0xD001:
                    load1kVromBank((value >> 1), 0x1400);
                    
                case 0xE000:
                    load1kVromBank((value >> 1), 0x1800);
                    
                case 0xE001:
                    load1kVromBank((value >> 1), 0x1C00);
                    
            }
        }

    }

    override public function loadROM() {
        if (!nes.rom.valid) {
            trace("VRC2: Invalid ROM! Unable to load.");
            return;
        }

        // Get number of 8K banks:
        var num_8k_banks = nes.rom.romCount * 2;

        // Load PRG-ROM:
        load8kRomBank(0, 0x8000);
        load8kRomBank(1, 0xA000);
        load8kRomBank(num_8k_banks - 2, 0xC000);
        load8kRomBank(num_8k_banks - 1, 0xE000);

        // Load CHR-ROM:
        loadCHRROM();

        // Do Reset-Interrupt:
        nes.cpu.requestIrq(CPU.IRQ_RESET);
    }
	
}

class Mapper023 extends MapperDefault {
	
	var irq_counter:Int;
    var irq_latch:Int;
    var irq_enabled:Int;
    var regs:Array<Int>;
    static inline var patch:Int = 0xFFFF;

	public function new(nes:NES) {
		super(nes);
		reset();
	}
	
	override public function write(address:Int, value:Int) {

        if (address < 0x8000) {
            super.write(address, value);
        } else {
            switch (address & patch) {
                case 0x8000, 0x8004, 0x8008, 0x800C:
					if ((regs[8]) != 0) {
						load8kRomBank(value, 0xC000);
					} else {
						load8kRomBank(value, 0x8000);
					}
                    
                case 0x9000:
					if (value != 0xFF) {
						value &= 0x03;
						if (value == 0) {
							nes.ppu.setMirroring(ROM.VERTICAL_MIRRORING);
						} else if (value == 1) {
							nes.ppu.setMirroring(ROM.HORIZONTAL_MIRRORING);
						} else if (value == 2) {
							nes.ppu.setMirroring(ROM.SINGLESCREEN_MIRRORING);
						} else {
							nes.ppu.setMirroring(ROM.SINGLESCREEN_MIRRORING2);
						}
					}
                    
                case 0x9008:
                    regs[8] = value & 0x02;
                    
                case 0xA000, 0xA004, 0xA008, 0xA00C:
                    load8kRomBank(value, 0xA000);
                    
                case 0xB000:
                    regs[0] = (regs[0] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[0], 0x0000);
                    
                case 0xB001, 0xB004:
                    regs[0] = (regs[0] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[0], 0x0000);
                    
                case 0xB002, 0xB008:
                    regs[1] = (regs[1] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[1], 0x0400);
                    
                case 0xB003, 0xB00C:
                    regs[1] = (regs[1] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[1], 0x0400);
                    
                case 0xC000:
                    regs[2] = (regs[2] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[2], 0x0800);
                    
                case 0xC001, 0xC004:
                    regs[2] = (regs[2] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[2], 0x0800);
                    
                case 0xC002, 0xC008:
                    regs[3] = (regs[3] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[3], 0x0C00);
                    
                case 0xC003, 0xC00C:
                    regs[3] = (regs[3] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[3], 0x0C00);
                    
                case 0xD000:
                    regs[4] = (regs[4] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[4], 0x1000);
                    
                case 0xD001, 0xD004:
                    regs[4] = (regs[4] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[4], 0x1000);
                    
                case 0xD002, 0xD008:
                    regs[5] = (regs[5] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[5], 0x1400);
                                        
                case 0xD003, 0xD00C:
                    regs[5] = (regs[5] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[5], 0x1400);
                    
                case 0xE000:
                    regs[6] = (regs[6] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[6], 0x1800);
                    
                case 0xE004:
                    regs[6] = (regs[6] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[6], 0x1800);
                    
                case 0xE002, 0xE008:
                    regs[7] = (regs[7] & 0xF0) | (value & 0x0F);
                    load1kVromBank(regs[7], 0x1C00);
                    
                case 0xE003, 0xE00C:
                    regs[7] = (regs[7] & 0x0F) | ((value & 0x0F) << 4);
                    load1kVromBank(regs[7], 0x1C00);                    

                case 0xF000:
                    irq_latch = (irq_latch & 0xF0) | (value & 0x0F);
                    
                case 0xF004:
                    irq_latch = (irq_latch & 0x0F) | ((value & 0x0F) << 4);
                    
                case 0xF008:
                    irq_enabled = value & 0x03;
					if ((irq_enabled & 0x02) != 0) {
						irq_counter = irq_latch;
					}
                    
                case 0xF00C:
                    irq_enabled = (irq_enabled & 0x01) * 3;
                    
            }
        }
    }

    override public function loadROM() {
        if (!nes.rom.valid) {
            trace("VRC2: Invalid ROM! Unable to load.");
            return;
        }

        // Get number of 8K banks:
        var num_8k_banks = nes.rom.romCount * 2;

        // Load PRG-ROM:
        load8kRomBank(0, 0x8000);
        load8kRomBank(1, 0xA000);
        load8kRomBank(num_8k_banks - 2, 0xC000);
        load8kRomBank(num_8k_banks - 1, 0xE000);

        // Load CHR-ROM:
        loadCHRROM();

        // Do Reset-Interrupt:
        nes.cpu.requestIrq(CPU.IRQ_RESET);
    }

    public function syncH(scanline:Int) {
        if ((irq_enabled & 0x02) != 0) {
            if (irq_counter == 0xFF) {
                irq_counter = irq_latch;
                irq_enabled = (irq_enabled & 0x01) * 3;
                return 3;
            } else {
                irq_counter++;
            }
        }

        return 0;
    }

    override public function reset() {
		regs = [];
        regs[0] = 0;
        regs[1] = 1;
        regs[2] = 2;
        regs[3] = 3;
        regs[4] = 4;
        regs[5] = 5;
        regs[6] = 6;
        regs[7] = 7;
        regs[8] = 0;

        // IRQ Settings
        irq_enabled = 0;
        irq_latch = 0;
        irq_counter = 0;
    }
	
}

class Mapper032 extends MapperDefault {
	
	var regs:Array<Int>;
    var patch:Int = 0;

	public function new(nes:NES) {
		super(nes);		
	}
	
	override public function write(address:Int, value:Int) {
        if (address < 0x8000) {
            super.write(address, value);
        } else {
            switch (address & 0xF000) {
                case 0x8000:
                    if ((regs[0] & 0x02) != 0) {
						load8kRomBank(value, 0xC000);
					} else {
						load8kRomBank(value, 0x8000);
					}                   

                case 0x9000:
                    if ((value & 0x01) != 0) {
						nes.ppu.setMirroring(ROM.HORIZONTAL_MIRRORING);
					} else {
						nes.ppu.setMirroring(ROM.VERTICAL_MIRRORING);
					}
					regs[0] = value;
                    
                case 0xA000:
                    load8kRomBank(value, 0xA000);
                    
            }

            switch (address & 0xF007) {
                case 0xB000:
                    load1kVromBank(value, 0x0000);
                    
                case 0xB001:
                    load1kVromBank(value, 0x0400);
                    
                case 0xB002:
                    load1kVromBank(value, 0x0800);
                    
                case 0xB003:
                    load1kVromBank(value, 0x0C00);
                    
                case 0xB004:
                    load1kVromBank(value, 0x1000);
                    
                case 0xB005:
                    load1kVromBank(value, 0x1400);
                    
                case 0xB006:
                    if ((patch == 1) && ((value & 0x40) != 0)) {
						// nes.getPpu().setMirroring(ROM.SINGLESCREEN_MIRRORING); /* 0,0,0,1 */
					}
					load1kVromBank(value, 0x1800);                                       

                case 0xB007:
                    if ((patch == 1) && ((value & 0x40) != 0)) {
						nes.ppu.setMirroring(ROM.SINGLESCREEN_MIRRORING);
					}
					load1kVromBank(value, 0x1C00);
                    
            }
        }
    }

    override public function loadROM() {
        var num_8k_banks = nes.rom.romCount * 2;

        // Load PRG-ROM:
        load8kRomBank(0, 0x8000);
        load8kRomBank(1, 0xA000);
        load8kRomBank(num_8k_banks - 2, 0xC000);
        load8kRomBank(num_8k_banks - 1, 0xE000);

        // Load CHR-ROM:
        loadCHRROM();

        // Do Reset-Interrupt:
        nes.cpu.requestIrq(CPU.IRQ_RESET);

    }

    override public function reset() {		
        if (patch == 1) {
            nes.ppu.setMirroring(ROM.SINGLESCREEN_MIRRORING);
        }

		regs = [0];
    }
	
}

class Mapper033 extends MapperDefault {

	public function new(nes:NES) {
		super(nes);		
	}

	override public function write(address:Int, value:Int) {
        if (address < 0x8000) {
            super.write(address, value);
        } else {
            switch (address) {
                case 0x8000:
                    if ((value & 0x40) != 0) {
						nes.ppu.setMirroring(ROM.HORIZONTAL_MIRRORING);
					} else {
						nes.ppu.setMirroring(ROM.VERTICAL_MIRRORING);
					}
					load8kRomBank(value & 0x1F, 0x8000);
                   
                case 0x8001:
                    load8kRomBank(value & 0x1F, 0xA000);
                    
                case 0x8002:
                    load2kVromBank(value, 0x0000);
                    
                case 0x8003:
                    load2kVromBank(value, 0x0800);
                    
                case 0xA000:
                    load1kVromBank(value, 0x1000);
                    
                case 0xA001:
                    load1kVromBank(value, 0x1400);
                    
                case 0xA002:
                    load1kVromBank(value, 0x1800);
                    
                case 0xA003:
                    load1kVromBank(value, 0x1C00);
                    
            }
        }
    }

    override public function loadROM() {
        if (!nes.rom.valid) {
            trace("048: Invalid ROM! Unable to load.");
            return;
        }

        // Get number of 8K banks:
        var num_8k_banks = nes.rom.romCount * 2;

        // Load PRG-ROM:
        load8kRomBank(0, 0x8000);
        load8kRomBank(1, 0xA000);
        load8kRomBank(num_8k_banks - 2, 0xC000);
        load8kRomBank(num_8k_banks - 1, 0xE000);

        // Load CHR-ROM:
        loadCHRROM();

        // Do Reset-Interrupt:
        nes.cpu.requestIrq(CPU.IRQ_RESET);
    }
	
}

class Mapper034 extends MapperDefault {

	public function new(nes:NES) {
		super(nes);
	}
	
	override public function write(address:Int, value:Int) {
        if (address < 0x8000) {
            super.write(address, value);
        } else {
            load32kRomBank(value, 0x8000);
        }
    }
	
}

class Mapper048 extends MapperDefault {
	
	var irq_counter:Int;
    var irq_enabled:Bool;

	public function new(nes:NES) {
		super(nes);
		reset();
	}
	
	override public function write(address:Int, value:Int) {
        if (address < 0x8000) {
            super.write(address, value);
        } else {
            switch (address) {
                case 0x8000:
                    load8kRomBank(value, 0x8000);
                    
                case 0x8001:
                    load8kRomBank(value, 0xA000);
                    
                case 0x8002:
                    load2kVromBank(value * 2, 0x0000);
                    
                case 0x8003:
                    load2kVromBank(value * 2, 0x0800);
                    
                case 0xA000:
                    load1kVromBank(value, 0x1000);
                    
                case 0xA001:
                    load1kVromBank(value, 0x1400);
                    
                case 0xA002:
                    load1kVromBank(value, 0x1800);
                    
                case 0xA003:
                    load1kVromBank(value, 0x1C00);
                    
                case 0xC000:
                    irq_counter = value;
                    
                case 0xC001, 0xC002, 0xE001, 0xE002:
                    irq_enabled = (value != 0);
                    
                case 0xE000:
                    if ((value & 0x40) != 0) {
						nes.ppu.setMirroring(ROM.HORIZONTAL_MIRRORING);
					} else {
						nes.ppu.setMirroring(ROM.VERTICAL_MIRRORING);
					}
                    
            }
        }
    }

    override public function loadROM() {
        if (!nes.rom.valid) {
            trace("VRC4: Invalid ROM! Unable to load.");
            return;
        }

        // Get number of 8K banks:
        var num_8k_banks = nes.rom.romCount * 2;

        // Load PRG-ROM:
        load8kRomBank(0, 0x8000);
        load8kRomBank(1, 0xA000);
        load8kRomBank(num_8k_banks - 2, 0xC000);
        load8kRomBank(num_8k_banks - 1, 0xE000);

        // Load CHR-ROM:
        loadCHRROM();

        // Load Battery RAM (if present):
        loadBatteryRam();

        // Do Reset-Interrupt:
        nes.cpu.requestIrq(CPU.IRQ_RESET);
    }

    public function syncH(scanline:Int):Int {
        if (irq_enabled) {
            if ((nes.ppu.scanline & 0x18) != 0) {
                if (scanline >= 0 && scanline <= 239) {
                    if (irq_counter == 0) {
                        irq_counter = 0;
                        irq_enabled = false;

                        return 3;

                    } else {
                        irq_counter++;
                    }
                }
            }
        }

        return 0;
    }

    override public function reset() {
        irq_enabled = false;
        irq_counter = 0;
    }
	
}

class Mapper071 extends MapperDefault {
	
	var curBank:Int;

	public function new(nes:NES) {
		super(nes);
		reset();
	}
	
	override public function loadROM() {
        if (!nes.rom.valid) {
            trace("Camerica: Invalid ROM! Unable to load.");
            return;
        }

        // Load PRG-ROM:
        loadRomBank(0, 0x8000);
        loadRomBank(nes.rom.romCount - 1, 0xC000);

        // Load CHR-ROM:
        loadCHRROM();

        // Load Battery RAM (if present):
        loadBatteryRam();

        // Do Reset-Interrupt:
        nes.cpu.requestIrq(CPU.IRQ_RESET);
    }

    override public function write(address:Int, value:Int) {
        if (address < 0x8000) {
            // Handle normally:
            super.write(address, value);

        } else if (address < 0xC000) {
            // Unknown function.
        } else {
            // Select 16K PRG ROM at 0x8000:
            if (value != curBank) {
                curBank = value;
                loadRomBank(value, 0x8000);
            }
        }
    }

    override function reset() {
        curBank = -1;
    }
	
}

class Mapper072 extends MapperDefault {

	public function new(nes:NES) {
		super(nes);
	}
	
	override public function write(address:Int, value:Int) {
        if (address < 0x8000) {
            super.write(address, value);
        } else {
            var bank = value & 0x0f;
            var num_banks = nes.rom.romCount;

            if ((value & 0x80) != 0) {
                loadRomBank(bank * 2, 0x8000);
                loadRomBank(num_banks - 1, 0xC000);
            }
            if ((value & 0x40) != 0) {
                load8kVromBank(bank * 8, 0x0000);
            }
        }
    }

    override public function loadROM() {
        if (!nes.rom.valid) {
            trace("048: Invalid ROM! Unable to load.");
            return;
        }

        // Get number of 8K banks:
        var num_banks = nes.rom.romCount * 2;

        // Load PRG-ROM:
        loadRomBank(1, 0x8000);
        loadRomBank(num_banks - 1, 0xC000);

        // Load CHR-ROM:
        loadCHRROM();

        // Do Reset-Interrupt:
        nes.cpu.requestIrq(CPU.IRQ_RESET);
    }
	
}

class Mapper075 extends MapperDefault {
	
	var regs:Array<Int>;

	public function new(nes:NES) {
		super(nes);
		reset();
	}
	
	override public function write(address:Int, value:Int) {
        if (address < 0x8000) {
            super.write(address, value);
        } else {
            switch (address & 0xF000) {
                case 0x8000:
                    load8kRomBank(value, 0x8000);
                    
                case 0x9000:                     
					if ((value & 0x01) != 0) {
						nes.ppu.setMirroring(ROM.HORIZONTAL_MIRRORING);
					} else {
						nes.ppu.setMirroring(ROM.VERTICAL_MIRRORING);
					}

					regs[0] = (regs[0] & 0x0F) | ((value & 0x02) << 3);
					loadVromBank(regs[0], 0x0000);

					regs[1] = (regs[1] & 0x0F) | ((value & 0x04) << 2);
					loadVromBank(regs[1], 0x1000);
                   
                case 0xA000:
                    load8kRomBank(value, 0xA000);
                    
                case 0xC000:
                    load8kRomBank(value, 0xC000);
                   
                case 0xE000:
                    regs[0] = (regs[0] & 0x10) | (value & 0x0F);
                    loadVromBank(regs[0], 0x0000);
                    
                case 0xF000:
                    regs[1] = (regs[1] & 0x10) | (value & 0x0F);
                    loadVromBank(regs[1], 0x1000);
                   
            }
        }
    }

    override public function loadROM() {
        var num_8k_banks = nes.rom.romCount * 2;

        // Load PRG-ROM:
        load8kRomBank(0, 0x8000);
        load8kRomBank(1, 0xA000);
        load8kRomBank(num_8k_banks - 2, 0xC000);
        load8kRomBank(num_8k_banks - 1, 0xE000);

        // Load CHR-ROM:
        loadCHRROM();

        // Do Reset-Interrupt:
        nes.cpu.requestIrq(CPU.IRQ_RESET);
    }

    override public function reset() {
		regs = [];
        regs[0] = 0;
        regs[1] = 1;
    }
	
}

class Mapper078 extends MapperDefault {

	public function new(nes:NES) {
		super(nes);		
	}
	
	override public function write(address:Int, value:Int) {
        var prg_bank = value & 0x0F;
        var chr_bank = (value & 0xF0) >> 4;

        if (address < 0x8000) {
            super.write(address, value);
        } else {

            loadRomBank(prg_bank, 0x8000);
            load8kVromBank(chr_bank, 0x0000);

            if ((address & 0xFE00) != 0xFE00) {
                if ((value & 0x08) != 0) {
                    nes.ppu.setMirroring(ROM.SINGLESCREEN_MIRRORING2);
                } else {
                    nes.ppu.setMirroring(ROM.SINGLESCREEN_MIRRORING);
                }
            }
        }
    }

    override public function loadROM() {
        if (!nes.rom.valid) {
            return;
        }

        var num_16k_banks = nes.rom.romCount * 4;

        // Init:
        loadRomBank(0, 0x8000);
        loadRomBank(num_16k_banks - 1, 0xC000);

        loadCHRROM();

        // Do Reset-Interrupt:
        nes.cpu.requestIrq(CPU.IRQ_RESET);
    }
	
}

class Mapper079 extends MapperDefault {

	public function new(nes:NES) {
		super(nes);
	}
	
	override public function writelow(address:Int, value:Int) {
        if (address < 0x4000) {
            super.writelow(address, value);
        }

        if (address < 0x6000 && address >= 0x4100) {
            var prg_bank = (value & 0x08) >> 3;
            var chr_bank = value & 0x07;

            load32kRomBank(prg_bank, 0x8000);
            load8kVromBank(chr_bank, 0x0000);
        }
    }

    override public function loadROM() {
        if (!nes.rom.valid) {
            trace("Invalid ROM! Unable to load.");
            return;
        }

        // Initial Load:
        loadPRGROM();
        loadCHRROM();

        // Do Reset-Interrupt:
        nes.cpu.requestIrq(CPU.IRQ_RESET);
    }
	
}

class Mapper087 extends MapperDefault {

	public function new(nes:NES) {
		super(nes);
	}
	
	override public function writelow(address:Int, value:Int) {
        if (address < 0x6000) {
            // Let the base mapper take care of it.
            super.writelow(address, value);
        } else if (address == 0x6000) {
            var chr_bank = (value & 0x02) >> 1;
            load8kVromBank(chr_bank * 8, 0x0000);
        }
    }

    override public function loadROM() {
        if (!nes.rom.valid) {
            trace("Invalid ROM! Unable to load.");
            return;
        }

        // Get number of 8K banks:
        var num_8k_banks = nes.rom.romCount * 2;

        // Load PRG-ROM:
        load8kRomBank(0, 0x8000);
        load8kRomBank(1, 0xA000);
        load8kRomBank(2, 0xC000);
        load8kRomBank(3, 0xE000);

        // Load CHR-ROM:
        loadCHRROM();

        // Load Battery RAM (if present):

        // Do Reset-Interrupt:
        nes.cpu.requestIrq(CPU.IRQ_RESET);
    }
	
}

class Mapper094 extends MapperDefault {

	public function new(nes:NES) {
		super(nes);
	}
	
	override public function write(address:Int, value:Int) {
        if (address < 0x8000) {
            // Let the base mapper take care of it.
            super.write(address, value);
        } else {
            if ((address & 0xFFF0) == 0xFF00) {
                var bank = (value & 0x1C) >> 2;
                loadRomBank(bank, 0x8000);
            }
        }
    }

    override public function loadROM() {
        if (!nes.rom.valid) {
            trace("Invalid ROM! Unable to load.");
            return;
        }
		
        var num_banks = nes.rom.romCount;

        // Load PRG-ROM:
        loadRomBank(0, 0x8000);
        loadRomBank(num_banks - 1, 0xC000);

        // Load CHR-ROM:
        loadCHRROM();

        // Do Reset-Interrupt:
        nes.cpu.requestIrq(CPU.IRQ_RESET);
    }
	
}

class Mapper105 extends MapperDefault {
	
	var irq_counter:Int = 0;
    var irq_enabled:Bool = false;
    var init_state:Int = 0;
    var regs:Array<Int>;
    var bits:Int = 0;
    var write_count:Int = 0;

	public function new(nes:NES) {
		super(nes);
		reset();
	}
	
    override public function write(address:Int, value:Int) {
        var reg_num = (address & 0x7FFF) >> 13;

        if (address < 0x8000) {
            super.write(address, value);
        } else {
            if ((value & 0x80) != 0) {
                bits = 0;
                write_count = 0;
                if (reg_num == 0) {
                    regs[reg_num] |= 0x0C;
                }
            } else {
                bits |= (value & 1) << write_count++;
                if (write_count == 5) {
                    regs[reg_num] = bits & 0x1F;
                    bits = write_count = 0;
                }
            }

            if ((regs[0] & 0x02) != 0) {
                if ((regs[0] & 0x01) != 0) {
                    nes.ppu.setMirroring(ROM.HORIZONTAL_MIRRORING);
                } else {
                    nes.ppu.setMirroring(ROM.VERTICAL_MIRRORING);
                }
            } else {
                if ((regs[0] & 0x01) != 0) {
                    nes.ppu.setMirroring(ROM.SINGLESCREEN_MIRRORING2);
                } else {
                    nes.ppu.setMirroring(ROM.SINGLESCREEN_MIRRORING);
                }
            }

            switch (init_state) {
                case 0, 1:
                    init_state++;

                case 2:
					if ((regs[1] & 0x08) != 0) {
						if ((regs[0] & 0x08) != 0) {
							if ((regs[0] & 0x04) != 0) {
								load8kRomBank((regs[3] & 0x07) * 2 + 16, 0x8000);
								load8kRomBank((regs[3] & 0x07) * 2 + 17, 0xA000);
								load8kRomBank(30, 0xC000);
								load8kRomBank(31, 0xE000);
							} else {
								load8kRomBank(16, 0x8000);
								load8kRomBank(17, 0xA000);
								load8kRomBank((regs[3] & 0x07) * 2 + 16, 0xC000);
								load8kRomBank((regs[3] & 0x07) * 2 + 17, 0xE000);
							}
						} else {
							load8kRomBank((regs[3] & 0x06) * 2 + 16, 0x8000);
							load8kRomBank((regs[3] & 0x06) * 2 + 17, 0xA000);
							load8kRomBank((regs[3] & 0x06) * 2 + 18, 0xC000);
							load8kRomBank((regs[3] & 0x06) * 2 + 19, 0xE000);
						}
					} else {
						load8kRomBank((regs[1] & 0x06) * 2 + 0, 0x8000);
						load8kRomBank((regs[1] & 0x06) * 2 + 1, 0xA000);
						load8kRomBank((regs[1] & 0x06) * 2 + 2, 0xC000);
						load8kRomBank((regs[1] & 0x06) * 2 + 3, 0xE000);
					}

					if ((regs[1] & 0x10) != 0) {
						irq_counter = 0;
						irq_enabled = false;
					} else {
						irq_enabled = true;
					}
                   
            }
        }
    }

    public function syncH(scanline:Int):Int {
        if (scanline == 0) {
            if (irq_enabled) {
                irq_counter += 29781;
            }
            if (((irq_counter | 0x21FFFFFF) & 0x3E000000) == 0x3E000000) {
                return 3;
            }
        }
        return 0;
    }

    override public function loadROM() {
        if (!nes.rom.valid) {
            trace("Invalid ROM! Unable to load.");
            return;
        }

        // Init:
        load8kRomBank(0, 0x8000);
        load8kRomBank(1, 0xA000);
        load8kRomBank(2, 0xC000);
        load8kRomBank(3, 0xE000);

        loadCHRROM();

        // Do Reset-Interrupt:
        nes.cpu.requestIrq(CPU.IRQ_RESET);
    }

    override public function reset() {
		regs = [];
        regs[0] = 0x0C;
        regs[1] = 0x00;
        regs[2] = 0x00;
        regs[3] = 0x10;

        bits = 0;
        write_count = 0;

        irq_enabled = false;
        irq_counter = 0;
        init_state = 0;
    }
	
}

class Mapper140 extends MapperDefault {

	public function new(nes:NES) {
		super(nes);
	}
	
	override public function loadROM() {
        if (!nes.rom.valid || nes.rom.romCount < 1) {
            trace("Mapper 140: Invalid ROM! Unable to load.");
            return;
        }

        // Initial Load:
        loadPRGROM();
        loadCHRROM();

        // Do Reset-Interrupt:
        nes.cpu.requestIrq(CPU.IRQ_RESET);
    }

    override public function write(address:Int, value:Int) {
        if (address < 0x8000) {
            // Handle normally:
            super.write(address, value);
        }

        if (address >= 0x6000 && address < 0x8000) {
            var prg_bank = (value & 0xF0) >> 4;
            var chr_bank = value & 0x0F;

            load32kRomBank(prg_bank, 0x8000);
            load8kVromBank(chr_bank, 0x0000);
        }
    }
	
}

class Mapper182 extends MapperDefault {
	
	var irq_counter:Int = 0;
    var irq_enabled:Bool = false;
    var regs:Array<Int>;

	public function new(nes:NES) {
		super(nes);
		reset();
	}
	
	override public function write(address:Int, value:Int) {

        if (address < 0x8000) {
            super.write(address, value);
        } else {
            switch (address & 0xF003) {
                case 0x8001:
					if ((value & 0x01) != 0) {
						nes.ppu.setMirroring(ROM.HORIZONTAL_MIRRORING);
					} else {
						nes.ppu.setMirroring(ROM.VERTICAL_MIRRORING);
					}
                   
                case 0xA000:
                    regs[0] = value & 0x07;
                    
                case 0xC000:
					switch (regs[0]) {
						case 0x00:
							load2kVromBank(value, 0x0000);
							
						case 0x01:
							load1kVromBank(value, 0x1400);
							
						case 0x02:
							load2kVromBank(value, 0x0800);
							
						case 0x03:
							load1kVromBank(value, 0x1C00);
							
						case 0x04:
							load8kRomBank(value, 0x8000);
							
						case 0x05:
							load8kRomBank(value, 0xA000);
							
						case 0x06:
							load1kVromBank(value, 0x1000);
							
						case 0x07:
							load1kVromBank(value, 0x1800);
							
					}

                case 0xE003:
                    irq_counter = value;
                    irq_enabled = (value != 0);

            }
        }
    }

    override public function loadROM() {
        if (!nes.rom.valid) {
            trace("182: Invalid ROM! Unable to load.");
            return;
        }

        // Get number of 8K banks:
        var num_8k_banks = nes.rom.romCount * 2;

        // Load PRG-ROM:
        load8kRomBank(0, 0x8000);
        load8kRomBank(1, 0xA000);
        load8kRomBank(num_8k_banks - 2, 0xC000);
        load8kRomBank(num_8k_banks - 1, 0xE000);

        // Load CHR-ROM:
        loadCHRROM();

        // Do Reset-Interrupt:
        nes.cpu.requestIrq(CPU.IRQ_RESET);
    }

    public function syncH(scanline:Int):Int {
        if (irq_enabled) {
            if ((scanline >= 0) && (scanline <= 240)) {
                if ((nes.ppu.scanline & 0x18) != 0) {
                    if (0 == (--irq_counter)) {
                        irq_counter = 0;
                        irq_enabled = false;
                        return 3;
                    }
                }
            }
        }
        return 0;
    }

    override public function reset() {
		regs = [];
        irq_enabled = false;
        irq_counter = 0;
    }
	
}
