package papu;

/**
 * ...
 * @author Krtolica Vujadin
 */
 // ported from vNES
class PAPU {

	public var nes(default, null):NES;
    
    var square1:ChannelSquare;
    var square2:ChannelSquare;
    var triangle:ChannelTriangle;
    var noise:ChannelNoise;
    var dmc:ChannelDM;

    var frameIrqCounter:Int;
    var frameIrqCounterMax:Int = 4;
    var initCounter:Int = 2048;
    var channelEnableValue:Int;

    var bufferSize:Int = 8192;
    var bufferIndex:Int = 0;
    var sampleRate:Int = 44100;

    var lengthLookup:Array<Int>;
    var dmcFreqLookup:Array<Int>;
    var noiseWavelengthLookup:Array<Int>;
    var square_table:Array<Int>;
    var tnd_table:Array<Int>;
    var sampleBuffer:Array<Int>;

    var frameIrqEnabled:Bool = false;
    var frameIrqActive:Bool;
    var frameClockNow:Bool;
    var startedPlaying:Bool = false;
    var recordOutput:Bool = false;
    var initingHardware:Bool = false;

    var masterFrameCounter:Int;
    var derivedFrameCounter:Int;
    var countSequence:Int;
    var sampleTimer:Int;
    var frameTime:Int;
    var sampleTimerMax:Int;
    var sampleCount:Int;
    var triValue:Int = 0;

    var smpSquare1:Int;
    var smpSquare2:Int;
    var smpTriangle:Int;
    var smpDmc:Int;
    var accCount:Int;

    // DC removal vars:
    var prevSampleL:Int = 0;
    var prevSampleR:Int = 0;
    var smpAccumL:Int = 0;
    var smpAccumR:Int = 0;
	var sq_index:Int = 0;
	var tnd_index:Int = 0;
	var smpNoise:Int = 0;
	
	var sampleValueL:Int;
	var sampleValueR:Int;
	
	var smpDiffL:Int;
	var smpDiffR:Int;

    // DAC range:
    var dacRange:Int = 0;
    var dcValue:Int = 0;

    // Master volume:
    var masterVolume:Int = 256;

    // Stereo positioning:
    var stereoPosLSquare1:Int;
    var stereoPosLSquare2:Int;
    var stereoPosLTriangle:Int;
    var stereoPosLNoise:Int;
    var stereoPosLDMC:Int;
    var stereoPosRSquare1:Int;
    var stereoPosRSquare2:Int;
    var stereoPosRTriangle:Int;
    var stereoPosRNoise:Int;
    var stereoPosRDMC:Int;

    var extraCycles:Int = 0;
    
    var maxSample:Int;
    var minSample:Int;
    
    // Panning:
    var panning:Array<Int>;

	public function new(nes:NES) {
		this.nes = nes;
		
		square1 = new ChannelSquare(this, true);
		square2 = new ChannelSquare(this, false);
		triangle = new ChannelTriangle(this);
		noise = new ChannelNoise(this);
		dmc = new ChannelDM(this);
		
		lengthLookup = [];
		dmcFreqLookup = [];
		noiseWavelengthLookup = [];
		square_table = [];
		tnd_table = [];
		sampleBuffer = [];
		
		// Panning:
		panning = [80, 170, 100, 150, 128];
		setPanning(panning);

		// Initialize lookup tables:
		initLengthLookup();
		initDmcFrequencyLookup();
		initNoiseWavelengthLookup();
		initDACtables();
		
		// Init sound registers:
		for (i in 0...0x14) {
			if (i == 0x10){
				writeReg(0x4010, 0x10);
			}
			else {
				writeReg(0x4000 + i, 0);
			}
		}
		
		reset();
	}
	
