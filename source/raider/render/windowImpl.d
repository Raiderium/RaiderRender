module raider.render.windowImpl;

package: //The contents of this module are visible only to other modules in raider-render.

import raider.math.vec : vec2u, vec2i;
import raider.tools.reference;

final class WindowException : Exception
{ import raider.tools.exception; mixin SimpleThis; }


mixin template WindowImpl()
{
	version(linux) mixin LinuxImpl;
	version(OSX) mixin OSXImpl;
	version(Windows) mixin WindowsImpl;
}

mixin template WindowModuleImpl()
{
	version(linux) mixin LinuxModuleImpl;
	version(OSX) mixin OSXModuleImpl;
	version(Windows) mixin WindowsModuleImpl;
}

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

version(Windows)
{
	import core.sys.windows.winuser;
	import core.sys.windows.windef;
	import core.sys.windows.winbase;
	/* wingdi defines wgl methods that are normally linked statically. 
	 * However, derelict links them dynamically. So we must import 
	 * only what is needed, to avoid conflicting definitions. */
	import core.sys.windows.wingdi : 
		SwapBuffers, SetPixelFormat, ChoosePixelFormat,
		PFD_DRAW_TO_WINDOW, PFD_SUPPORT_OPENGL, PFD_DOUBLEBUFFER,
		PFD_TYPE_RGBA, PFD_MAIN_PLANE, PIXELFORMATDESCRIPTOR;
	import derelict.opengl3.wgl;
	import derelict.opengl3.wglext;
	import std.utf;

	void _createContext(HWND hwnd, ref HDC hdc, ref HGLRC hrc)
	{
		/* Note: If hwnd is null, you get fullscreen windows with single monitor 
		 * and weird see-through windows with multimonitor, seemingly regardless 
		 * of the window style. I spent days tracking down a trivial bug because 
		 * the Windows API likes to use null as a valid input with unintuitive 
		 * results. */

		hdc = GetDC(hwnd);
		if(!hdc) throw new WindowException("Failed to acquire device context.");
		
		static PIXELFORMATDESCRIPTOR pfd = {
			PIXELFORMATDESCRIPTOR.sizeof, 1, 
				PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,
				PFD_TYPE_RGBA,32,0,0,0,0,0,0,0,0,0,0,0,0,0,24,8,0,
			PFD_MAIN_PLANE,0,0,0,0};
		
		int pfi = ChoosePixelFormat(hdc, &pfd);
		if(!pfi) throw new WindowException("No compatible pixel format found.");
		
		if(!SetPixelFormat(hdc, pfi, &pfd)) throw new WindowException("Failed to set pixel format.");
		
		hrc = wglCreateContext(hdc);
		if(!hrc) throw new WindowException("Failed to create rendering context.");
	}
	
	void _destroyContext(ref HWND hwnd, ref HDC hdc, ref HGLRC hrc)
	{
		if(hrc == wglGetCurrentContext()) wglMakeCurrent(null, null);
		if(!wglDeleteContext(hrc)) throw new WindowException("Failed to delete rendering context.");
		if(!ReleaseDC(hwnd, hdc)) throw new WindowException("Failed to release device context.");
	}
}

mixin template WindowsImpl()
{private:
	HWND hwnd;
	HDC hdc;
	HGLRC hrc;

	static Window eventProcContext; //For passing context to the window procedure
	static Exception eventProcException; //For returning an exception thrown within eventProc
	static bool eventProcQuittable; //

	void i_ctor()
	{
		eventProcContext = this;

		hwnd = CreateWindowA("raider-render", "", WS_POPUP | WS_DISABLED,
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

	@property void i_title(string value) { SetWindowTextW(hwnd, toUTF16z(value)); }
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
		return vec2u(rect.right - rect.left, rect.bottom - rect.top);
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
		int style = GetWindowLongPtr(hwnd, GWL_STYLE);
		style &= ~(WS_OVERLAPPEDWINDOW | WS_POPUP);
		if(value == Style.Windowed) style |= WS_OVERLAPPEDWINDOW;
		if(value == Style.Borderless) style |= WS_POPUP;
		if(value == Style.Exclusive) { }

		SetWindowLongPtr(hwnd, GWL_STYLE, style);
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
			DispatchMessage(&msg);
		}

		eventProcContext = null;

		if(Window.eventProcException) throw Window.eventProcException;

		if(msg.message == WM_QUIT)
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
	extern(Windows) LRESULT eventProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) nothrow
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
		wc.lpfnWndProc = &eventProc;
		wc.style = CS_OWNDC;
		wc.hInstance = GetModuleHandleW(null);
		wc.cbClsExtra = wc.cbWndExtra = 0;
		wc.hCursor = wc.hbrBackground = wc.hIcon = null;
		wc.lpszMenuName = null;
		wc.lpszClassName = "raider-render";
		
		if(!RegisterClassW(&wc)) throw new WindowException("Windows NT required.");
	}
	
	shared static ~this()
	{ //this is rather pointless :D
		UnregisterClassW("raider-render", GetModuleHandleW(null));
	}
}
