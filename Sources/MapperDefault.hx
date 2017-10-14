package;

import haxe.ds.Vector;

/**
 * ...
 * @author Krtolica Vujadin
 */
 // ported from vNES
class MapperDefault {
	
	var nes:NES;
	var joy1StrobeState:Int;
	var joy2StrobeState:Int;
	var joypadLastWrite:Int;
	
	var mousePressed:Bool;
	var mouseX:Int;
	var mouseY:Int;		// Float ?

	public function new(nes:NES) {
		this.nes = nes;
		joypadLastWrite = -1;
	}
	
	public function reset() {
        joy1StrobeState = 0;
        joy2StrobeState = 0;
        joypadLastWrite = 0;
        
        mousePressed = false;
        mouseX = 0;
        mouseY = 0;
    }
    
    public function write(address:Int, value:Int) {
        if (address < 0x2000) {
            // Mirroring of RAM:
            nes.cpu.mem[address & 0x7FF] = value;        
        } 
		else if (address > 0x4017) {
            nes.cpu.mem[address] = value;
            if (address >= 0x6000 && address < 0x8000) {
                // Write to SaveRAM. Store in file:
                // TODO: not yet
                //if(this.nes.rom!=null)
                //    this.nes.rom.writeBatteryRam(address,value);
            }
        } 
		else if (address > 0x2007 && address < 0x4000) {
            regWrite(0x2000 + (address & 0x7), value);
        }
        else {
            regWrite(address, value);
        }
    }
    
    public function writelow(address:Int, value:Int) {
        if (address < 0x2000) {
            // Mirroring of RAM:
            nes.cpu.mem[address & 0x7FF] = value;
        } 
		else if (address > 0x4017) {
            nes.cpu.mem[address] = value;
        } 
		else if (address > 0x2007 && address < 0x4000) {
            regWrite(0x2000 + (address & 0x7), value);
        } 
		else {
            regWrite(address, value);
        }
    }

    public function load(address:Int):Int {
        // Wrap around:
        address &= 0xFFFF;
		    
        // Check address range:
        if (address > 0x4017) {
            // ROM:
            return nes.cpu.mem[address];
        } 
		else if (address >= 0x2000) {
            // I/O Ports.
            return regLoad(address);
        } 
		else {
            // RAM (mirrored)
            return nes.cpu.mem[address & 0x7FF];
        }
    }

    function regLoad(address:Int):Int {
        switch (address >> 12) { // use fourth nibble (0xF000)
            case 2, 3:
                // PPU Registers
                switch (address & 0x7) {
                    case 0x0:
                        // 0x2000:
                        // PPU Control Register 1.
                        // (the value is stored both
                        // in main memory and in the
                        // PPU as flags):
                        // (not in the real NES)
                        return nes.cpu.mem[0x2000];
                    
                    case 0x1:
                        // 0x2001:
                        // PPU Control Register 2.
                        // (the value is stored both
                        // in main memory and in the
                        // PPU as flags):
                        // (not in the real NES)
                        return nes.cpu.mem[0x2001];
                    
                    case 0x2:
                        // 0x2002:
                        // PPU Status Register.
                        // The value is stored in
                        // main memory in addition
                        // to as flags in the PPU.
                        // (not in the real NES)
                        return nes.ppu.readStatusRegister();
                    
                    case 0x3:
                        return 0;
                    
                    case 0x4:
                        // 0x2004:
                        // Sprite Memory read.
                        return nes.ppu.sramLoad();
                    case 0x5:
                        return 0;
                    
                    case 0x6:
                        return 0;
                    
                    case 0x7:
                        // 0x2007:
                        // VRAM read:
                        return nes.ppu.vramLoad();
                }
				
			case 4:
                // Sound+Joypad registers
                switch (address - 0x4015) {
                    case 0:
                        // 0x4015:
                        // Sound channel enable, DMC Status
                        //return nes.papu.readReg(address);
						
                    case 1:
                        // 0x4016:
                        // Joystick 1 + Strobe
                        return joy1Read();
						
                    case 2:
                        // 0x4017:
                        // Joystick 2 + Strobe
                        if (mousePressed) {                        
                            // Check for white pixel nearby:
                            var sx:Int = Std.int(Math.max(0, mouseX - 4));
                            var ex:Int = Std.int(Math.min(256, mouseX + 4));
                            var sy:Int = Std.int(Math.max(0, mouseY - 4));
                            var ey:Int = Std.int(Math.min(240, mouseY + 4));
                            var w:Int = 0;
							
                            for (y in sy...ey) {
                                for (x in sx...ex) {                               
                                    if (nes.ppu.buffer[(y << 8) + x] == 0xFFFFFF) {										
                                        w |= 0x1 << 3;
                                        trace("Clicked on white!");
                                        break;
                                    }
                                }
                            }
							
                            w |= (this.mousePressed ? (0x1 << 4) : 0);
                            return (this.joy2Read() | w) & 0xFFFF;
                        }
                        else {
                            return this.joy2Read();
                        }
                    
                }
        }
        return 0;
    }