	public function reset() {
        sampleRate = nes.opts.sampleRate;
        sampleTimerMax = Math.floor(
            (1024 * CPU.CPU_FREQ_NTSC *
                nes.opts.preferredFrameRate) / 
                (sampleRate * 60.0)
        );
    
        frameTime = Math.floor((14915 * nes.opts.preferredFrameRate) / 60.0);

        sampleTimer = 0;
        bufferIndex = 0;
    
        updateChannelEnable(0);
        masterFrameCounter = 0;
        derivedFrameCounter = 0;
        countSequence = 0;
        sampleCount = 0;
        initCounter = 2048;
        frameIrqEnabled = false;
        initingHardware = false;

        resetCounter();

        square1.reset();
        square2.reset();
        triangle.reset();
        noise.reset();
        dmc.reset();

        bufferIndex = 0;
        accCount = 0;
        smpSquare1 = 0;
        smpSquare2 = 0;
        smpTriangle = 0;
        smpDmc = 0;

        frameIrqEnabled = false;
        frameIrqCounterMax = 4;

        channelEnableValue = 0xFF;
        startedPlaying = false;
        prevSampleL = 0;
        prevSampleR = 0;
        smpAccumL = 0;
        smpAccumR = 0;
    
        maxSample = -500000;
        minSample = 500000;    
	}
	
	inline public function readReg(address:Int):Int {
        // Read 0x4015:
        var tmp:Int = 0;
        tmp |= square1.getLengthStatus();
        tmp |= square2.getLengthStatus() << 1;
        tmp |= triangle.getLengthStatus() << 2;
        tmp |= noise.getLengthStatus() << 3;
        tmp |= dmc.getLengthStatus() << 4;
        tmp |= ((frameIrqActive && frameIrqEnabled)? 1 : 0) << 6;
        tmp |= dmc.getIrqStatus() << 7;

        frameIrqActive = false;
        dmc.irqGenerated = false;
    
        return tmp & 0xFFFF;
    }
	
	public function writeReg(address:Int, value:Int) {
        if (address >= 0x4000 && address < 0x4004) {
            // Square Wave 1 Control
            square1.writeReg(address, value);
        }
        else if (address >= 0x4004 && address < 0x4008) {
            // Square 2 Control
            square2.writeReg(address, value);
        }
        else if (address >= 0x4008 && address < 0x400C) {
            // Triangle Control
            triangle.writeReg(address, value);
        }
        else if (address >= 0x400C && address <= 0x400F) {
            // Noise Control
            noise.writeReg(address, value);
        }
        else if (address == 0x4010){
            // DMC Play mode & DMA frequency
            dmc.writeReg(address, value);
        }
        else if (address == 0x4011){
            // DMC Delta Counter
            dmc.writeReg(address, value);
        }
        else if (address == 0x4012){
            // DMC Play code starting address
            dmc.writeReg(address, value);
        }
        else if (address == 0x4013){
            // DMC Play code length
            dmc.writeReg(address, value);
        }
        else if (address == 0x4015){
            // Channel enable
            updateChannelEnable(value);

            if (value != 0 && initCounter > 0) {
                // Start hardware initialization
                initingHardware = true;
            }

            // DMC/IRQ Status
            dmc.writeReg(address, value);
        }
        else if (address == 0x4017) {
            // Frame counter control
            countSequence = (value >> 7) & 1;
            masterFrameCounter = 0;
            frameIrqActive = false;

            if (((value>>6)&0x1)==0){
                frameIrqEnabled = true;
            }
            else {
                frameIrqEnabled = false;
            }

            if (countSequence == 0) {
                // NTSC:
                frameIrqCounterMax = 4;
                derivedFrameCounter = 4;
            }
            else {
                // PAL:
                frameIrqCounterMax = 5;
                derivedFrameCounter = 0;
                frameCounterTick();
            }
        }
    }
	
	inline function resetCounter() {
        if (countSequence == 0) {
            derivedFrameCounter = 4;
        } else {
            derivedFrameCounter = 0;
        }
    }

