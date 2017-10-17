package papu;

/**
 * ...
 * @author Krtolica Vujadin
 */
 // ported from vNES
class ChannelNoise {
	
	var papu:PAPU;
    
    public var isEnabled:Bool;
    var envDecayDisable:Bool;
    var envDecayLoopEnable:Bool;
    var lengthCounterEnable:Bool;
    var envReset:Bool;
    var shiftNow:Bool;
    
    public var lengthCounter:Int;
    public var progTimerCount:Int;
    public var progTimerMax:Int;
    public var envDecayRate:Int;
    public var envDecayCounter:Int;
    public var envVolume:Int;
    public var masterVolume:Int;
    public var shiftReg:Int;
    public var randomBit:Int;
    public var randomMode:Int;
    public var sampleValue:Int;
    public var accValue:Int = 0;
    public var accCount:Int = 1;
    public var tmp:Int;

	public function new(papu:PAPU) {
		this.papu = papu;		
		reset();
		shiftReg = 1 << 14;
	}
	
	public function reset() {
        progTimerCount = 0;
        progTimerMax = 0;
        isEnabled = false;
        lengthCounter = 0;
        lengthCounterEnable = false;
        envDecayDisable = false;
        envDecayLoopEnable = false;
        shiftNow = false;
        envDecayRate = 0;
        envDecayCounter = 0;
        envVolume = 0;
        masterVolume = 0;
        shiftReg = 0;
        randomBit = 0;
        randomMode = 0;
        sampleValue = 0;
        tmp = 0;
    }
	
	inline public function clockLengthCounter() {
        if (lengthCounterEnable && lengthCounter > 0){
            lengthCounter--;
            if (lengthCounter == 0) {
                updateSampleValue();
            }
        }
    }

    public function clockEnvDecay() {
        if(envReset) {
            // Reset envelope:
            envReset = false;
            envDecayCounter = envDecayRate + 1;
            envVolume = 0xF;
        } else if (--envDecayCounter <= 0) {
            // Normal handling:
            envDecayCounter = envDecayRate + 1;
            if(envVolume > 0) {
                envVolume--;
            }
            else {
                envVolume = envDecayLoopEnable ? 0xF : 0;
            }   
        }
        masterVolume = envDecayDisable ? envDecayRate : envVolume;
        updateSampleValue();
    }

    inline function updateSampleValue() {
        if (isEnabled && lengthCounter > 0) {
            sampleValue = randomBit * masterVolume;
        }
    }

    inline public function writeReg(address:Int, value:Int) {
        if(address == 0x400C) {
            // Volume/Envelope decay:
            envDecayDisable = ((value & 0x10) != 0);
            envDecayRate = value & 0xF;
            envDecayLoopEnable = ((value & 0x20) != 0);
            lengthCounterEnable = ((value & 0x20) == 0);
            masterVolume = envDecayDisable ? envDecayRate : envVolume;
        
        } else if(address == 0x400E) {
            // Programmable timer:
            progTimerMax = papu.getNoiseWaveLength(value & 0xF);
            randomMode = value >> 7;
        
        } else if(address == 0x400F) {
            // Length counter
            lengthCounter = papu.getLengthMax(value & 248);
            envReset = true;
        }
        // Update:
        //updateSampleValue();
    }

    public function setEnabled(value:Bool) {
        isEnabled = value;
        if (!value) {
            lengthCounter = 0;
        }
        updateSampleValue();
    }

    inline public function getLengthStatus():Int {
        return ((lengthCounter == 0 || !isEnabled) ? 0 : 1);
    }
	
}