    function regWrite(address:Int, value:Int) {
        switch (address) {
            case 0x2000:
                // PPU Control register 1
                nes.cpu.mem[address] = value;
                nes.ppu.updateControlReg1(value);
				
            case 0x2001:
                // PPU Control register 2
                nes.cpu.mem[address] = value;
                nes.ppu.updateControlReg2(value);
				
            case 0x2003:
                // Set Sprite RAM address:
                nes.ppu.writeSRAMAddress(value);
				
            case 0x2004:
                // Write to Sprite RAM:
                nes.ppu.sramWrite(value);
				
            case 0x2005:
                // Screen Scroll offsets:
                nes.ppu.scrollWrite(value);
				            
            case 0x2006:
                // Set VRAM address:
                nes.ppu.writeVRAMAddress(value);
				
            case 0x2007:
                // Write to VRAM:
                nes.ppu.vramWrite(value);
				
            case 0x4014:
                // Sprite Memory DMA Access
                nes.ppu.sramDMA(value);
				            
            case 0x4015:
                // Sound Channel Switch, DMC Status
                //nes.papu.writeReg(address, value);
				
            case 0x4016:
                // Joystick 1 + Strobe
                if ((value & 1) == 0 && (joypadLastWrite & 1) == 1) {
                    joy1StrobeState = 0;
                    joy2StrobeState = 0;
                }
                joypadLastWrite = value;
				
            case 0x4017:
                // Sound channel frame sequencer:
                //nes.papu.writeReg(address, value);
				
			default:
                // Sound registers
                //if (address >= 0x4000 && address <= 0x4017) {
                //    nes.papu.writeReg(address,value);
                //}
                
        }
    }

    inline public function joy1Read() {
        var ret:Int = 0;
    
        switch (joy1StrobeState) {
            case 0, 1, 2, 3, 4, 5, 6, 7:
                ret = nes.input.state1[joy1StrobeState];
				
			case 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18:
				ret = 0;
				
			case 19:
                ret = 1;
				
			default:
                ret = 0;
        }
		
        joy1StrobeState++;
        if (joy1StrobeState == 24) {
            joy1StrobeState = 0;
        }
		    
        return ret;
    }

    inline public function joy2Read():Int {
        var ret:Int = 0;
		    
        switch (joy2StrobeState) {
            case 0, 1, 2, 3, 4, 5, 6, 7:
                ret = nes.input.state2[joy2StrobeState];
				
            case 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18:
				ret = 0;
               
            case 19:
                ret = 1;
                
            default:
                ret = 0;
        }
		
        joy2StrobeState++;
        if (joy2StrobeState == 24) {
            joy2StrobeState = 0;
        }
		    
        return ret;
    }

    public function loadROM() {
        if (!nes.rom.valid || nes.rom.romCount < 1) {
            trace("NoMapper: Invalid ROM! Unable to load.");
            return;
        }
		
        // Load ROM into memory:
        loadPRGROM();
		    
        // Load CHR-ROM:
        loadCHRROM();
		
        // Load Battery RAM (if present):
        loadBatteryRam();
		
        // Reset IRQ:
        //nes.getCpu().doResetInterrupt();
        nes.cpu.requestIrq(CPU.IRQ_RESET);
    }

    inline function loadPRGROM() {
        if (nes.rom.romCount > 1) {
            // Load the two first banks into memory.
            loadRomBank(0, 0x8000);
            loadRomBank(1, 0xC000);
        }
        else {
            // Load the one bank into both memory locations:
            loadRomBank(0, 0x8000);
            loadRomBank(0, 0xC000);
        }
    }

    inline function loadCHRROM() {
        if (nes.rom.vromCount > 0) {
            if (nes.rom.vromCount == 1) {
                loadVromBank(0,0x0000);
                loadVromBank(0,0x1000);
            } else {
                loadVromBank(0,0x0000);
                loadVromBank(1,0x1000);
            }
        } else {
            trace("There aren't any CHR-ROM banks..");
        }
    }