    // Updates channel enable status.
    // This is done on writes to the
    // channel enable register (0x4015),
    // and when the user enables/disables channels
    // in the GUI.
    function updateChannelEnable(value:Int) {
        channelEnableValue = value & 0xFFFF;
        square1.setEnabled((value & 1) != 0);
        square2.setEnabled((value & 2) != 0);
        triangle.setEnabled((value & 4) != 0);
        noise.setEnabled((value & 8) != 0);
        dmc.setEnabled((value & 16) != 0);
    }

    // Clocks the frame counter. It should be clocked at
    // twice the cpu speed, so the cycles will be
    // divided by 2 for those counters that are
    // clocked at cpu speed.
    public function clockFrameCounter(nCycles:Int) {
		
        if (initCounter > 0) {
            if (initingHardware) {
                initCounter -= nCycles;
                if (initCounter <= 0) {
                    initingHardware = false;
                }
                return;
            }
        }

        // Don't process ticks beyond next sampling:
        nCycles += extraCycles;
        var maxCycles = sampleTimerMax - sampleTimer;
        if ((nCycles << 10) > maxCycles) {

            extraCycles = ((nCycles << 10) - maxCycles) >> 10;
            nCycles -= extraCycles;
        } else {        
            extraCycles = 0;        
        }
        
        // Clock DMC:
        if (dmc.isEnabled) {        
            dmc.shiftCounter -= (nCycles << 3);
            while (dmc.shiftCounter <= 0 && dmc.dmaFrequency > 0) {
                dmc.shiftCounter += dmc.dmaFrequency;
                dmc.clockDmc();
            }
        }

        // Clock Triangle channel Prog timer:
        if (triangle.progTimerMax > 0) {        
            triangle.progTimerCount -= nCycles;
            while(triangle.progTimerCount <= 0) {            
                triangle.progTimerCount += triangle.progTimerMax + 1;
                if (triangle.linearCounter > 0 && triangle.lengthCounter > 0) {
                    triangle.triangleCounter++;
                    triangle.triangleCounter &= 0x1F;

                    if (triangle.isEnabled) {
                        if (triangle.triangleCounter >= 0x10) {
                            // Normal value.
                            triangle.sampleValue = (triangle.triangleCounter & 0xF);
                        } else {
                            // Inverted value.
                            triangle.sampleValue = (0xF - (triangle.triangleCounter & 0xF));
                        }
                        triangle.sampleValue <<= 4;
                    }
                }
            }
        }

        // Clock Square channel 1 Prog timer:
        square1.progTimerCount -= nCycles;
        if (square1.progTimerCount <= 0) {
            square1.progTimerCount += (square1.progTimerMax + 1) << 1;

            square1.squareCounter++;
            square1.squareCounter &= 0x7;
            square1.updateSampleValue();            
        }

        // Clock Square channel 2 Prog timer:
        square2.progTimerCount -= nCycles;
        if (square2.progTimerCount <= 0) {
            square2.progTimerCount += (square2.progTimerMax + 1) << 1;

            square2.squareCounter++;
            square2.squareCounter &= 0x7;
            square2.updateSampleValue();        
        }

        // Clock noise channel Prog timer:
        var acc_c = nCycles;
        if (noise.progTimerCount - acc_c > 0) {
        
            // Do all cycles at once:
            noise.progTimerCount -= acc_c;
            noise.accCount       += acc_c;
            noise.accValue       += acc_c * noise.sampleValue;    
			
        } else {        
            // Slow-step:
            while((acc_c--) > 0) {            
                if (--noise.progTimerCount <= 0 && noise.progTimerMax > 0) {    
                    // Update noise shift register:
                    noise.shiftReg <<= 1;
                    noise.tmp = (((noise.shiftReg << (noise.randomMode == 0 ? 1 : 6)) ^ noise.shiftReg) & 0x8000);
                    if (noise.tmp != 0) {                    
                        // Sample value must be 0.
                        noise.shiftReg |= 0x01;
                        noise.randomBit = 0;
                        noise.sampleValue = 0;                    
                    } else {                    
                        // Find sample value:
                        noise.randomBit = 1;
                        if (noise.isEnabled && noise.lengthCounter > 0) {
                            noise.sampleValue = noise.masterVolume;
                        } else {
                            noise.sampleValue = 0;
                        }                    
                    }
                
                    noise.progTimerCount += noise.progTimerMax;                    
                }
        
                noise.accValue += noise.sampleValue;
                noise.accCount++;        
            }
        }    

        // Frame IRQ handling:
        if (frameIrqEnabled && frameIrqActive){
            nes.cpu.requestIrq(CPU.IRQ_NORMAL);
        }

        // Clock frame counter at double CPU speed:
        masterFrameCounter += (nCycles << 1);
        if (masterFrameCounter >= frameTime) {
            // 240Hz tick:
            masterFrameCounter -= frameTime;
            frameCounterTick();
        }
    
        // Accumulate sample value:
        accSample(nCycles);

        // Clock sample timer:
        sampleTimer += nCycles << 10;
        if (sampleTimer >= sampleTimerMax) {
            // Sample channels:
            sample();
            sampleTimer -= sampleTimerMax;
        }
    }
	
