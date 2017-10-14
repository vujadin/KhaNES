package;

import haxe.ds.Vector;

/**
 * ...
 * @author Krtolica Vujadin
 */
 // ported from vNES
class PPU {
	
	// Status flags
	public static inline var STATUS_VRAMWRITE:Int = 4;
	public static inline var STATUS_SLSPRITECOUNT:Int = 5;
	public static inline var STATUS_SPRITE0HIT:Int = 6;
	public static inline var STATUS_VBLANK:Int = 7;
	
	var nes:NES;
	public var vramMem(default, null):Vector<Int>;
    var spriteMem:Vector<Int>;
	
	// VRAM I/O:
    var vramAddress:Int;
    var vramTmpAddress:Int;
    var vramBufferedReadValue:Int;
    var firstWrite:Bool = true;					// VRAM/Scroll Hi/Lo latch
    var sramAddress:Int;
    var currentMirroring:Int;
    public var requestEndFrame:Bool;
    var nmiOk:Bool;
    var dummyCycleToggle:Bool;
    var validTileData:Bool;
    public var nmiCounter:Int;
    var scanlineAlreadyRendered:Bool;
	// Control Flags Register 1
    var f_nmiOnVblank:Int;   				// NMI on VBlank. 0=disable, 1=enable
    var f_spriteSize:Int;					// Sprite size. 0=8x8, 1=8x16
    var f_bgPatternTable:Int;				// Background Pattern Table address. 0=0x0000,1=0x1000
    var f_spPatternTable:Int;				// Sprite Pattern Table address. 0=0x0000,1=0x1000
    var f_addrInc:Int;						// PPU Address Increment. 0=1,1=32
    var f_nTblAddress:Int;					// Name Table Address. 0=0x2000,1=0x2400,2=0x2800,3=0x2C00    
	// Control Flags Register 2
	var f_color:Int;						// Background color. 0=black, 1=blue, 2=green, 4=red
    public var f_spVisibility:Int;			// Sprite visibility. 0=not displayed,1=displayed
    var f_bgVisibility:Int;					// Background visibility. 0=Not Displayed,1=displayed
    var f_spClipping:Int;					// Sprite clipping. 0=Sprites invisible in left 8-pixel column,1=No clipping
    var f_bgClipping:Int;					// Background clipping. 0=BG invisible in left 8-pixel column, 1=No clipping
    var f_dispType:Int;						// Display type. 0=color, 1=monochrome
	
	// Counters
    var cntFV:Int;
    var cntV:Int;
    var cntH:Int;
    var cntVT:Int;
    var cntHT:Int;
	
	// Registers
    var regFV:Int;
    var regV:Int;
    var regH:Int;
    var regVT:Int;
    var regHT:Int;
    var regFH:Int;
    var regS:Int;
    var curNt:Int;
    var attrib:Vector<Int>;
    public var buffer:Vector<Int>;
    var prevBuffer:Vector<Int>;
    var bgbuffer:Vector<Int>;
    var pixrendered:Vector<Int>;
    
    var scantile:Vector<Tile>;
    public var scanline:Int = 0;
    var lastRenderedScanline:Int = -1;
    public var curX:Int = 0;
    var sprX:Vector<Int>; 
    var sprY:Vector<Int>; 
    var sprTile:Vector<Int>; 
    var sprCol:Vector<Int>; 
    var vertFlip:Vector<Bool>; 
    var horiFlip:Vector<Bool>; 
    var bgPriority:Vector<Bool>; 
    public var spr0HitX:Int; 
    public var spr0HitY:Int; 
    var hitSpr0:Bool = false;
    var sprPalette:Vector<Int>;
    var imgPalette:Vector<Int>;
	var x:Int;
	var y:Int;
	
	// Tiles
    public var ptTile:Vector<Tile>;
	
	// Name table data
    var ntable1:Vector<Int>;
    var nameTable:Vector<NameTable>;
    var vramMirrorTable:Vector<Int>;			// Mirroring Lookup Table.
    var palTable:PaletteTable;    
    
    // Rendering Options:
    public var showSpr0Hit:Bool = false;
    public var clipToTvSize:Bool = false;
	
	var vblankAdd:Int = 1;
	
	public function new(nes:NES) {
		this.nes = nes;		
		reset();
	}
	
