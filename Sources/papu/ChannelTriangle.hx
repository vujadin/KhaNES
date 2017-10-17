package papu;

/**
 * ...
 * @author Krtolica Vujadin
 */
 // ported from vNES
class ChannelTriangle {
	
	var papu:PAPU;
    
    public var isEnabled:Bool;
    public var sampleCondition:Bool;
    var lengthCounterEnable:Bool;
    var lcHalt:Bool;
    var lcControl:Bool;
    
    public var progTimerCount:Int;
    public var progTimerMax:Int;
    public var triangleCounter:Int;
    public var lengthCounter:Int;
    public var linearCounter:Int;
    public var lcLoadValue:Int;
    public var sampleValue:Int;
    var tmp:Int;

	public function new(papu:PAPU) {
		this.papu = papu;
		reset();
	}
	
	public function reset() {
        progTimerCount = 0;
        progTimerMax = 0;
        triangleCounter = 0;
        isEnabled = false;
        sampleCondition = false;
        lengthCounter = 0;
        lengthCounterEnable = false;
        linearCounter = 0;
        lcLoadValue = 0;
        lcHalt = true;
        lcControl = false;
        tmp = 0;
        sampleValue = 0xF;
    }
	
	inline public function clockLengthCounter() {
        if (lengthCounterEnable && lengthCounter > 0) {
            lengthCounter--;
            if (lengthCounter == 0) {
                updateSampleCondition();
            }
        }
    }

    inline public function clockLinearCounter() {
        if (lcHalt){
            // Load:
            linearCounter = lcLoadValue;
            updateSampleCondition();
        } else if (linearCounter > 0) {
            // Decrement:
            linearCounter--;
            updateSampleCondition();
        }
		
        if (!lcControl) {
            // Clear halt flag:
            lcHalt = false;
        }
    }

    inline public function getLengthStatus():Int {
        return ((lengthCounter == 0 || !isEnabled) ? 0 : 1);
    }

    inline function readReg(address:Int):Int {
        return 0;
    }

    inline public function writeReg(address:Int, value:Int) {
        if (address == 0x4008) {
            // New values for linear counter:
            lcControl  = (value & 0x80) != 0;
            lcLoadValue =  value & 0x7F;
        
            // Length counter enable:
            lengthCounterEnable = !lcControl;
        }
        else if (address == 0x400A) {
            // Programmable timer:
            progTimerMax &= 0x700;
            progTimerMax |= value;
        
        }
        else if(address == 0x400B) {
            // Programmable timer, length counter
            progTimerMax &= 0xFF;
            progTimerMax |= (value & 0x07) << 8;
            lengthCounter = papu.getLengthMax(value & 0xF8);
            lcHalt = true;
        }
    
        updateSampleCondition();
    }

    inline function clockProgrammableTimer(nCycles:Int) {
        if (progTimerMax > 0) {
            progTimerCount += nCycles;
            while (progTimerMax > 0 && progTimerCount >= progTimerMax) {
                progTimerCount -= progTimerMax;
                if (isEnabled && lengthCounter > 0 && linearCounter > 0) {
                    clockTriangleGenerator();
                }
            }
        }
    }

    inline function clockTriangleGenerator() {
        triangleCounter++;
        triangleCounter &= 0x1F;
    }

    public function setEnabled(value:Bool) {
        isEnabled = value;
        if(!value) {
            lengthCounter = 0;
        }
        updateSampleCondition();
    }

    inline function updateSampleCondition() {
        sampleCondition = isEnabled && progTimerMax > 7 && linearCounter > 0 && lengthCounter > 0;
    }
	
}
