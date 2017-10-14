package;

/**
 * ...
 * @author Krtolica Vujadin
 */
// ported from vNES
class PaletteTable {
	
	var curTable:Array<Int>;
	var emphTable:Array<Array<Int>>;
	var currentEmph:Int;
	
	
	public function new() {
		curTable = [];
		emphTable = [];
		currentEmph = -1;
	}
	
	function reset() {
        setEmphasis(0);
    }
    
    public function loadNTSCPalette() {
        curTable = [
			0x525252, 0xB40000, 0xA00000, 0xB1003D, 0x740069, 0x00005B, 0x00005F, 0x001840, 
			0x002F10, 0x084A08, 0x006700, 0x124200, 0x6D2800, 0x000000, 0x000000, 0x000000, 
			0xC4D5E7, 0xFF4000, 0xDC0E22, 0xFF476B, 0xD7009F, 0x680AD7, 0x0019BC, 0x0054B1, 
			0x006A5B, 0x008C03, 0x00AB00, 0x2C8800, 0xA47200, 0x000000, 0x000000, 0x000000, 
			0xF8F8F8, 0xFFAB3C, 0xFF7981, 0xFF5BC5, 0xFF48F2, 0xDF49FF, 0x476DFF, 0x00B4F7, 
			0x00E0FF, 0x00E375, 0x03F42B, 0x78B82E, 0xE5E218, 0x787878, 0x000000, 0x000000, 
			0xFFFFFF, 0xFFF2BE, 0xF8B8B8, 0xF8B8D8, 0xFFB6FF, 0xFFC3FF, 0xC7D1FF, 0x9ADAFF, 
			0x88EDF8, 0x83FFDD, 0xB8F8B8, 0xF5F8AC, 0xFFFFB0, 0xF8D8F8, 0x000000, 0x000000
		];
        makeTables();
        setEmphasis(0);
    }
    
    public function loadPALPalette() {
        curTable = [
			0x525252, 0xB40000, 0xA00000, 0xB1003D, 0x740069, 0x00005B, 0x00005F, 0x001840, 
			0x002F10, 0x084A08, 0x006700, 0x124200, 0x6D2800, 0x000000, 0x000000, 0x000000, 
			0xC4D5E7, 0xFF4000, 0xDC0E22, 0xFF476B, 0xD7009F, 0x680AD7, 0x0019BC, 0x0054B1, 
			0x006A5B, 0x008C03, 0x00AB00, 0x2C8800, 0xA47200, 0x000000, 0x000000, 0x000000, 
			0xF8F8F8, 0xFFAB3C, 0xFF7981, 0xFF5BC5, 0xFF48F2, 0xDF49FF, 0x476DFF, 0x00B4F7, 
			0x00E0FF, 0x00E375, 0x03F42B, 0x78B82E, 0xE5E218, 0x787878, 0x000000, 0x000000, 
			0xFFFFFF, 0xFFF2BE, 0xF8B8B8, 0xF8B8D8, 0xFFB6FF, 0xFFC3FF, 0xC7D1FF, 0x9ADAFF, 
			0x88EDF8, 0x83FFDD, 0xB8F8B8, 0xF5F8AC, 0xFFFFB0, 0xF8D8F8, 0x000000, 0x000000
		];
        makeTables();
        setEmphasis(0);
    }
    
    function makeTables() {
        var r:Int, g:Int, b:Int, col:Int, rFactor:Float, gFactor:Float, bFactor:Float;
        
        // Calculate a table for each possible emphasis setting:
        for (emph in 0...8) {
            
            // Determine color component factors:
            rFactor = 1.0;
            gFactor = 1.0;
            bFactor = 1.0;
            
            if ((emph & 1) != 0) {
                rFactor = 0.75;
                bFactor = 0.75;
            }
            if ((emph & 2) != 0) {
                rFactor = 0.75;
                gFactor = 0.75;
            }
            if ((emph & 4) != 0) {
                gFactor = 0.75;
                bFactor = 0.75;
            }
            
            emphTable[emph] = [];
            
            // Calculate table:
            for (i in 0...64) {
                col = curTable[i];
                r = Std.int(getRed(col) * rFactor);
                g = Std.int(getGreen(col) * gFactor);
                b = Std.int(getBlue(col) * bFactor);
                emphTable[emph][i] = getRgb(b, g, r); //getRgb(r, g, b);
            }
        }
    }
    