	public function reset() {        
        // Memory
        vramMem = new Vector<Int>(0x8000);
        spriteMem = new Vector<Int>(0x100);
        for (i in 0...0x8000) {
            vramMem[i] = 0;
        }
        for (i in 0...0x100) {
            spriteMem[i] = 0;
        }
        
        // VRAM I/O:
        vramAddress = 0;
        vramTmpAddress = 0;
        vramBufferedReadValue = 0;
        firstWrite = true;       // VRAM/Scroll Hi/Lo latch

        // SPR-RAM I/O:
		sramAddress = 0; // 8-bit only.
        
        currentMirroring = -1;
        requestEndFrame = false;
        nmiOk = false;
        dummyCycleToggle = false;
        validTileData = false;
        nmiCounter = 0;
        scanlineAlreadyRendered = false;
        
        // Control Flags Register 1:
        f_nmiOnVblank = 0;    // NMI on VBlank. 0=disable, 1=enable
        f_spriteSize = 0;     // Sprite size. 0=8x8, 1=8x16
        f_bgPatternTable = 0; // Background Pattern Table address. 0=0x0000,1=0x1000
        f_spPatternTable = 0; // Sprite Pattern Table address. 0=0x0000,1=0x1000
        f_addrInc = 0;        // PPU Address Increment. 0=1,1=32
        f_nTblAddress = 0;    // Name Table Address. 0=0x2000,1=0x2400,2=0x2800,3=0x2C00
        
        // Control Flags Register 2:
        f_color = 0;          // Background color. 0=black, 1=blue, 2=green, 4=red
        f_spVisibility = 0;   // Sprite visibility. 0=not displayed,1=displayed
        f_bgVisibility = 0;   // Background visibility. 0=Not Displayed,1=displayed
        f_spClipping = 0;     // Sprite clipping. 0=Sprites invisible in left 8-pixel column,1=No clipping
        f_bgClipping = 0;     // Background clipping. 0=BG invisible in left 8-pixel column, 1=No clipping
        f_dispType = 0;       // Display type. 0=color, 1=monochrome
        
        // Counters:
        cntFV = 0;
        cntV = 0;
        cntH = 0;
        cntVT = 0;
        cntHT = 0;
        
        // Registers:
        regFV = 0;
        regV = 0;
        regH = 0;
        regVT = 0;
        regHT = 0;
        regFH = 0;
        regS = 0;
        
        // These are temporary variables used in rendering and sound procedures.
        // Their states outside of those procedures can be ignored.
        // TODO: the use of this is a bit weird, investigate
        curNt = 0;
        
        // Variables used when rendering:
        attrib = new Vector<Int>(32);
        buffer = new Vector<Int>(256 * 240);
        prevBuffer = new Vector<Int>(256 * 240);
		// init prev buffer with zeros (black)
		for (i in 0...256 * 240) {
			prevBuffer.set(i, 0);
		}
		
        bgbuffer = new Vector<Int>(256 * 240);
        pixrendered = new Vector<Int>(256 * 240);
		
        validTileData = false;
		
        scantile = new Vector<Tile>(32);
        
        // Initialize misc vars:
        scanline = 0;
        lastRenderedScanline = -1;
        curX = 0;
        
        // Sprite data:
        sprX = new Vector<Int>(64);				// X coordinate
        sprY = new Vector<Int>(64);				// Y coordinate
        sprTile = new Vector<Int>(64);			// Tile Index (into pattern table)
        sprCol = new Vector<Int>(64); 			// Upper two bits of color
        vertFlip = new Vector<Bool>(64);		// Vertical Flip
        horiFlip = new Vector<Bool>(64); 		// Horizontal Flip
        bgPriority = new Vector<Bool>(64); 		// Background priority
        spr0HitX = 0; 							// Sprite #0 hit X coordinate
        spr0HitY = 0; 							// Sprite #0 hit Y coordinate
        hitSpr0 = false;
        
        // Palette data:
        sprPalette = new Vector<Int>(16);
        imgPalette = new Vector<Int>(16);
        
        // Create pattern table tile buffers:
        ptTile = new Vector<Tile>(512);
        for (i in 0...512) {
            ptTile[i] = new Tile();
        }
        
        // Create nametable buffers:
        // Name table data:
        ntable1 = new Vector<Int>(4);
        currentMirroring = -1;
        nameTable = new Vector<NameTable>(4);
        for (i in 0...4) {
            nameTable[i] = new NameTable(32, 32, "Nt" + i);
        }
        
        // Initialize mirroring lookup table:
        vramMirrorTable = new Vector<Int>(0x8000);
        for (i in 0...0x8000) {
            vramMirrorTable[i] = i;
        }
        
        palTable = new PaletteTable();
        palTable.loadNTSCPalette();
        //palTable.loadDefaultPalette();
        
        updateControlReg1(0);
        updateControlReg2(0);
	}
	
	// Sets Nametable mirroring.
    public function setMirroring(mirroring:Int) {    
        if (mirroring == currentMirroring) {
            return;
        }
        
        currentMirroring = mirroring;
        triggerRendering();
		
        // Remove mirroring:
        if (vramMirrorTable == null) {
            vramMirrorTable = new Vector<Int>(0x8000);
        }
        for (i in 0...0x8000) {
            vramMirrorTable[i] = i;
        }
        
        // Palette mirroring:
        defineMirrorRegion(0x3f20, 0x3f00, 0x20);
        defineMirrorRegion(0x3f40, 0x3f00, 0x20);
        defineMirrorRegion(0x3f80, 0x3f00, 0x20);
        defineMirrorRegion(0x3fc0, 0x3f00, 0x20);
        
        // Additional mirroring:
        defineMirrorRegion(0x3000, 0x2000, 0xf00);
        defineMirrorRegion(0x4000, 0x0000, 0x4000);
		
        if (mirroring == ROM.HORIZONTAL_MIRRORING) {
            // Horizontal mirroring.            
            ntable1[0] = 0;
            ntable1[1] = 0;
            ntable1[2] = 1;
            ntable1[3] = 1;
            
            defineMirrorRegion(0x2400, 0x2000, 0x400);
            defineMirrorRegion(0x2c00, 0x2800, 0x400);            
        } 
		else if (mirroring == ROM.VERTICAL_MIRRORING) {
            // Vertical mirroring.            
            ntable1[0] = 0;
            ntable1[1] = 1;
            ntable1[2] = 0;
            ntable1[3] = 1;
            
            defineMirrorRegion(0x2800, 0x2000, 0x400);
            defineMirrorRegion(0x2c00, 0x2400, 0x400);            
        } 
		else if (mirroring == ROM.SINGLESCREEN_MIRRORING) {            
            // Single Screen mirroring            
            ntable1[0] = 0;
            ntable1[1] = 0;
            ntable1[2] = 0;
            ntable1[3] = 0;
            
            defineMirrorRegion(0x2400, 0x2000, 0x400);
            defineMirrorRegion(0x2800, 0x2000, 0x400);
            defineMirrorRegion(0x2c00, 0x2000, 0x400);            
        } 
		else if (mirroring == ROM.SINGLESCREEN_MIRRORING2) {           
            ntable1[0] = 1;
            ntable1[1] = 1;
            ntable1[2] = 1;
            ntable1[3] = 1;
            
            defineMirrorRegion(0x2400, 0x2400, 0x400);
            defineMirrorRegion(0x2800, 0x2400, 0x400);
            defineMirrorRegion(0x2c00, 0x2400, 0x400);            
        } 
		else {            
            // Assume Four-screen mirroring.            
            ntable1[0] = 0;
            ntable1[1] = 1;
            ntable1[2] = 2;
            ntable1[3] = 3;            
        }          
    }    
    
