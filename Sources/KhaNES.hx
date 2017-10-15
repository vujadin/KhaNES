package;

import haxe.io.UInt8Array;
import haxe.io.Bytes;

import kha.Shaders;
import kha.graphics4.PipelineState;
import kha.graphics4.VertexStructure;
import kha.graphics4.ConstantLocation;
import kha.graphics4.VertexBuffer;
import kha.graphics4.IndexBuffer;
import kha.graphics4.FragmentShader;
import kha.graphics4.VertexShader;
import kha.graphics4.VertexData;
import kha.graphics4.TextureUnit;
import kha.graphics4.Usage;
import kha.math.FastVector2;
import kha.Framebuffer;
import kha.Scheduler;
import kha.Assets;
import kha.System;
import kha.Image;
import kha.Blob;

class KhaNES {

    var enableCRT:Bool = true;

	var nes:NES;
	var nesDisplay:UInt8Array;
	var finalImage:Image;
    var nesFrameUnit:TextureUnit;
    var resLoc:ConstantLocation;
    var res:FastVector2 = new FastVector2();
	var vertexBuffer:VertexBuffer;
	var indexBuffer:IndexBuffer;
	var pipeline:PipelineState;

	static inline var pixelCount:Int = 61440; // 256 * 240

    static var vertices:Array<Float> = [
	   -1.0, -1.0, 0.0,
	    1.0, -1.0, 0.0,
	    1.0,  1.0, 0.0,
        1.0, 1.0, 0.0,
        -1.0, 1.0, 0.0,
        -1.0, -1.0, 0.0
	];
	var indices:Array<Int> = [0, 1, 2, 3, 4, 5];
    var uvs:Array<Float> = [
        0.0, 1.0,
        1.0, 1.0,
        1.0, 0.0,
        1.0, 0.0,
        0.0, 0.0,
        0.0, 1.0
    ];

	public function new() {
		Assets.loadEverything(init);
	}

	function init() {
        nesDisplay = new UInt8Array(256 * 240 * 4);
		nes = new NES(nesDisplay);

		finalImage = Image.create(256, 240);

        var structure = new VertexStructure();
        structure.add("pos", VertexData.Float3);
        structure.add("uv", VertexData.Float2);
	
		pipeline = new PipelineState();
		pipeline.inputLayout = [structure];
		pipeline.fragmentShader = Shaders.simple_frag;
		pipeline.vertexShader = Shaders.simple_vert;
		pipeline.compile();

        nesFrameUnit = pipeline.getTextureUnit("nesFrame");
        resLoc = pipeline.getConstantLocation("res");

		vertexBuffer = new VertexBuffer(
			Std.int(vertices.length / 3),
			structure,
			Usage.StaticUsage
		);
		
		var vbData = vertexBuffer.lock();
		for (i in 0...Std.int(vbData.length / 5)) {
            vbData.set(i * 5, vertices[i * 3]);
			vbData.set(i * 5 + 1, vertices[i * 3 + 1]);
			vbData.set(i * 5 + 2, vertices[i * 3 + 2]);
			vbData.set(i * 5 + 3, uvs[i * 2]);
			vbData.set(i * 5 + 4, uvs[i * 2 + 1]);
		}
		vertexBuffer.unlock();

		indexBuffer = new IndexBuffer(6, Usage.StaticUsage);
		
		var iData = indexBuffer.lock();
		for (i in 0...iData.length) {
			iData[i] = indices[i];
		}
		indexBuffer.unlock();

        System.notifyOnRender(render);

        var rom = Assets.blobs.smb_nes.toBytes();        
        var loaded = nes.loadRom(rom);
        if (loaded) {
            nes.start();
        }
	}

	function render(framebuffer:Framebuffer) {
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

        if (enableCRT) {
            var g = framebuffer.g4;
            res.x = System.windowWidth();
            res.y = System.windowHeight();
            g.begin();
            g.setPipeline(pipeline);
            g.setVertexBuffer(vertexBuffer);
            g.setIndexBuffer(indexBuffer);
            g.setTexture(nesFrameUnit, finalImage);
            g.setVector2(resLoc, res);
            g.drawIndexedVertices();
            g.end();
        }
        else {
            var g = framebuffer.g2;
            g.begin();
			g.drawScaledImage(finalImage, 0, 0, System.windowWidth(), System.windowHeight());//800, 600);
			g.end();
        }
	}
	
}
