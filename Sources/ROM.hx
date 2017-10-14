package;

import Mappers.Mapper001;
import Mappers.Mapper002;
import Mappers.Mapper003;
import Mappers.Mapper004;
import Mappers.Mapper007;
import Mappers.Mapper009;
import Mappers.Mapper010;
import Mappers.Mapper011;
import Mappers.Mapper015;
import Mappers.Mapper018;
import Mappers.Mapper021;
import Mappers.Mapper022;
import Mappers.Mapper023;
import Mappers.Mapper032;
import Mappers.Mapper033;
import Mappers.Mapper034;
import Mappers.Mapper048;
import Mappers.Mapper071;
import Mappers.Mapper072;
import Mappers.Mapper075;
import Mappers.Mapper078;
import Mappers.Mapper079;
import Mappers.Mapper087;
import Mappers.Mapper094;
import Mappers.Mapper105;
import Mappers.Mapper140;
import Mappers.Mapper182;

import haxe.ds.Vector;
import haxe.io.Bytes;

/**
 * ...
 * @author Krtolica Vujadin
 */
 // ported from vNES
class ROM {
	
	// Mirroring types:
    public static inline var VERTICAL_MIRRORING:Int = 0;
    public static inline var HORIZONTAL_MIRRORING:Int = 1;
    public static inline var FOURSCREEN_MIRRORING:Int = 2;
    public static inline var SINGLESCREEN_MIRRORING:Int = 3;
    public static inline var SINGLESCREEN_MIRRORING2:Int = 4;
    public static inline var SINGLESCREEN_MIRRORING3:Int = 5;
    public static inline var SINGLESCREEN_MIRRORING4:Int = 6;
    public static inline var CHRROM_MIRRORING:Int = 7;
	
	var nes:NES;
	var mapperName:Array<String>;
	var supportedMappers:Array<Int>;
	
	var header:Array<Int>;
    public var rom(default, null):Vector<Vector<Int>>;
    public var vrom(default, null):Vector<Vector<Int>>;
    public var vromTile(default, null):Vector<Vector<Tile>>;
    
    public var romCount(default, null):Int;
    public var vromCount(default, null):Int;
    public var mirroring(default, null):Int;
    public var batteryRam(default, null):Vector<Int>;
    public var trainer(default, null):Bool;
    public var fourScreen(default, null):Bool;
    public var mapperType(default, null):Int;
    public var valid(default, null):Bool;

	public function new(nes:NES) {
		this.nes = nes;
    
		mapperName = [];
		
		supportedMappers = [0, 1, 2, 3, 4, 7, 9, 10, 11, 15, 18, 21, 22, 23, 32, 33, 34, 48, 71, 72, 75, 78, 79, 87, 94, 105, 140, 182];
		
		for (i in 0...255) {
			mapperName[i] = "Unknown Mapper";
		}
		mapperName[ 0] = "Direct Access";
		mapperName[ 1] = "Nintendo MMC1";
		mapperName[ 2] = "UNROM";
		mapperName[ 3] = "CNROM";
		mapperName[ 4] = "Nintendo MMC3";
		mapperName[ 5] = "Nintendo MMC5";
		mapperName[ 6] = "FFE F4xxx";
		mapperName[ 7] = "AOROM";
		mapperName[ 8] = "FFE F3xxx";
		mapperName[ 9] = "Nintendo MMC2";
		mapperName[10] = "Nintendo MMC4";
		mapperName[11] = "Color Dreams Chip";
		mapperName[12] = "FFE F6xxx";
		mapperName[15] = "100-in-1 switch";
		mapperName[16] = "Bandai chip";
		mapperName[17] = "FFE F8xxx";
		mapperName[18] = "Jaleco SS8806 chip";
		mapperName[19] = "Namcot 106 chip";
		mapperName[20] = "Famicom Disk System";
		mapperName[21] = "Konami VRC4a";
		mapperName[22] = "Konami VRC2a";
		mapperName[23] = "Konami VRC2a";
		mapperName[24] = "Konami VRC6";
		mapperName[25] = "Konami VRC4b";
		mapperName[32] = "Irem G-101 chip";
		mapperName[33] = "Taito TC0190/TC0350";
		mapperName[34] = "32kB ROM switch";
		
		mapperName[64] = "Tengen RAMBO-1 chip";
		mapperName[65] = "Irem H-3001 chip";
		mapperName[66] = "GNROM switch";
		mapperName[67] = "SunSoft3 chip";
		mapperName[68] = "SunSoft4 chip";
		mapperName[69] = "SunSoft5 FME-7 chip";
		mapperName[71] = "Camerica chip";
		mapperName[78] = "Irem 74HC161/32-based";
		mapperName[91] = "Pirate HK-SF3 chip";
	}
	