    // Define a mirrored area in the address lookup table.
    // Assumes the regions don't overlap.
    // The 'to' region is the region that is physically in memory.
    inline function defineMirrorRegion(fromStart:Int, toStart:Int, size:Int) {
        for (i in 0...size) {
            vramMirrorTable[fromStart + i] = toStart + i;
        }
    }
	
    public function startVBlank() {        
        // Do NMI:
        nes.cpu.requestIrq(CPU.IRQ_NMI);
        
		// Make sure everything is rendered:
		if (lastRenderedScanline < 239) {
			renderFramePartially(lastRenderedScanline + 1, 240 - lastRenderedScanline);
		}
		
		// End frame:
		//endFrame();
		// Draw spr#0 hit coordinates:
		if (showSpr0Hit) {
			// Spr 0 position:
			if (sprX[0] >= 0 && sprX[0] < 256 && sprY[0] >= 0 && sprY[0] < 240) {
				for (i in 0...256) {  
					buffer[(sprY[0] << 8) + i] = 0xFF5555;
				}
				for (i in 0...240) {
					buffer[(i << 8) + sprX[0]] = 0xFF5555;
				}
			}
			// Hit position:
			if (spr0HitX >= 0 && spr0HitX < 256 && spr0HitY >= 0 && spr0HitY < 240) {
				for (i in 0...256) {
					buffer[(spr0HitY << 8) + i] = 0x55FF55;
				}
				for (i in 0...240) {
					buffer[(i << 8) + spr0HitX] = 0x55FF55;
				}
			}
		}
		
		// This is a bit lazy..
		// if either the sprites or the background should be clipped,
		// both are clipped after rendering is finished.
		if (clipToTvSize || f_bgClipping == 0 || f_spClipping == 0) {
			// Clip left 8-pixels column:
			for (y in 0...240) {
				for (x in 0...8) {
					buffer[(y << 8) + x] = 0;
				}
			}
		}
		
		if (clipToTvSize) {
			// Clip right 8-pixels column too:
			for (y in 0...240) {
				for (x in 0...8) {
					buffer[(y << 8) + 255 - x] = 0;
				}
			}
		}
		
		// Clip top and bottom 8 pixels:
		if (clipToTvSize) {
			for (y in 0...8) {
				for (x in 0...256) {
					buffer[(y << 8) + x] = 0;
					buffer[((239 - y) << 8) + x] = 0;
				}
			}
		}
				
		// Reset scanline counter:
		lastRenderedScanline = -1;
    }
    
    public function endScanline() {
        switch (scanline) {
            case 19:
                // Dummy scanline.
                // May be variable length:
                if (dummyCycleToggle) {
                    // Remove dead cycle at end of scanline,
                    // for next scanline:
                    curX = 1;
                    dummyCycleToggle = !dummyCycleToggle;
                }
                
            case 20:
                // Clear VBlank flag:
                setStatusFlag(PPU.STATUS_VBLANK, false);
				
                // Clear Sprite #0 hit flag:
                setStatusFlag(PPU.STATUS_SPRITE0HIT, false);
                hitSpr0 = false;
                spr0HitX = -1;
                spr0HitY = -1;
				
                if (f_bgVisibility == 1 || f_spVisibility == 1) {
                    // Update counters:
                    cntFV = regFV;
                    cntV = regV;
                    cntH = regH;
                    cntVT = regVT;
                    cntHT = regHT;
					
                    if (f_bgVisibility == 1) {
                        // Render dummy scanline:
                        renderBgScanline(buffer, 0);
                    }  
                }
				
                if (f_bgVisibility == 1 && f_spVisibility == 1) {
                    // Check sprite 0 hit for first scanline:
                    checkSprite0(0);
                }
				
                if (f_bgVisibility == 1 || f_spVisibility == 1) {
                    // Clock mapper IRQ Counter:
                    nes.mmap.clockIrqCounter();
                }
                
            case 261:
                // Dead scanline, no rendering.
                // Set VINT:
                setStatusFlag(PPU.STATUS_VBLANK, true);
                requestEndFrame = true;
                nmiCounter = 9;
				
                // Wrap around:
                scanline = -1; // will be incremented to 0
             
            default:
                if (scanline >= 21 && scanline <= 260) {
                    // Render normally:
                    if (f_bgVisibility == 1) {
                        if (!scanlineAlreadyRendered) {
                            // update scroll:
                            cntHT = regHT;
                            cntH = regH;
                            renderBgScanline(bgbuffer, scanline + 1 - 21);
                        }
                        scanlineAlreadyRendered = false;
						
                        // Check for sprite 0 (next scanline):
                        if (!hitSpr0 && f_spVisibility == 1) {
                            if (sprX[0] >= -7 &&
                                    sprX[0] < 256 &&
                                    sprY[0] + 1 <= (scanline - 20) &&
                                    (sprY[0] + 1 + (
                                        f_spriteSize == 0 ? 8 : 16
                                    )) >= (scanline - 20)) {
                                if (checkSprite0(scanline - 20)) {
                                    hitSpr0 = true;
                                }
                            }
                        }
                    }
					
                    if (f_bgVisibility == 1 || f_spVisibility == 1) {
                        // Clock mapper IRQ Counter:
                        nes.mmap.clockIrqCounter();
                    }
                }
        }
        
        scanline++;
        regsToAddress();
        cntsToAddress();        
    }
    