	inline  public function setEmphasis(emph:Int) {
        if (emph != currentEmph) {
            currentEmph = emph;
            for (i in 0...64) {
                curTable[i] = emphTable[emph][i];
            }
        }
    }
    
    inline public function getEntry(yiq:Int):Int {
        return curTable[yiq];
    }
    
    inline function getRed(rgb:Int):Int {
        return (rgb >> 16) & 0xFF;
    }
    
    inline function getGreen(rgb:Int):Int {
        return (rgb >> 8) & 0xFF;
    }
    
    inline function getBlue(rgb:Int):Int {
        return rgb & 0xFF;
    }
    
    inline function getRgb(r:Int, g:Int, b:Int):Int {
        return 0xFF << 24 | (r << 16) | (g << 8) | b;
    }
    
    function loadDefaultPalette() {
        curTable[ 0] = getRgb(117,117,117);
        curTable[ 1] = getRgb( 39, 27,143);
        curTable[ 2] = getRgb(  0,  0,171);
        curTable[ 3] = getRgb( 71,  0,159);
        curTable[ 4] = getRgb(143,  0,119);
        curTable[ 5] = getRgb(171,  0, 19);
        curTable[ 6] = getRgb(167,  0,  0);
        curTable[ 7] = getRgb(127, 11,  0);
        curTable[ 8] = getRgb( 67, 47,  0);
        curTable[ 9] = getRgb(  0, 71,  0);
        curTable[10] = getRgb(  0, 81,  0);
        curTable[11] = getRgb(  0, 63, 23);
        curTable[12] = getRgb( 27, 63, 95);
        curTable[13] = getRgb(  0,  0,  0);
        curTable[14] = getRgb(  0,  0,  0);
        curTable[15] = getRgb(  0,  0,  0);
        curTable[16] = getRgb(188,188,188);
        curTable[17] = getRgb(  0,115,239);
        curTable[18] = getRgb( 35, 59,239);
        curTable[19] = getRgb(131,  0,243);
        curTable[20] = getRgb(191,  0,191);
        curTable[21] = getRgb(231,  0, 91);
        curTable[22] = getRgb(219, 43,  0);
        curTable[23] = getRgb(203, 79, 15);
        curTable[24] = getRgb(139,115,  0);
        curTable[25] = getRgb(  0,151,  0);
        curTable[26] = getRgb(  0,171,  0);
        curTable[27] = getRgb(  0,147, 59);
        curTable[28] = getRgb(  0,131,139);
        curTable[29] = getRgb(  0,  0,  0);
        curTable[30] = getRgb(  0,  0,  0);
        curTable[31] = getRgb(  0,  0,  0);
        curTable[32] = getRgb(255,255,255);
        curTable[33] = getRgb( 63,191,255);
        curTable[34] = getRgb( 95,151,255);
        curTable[35] = getRgb(167,139,253);
        curTable[36] = getRgb(247,123,255);
        curTable[37] = getRgb(255,119,183);
        curTable[38] = getRgb(255,119, 99);
        curTable[39] = getRgb(255,155, 59);
        curTable[40] = getRgb(243,191, 63);
        curTable[41] = getRgb(131,211, 19);
        curTable[42] = getRgb( 79,223, 75);
        curTable[43] = getRgb( 88,248,152);
        curTable[44] = getRgb(  0,235,219);
        curTable[45] = getRgb(  0,  0,  0);
        curTable[46] = getRgb(  0,  0,  0);
        curTable[47] = getRgb(  0,  0,  0);
        curTable[48] = getRgb(255,255,255);
        curTable[49] = getRgb(171,231,255);
        curTable[50] = getRgb(199,215,255);
        curTable[51] = getRgb(215,203,255);
        curTable[52] = getRgb(255,199,255);
        curTable[53] = getRgb(255,199,219);
        curTable[54] = getRgb(255,191,179);
        curTable[55] = getRgb(255,219,171);
        curTable[56] = getRgb(255,231,163);
        curTable[57] = getRgb(227,255,163);
        curTable[58] = getRgb(171,243,191);
        curTable[59] = getRgb(179,255,207);
        curTable[60] = getRgb(159,255,243);
        curTable[61] = getRgb(  0,  0,  0);
        curTable[62] = getRgb(  0,  0,  0);
        curTable[63] = getRgb(  0,  0,  0);
        
        makeTables();
        setEmphasis(0);
    }
    
}
