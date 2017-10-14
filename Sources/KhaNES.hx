package;

import haxe.io.UInt8Array;
import haxe.io.Bytes;

import kha.graphics4.TextureFormat;
import kha.graphics4.Usage;
import kha.Framebuffer;
import kha.Scheduler;
import kha.Assets;
import kha.System;
import kha.Image;

/**
 * ...
 * @author Krtolica Vujadin
 */
class KhaNES {

	var nes:NES;
	var nesDisplay:UInt8Array;
	var finalImage:Image;

	static inline var pixelCount:Int = 61440; // 256 * 240


	public function new() {	
		System.notifyOnRender(render);
		Scheduler.addTimeTask(update, 0, 1 / 60);

		Assets.loadEverything(init);
	}

	function init() {
		nesDisplay = new UInt8Array(256 * 240 * 4);
		nes = new NES(nesDisplay);

		finalImage = Image.fromBytes(nes.bmp.view.buffer, 256, 240);

		var rom = Assets.blobs.alladin_nes.toBytes();
		var loaded = nes.loadRom(rom);
		if (loaded) {
			nes.start();
		}
	}

	function update() { 

	}

	function render(framebuffer:Framebuffer) {
		var graphics = framebuffer.g2;

		if (nes != null) {
			nes.frame();
			var data = finalImage.lock();
			var index:Int = 0;
			for (i in 0...pixelCount) {
				index = 4 * i;
				data.set(index + 3, 255);
				data.set(index + 0, (nes.ppu.buffer[i] & 0xff0000) >> 16);
				data.set(index + 1, (nes.ppu.buffer[i] & 0x00ff00) >> 8);
				data.set(index + 2, nes.ppu.buffer[i] & 0x0000ff);
			}
			finalImage.unlock();
			graphics.begin();
			graphics.drawScaledImage(finalImage, 0, 0, System.windowWidth(), System.windowHeight());
			graphics.end();
		}
	}
	
}