    public function startFrame() {    
        // Set background color:
        var bgColor = 0;
        
        if (f_dispType == 0) {
            // Color display.
            // f_color determines color emphasis.
            // Use first entry of image palette as BG color.
            bgColor = imgPalette[0];
        } 
		else {
            // Monochrome display.
            // f_color determines the bg color.
            switch (f_color) {
                case 0:
                    // Black
                    bgColor = 0x00000;
					
                case 1:
                    // Green
                    bgColor = 0x00FF00;
					
                case 2:
                    // Blue
                    bgColor = 0xFF0000;
					
                case 3:
                    // Invalid. Use black.
                    bgColor = 0x000000;
					
                case 4:
                    // Red
                    bgColor = 0x0000FF;
                    
                default:
                    // Invalid. Use black.
                    bgColor = 0x0;
            }
        }
        
        for (i in 0...256 * 240) {
            buffer[i] = bgColor;
        }
		
        for (i in 0...pixrendered.length) {
            pixrendered[i] = 65;
        }
    }
    
    function endFrame() { 
        // Draw spr#0 hit coordinates:
        if (showSpr0Hit) {
            // Spr 0 position:
            if (sprX[0] >= 0 && sprX[0] < 256 && sprY[0] >= 0 && sprY[0] < 240) {
                for (i in 0...256) {  
                    buffer[(sprY[0] << 8) + i] = 0xFF5555;
                }
                for (i in 0...240) {
                    buffer[(i << 8) + sprX[0]] = 0xFF5555;
                }
            }
            // Hit position:
            if (spr0HitX >= 0 && spr0HitX < 256 && spr0HitY >= 0 && spr0HitY < 240) {
                for (i in 0...256) {
                    buffer[(spr0HitY << 8) + i] = 0x55FF55;
                }
                for (i in 0...240) {
                    buffer[(i << 8) + spr0HitX] = 0x55FF55;
                }
            }
        }
        
        // This is a bit lazy..
        // if either the sprites or the background should be clipped,
        // both are clipped after rendering is finished.
        if (clipToTvSize || f_bgClipping == 0 || f_spClipping == 0) {
            // Clip left 8-pixels column:
            for (y in 0...240) {
                for (x in 0...8) {
                    buffer[(y << 8) + x] = 0;
                }
            }
        }
        
        if (clipToTvSize) {
            // Clip right 8-pixels column too:
            for (y in 0...240) {
                for (x in 0...8) {
                    buffer[(y << 8) + 255 - x] = 0;
                }
            }
        }
        
        // Clip top and bottom 8 pixels:
        if (clipToTvSize) {
            for (y in 0...8) {
                for (x in 0...256) {
                    buffer[(y << 8) + x] = 0;
                    buffer[((239 - y) << 8) + x] = 0;
                }
            }
        }        	
    }
    
    public function updateControlReg1(value:Int) {        
        triggerRendering();
        
        f_nmiOnVblank    = (value >> 7) & 1;
        f_spriteSize     = (value >> 5) & 1;
        f_bgPatternTable = (value >> 4) & 1;
        f_spPatternTable = (value >> 3) & 1;
        f_addrInc        = (value >> 2) & 1;
        f_nTblAddress    = value & 3;
        
        regV = (value >> 1) & 1;
        regH = value & 1;
        regS = (value >> 4) & 1;        
    }
    
    public function updateControlReg2(value:Int) {        
        triggerRendering();
        
        f_color 		= (value >> 5) & 7;
        f_spVisibility = (value >> 4) & 1;
        f_bgVisibility = (value >> 3) & 1;
        f_spClipping 	= (value >> 2) & 1;
        f_bgClipping 	= (value >> 1) & 1;
        f_dispType 	= value & 1;
        
        if (f_dispType == 0) {
            palTable.setEmphasis(f_color);
        }
        updatePalettes();
    }
    
    inline public function setStatusFlag(flag:Int, value:Bool) {
        var n = 1 << flag;
        nes.cpu.mem[0x2002] = ((nes.cpu.mem[0x2002] & (255 - n)) | (value ? n : 0));
    }
    
    // CPU Register $2002:
    // Read the Status Register.
    public function readStatusRegister() {        
        var tmp = nes.cpu.mem[0x2002];
        
        // Reset scroll & VRAM Address toggle:
        firstWrite = true;
        
        // Clear VBlank flag:
        setStatusFlag(PPU.STATUS_VBLANK, false);
        
        // Fetch status data:
        return tmp;        
    }
    
    // CPU Register $2003:
    // Write the SPR-RAM address that is used for sramWrite (Register 0x2004 in CPU memory map)
    inline public function writeSRAMAddress(address:Int) {
        sramAddress = address;
    }
    
    // CPU Register $2004 (R):
    // Read from SPR-RAM (Sprite RAM).
    // The address should be set first.
    inline public function sramLoad() {
        return spriteMem[sramAddress];
    }
    
    // CPU Register $2004 (W):
    // Write to SPR-RAM (Sprite RAM).
    // The address should be set first.
    inline public function sramWrite(value:Int) {
        spriteMem[sramAddress] = value;
        spriteRamWriteUpdate(sramAddress, value);
        sramAddress++; // Increment address
        sramAddress %= 0x100;
    }
    
    // CPU Register $2005:
    // Write to scroll registers.
    // The first write is the vertical offset, the second is the
    // horizontal offset:
    public function scrollWrite(value:Int) {
        triggerRendering();
        
        if (firstWrite) {
            // First write, horizontal scroll:
            regHT = (value >> 3) & 31;
            regFH = value & 7;
            
        } 
		else {            
            // Second write, vertical scroll:
            regFV = value & 7;
            regVT = (value >> 3) & 31;            
        }
        firstWrite = !firstWrite;        
    }
    
