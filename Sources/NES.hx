package;

import haxe.io.UInt8Array;

/**
 * ...
 * @author Krtolica Vujadin
 */
// ported from vNES
typedef HaxedNESConfig = {
	var preferredFrameRate:Int;
	var fpsInterval:Int;
}
 
class NES {
	
	public var bmp:UInt8Array;	
	public var opts(default, null):HaxedNESConfig;
	public var cpu(default, null):CPU;
	public var ppu(default, null):PPU;
	public var mmap(default, null):MapperDefault;
	public var rom(default, null):ROM;
	public var isRunning(default, null):Bool;
	public var input(default, null):InputHandler;
	
	var frameTime:Float;	
	var fpsFrameCount:Int;
	var lastFpsTime:Float;
	var lastFrameTime:Float;
	var romData:Dynamic;
	
	var cycles:Int = 0;
	var isInLoop:Bool = true;
	
	
	public function new(bmp:UInt8Array) {
		this.bmp = bmp;
		
		opts = {
			preferredFrameRate: 60,
			fpsInterval: 500 // Time between updating FPS in ms
		};
		
		isRunning = false;
		fpsFrameCount = 0;
		romData = null;
		
		frameTime = 1000 / opts.preferredFrameRate;
		
		cpu = new CPU(this);
		ppu = new PPU(this);
		mmap = null; // set in loadRom()
		input = new InputHandler(this);
	}
	
	public function reset() {
        if (mmap != null) {
            mmap.reset();
        }
		        
        cpu.reset();
        ppu.reset();
    }
	
	public function start() {       
        if (rom != null && rom.valid) {
            if (!isRunning) {				
                isRunning = true;
            }
        } 
		else {
            trace("There is no ROM loaded, or it is invalid.");
        }
    }
	
	var frameSkip:Int = 0;
	public function frame() {
		if (isRunning) {
			ppu.startFrame(); 
			
			cycles = 0;
			isInLoop = true;
			
			while (isInLoop) {
				if (cpu.cyclesToHalt == 0) {
					// Execute a CPU instruction
					cycles = cpu.emulate();
					cycles *= 3;
					
				} 
				else {
					if (cpu.cyclesToHalt > 8) {
						cycles = 24;
						cpu.cyclesToHalt -= 8;
					}
					else {
						cycles = cpu.cyclesToHalt * 3;
						cpu.cyclesToHalt = 0;
					}
				}				
				
				while (cycles > 0) {
					if (ppu.curX == ppu.spr0HitX && ppu.f_spVisibility == 1 && ppu.scanline - 21 == ppu.spr0HitY) {
						// Set sprite 0 hit flag:
						ppu.setStatusFlag(PPU.STATUS_SPRITE0HIT, true);
					}
					
					if (ppu.requestEndFrame) {
						if (--ppu.nmiCounter == 0) {
							ppu.requestEndFrame = false;
							ppu.startVBlank();
							isInLoop = false;
							break;
						}
					}
					
					ppu.curX++;
					if (ppu.curX == 341) {
						ppu.curX = 0;
						ppu.endScanline();
					}
					
					cycles--;
				}
			}
		}
	}
    	
	public function stop() {
        isRunning = false;
		isInLoop = false;
    }
	
	function reloadRom() {
        if (romData != null) {
            loadRom(romData);
        }
    }
    
    // Loads a ROM file into the CPU and PPU.
    // The ROM file is validated first.
    public function loadRom(data:haxe.io.Bytes):Bool {
        if (isRunning) {
            stop();
        }
        
        // Load ROM file:
        rom = new ROM(this);
        rom.load(data);
        
        if (rom.valid) {
            reset();
            mmap = rom.createMapper();
            if (mmap == null) {
                return false;
            }
			
            mmap.loadROM();
            ppu.setMirroring(rom.getMirroringType());
            romData = data;
        }
		
        return rom.valid;
    }
	    
    function resetFps() {
        lastFpsTime = 0;
        fpsFrameCount = 0;
    }
	
}