	public function load(data_:haxe.io.Bytes) {
        var isNES:String = data_.getString(0, 1) + data_.getString(1, 1) + data_.getString(2, 1) + data_.getString(3, 1);
        if (isNES != "NES\x1a") {
			trace("Not a valid NES ROM.");
            return;
        }

        var data = data_.getData();
		
        header = [];
        for (i in 0...16) {
            header[i] = Bytes.fastGet(data_.getData(), i) & 0xFF;
        }
		
        romCount = header[4];
        vromCount = header[5] * 2; // Get the number of 4kB banks, not 8kB
        mirroring = ((header[6] & 1) != 0 ? 1 : 0);
        //batteryRam = (header[6] & 2) != 0;
        trainer = (header[6] & 4) != 0;
        fourScreen = (header[6] & 8) != 0;
        mapperType = (header[6] >> 4) | (header[7] & 0xF0);
		
        /* TODO
        if (this.batteryRam)
            this.loadBatteryRam();*/
        // Check whether byte 8-15 are zero's:
        var foundError = false;
        for (i in 8...16) {
            if (header[i] != 0) {
                foundError = true;
                break;
            }
        }
        if (foundError) {
            mapperType &= 0xF; // Ignore byte 7
        }
		
        // Load PRG-ROM banks:
        rom = new Vector<Vector<Int>>(romCount);
        var offset:Int = 16;
        for (i in 0...this.romCount) {
            rom[i] = new Vector<Int>(16384);
            for (j in 0...16384) {
                if (offset + j >= data_.length) {
                    break;
                }
                rom[i][j] = Bytes.fastGet(data_.getData(), offset + j) & 0xFF;
            }
            offset += 16384;
        }
		
        // Load CHR-ROM banks:
        vrom = new Vector<Vector<Int>>(vromCount);
        for (i in 0...this.vromCount) {
            vrom[i] = new Vector<Int>(4096);
            for (j in 0...4096) {
                if (offset + j >= data_.length){
                    break;
                }
                vrom[i][j] = Bytes.fastGet(data_.getData(), offset + j) & 0xFF;
            }
            offset += 4096;
        }
        
        // Create VROM tiles:
        vromTile = new Vector<Vector<Tile>>(vromCount);
        for (i in 0...this.vromCount) {
            vromTile[i] = new Vector<Tile>(256);
            for (j in 0...256) {
                vromTile[i][j] = new Tile();
            }
        }
        
        // Convert CHR-ROM banks to tiles:
        var tileIndex:Int = 0;
        var leftOver:Int = 0;
        for (v in 0...this.vromCount) {
            for (i in 0...4096) {
                tileIndex = i >> 4;
                leftOver = i % 16;
                if (leftOver < 8) {
                    vromTile[v][tileIndex].setScanline(
                        leftOver,
                        vrom[v][i],
                        vrom[v][i+8]
                    );
                } 
				else {
                    vromTile[v][tileIndex].setScanline(
                        leftOver-8,
                        vrom[v][i-8],
                        vrom[v][i]
                    );
                }
            }
        }		
        
        valid = true;
    }
    
    public function getMirroringType():Int {
        if (fourScreen) {
            return ROM.FOURSCREEN_MIRRORING;
        }
        if (mirroring == 0) {
            return ROM.HORIZONTAL_MIRRORING;
        }
        return ROM.VERTICAL_MIRRORING;
    }
    
    function getMapperName():String {
        if (mapperType >= 0 && mapperType < mapperName.length) {
            return mapperName[mapperType];
        }
        return "Unknown Mapper, " + mapperType;
    }
    
    function mapperSupported():Bool {
        return Lambda.indexOf(supportedMappers, mapperType) != -1;
    }
    
    public function createMapper():MapperDefault {
		trace(mapperType);
        if (mapperSupported()) {
			switch(mapperType) {
				case 0:
					return new MapperDefault(nes);
				
				case 1:
					return new Mapper001(nes);
					
				case 2: 
					return new Mapper002(nes);
					
				case 3:
					return new Mapper003(nes);
					
				case 4:
					return new Mapper004(nes);
					
				case 7:
					return new Mapper007(nes);
					
				case 9:
					return new Mapper009(nes);
					
				case 10:
					return new Mapper010(nes);
					
				case 11:
					return new Mapper011(nes);
					
				case 15:
					return new Mapper015(nes);
					
				case 18:
					return new Mapper018(nes);
					
				case 21:
					return new Mapper021(nes);
					
				case 22:
					return new Mapper022(nes);
					
				case 23:
					return new Mapper023(nes);
					
				case 32:
					return new Mapper032(nes);
					
				case 33:
					return new Mapper033(nes);
					
				case 34:
					return new Mapper034(nes);
					
				case 48:
					return new Mapper048(nes);
					
				case 71:
					return new Mapper071(nes);
					
				case 72:
					return new Mapper072(nes);
					
				case 75:
					return new Mapper075(nes);
					
				case 78:
					return new Mapper078(nes);
					
				case 79:
					return new Mapper079(nes);
					
				case 87:
					return new Mapper087(nes);
					
				case 94:
					return new Mapper094(nes);
					
				case 105:
					return new Mapper105(nes);
					
				case 140:
					return new Mapper140(nes);
					
				case 182:
					return new Mapper182(nes);
			}    
			
			return null;
        }
        else {
            trace("This ROM uses a mapper not supported by JSNES: " + getMapperName() + " (" + mapperType + ")");
            return null;
        }
    }
	
}