    // CPU Register $2006:
    // Sets the adress used when reading/writing from/to VRAM.
    // The first write sets the high byte, the second the low byte.
    public function writeVRAMAddress(address:Int) {   
        if (firstWrite) {            
            regFV = (address >> 4) & 3;
            regV = (address >> 3) & 1;
            regH = (address >> 2) & 1;
            regVT = (regVT & 7) | ((address & 3) << 3);
            
        } 
		else {
            triggerRendering();
            
            regVT = (regVT & 24) | ((address >> 5) & 7);
            regHT = address & 31;
            
            cntFV = regFV;
            cntV = regV;
            cntH = regH;
            cntVT = regVT;
            cntHT = regHT;
            
            checkSprite0(scanline - 20);            
        }
        
        firstWrite = !firstWrite;
        
        // Invoke mapper latch:
        cntsToAddress();
        if (vramAddress < 0x2000) {
            nes.mmap.latchAccess(vramAddress);
        }   
    }
    
    // CPU Register $2007(R):
    // Read from PPU memory. The address should be set first.
    public function vramLoad():Int {
        var tmp:Int = 0;
        
        cntsToAddress();
        regsToAddress();
        
        // If address is in range 0x0000-0x3EFF, return buffered values:
        if (vramAddress <= 0x3EFF) {
            tmp = vramBufferedReadValue;
        
            // Update buffered value:
            if (vramAddress < 0x2000) {
                vramBufferedReadValue = vramMem[vramAddress];
            }
            else {
                vramBufferedReadValue = mirroredLoad(vramAddress);
            }
            
            // Mapper latch access:
            if (vramAddress < 0x2000) {
                nes.mmap.latchAccess(vramAddress);
            }
            
            // Increment by either 1 or 32, depending on d2 of Control Register 1:
            vramAddress += (f_addrInc == 1 ? 32 : 1);
            
            cntsFromAddress();
            regsFromAddress();
            
            return tmp; // Return the previous buffered value.
        }
        
        // No buffering in this mem range. Read normally.
        tmp = mirroredLoad(vramAddress);
        
        // Increment by either 1 or 32, depending on d2 of Control Register 1:
        vramAddress += (f_addrInc == 1 ? 32 : 1); 
        
        cntsFromAddress();
        regsFromAddress();
        
        return tmp;
    }
    
    // CPU Register $2007(W):
    // Write to PPU memory. The address should be set first.
    public function vramWrite(value:Int) {        
        triggerRendering();
        cntsToAddress();
        regsToAddress();
        
        if (vramAddress >= 0x2000) {
            // Mirroring is used.
            mirroredWrite(vramAddress,value);
        } 
		else {            
            // Write normally.
            writeMem(vramAddress,value);
            
            // Invoke mapper latch:
            nes.mmap.latchAccess(vramAddress);            
        }
        
        // Increment by either 1 or 32, depending on d2 of Control Register 1:
        vramAddress += (f_addrInc == 1 ? 32 : 1);
        regsFromAddress();
        cntsFromAddress();        
    }
    
    // CPU Register $4014:
    // Write 256 bytes of main memory
    // into Sprite RAM.
    public function sramDMA(value:Int) {
        var baseAddress = value * 0x100;
        var data:Int = 0;
        for (i in sramAddress...256) {
            data = nes.cpu.mem[baseAddress + i];
            spriteMem[i] = data;
            spriteRamWriteUpdate(i, data);
        }
        
        nes.cpu.haltCycles(513);        
    }
    
    // Updates the scroll registers from a new VRAM address.
    public function regsFromAddress() {        
        var address = (vramTmpAddress >> 8) & 0xFF;
        regFV = (address >> 4) & 7;
        regV = (address >> 3) & 1;
        regH = (address >> 2) & 1;
        regVT = (regVT & 7) | ((address & 3) << 3);
        
        address = vramTmpAddress & 0xFF;
        regVT = (regVT & 24) | ((address >> 5) & 7);
        regHT = address & 31;
    }
    
    // Updates the scroll registers from a new VRAM address.
    function cntsFromAddress() {        
        var address = (vramAddress >> 8) & 0xFF;
        cntFV = (address >> 4) & 3;
        cntV = (address >> 3) & 1;
        cntH = (address >> 2) & 1;
        cntVT = (cntVT & 7) | ((address & 3) << 3);      
        
        address = vramAddress & 0xFF;
        cntVT = (cntVT & 24) | ((address >> 5) & 7);
        cntHT = address & 31;        
    }
    
    function regsToAddress() {
        var b1  = (regFV & 7) << 4;
        b1 |= (regV & 1) << 3;
        b1 |= (regH & 1) << 2;
        b1 |= (regVT >> 3) & 3;
        
        var b2  = (regVT & 7) << 5;
        b2 |= regHT & 31;
        
        vramTmpAddress = ((b1 << 8) | b2) & 0x7FFF;
    }
    
    function cntsToAddress() {
        var b1  = (cntFV & 7) << 4;
        b1 |= (cntV & 1) << 3;
        b1 |= (cntH & 1) << 2;
        b1 |= (cntVT >> 3) & 3;
        
        var b2  = (cntVT & 7) << 5;
        b2 |= cntHT & 31;
        
        vramAddress = ((b1 << 8) | b2) & 0x7FFF;
    }
    
    function incTileCounter(count:Int) { 
		var i:Int = count;
		while(i != 0) {
            cntHT++;
            if (cntHT == 32) {
                cntHT = 0;
                cntVT++;
                if (cntVT >= 30) {
                    cntH++;
                    if(cntH == 2) {
                        cntH = 0;
                        cntV++;
                        if (cntV == 2) {
                            cntV = 0;
                            cntFV++;
                            cntFV &= 0x7;
                        }
                    }
                }
            }
			i--;
        }
    }
    
