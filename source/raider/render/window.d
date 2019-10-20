module raider.render.window;

import raider.math.vec;
import raider.tools.array;
import raider.tools.reference;
import raider.render.texture;
import raider.render.gl;
import raider.math.vec : vec2u, vec2i;

final class WindowException : Exception
{ import raider.tools.exception : SimpleThis; mixin SimpleThis; }

//Module-level platform junk. (See latter half of module for definitions.)
version(linux) mixin LinuxModuleImpl;
version(OSX) mixin OSXModuleImpl;
version(Windows) mixin WindowsModuleImpl;

/**
 * A thing that puts rendered pixels on a physical monitor.
 *
 * Provides an OpenGL context.
 */
@RC final class Window
{
	 //Platform junk. Platform-specific functions begin with i_.
	 //The rest of this class is platform-agnostic.
	 version(linux) mixin LinuxImpl;
	 version(OSX) mixin OSXImpl;
	 version(Windows) mixin WindowsImpl;

private:
	static Window _activeWindow;
	vec4 _viewport;

	//Calls glViewport with the coordinates stored in _viewport.
	void updateViewport()
	{
		bind;
		uint x = cast(uint)(_viewport[0]*width); //USE CLIENT WIDTH (GetClientRect on Windows)
		uint y = cast(uint)(_viewport[1]*height);
		uint w = cast(uint)((_viewport[2] - _viewport[0])*width);
		uint h = cast(uint)((_viewport[3] - _viewport[1])*height);
		glViewport(x, y, w, h); //TODO Confirm viewports are pixel-correct.
	}

public:

	/**
	 * Each thread has an active window, bound for rendering.
	 */
	@property static Window activeWindow() { return _activeWindow; }

	/**
	 * Constructor
	 *
	 * Windows begin life in a disabled state, invisible
	 * and unable to be interacted with. The user should
	 * set enabled = true after configuring the window.
	 */
	this()
	{

		//Lazy DerelictGl.load();
		i_ctor; bind;
		//Lazy DerelictGL.reload();

		//Add a model transform matrix to sit on top of the camera inverse matrix.
		glMatrixMode(GL_MODELVIEW); glPushMatrix();

		glEnable(GL_TEXTURE_2D);
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		glClearColor(0,0.05,0.1,1.0);
		glDrawBuffer(GL_BACK);

		glEnableClientState(GL_VERTEX_ARRAY);
		glEnableClientState(GL_NORMAL_ARRAY);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);

		glEnable(GL_LIGHTING);
		glEnable(GL_DEPTH_TEST);

		glEnable(GL_CULL_FACE);
		glCullFace(GL_BACK);
		glFrontFace(GL_CCW);

