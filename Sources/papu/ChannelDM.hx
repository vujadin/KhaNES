package papu;

/**
 * ...
 * @author Krtolica Vujadin
 */
 // ported from vNES
class ChannelDM {
	
	var papu:PAPU;
    
    public static inline var MODE_NORMAL:Int = 0;
    public static inline var MODE_LOOP:Int = 1;
    public static inline var MODE_IRQ:Int = 2;
    
    public var isEnabled:Bool;
    public var hasSample:Bool;
    public var irqGenerated:Bool;
    
    var playMode:Int;
    public var dmaFrequency:Int;
    var dmaCounter:Int;
    var deltaCounter:Int;
    var playStartAddress:Int;
    var playAddress:Int;
    var playLength:Int;
    var playLengthCounter:Int;
    public var shiftCounter:Int;
    var reg4012:Int;
    var reg4013:Int;
    public var sample:Int;
    var dacLsb:Int;
    var data:Int;
    
	
	public function new(papu:PAPU) {
		this.papu = papu;
		reset();
	}
	
	inline public function clockDmc() {    
        // Only alter DAC value if the sample buffer has data:
        if(hasSample) {
        
            if ((data & 1) == 0) {            
                // Decrement delta:
                if(deltaCounter > 0) {
                    deltaCounter--;
                }
            } else {
                // Increment delta:
                if (deltaCounter < 63) {
                    deltaCounter++;
                }
            }
        
            // Update sample value:
            sample = isEnabled ? (deltaCounter << 1) + dacLsb : 0;
        
            // Update shift register:
            data >>= 1;        
        }
    
        dmaCounter--;
        if (dmaCounter <= 0) {        
            // No more sample bits.
            hasSample = false;
            endOfSample();
            dmaCounter = 8;        
        }
    
        if (irqGenerated) {
            papu.nes.cpu.requestIrq(CPU.IRQ_NORMAL);
        }    
    }

    inline function endOfSample() {
        if (playLengthCounter == 0 && playMode == ChannelDM.MODE_LOOP) {        
            // Start from beginning of sample:
            playAddress = playStartAddress;
            playLengthCounter = playLength;        
        }
    
        if (playLengthCounter > 0) {        
            // Fetch next sample:
            nextSample();
        
            if (playLengthCounter == 0) {        
                // Last byte of sample fetched, generate IRQ:
                if (playMode == ChannelDM.MODE_IRQ) {                
                    // Generate IRQ:
                    irqGenerated = true;                
                }            
            }        
        }    
    }

    inline public function nextSample() {
        // Fetch byte:
        data = papu.nes.mmap.load(playAddress);
        papu.nes.cpu.haltCycles(4);
    
        playLengthCounter--;
        playAddress++;
        if (playAddress > 0xFFFF) {
            playAddress = 0x8000;
        }
    
        hasSample = true;
    }

    inline public function writeReg(address:Int, value:Int) {
        if (address == 0x4010) {        
            // Play mode, DMA Frequency
            if ((value >> 6) == 0) {
                playMode = ChannelDM.MODE_NORMAL;
            } else if (((value >> 6) & 1) == 1) {
                playMode = ChannelDM.MODE_LOOP;
            } else if ((value >> 6) == 2) {
                playMode = ChannelDM.MODE_IRQ;
            }
        
            if ((value & 0x80) == 0) {
                irqGenerated = false;
            }
        
            dmaFrequency = papu.getDmcFrequency(value & 0xF);     
			
        } else if (address == 0x4011) {        
            // Delta counter load register:
            deltaCounter = (value >> 1) & 63;
            dacLsb = value & 1;
            sample = ((deltaCounter << 1) + dacLsb); // update sample value  
			
        } else if (address == 0x4012) {        
            // DMA address load register
            playStartAddress = (value << 6) | 0x0C000;
            playAddress = playStartAddress;
            reg4012 = value;  
			
        } else if (address == 0x4013) {        
            // Length of play code
            playLength = (value << 4) + 1;
            playLengthCounter = playLength;
            reg4013 = value;   
			
        } else if (address == 0x4015) {        
            // DMC/IRQ Status
            if (((value >> 4) & 1) == 0) {
                // Disable:
                playLengthCounter = 0;
            } else {
                // Restart:
                playAddress = playStartAddress;
                playLengthCounter = playLength;
            }
            irqGenerated = false;
        }
    }

    public function setEnabled(value:Bool) {
        if (!isEnabled && value) {
            playLengthCounter = playLength;
        }
        isEnabled = value;
    }

    inline public function getLengthStatus() {
        return ((playLengthCounter == 0 || !isEnabled) ? 0 : 1);
    }

    inline public function getIrqStatus() {
        return (irqGenerated ? 1 : 0);
    }

    public function reset() {
        isEnabled = false;
        irqGenerated = false;
        playMode = ChannelDM.MODE_NORMAL;
        dmaFrequency = 0;
        dmaCounter = 0;
        deltaCounter = 0;
        playStartAddress = 0;
        playAddress = 0;
        playLength = 0;
        playLengthCounter = 0;
        sample = 0;
        dacLsb = 0;
        shiftCounter = 0;
        reg4012 = 0;
        reg4013 = 0;
        data = 0;
    }
	
}