    // Reads from memory, taking into account
    // mirroring/mapping of address ranges.
    inline function mirroredLoad(address:Int):Int {
        return vramMem[vramMirrorTable[address]];
    }
    
    // Writes to memory, taking into account
    // mirroring/mapping of address ranges.
    function mirroredWrite(address:Int, value:Int) {
        if (address >= 0x3f00 && address < 0x3f20) {
            // Palette write mirroring.
            if (address == 0x3F00 || address == 0x3F10) {				
                writeMem(0x3F00, value);
                writeMem(0x3F10, value);                
            } 
			else if (address == 0x3F04 || address == 0x3F14) {                
                writeMem(0x3F04, value);
                writeMem(0x3F14, value);                
            } 
			else if (address == 0x3F08 || address == 0x3F18) {                
                writeMem(0x3F08, value);
                writeMem(0x3F18, value);                
            } 
			else if (address == 0x3F0C || address == 0x3F1C) {                
                writeMem(0x3F0C, value);
                writeMem(0x3F1C, value);                
            } 
			else {
                writeMem(address, value);
            }            
        } 
		else {            
            // Use lookup table for mirrored address:
            if (address < vramMirrorTable.length) {
                writeMem(vramMirrorTable[address], value);
            } 
			else {
                // FIXME
				trace("Invalid VRAM address: " + address);
            }            
        }
    }
    
    inline public function triggerRendering() {
        if (scanline - vblankAdd >= 21 && scanline - vblankAdd <= 260) {
            // Render sprites, and combine:
            renderFramePartially(
                lastRenderedScanline + 1,
                scanline - 21 - lastRenderedScanline
            );
            
            // Set last rendered scanline:
            lastRenderedScanline = scanline - 21;
        }
    }
    
    function renderFramePartially(startScan:Int, scanCount:Int) {
        if (f_spVisibility == 1) {
            renderSpritesPartially(startScan, scanCount, true);
        }
        
        if(f_bgVisibility == 1) {
            var si = startScan << 8;
            var ei = (startScan + scanCount) << 8;
            if (ei > 0xF000) {
                ei = 0xF000;
            }           
            var pixrendered = pixrendered;
            for (destIndex in si...ei) {
                if (pixrendered[destIndex] > 0xFF) {
                    buffer[destIndex] = bgbuffer[destIndex];
                }
            }
        }
        
        if (f_spVisibility == 1) {
            renderSpritesPartially(startScan, scanCount, false);
        }
        
        validTileData = false;
    }
    
	var t:Tile;
	var tpix:Vector<Int>;
	var att:Int;
	var col:Int;
	var sx:Int;
	var _baseTile:Int;
	var _destIndex:Int;
    function renderBgScanline(bgbuffer:Vector<Int>, scan:Int) {
        _baseTile = (regS == 0 ? 0 : 256);
        _destIndex = (scan << 8) - regFH;
		
        curNt = ntable1[cntV + cntV + cntH];
        
        cntHT = regHT;
        cntH = regH;
        curNt = ntable1[cntV + cntV + cntH];
        
        if (scan < 240 && (scan - cntFV) >= 0) {
            
            var tscanoffset = cntFV << 3;
            var targetBuffer = bgbuffer != null ? bgbuffer : buffer;
			
			y = scan - cntFV;
			
            for (tile in 0...32) {                
                if (scan >= 0) {                
                    // Fetch tile & attrib data:
                    if (validTileData) {
                        // Get data from array:
                        t = scantile[tile];
                        tpix = t.pix;
                        att = attrib[tile];
						
                    } else {
                        // Fetch data:
                        t = ptTile[_baseTile + nameTable[curNt].getTileIndex(cntHT, cntVT)];
                        tpix = t.pix;
                        att = nameTable[curNt].getAttrib(cntHT, cntVT);
                        scantile[tile] = t;
                        attrib[tile] = att;
                    }
                    
                    // Render tile scanline:
                    sx = 0;
                    x = (tile << 3) - regFH;
					
                    if (x >- 8) {
                        if (x < 0) {
                            _destIndex -= x;
                            sx = -x;
                        }
                        if (t.opaque[cntFV]) {
                            while (sx < 8) {
                                targetBuffer[_destIndex] = imgPalette[tpix[tscanoffset + sx] + att];
                                pixrendered[_destIndex] |= 256;
                                _destIndex++;
								sx++;
                            }
                        } 
						else {
                            while (sx < 8) {
                                col = tpix[tscanoffset + sx];
                                if(col != 0) {
                                    targetBuffer[_destIndex] = imgPalette[col + att];
                                    pixrendered[_destIndex] |= 256;
                                }
                                _destIndex++;
								sx++;
                            }
                        }
                    }                    
                }
                
                // Increase Horizontal Tile Counter:
				cntHT++;
                if (cntHT == 32) {
                    cntHT = 0;
                    cntH++;
                    cntH %= 2;
                    curNt = ntable1[(cntV << 1) + cntH];   
                }
            }
            
            // Tile data for one row should now have been fetched,
            // so the data in the array is valid.
            validTileData = true;            
        }
        
        // update vertical scroll:
        cntFV++;
        if (cntFV == 8) {
            cntFV = 0;
            cntVT++;
            if (cntVT == 30) {
                cntVT = 0;
                cntV++;
                cntV %= 2;
                curNt = ntable1[(cntV << 1) + cntH];
            } else if (cntVT == 32) {
                cntVT = 0;
            }
            
            // Invalidate fetched data:
            validTileData = false;            
        }
    }
    