	inline function accSample(cycles:Int) {
        // Special treatment for triangle channel - need to interpolate.
        if (triangle.sampleCondition) {
            triValue = Math.floor((triangle.progTimerCount << 4) / (triangle.progTimerMax + 1));
            if (triValue > 16) {
                triValue = 16;
            }
            if (triangle.triangleCounter >= 16) {
                triValue = 16 - triValue;
            }
        
            // Add non-interpolated sample value:
            triValue += triangle.sampleValue;
        }
    
        // Now sample normally:
        if (cycles == 2) {        
            smpTriangle += triValue << 1;
            smpDmc      += dmc.sample << 1;
            smpSquare1  += square1.sampleValue << 1;
            smpSquare2  += square2.sampleValue << 1;
            accCount    += 2;
        
        } else if (cycles == 4) {        
            smpTriangle += triValue << 2;
            smpDmc      += dmc.sample << 2;
            smpSquare1  += square1.sampleValue << 2;
            smpSquare2  += square2.sampleValue << 2;
            accCount    += 4;
        
        } else {        
            smpTriangle += cycles * triValue;
            smpDmc      += cycles * dmc.sample;
            smpSquare1  += cycles * square1.sampleValue;
            smpSquare2  += cycles * square2.sampleValue;
            accCount    += cycles;        
        }
    }

    inline function frameCounterTick() {    
        derivedFrameCounter++;
        if (derivedFrameCounter >= frameIrqCounterMax) {
            derivedFrameCounter = 0;
        }
    
        if (derivedFrameCounter == 1 || derivedFrameCounter == 3) {
            // Clock length & sweep:
            triangle.clockLengthCounter();
            square1.clockLengthCounter();
            square2.clockLengthCounter();
            noise.clockLengthCounter();
            square1.clockSweep();
            square2.clockSweep();
        }

        if (derivedFrameCounter >= 0 && derivedFrameCounter < 4) {
            // Clock linear & decay:            
            square1.clockEnvDecay();
            square2.clockEnvDecay();
            noise.clockEnvDecay();
            triangle.clockLinearCounter();
        }
    
        if (derivedFrameCounter == 3 && countSequence == 0) {        
            // Enable IRQ:
            frameIrqActive = true;        
        }   
    
        // End of 240Hz tick    
    }