		viewport = vec4(0, 0, 1, 1);
	}

	~this()
	{
		if(_activeWindow == this)
		{
			i_bind(false);
			_activeWindow = null;
		}

		i_dtor;
	}

	/**
	 * The renderable region of the window.
	 *
	 * The upper-left of the window is (0, 0). The lower-right is (1, 1).
	 * The viewport is specified with a vec4, containing the upper-left
	 * corner and then the lower-right. Once set, the viewport remains
	 * proportional and correct even if the window is resized.
	 */
	@property void viewport(vec4 v)
	{
		assert(0.0 <= v[0] && v[0] < v[2] && v[2] <= 1.0);
		assert(0.0 <= v[1] && v[1] < v[3] && v[3] <= 1.0);
		_viewport = v;
		updateViewport;
	}

	@property vec4 viewport() { return _viewport; }

	@property double viewportAspect()
	{
		double x = _viewport[2] - _viewport[0];
		double y = _viewport[3] - _viewport[1];
		return y != 0.0 ? x / y : 1.0;
	}

	@property double aspect()
	{
		vec2 s = vec2(size);
		return s[1] != 0.0 ? s[0] / s[1] : 1.0;
	}

	enum Size { Minimum, Restore, Maximum }
	enum Style { Windowed, Borderless, Exclusive }

	/**
	 * Window title text.
	 */
	@property void title(wstring value) { i_title = value; }
	@property string title() { return i_title; }

	/**
	 * Window icon.
	 *
	 * The texture will be resized as necessary.
	 */
	@property void icon(Texture value) { i_icon = value; }

	/**
	 * Window dimensions.
	 *
	 * Set a vec2u value to specify exact width and height. If
	 * the window style is Exclusive, this will jump to the
	 * closest available exclusive fullscreen video mode.
	 *
	 * Set a Size value to minimise, maximise or restore the
	 * window. If the window is Exclusive, maximise has no
	 * effect.
	 */
	@property void size(vec2u value) { i_size = value; }
	@property void size(Size value) { i_size = value; }
	@property vec2u size() { return i_size; }

	@property uint width() { return i_size[0]; }
	@property void width(uint value) { i_size = vec2u(value, i_size[1]); }
	@property uint height() { return i_size[1]; }
	@property void height(uint value) { i_size = vec2u(i_size[0], value); }

	@property void position(vec2i value) { i_position = value; }

	/**
	 * Window style.
	 *
	 * Style.Windowed has native decorations including borders
	 * and minimise / maximise / close buttons.
	 *
	 * Style.Borderless is a plain square of pixels.
	 *
	 * Style.Exclusive commandeers the entire screen, stretching
	 * the output to fit and allowing gamma adjustment.
	 */
	@property void style(Style value) { i_style = value; }

	/**
	 * Window enabled state.
	 *
	 * If disabled, a window doesn't exist on the screen and receives no input.
	 * No other method will enable or disable the window.
	 * Other methods can modify the window while it is disabled.
	 */
	@property void enabled(bool value) { i_enabled = value; }
	@property void mouseVisible(bool value) { i_mouseVisible = value; }

	/**
	 * Bind the window for rendering.
	 */
	void bind()
	{
		if(_activeWindow != this)
		{
			i_bind(true);
			_activeWindow = this;
		}
	}

	/**
	 * Process the native event queue.
	 *
	 * Event-based inputs are inappropriate for a system that should
	 * always completely consume these inputs between every frame of
	 * user interaction, and often contains multiple agents that use
	 * the same input information at arbitrary times. So, we convert
	 * the events into a big lump of state. Even buffered text input
	 * can be dealt with this way, and it avoids annoying callbacks.
	 */
	void processEvents() { i_processEvents(); }

	void swapBuffers() { i_swapBuffers(); }

	private bool _sync;
	@property bool sync() { return _sync; }
	@property void sync(bool value) { i_swapInterval(value); _sync = value; }
}

// PLATFORM JUNK
package:

/////////
//LINUX//
/////////

mixin template LinuxImpl() { }
mixin template LinuxModuleImpl() { }

///////
//OSX//
///////

mixin template OSXImpl() { }
mixin template OSXModuleImpl() { }

///////////
//WINDOWS//
///////////