    function renderSpritesPartially(startscan:Int, scancount:Int, bgPri:Bool) {
        if (f_spVisibility == 1) {			
			var srcy1:Int = 0;
			var srcy2:Int = 0;
            
            for (i in 0...64) {
                if (bgPriority[i] == bgPri && sprX[i] >= 0 && sprX[i] < 256 && sprY[i] + 8 >= startscan && sprY[i] < startscan + scancount) {				
                    // Show sprite.
                    if (f_spriteSize == 0) {
                        // 8x8 sprites
                        
                        srcy1 = 0;
                        srcy2 = 8;
                        
                        if (sprY[i] < startscan) {
                            srcy1 = startscan - sprY[i] - 1;
                        }
                        
                        if (sprY[i] + 8 > startscan + scancount) {
                            srcy2 = startscan + scancount - sprY[i] + 1;
                        }
                        
                        if (f_spPatternTable == 0) {
                            ptTile[sprTile[i]].render(buffer, 
                                0, srcy1, 8, srcy2, sprX[i], 
                                sprY[i] + 1, sprCol[i], sprPalette, 
                                horiFlip[i], vertFlip[i], i, 
                                pixrendered
                            );
                        } 
						else {
                            ptTile[sprTile[i] + 256].render(buffer, 0, srcy1, 8, srcy2, sprX[i], sprY[i] + 1, sprCol[i], sprPalette, horiFlip[i], vertFlip[i], i, pixrendered);
                        }
                    } 
					else {
                        // 8x16 sprites
                        var top = sprTile[i];
                        if ((top & 1) != 0) {
                            top = sprTile[i] - 1 + 256;
                        }
                        
                        srcy1 = 0;
                        srcy2 = 8;
                        
                        if (sprY[i] < startscan) {
                            srcy1 = startscan - sprY[i] - 1;
                        }
                        
                        if (sprY[i] + 8 > startscan+scancount) {
                            srcy2 = startscan + scancount - sprY[i];
                        }
                        
                        ptTile[top + (vertFlip[i] ? 1 : 0)].render(
                            buffer,
                            0,
                            srcy1,
                            8,
                            srcy2,
                            sprX[i],
                            sprY[i] + 1,
                            sprCol[i],
                            sprPalette,
                            horiFlip[i],
                            vertFlip[i],
                            i,
                            pixrendered
                        );
                        
                        srcy1 = 0;
                        srcy2 = 8;
                        
                        if (sprY[i] + 8 < startscan) {
                            srcy1 = startscan - (sprY[i] + 8 + 1);
                        }
                        
                        if (sprY[i] + 16 > startscan + scancount) {
                            srcy2 = startscan + scancount - (sprY[i] + 8);
                        }
                        
                        ptTile[top + (vertFlip[i] ? 0 : 1)].render(
                            buffer,
                            0,
                            srcy1,
                            8,
                            srcy2,
                            sprX[i],
                            sprY[i] + 1 + 8,
                            sprCol[i],
                            sprPalette,
                            horiFlip[i],
                            vertFlip[i],
                            i,
                            pixrendered
                        );
                        
                    }
                }
            }
        }
    }
    
	var toffset:Int;
	var tIndexAdd:Int;
	var bufferIndex:Int;
	var bgPri:Bool;
    function checkSprite0(scan:Int):Bool {        
        spr0HitX = -1;
        spr0HitY = -1;
        
        toffset = 0;
        tIndexAdd = (f_spPatternTable == 0 ? 0 : 256);        
        bufferIndex = 0;
        col = 0;
        bgPri = false;
		
		var t:Tile, i:Int = 0;
        var x = sprX[0];
        var y = sprY[0] + 1;
        
        if (f_spriteSize == 0) {
            // 8x8 sprites.
            // Check range:
            if (y <= scan && y + 8 > scan && x >= -7 && x < 256) {                
                // Sprite is in range.
                // Draw scanline:
                t = ptTile[sprTile[0] + tIndexAdd];
                col = sprCol[0];
                bgPri = bgPriority[0];
                
                if (vertFlip[0]) {
                    toffset = 7 - (scan -y);
                } 
				else {
                    toffset = scan - y;
                }
                toffset *= 8;
                
                bufferIndex = scan * 256 + x;
                if (horiFlip[0]) {
					i = 7;
					while(i >= 0) {
                        if (x >= 0 && x < 256) {
                            if (bufferIndex >= 0 && bufferIndex < 61440 && pixrendered[bufferIndex] != 0) {
                                if (t.pix[toffset + i] != 0) {
                                    spr0HitX = bufferIndex % 256;
                                    spr0HitY = scan;
                                    return true;
                                }
                            }
                        }
                        x++;
                        bufferIndex++;
						i--;
                    }
                } 
				else {
                    for (i in 0...8) {
                        if (x >= 0 && x < 256) {
                            if (bufferIndex >= 0 && bufferIndex < 61440 && pixrendered[bufferIndex] != 0) {
                                if (t.pix[toffset + i] != 0) {
                                    spr0HitX = bufferIndex % 256;
                                    spr0HitY = scan;
                                    return true;
                                }
                            }
                        }
                        x++;
                        bufferIndex++;  
                    }   
                }
            }
        } 
		else {
            // 8x16 sprites:        
            // Check range:
            if (y <= scan && y + 16 > scan && x >= -7 && x < 256) {
                // Sprite is in range.
                // Draw scanline:
                
                if (vertFlip[0]) {
                    toffset = 15 - (scan - y);
                } 
				else {
                    toffset = scan - y;
                }
                
                if (toffset < 8) {
                    // first half of sprite.
                    t = ptTile[sprTile[0] + (vertFlip[0] ? 1 : 0) + ((sprTile[0] & 1) != 0 ? 255 : 0)];
                } 
				else {
                    // second half of sprite.
                    t = ptTile[sprTile[0] + (vertFlip[0] ? 0 : 1) + ((sprTile[0] & 1) != 0 ? 255 : 0)];
                    if (vertFlip[0]) {
                        toffset = 15 - toffset;
                    }
                    else {
                        toffset -= 8;
                    }
                }
                toffset *= 8;
                col = sprCol[0];
                bgPri = bgPriority[0];
                
                bufferIndex = scan * 256 + x;
                if (horiFlip[0]) {
					i = 7;
					while(i >= 0) {
                        if (x >= 0 && x < 256) {
                            if (bufferIndex >= 0 && bufferIndex < 61440 && pixrendered[bufferIndex] != 0) {
                                if (t.pix[toffset + i] != 0) {
                                    spr0HitX = bufferIndex % 256;
                                    spr0HitY = scan;
                                    return true;
                                }
                            }
                        }
                        x++;
                        bufferIndex++;
						i--;
                    }                    
                } 
				else {                    
                    for (i in 0...8) {
                        if (x >= 0 && x < 256) {
                            if (bufferIndex >= 0 && bufferIndex < 61440 && pixrendered[bufferIndex] != 0) {
                                if (t.pix[toffset + i] != 0) {
                                    spr0HitX = bufferIndex % 256;
                                    spr0HitY = scan;
                                    return true;
                                }
                            }
                        }
                        x++;
                        bufferIndex++;
                    }                    
                }                
            }            
        }
        
        return false;
    }
    