    // Samples the channels, mixes the output together,
    // writes to buffer and (if enabled) file.
    function sample() {        
        if (accCount > 0) {
            smpSquare1 <<= 4;
            smpSquare1 = Math.floor(smpSquare1 / accCount);

            smpSquare2 <<= 4;
            smpSquare2 = Math.floor(smpSquare2 / accCount);

            smpTriangle = Math.floor(smpTriangle / accCount);

            smpDmc <<= 4;
            smpDmc = Math.floor(smpDmc / accCount);
        
            accCount = 0;
        } else {
            smpSquare1 = square1.sampleValue << 4;
            smpSquare2 = square2.sampleValue << 4;
            smpTriangle = triangle.sampleValue;
            smpDmc = dmc.sample << 4;
        }
    
        smpNoise = Math.floor((noise.accValue << 4) / noise.accCount);
        noise.accValue = smpNoise >> 4;
        noise.accCount = 1;

        // Stereo sound.
    
        // Left channel:
        sq_index = (smpSquare1 * stereoPosLSquare1 + smpSquare2 * stereoPosLSquare2) >> 8;
        tnd_index = (
                3 * smpTriangle * stereoPosLTriangle + 
                (smpNoise << 1) * stereoPosLNoise + smpDmc * 
                stereoPosLDMC
            ) >> 8;
        if (sq_index >= square_table.length) {
            sq_index  = square_table.length - 1;
        }
        if (tnd_index >= tnd_table.length) {
            tnd_index = tnd_table.length - 1;
        }
        sampleValueL = square_table[sq_index] + tnd_table[tnd_index] - dcValue;

        // Right channel:
        sq_index = (smpSquare1 * stereoPosRSquare1 +  
                smpSquare2 * stereoPosRSquare2
            ) >> 8;
        tnd_index = (3 * smpTriangle * stereoPosRTriangle + 
                (smpNoise << 1) * stereoPosRNoise + smpDmc * 
                stereoPosRDMC
            ) >> 8;
        if (sq_index >= square_table.length) {
            sq_index = square_table.length - 1;
        }
        if (tnd_index >= tnd_table.length) {
            tnd_index = tnd_table.length - 1;
        }
        var sampleValueR = square_table[sq_index] + 
                tnd_table[tnd_index] - dcValue;

        // Remove DC from left channel:
        smpDiffL = sampleValueL - prevSampleL;
        prevSampleL += smpDiffL;
        smpAccumL += smpDiffL - (smpAccumL >> 10);
        sampleValueL = smpAccumL;
        
        // Remove DC from right channel:
        smpDiffR = sampleValueR - prevSampleR;
        prevSampleR += smpDiffR;
        smpAccumR += smpDiffR - (smpAccumR >> 10);
        sampleValueR = smpAccumR;

        // Write:
        if (sampleValueL > maxSample) {
            maxSample = sampleValueL;
        }
        if (sampleValueL < minSample) {
            minSample = sampleValueL;
        }
				
        sampleBuffer[bufferIndex++] = sampleValueL;
        sampleBuffer[bufferIndex++] = sampleValueR;
        
        // Write full buffer
        if (bufferIndex == sampleBuffer.length) {
            nes.writeAudio(sampleBuffer);
            bufferIndex = 0;
        }

        // Reset sampled values:
        smpSquare1 = 0;
        smpSquare2 = 0;
        smpTriangle = 0;
        smpDmc = 0;
    }
	
	inline public function getLengthMax(value:Int):Int {
        return lengthLookup[value >> 3];
    }

    public function getDmcFrequency(value:Int):Int {
        if (value >= 0 && value < 0x10) {
            return dmcFreqLookup[value];
        }
        return 0;
    }

    public function getNoiseWaveLength(value:Int):Int {
        if (value >= 0 && value < 0x10) {
            return noiseWavelengthLookup[value];
        }
        return 0;
    }

    inline function setPanning(pos:Array<Int>) {
        for (i in 0...5) {
            panning[i] = pos[i];
        }
        updateStereoPos();
    }

    inline function setMasterVolume(value:Int) {
        if (value < 0) {
            value = 0;
        }
        if (value > 256) {
            value = 256;
        }
        masterVolume = value;
        updateStereoPos();
    }

    function updateStereoPos() {
        stereoPosLSquare1 = (panning[0] * masterVolume) >> 8;
        stereoPosLSquare2 = (panning[1] * masterVolume) >> 8;
        stereoPosLTriangle = (panning[2] * masterVolume) >> 8;
        stereoPosLNoise = (panning[3] * masterVolume) >> 8;
        stereoPosLDMC = (panning[4] * masterVolume) >> 8;
    
        stereoPosRSquare1 = masterVolume - stereoPosLSquare1;
        stereoPosRSquare2 = masterVolume - stereoPosLSquare2;
        stereoPosRTriangle = masterVolume - stereoPosLTriangle;
        stereoPosRNoise = masterVolume - stereoPosLNoise;
        stereoPosRDMC = masterVolume - stereoPosLDMC;
    }