mixin template WindowsImpl()
{private:
	void* hwnd;
	void* hdc;
	void* hrc;

	static Window eventProcContext; //For passing context to the window procedure
	static Exception eventProcException; //For returning an exception thrown within eventProc
	static bool eventProcQuittable; //

	void i_ctor()
	{
		eventProcContext = this;

		hwnd = CreateWindowExA(0, "raider-render", "", WS_POPUP | WS_DISABLED,
			200,200,400,400, null, null, GetModuleHandleW(null), null);

		_createContext(hwnd, hdc, hrc);
		eventProcContext = null;

		if(Window.eventProcException) throw Window.eventProcException;

		if(hwnd == null) throw new WindowException("Failed to create window.");
	}

	void i_dtor()
	{
		eventProcContext = this;
		DestroyWindow(hwnd);
		eventProcContext = null;
	}
public:

	@property void i_title(wstring value) { SetWindowTextW(hwnd, value.ptr); } //toUTF16z(value)
	@property string i_title() { return ""; }


	@property void i_size(vec2u value)
	{
		eventProcContext = this;
		SetWindowPos(hwnd, null, 0, 0, value[0], value[1], SWP_NOMOVE | SWP_NOZORDER);
		updateViewport;
		eventProcContext = null;
	}

	@property void i_size(Size value) {  }

	@property vec2u i_size()
	{
		RECT rect;
		GetWindowRect(hwnd, &rect);
		return vec2u(rect.r - rect.l, rect.b - rect.t);
	}

	@property void i_position(vec2i value)
	{
		eventProcContext = this;
		SetWindowPos(hwnd, null, value[0], value[1], 0, 0, SWP_NOSIZE | SWP_NOZORDER);
		eventProcContext = null;
	}

	@property void i_enabled(bool value)
	{
		eventProcContext = this;
		EnableWindow(hwnd, value);
		ShowWindow(hwnd, value ? SW_SHOW : SW_HIDE);
		eventProcContext = null;
	}

	@property void i_style(Style value)
	{
		eventProcContext = this;
		auto style = GetWindowLongW(hwnd, GWL_STYLE);
		style &= ~(WS_OVERLAPPEDWINDOW | WS_POPUP);
		if(value == Style.Windowed) style |= WS_OVERLAPPEDWINDOW;
		if(value == Style.Borderless) style |= WS_POPUP;
		if(value == Style.Exclusive) { }

		SetWindowLongW(hwnd, GWL_STYLE, style);
		SetWindowPos(hwnd, null, 0, 0, 0, 0, SWP_FRAMECHANGED | SWP_NOSIZE | SWP_NOMOVE |SWP_NOZORDER );
		eventProcContext = null;
	}

	@property void i_icon(Texture value)
	{

	}

	@property void i_mouseVisible(bool value)
	{

	}

	void i_bind(bool value)
	{
		if(value)
		{
			if(!wglMakeCurrent(hdc, hrc))
				throw new WindowException("Failed to bind window.");
		}
		else
		{
			if(!wglMakeCurrent(null, null))
				throw new WindowException("Failed to unbind window.");
		}

	}

	void i_processEvents()
	{
		eventProcContext = this;

		MSG msg;
		while(PeekMessageA(&msg, hwnd, 0, 0, PM_REMOVE))
		{
			TranslateMessage(&msg);
			DispatchMessageW(&msg);
		}

		eventProcContext = null;

		if(Window.eventProcException) throw Window.eventProcException;

		if(msg.m == WM_QUIT)
			throw new WindowException("Window died without permission.");
	}

	void i_swapBuffers()
	{
		if(!SwapBuffers(hdc))
			throw new WindowException("Buffer swap failed.");
	}

	void i_swapInterval(bool value)
	{
		if(!wglSwapIntervalEXT(value ? 1 : 0))
			assert(0, "Vertical sync override detected.");

	}
}

mixin template WindowsModuleImpl()
{
	extern(Windows) int eventProc(void* hwnd, uint msg, uint wParam, int lParam) nothrow
	{
		//Somewhat more severe than an exception, but asserts don't work here :I
		if(!Window.eventProcContext)
		{
			Window.eventProcException = new WindowException("No window procedure context!");
			return DefWindowProcA(hwnd, msg, wParam, lParam);
		}

		Window wnd = Window.eventProcContext;

		switch(msg)
		{
			case WM_CREATE:
				//note for posterity: at this point, wnd.hwnd is uninitialised
				// (eventProc being invoked within CreateWindow)
				return 0;

			case WM_CLOSE:
				//TODO set 'close requested' thing or summink
				return 0;

			case WM_DESTROY:
				try { _destroyContext(wnd.hwnd, wnd.hdc, wnd.hrc); }
				catch(Exception e) Window.eventProcException = e;
				PostQuitMessage(0);
				return 0;

			default:
				return DefWindowProcA(hwnd, msg, wParam, lParam);
		}
	}

	//Register window class
	shared static this()
	{
		WNDCLASS wc;
		wc.wp = &eventProc;
		wc.s = CS_OWNDC;
		wc.hin = GetModuleHandleW(null);
		wc.ce = wc.we = 0;
		wc.cur = wc.hb = wc.ico = null;
		wc.mn = null;
		wc.cn = "raider-render";

		if(!RegisterClassW(&wc)) throw new WindowException("Windows NT required.");
	}

	shared static ~this()
	{ //this is rather pointless :D
		UnregisterClassW("raider-render", GetModuleHandleW(null));
	}
}