    // This will write to PPU memory, and
    // update internally buffered data
    // appropriately.
    function writeMem(address:Int, value:Int) {
        vramMem[address] = value;
        
        // Update internally buffered data:
        if (address < 0x2000) {
            vramMem[address] = value;
            patternWrite(address, value);
        }
        else if (address >= 0x2000 && address < 0x23c0) {    
            nameTableWrite(ntable1[0], address - 0x2000, value);
        }
        else if (address >= 0x23c0 && address < 0x2400) {    
            attribTableWrite(ntable1[0],address - 0x23c0, value);
        }
        else if (address >= 0x2400 && address < 0x27c0) {    
            nameTableWrite(ntable1[1],address - 0x2400, value);
        }
        else if (address >= 0x27c0 && address < 0x2800) {    
            attribTableWrite(ntable1[1],address - 0x27c0, value);
        }
        else if (address >= 0x2800 && address < 0x2bc0) {    
            nameTableWrite(ntable1[2],address - 0x2800, value);
        }
        else if (address >= 0x2bc0 && address < 0x2c00) {    
            attribTableWrite(ntable1[2],address - 0x2bc0, value);
        }
        else if (address >= 0x2c00 && address < 0x2fc0) {    
            nameTableWrite(ntable1[3], address - 0x2c00, value);
        }
        else if (address >= 0x2fc0 && address < 0x3000) {
            attribTableWrite(ntable1[3],address - 0x2fc0, value);
        }
        else if (address >= 0x3f00 && address < 0x3f20) {
            updatePalettes();
        }
    }
    
    // Reads data from $3f00 to $f20 
    // into the two buffered palettes.
    function updatePalettes() {        
        for (i in 0...16) {
            if (f_dispType == 0) {
                imgPalette[i] = palTable.getEntry(vramMem[0x3f00 + i] & 63);
            } 
			else {
                imgPalette[i] = palTable.getEntry(vramMem[0x3f00 + i] & 32);
            }
        }
		
        for (i in 0...16) {
            if (f_dispType == 0) {
                sprPalette[i] = palTable.getEntry(vramMem[0x3f10 + i] & 63);
            } 
			else {
                sprPalette[i] = palTable.getEntry(vramMem[0x3f10 + i] & 32);
            }
        }
    }
    
    // Updates the internal pattern
    // table buffers with this new byte.
    // In vNES, there is a version of this with 4 arguments which isn't used.
    function patternWrite(address:Int, value:Int) {
        var tileIndex = Std.int(address / 16);
        var leftOver = address % 16;
        if (leftOver < 8) {
            ptTile[tileIndex].setScanline(leftOver, value, vramMem[address + 8]);
        } 
		else {
            ptTile[tileIndex].setScanline(leftOver - 8, vramMem[address - 8], value);
        }
    }

    // Updates the internal name table buffers
    // with this new byte.
    inline function nameTableWrite(index:Int, address:Int, value:Int) {
        nameTable[index].tile[address] = value;
        
        // Update Sprite #0 hit:
        //updateSpr0Hit();
        checkSprite0(scanline - 20);
    }
    
    // Updates the internal pattern
    // table buffers with this new attribute
    // table byte.
    inline function attribTableWrite(index:Int, address:Int, value:Int) {
        nameTable[index].writeAttrib(address,value);
    }
    
    // Updates the internally buffered sprite
    // data with this new byte of info.
    function spriteRamWriteUpdate(address:Int, value:Int) {
        var tIndex = Std.int(address / 4);
        
        if (tIndex == 0) {
            //updateSpr0Hit();
            checkSprite0(scanline - 20);
        }
		
		switch(address % 4) {
			case 0:
				// Y coordinate
				sprY[tIndex] = value;
				
			case 1:
				// Tile index
				sprTile[tIndex] = value;
				
			case 2:
				// Attributes
				vertFlip[tIndex] = ((value & 0x80) != 0);
				horiFlip[tIndex] = ((value & 0x40) != 0);
				bgPriority[tIndex] = ((value & 0x20) != 0);
				sprCol[tIndex] = (value & 3) << 2;
				
			case 3: 
				// X coordinate
				sprX[tIndex] = value;
		}        
    }
    
    inline function doNMI() {
        // Set VBlank flag:
        setStatusFlag(PPU.STATUS_VBLANK, true);
        //nes.getCpu().doNonMaskableInterrupt();
        nes.cpu.requestIrq(CPU.IRQ_NMI);
    }
    
}
