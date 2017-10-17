package papu;

/**
 * ...
 * @author Krtolica Vujadin
 */
 // ported from vNES
class ChannelSquare {
	
	var papu:PAPU;
    
    static var dutyLookup:Array<Int> = [
         0, 1, 0, 0, 0, 0, 0, 0,
         0, 1, 1, 0, 0, 0, 0, 0,
         0, 1, 1, 1, 1, 0, 0, 0,
         1, 0, 0, 1, 1, 1, 1, 1
    ];
	
    static var impLookup:Array<Int> = [
         1,-1, 0, 0, 0, 0, 0, 0,
         1, 0,-1, 0, 0, 0, 0, 0,
         1, 0, 0, 0,-1, 0, 0, 0,
        -1, 0, 1, 0, 0, 0, 0, 0
    ];
    
    var sqr1:Bool;
    var isEnabled:Bool;
    var lengthCounterEnable:Bool;
    var sweepActive:Bool;
    var envDecayDisable:Bool;
    var envDecayLoopEnable:Bool;
    var envReset:Bool;
    var sweepCarry:Bool;
    var updateSweepPeriod:Bool;
    
    public var progTimerCount:Int;
    public var progTimerMax:Int;
    public var lengthCounter:Int;
    public var squareCounter:Int;
    public var sweepCounter:Int;
    public var sweepCounterMax:Int;
    var sweepMode:Int;
    var sweepShiftAmount:Int;
    var envDecayRate:Int;
    var envDecayCounter:Int;
    var envVolume:Int;
    var masterVolume:Int;
    var dutyMode:Int;
    var sweepResult:Int;
    public var sampleValue:Int;
    var vol:Int;
	

	public function new(papu:PAPU, square1:Bool) {
		this.papu = papu;
		sqr1 = square1;
		reset();
	}
	
	public function reset() {
        progTimerCount = 0;
        progTimerMax = 0;
        lengthCounter = 0;
        squareCounter = 0;
        sweepCounter = 0;
        sweepCounterMax = 0;
        sweepMode = 0;
        sweepShiftAmount = 0;
        envDecayRate = 0;
        envDecayCounter = 0;
        envVolume = 0;
        masterVolume = 0;
        dutyMode = 0;
        vol = 0;
    
        isEnabled = false;
        lengthCounterEnable = false;
        sweepActive = false;
        sweepCarry = false;
        envDecayDisable = false;
        envDecayLoopEnable = false;
    }

    inline public function clockLengthCounter() {
        if (lengthCounterEnable && lengthCounter > 0){
            lengthCounter--;
            if (lengthCounter == 0) {
                updateSampleValue();
            }
        }
    }

    inline public function clockEnvDecay() {
        if (envReset) {
            // Reset envelope:
            envReset = false;
            envDecayCounter = envDecayRate + 1;
            envVolume = 0xF;
			
        } else if (--envDecayCounter <= 0) {
            // Normal handling:
            envDecayCounter = envDecayRate + 1;
            if (envVolume > 0) {
                envVolume--;
            } else {
                envVolume = envDecayLoopEnable ? 0xF : 0;
            }
			
        }
    
        masterVolume = envDecayDisable ? envDecayRate : envVolume;
        updateSampleValue();
    }

    inline public function clockSweep() {
        if (--sweepCounter <= 0) {        
            sweepCounter = sweepCounterMax + 1;
            if (sweepActive && sweepShiftAmount > 0 && progTimerMax > 7) {            
                // Calculate result from shifter:
                sweepCarry = false;
                if (sweepMode == 0) {
                    progTimerMax += (progTimerMax >> sweepShiftAmount);
                    if (progTimerMax > 4095) {
                        progTimerMax = 4095;
                        sweepCarry = true;
                    }
					
                } else {
                    progTimerMax = progTimerMax - ((progTimerMax >> sweepShiftAmount) - (sqr1 ? 1 : 0));
                }
            }
        }
    
        if (updateSweepPeriod) {
            updateSweepPeriod = false;
            sweepCounter = sweepCounterMax + 1;
        }
    }

    inline public function updateSampleValue() {
        if (isEnabled && lengthCounter > 0 && progTimerMax > 7) {        
            if (sweepMode == 0 && (progTimerMax + (progTimerMax >> sweepShiftAmount)) > 4095) {
                sampleValue = 0;
            } else {
                sampleValue = masterVolume * dutyLookup[(dutyMode << 3) + squareCounter];   
            }			
        } else {
            sampleValue = 0;
        }
    }

    inline public function writeReg(address:Int, value:Int) {
        var addrAdd = sqr1 ? 0 : 4;
        if (address == 0x4000 + addrAdd) {
            // Volume/Envelope decay:
            envDecayDisable = ((value & 0x10) != 0);
            envDecayRate = value & 0xF;
            envDecayLoopEnable = ((value & 0x20) != 0);
            dutyMode = (value >> 6) & 0x3;
            lengthCounterEnable = (value & 0x20) == 0;
            masterVolume = envDecayDisable ? envDecayRate : envVolume;
            updateSampleValue();
        
        } else if (address == 0x4001 + addrAdd) {
            // Sweep:
            sweepActive = (value & 0x80) != 0;
            sweepCounterMax = ((value >> 4) & 7);
            sweepMode = (value >> 3) & 1;
            sweepShiftAmount = value & 7;
            updateSweepPeriod = true;
			
        } else if (address == 0x4002 + addrAdd){
            // Programmable timer:
            progTimerMax &= 0x700;
            progTimerMax |= value;
			
        } else if (address == 0x4003 + addrAdd) {
            // Programmable timer, length counter
            progTimerMax &= 0xFF;
            progTimerMax |= ((value & 0x7) << 8);
        
            if (isEnabled){
                lengthCounter = papu.getLengthMax(value&0xF8);
            }
        
            envReset  = true;
        }
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
