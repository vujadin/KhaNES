package;

import haxe.ds.Vector;

/**
 * ...
 * @author Krtolica Vujadin
 */
// ported from vNES
class NameTable {
	
	public var width:Int;
	public var height:Int;
	public var name:String;
	public var tile:Vector<Int>;
	public var attrib:Vector<Int>;
	
	var basex:Int;
	var basey:Int;
	var add:Int;
	var tx:Int;
	var ty:Int;
	var attindex:Int;
	

	public function new(width:Int, height:Int, name:String) {   
		this.width = width;
		this.height = height;
		this.name = name;    
		tile = new Vector<Int>(width * height);
		attrib = new Vector<Int>(width * height);
	}
	
	inline public function getTileIndex(x:Int, y:Int):Int {
        return tile[y * width + x];
    }

    inline public function getAttrib(x:Int, y:Int):Int {
        return attrib[y * width + x];
    }

    public function writeAttrib(index:Int, value:Int){
        basex = (index % 8) * 4;
        basey = Math.floor(index / 8) * 4;
        add = 0;
        tx = 0;
		ty = 0;
        attindex = 0;
		    
        for (sqy in 0...2) {
            for (sqx in 0...2) {
                add = (value >> (2 * (sqy * 2 + sqx))) & 3;
                for (y in 0...2) {
                    for (x in 0...2) {
                        tx = basex + sqx * 2 + x;
                        ty = basey + sqy * 2 + y;
                        attindex = ty * width + tx;
                        attrib[ty * width + tx] = (add << 2) & 12;
                    }
                }
            }
        }
    }
    
    public function toJSON():Dynamic {
        return {
            'tile': tile,
            'attrib': attrib
        };
    }
    
    public function fromJSON(s:Dynamic) {
        tile = s.tile;
        attrib = s.attrib;
    }
	
}