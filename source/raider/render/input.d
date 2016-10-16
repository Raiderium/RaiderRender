module raider.render.input;

import raider.render.window;
import raider.tools.map;
import raider.tools.reference;

//Stores the state of an input axis.
struct Axis
{private:
	float v0, v1;

public:
	@property float value() { return v1; }
	@property float velocity() { return v1 - v0; }

	//Axis as a button. Value is 'pressure', so 1.0 = pressed, 0.0 = released
	bool opCast(T:bool)() const { return v1 > 0.5; }
	@property bool down() { return v1 > 0.5; }
	@property bool pressed() { return down && changed; }
	@property bool released() { return !down && changed; }
	@property bool changed() { return v1 != v0; }
}

struct WindowState
{
	Axis[Input.Code.max] axises;
}

struct Input
{private:
	P!Window window;
	Map!(string, Adapter) map;

	struct Adapter 
	{
		Code code;
	}

public:
	this(P!Window window) { this.window = window; }


	enum Code
	{
		//Letters
		A, B, C, D, E, F, G, H, I, J, K, L, M,
		N, O, P, Q, R, S, T, U, V, W, X, Y, Z,
		
		//Number line
		N0, N1, N2, N3, N4, N5, N6, N7, N8, N9, 
		
		//Numpad
		P0, P1, P2, P3, P4, P5, P6, P7, P8, P9,
		
		F1, F2, F3, F4, F5, F6, F7, F8, 
		F9, F10, F11, F12, F13, F14, F15,
		
		Left, Right, Up, Down, Space,
		
		RShift, LShift, RAlt, LAlt, RCtrl, LCtrl,
		RSys, LSys, Tab, CapsLock, Tilde, Escape,
		
		Dash, Equals, Backspace, 
		LBracket, RBracket, Backslash, 
		Semicolon, Quote, Enter, 
		Comma, Period, Slash,
		
		Home, End, Delete, PageUp, PageDown,
		Insert, Plus, Minus, Multiply, Divide,
		
		//Mouse
		//Coords in pixels relative to window top-left
		LMB, RMB, MMB, 
		MWH, MWV, MX, MY,
		
		//Window
		Minimize, Maximise, Close,
		Width, Height, Focus
	}
	
	alias Code this;
}

/*@property vec2i mouse()
{
	sfVector2i sfv = sfMouse_getPosition(sfwindow);
	return vec2i(sfv.x, sfv.y);
}

@property void mouse(vec2i m)
{
	sfMouse_setPosition(sfVector2i(m[0], m[1]), sfwindow);
}*/
