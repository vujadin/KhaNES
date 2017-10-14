package;

import haxe.ds.Vector;

/**
 * ...
 * @author Krtolica Vujadin
 */
// ported from vNES
class Tile {
	
	public var pix:Vector<Int>;
	var fbIndex:Int;
	var tIndex:Int;
	var x:Int;
	var y:Int;
	var w:Int;
	var h:Int;
	var incX:Int;
	var incY:Int;
	var palIndex:Int;
	var tpri:Int;
	var c:Int;
	var initialized:Bool;
	public var opaque:Vector<Bool>;
	
	
	public function new() {
		// Tile data:
		pix = new Vector<Int>(64);
		
		fbIndex = 0;
		tIndex = 0;
		x = 0;
		y = 0;
		initialized = false;
		opaque = new Vector<Bool>(8);
	}
	
	inline public function setBuffer(scanline:Array<Int>) {
        for (y in 0...8) {
            setScanline(y, scanline[y], scanline[y + 8]);
        }
    }
    
    public function setScanline(sline:Int, b1:Int, b2:Int) {
        initialized = true;
        tIndex = sline << 3;
        for (x in 0...8) {
            pix[tIndex + x] = ((b1 >> (7 - x)) & 1) + (((b2 >> (7 - x)) & 1) << 1);
            if(pix[tIndex + x] == 0) {
                opaque[sline] = false;
            }
        }
    }
    
    public function render(buffer:Vector<Int>, srcx1:Int, srcy1:Int, srcx2:Int, srcy2:Int, dx:Int, dy:Int, palAdd:Int, palette:Vector<Int>, flipHorizontal:Bool, flipVertical:Bool, pri:Int, priTable:Vector<Int>) {
        if (!(dx < -7 || dx >= 256 || dy < -7 || dy >= 240)) {
            w = srcx2 - srcx1;
			h = srcy2 - srcy1;
			
			if (dx < 0) {
				srcx1 -= dx;
			}
			if (dx + srcx2 >= 256) {			
				srcx2 = 256 - dx;
			}
			
			if (dy < 0) {
				srcy1 -= dy;
			}
			if (dy + srcy2 >= 240) {
				srcy2 = 240 - dy;
			}
			
			if (!flipHorizontal && !flipVertical) {			
				fbIndex = (dy << 8) + dx;
				tIndex = 0;
				for (y in 0...8) {
					for (x in 0...8) {
						if (x >= srcx1 && x < srcx2 && y >= srcy1 && y < srcy2) {
							palIndex = pix[tIndex];
							tpri = priTable[fbIndex];
							if (palIndex != 0 && pri <= (tpri & 0xFF)) {
								buffer[fbIndex] = palette[palIndex + palAdd];
								tpri = (tpri & 0xF00) | pri;
								priTable[fbIndex] = tpri;
							}
						}
						fbIndex++;
						tIndex++;
					}
					fbIndex -= 8;
					fbIndex += 256;
				}			
			} 
			else if (flipHorizontal && !flipVertical) {			
				fbIndex = (dy << 8) + dx;
				tIndex = 7;
				for (y in 0...8) {
					for (x in 0...8) {
						if (x >= srcx1 && x < srcx2 && y >= srcy1 && y < srcy2) {
							palIndex = pix[tIndex];
							tpri = priTable[fbIndex];
							if (palIndex != 0 && pri <= (tpri & 0xFF)) {
								buffer[fbIndex] = palette[palIndex + palAdd];
								tpri = (tpri & 0xF00) | pri;
								priTable[fbIndex] = tpri;
							}
						}
						fbIndex++;
						tIndex--;
					}
					fbIndex -= 8;
					fbIndex += 256;
					tIndex += 16;
				}			
			} 
			else if(flipVertical && !flipHorizontal) {			
				fbIndex = (dy << 8) + dx;
				tIndex = 56;
				for (y in 0...8) {
					for (x in 0...8) {
						if (x >= srcx1 && x < srcx2 && y >= srcy1 && y < srcy2) {
							palIndex = pix[tIndex];
							tpri = priTable[fbIndex];
							if (palIndex != 0 && pri <= (tpri & 0xFF)) {
								buffer[fbIndex] = palette[palIndex + palAdd];
								tpri = (tpri & 0xF00) | pri;
								priTable[fbIndex] = tpri;
							}
						}
						fbIndex++;
						tIndex++;
					}
					fbIndex -= 8;
					fbIndex += 256;
					tIndex -= 16;
				}			
			} 
			else {
				fbIndex = (dy << 8) + dx;
				tIndex = 63;
				for (y in 0...8) {
					for (x in 0...8) {
						if (x >= srcx1 && x < srcx2 && y >= srcy1 && y < srcy2) {
							palIndex = pix[tIndex];
							tpri = priTable[fbIndex];
							if (palIndex != 0 && pri <= (tpri & 0xFF)) {
								buffer[fbIndex] = palette[palIndex + palAdd];
								tpri = (tpri & 0xF00) | pri;
								priTable[fbIndex] = tpri;
							}
						}
						fbIndex++;
						tIndex--;
					}
					fbIndex -= 8;
					fbIndex += 256;
				}        
			} 
        }  
    }
    
    inline public function isTransparent(x:Int, y:Int):Bool {
        return (pix[(y << 3) + x] == 0);
    }
    
    public function toJSON():Dynamic {
        return {
            'opaque': opaque,
            'pix': pix
        };
    }

    public function fromJSON(s:Dynamic) {
        opaque = s.opaque;
        pix = s.pix;
    }
	
}