    function initLengthLookup() {
        lengthLookup = [
            0x0A, 0xFE,
            0x14, 0x02,
            0x28, 0x04,
            0x50, 0x06,
            0xA0, 0x08,
            0x3C, 0x0A,
            0x0E, 0x0C,
            0x1A, 0x0E,
            0x0C, 0x10,
            0x18, 0x12,
            0x30, 0x14,
            0x60, 0x16,
            0xC0, 0x18,
            0x48, 0x1A,
            0x10, 0x1C,
            0x20, 0x1E
        ];
    }

    function initDmcFrequencyLookup() {
        dmcFreqLookup = [];

        dmcFreqLookup[0x0] = 0xD60;
        dmcFreqLookup[0x1] = 0xBE0;
        dmcFreqLookup[0x2] = 0xAA0;
        dmcFreqLookup[0x3] = 0xA00;
        dmcFreqLookup[0x4] = 0x8F0;
        dmcFreqLookup[0x5] = 0x7F0;
        dmcFreqLookup[0x6] = 0x710;
        dmcFreqLookup[0x7] = 0x6B0;
        dmcFreqLookup[0x8] = 0x5F0;
        dmcFreqLookup[0x9] = 0x500;
        dmcFreqLookup[0xA] = 0x470;
        dmcFreqLookup[0xB] = 0x400;
        dmcFreqLookup[0xC] = 0x350;
        dmcFreqLookup[0xD] = 0x2A0;
        dmcFreqLookup[0xE] = 0x240;
        dmcFreqLookup[0xF] = 0x1B0;
    }

    function initNoiseWavelengthLookup() {
        noiseWavelengthLookup = [];

        noiseWavelengthLookup[0x0] = 0x004;
        noiseWavelengthLookup[0x1] = 0x008;
        noiseWavelengthLookup[0x2] = 0x010;
        noiseWavelengthLookup[0x3] = 0x020;
        noiseWavelengthLookup[0x4] = 0x040;
        noiseWavelengthLookup[0x5] = 0x060;
        noiseWavelengthLookup[0x6] = 0x080;
        noiseWavelengthLookup[0x7] = 0x0A0;
        noiseWavelengthLookup[0x8] = 0x0CA;
        noiseWavelengthLookup[0x9] = 0x0FE;
        noiseWavelengthLookup[0xA] = 0x17C;
        noiseWavelengthLookup[0xB] = 0x1FC;
        noiseWavelengthLookup[0xC] = 0x2FA;
        noiseWavelengthLookup[0xD] = 0x3F8;
        noiseWavelengthLookup[0xE] = 0x7F2;
        noiseWavelengthLookup[0xF] = 0xFE4;
    }

    function initDACtables() {
        var value:Float = 0;
		var ival:Int = 0;
        var max_sqr:Int = 0;
        var max_tnd:Int = 0;
        
        square_table = [];
        tnd_table = [];

        for (i in 0...32 * 16) {
            value = 95.52 / (8128.0 / (i / 16.0) + 100.0);
            value *= 0.98411;
            value *= 50000.0;
            ival = Math.floor(value);
        
            square_table[i] = ival;
            if (ival > max_sqr) {
                max_sqr = ival;
            }
        }
    
        for (i in 0...204 * 16) {
            value = 163.67 / (24329.0 / (i / 16.0) + 100.0);
            value *= 0.98411;
            value *= 50000.0;
            ival = Math.floor(value);
        
            tnd_table[i] = ival;
            if (ival > max_tnd) {
                max_tnd = ival;
            }
        }
    
        dacRange = max_sqr + max_tnd;
        dcValue = Std.int(dacRange / 2);
    }
	
}
