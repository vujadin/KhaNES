package;

import kha.input.Keyboard;
import kha.input.KeyCode;

/**
 * ...
 * @author Krtolica Vujadin
 */
class InputHandler {
	
	var nes:NES;
	
	public static inline var KEY_A:Int = 0;
	public static inline var KEY_B:Int = 1;
	public static inline var KEY_SELECT:Int = 2;
	public static inline var KEY_START:Int = 3;
	public static inline var KEY_UP:Int = 4;
	public static inline var KEY_DOWN:Int = 5;
	public static inline var KEY_LEFT:Int = 6;
	public static inline var KEY_RIGHT:Int = 7;
	
	public var state1:Array<Int>;
	public var state2:Array<Int>;

	public function new(nes:NES) {
		state1 = [];
		state2 = [];
		
		for (i in 0...8) { 
			state1[i] = 0x40;
			state2[i] = 0x40;
		}
		
		Keyboard.get().notify(keyDown, keyUp);
	}
		
	public function setKey(key:KeyCode, value:Int) {
		trace(key);
		trace(value);
        switch (key) {
			case KeyCode.X: this.state1[InputHandler.KEY_A] = value;
			case KeyCode.Z: this.state1[InputHandler.KEY_B] = value;
			case KeyCode.Return: this.state1[InputHandler.KEY_SELECT] = value;
			case KeyCode.Space: this.state1[InputHandler.KEY_START] = value;
            case KeyCode.Up: this.state1[InputHandler.KEY_UP] = value;
            case KeyCode.Down: this.state1[InputHandler.KEY_DOWN] = value;
            case KeyCode.Left: this.state1[InputHandler.KEY_LEFT] = value;
            case KeyCode.Right: this.state1[InputHandler.KEY_RIGHT] = value;
			default: //
        }
    }

    public function keyDown(key:KeyCode) {
        this.setKey(key, 0x41);
    }
    
	public function keyUp(key:KeyCode) {
        this.setKey(key, 0x40);
    }
	
}