    function loadBatteryRam() {
        if (nes.rom.batteryRam != null) {
            var ram = nes.rom.batteryRam;
            if (ram != null && ram.length == 0x2000) {
                // Load Battery RAM into memory:				
				for (i in 0...0x2000) {
					nes.cpu.mem[0x6000 + i] = ram[i];
				}
            }
        }
    }

    function loadRomBank(bank:Int, address:Int) {
        // Loads a ROM bank into the specified address.
        bank %= nes.rom.romCount;
		//var copy = nes.rom.rom[bank].copy();
		for (i in 0...16384) {
            nes.cpu.mem[address + i] = nes.rom.rom[bank][i];
        }
    }

    function loadVromBank(bank:Int, address:Int) {
        if (nes.rom.vromCount != 0) {
            nes.ppu.triggerRendering();
    		
			//var copy = nes.rom.vrom[bank % nes.rom.vromCount].copy();
			for (i in 0...4096) {
				nes.ppu.vramMem[address + i] = nes.rom.vrom[bank % nes.rom.vromCount][i];
			}
			
			var vromTile:Vector<Tile> = nes.rom.vromTile[bank % nes.rom.vromCount];
			
			//var copy = vromTile.copy();
			for (i in 0...256) {
				nes.ppu.ptTile[(address >> 4) + i] = vromTile[i];
			}
        }        
    }

    inline function load32kRomBank(bank:Int, address:Int) {
        loadRomBank((bank * 2) % nes.rom.romCount, address);
        loadRomBank((bank * 2 + 1) % nes.rom.romCount, address + 16384);
    }

    inline function load8kVromBank(bank4kStart:Int, address:Int) {
        if (nes.rom.vromCount != 0) {
            nes.ppu.triggerRendering();
			
			loadVromBank((bank4kStart) % nes.rom.vromCount, address);
			loadVromBank((bank4kStart + 1) % nes.rom.vromCount, address + 4096);
        }        
    }

    inline function load1kVromBank(bank1k:Int, address:Int) {
        if (nes.rom.vromCount != 0) {
            nes.ppu.triggerRendering();
			
			var bank4k = Std.int(Math.floor(bank1k / 4) % nes.rom.vromCount);
			var bankoffset = (bank1k % 4) * 1024;
			
			//var copy = nes.rom.vrom[bank4k].copy();
			for (i in 0...1024) {
				nes.ppu.vramMem[bankoffset + i] = nes.rom.vrom[bank4k][i];
			}
			
			// Update tiles:
			var vromTile = nes.rom.vromTile[bank4k];
			var baseIndex = address >> 4;
			for (i in 0...64) {
				nes.ppu.ptTile[baseIndex + i] = vromTile[((bank1k % 4) << 6) + i];
			}
        }        
    }

    inline function load2kVromBank(bank2k:Int, address:Int) {
        if (nes.rom.vromCount != 0) {
            nes.ppu.triggerRendering();
			
			var bank4k = Std.int(Math.floor(bank2k / 2) % nes.rom.vromCount);
			var bankoffset = Std.int((bank2k % 2) * 2048);
			
			for (i in 0...2048) {
				nes.ppu.vramMem[address + i] = nes.rom.vrom[bank4k][bankoffset + i];
			}
			
			// Update tiles:
			var vromTile = nes.rom.vromTile[bank4k];
			var baseIndex = address >> 4;
			for (i in 0...128) {
				nes.ppu.ptTile[baseIndex + i] = vromTile[((bank2k % 2) << 7) + i];
			}
        }        
    }

    inline function load8kRomBank(bank8k:Int, address:Int) {
        var bank16k = Std.int(Math.floor(bank8k / 2) % nes.rom.romCount);
        var offset = Std.int((bank8k % 2) * 8192);
		    
        //this.nes.cpu.mem.write(address,this.nes.rom.rom[bank16k],offset,8192);		
		for (i in 0...8192) {
            nes.cpu.mem[address + i] = nes.rom.rom[bank16k][offset + i];
        }
    }

    public function clockIrqCounter() {
        // Does nothing. This is used by the MMC3 mapper.
    }

    public function latchAccess(address:Int) {
        // Does nothing. This is used by MMC2.
    }
    
    public function toJSON():Dynamic {
        return {
            'joy1StrobeState': joy1StrobeState,
            'joy2StrobeState': joy2StrobeState,
            'joypadLastWrite': joypadLastWrite
        };
    }
    
    public function fromJSON(s:Dynamic) {
        joy1StrobeState = s.joy1StrobeState;
        joy2StrobeState = s.joy2StrobeState;
        joypadLastWrite = s.joypadLastWrite;
    }
	
}
