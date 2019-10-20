module raider.render.gl;

import raider.tools.reference;
import std.exception : enforce;
import std.string : toStringz;

final class OpenGLException : Exception
{ import raider.tools.exception : SimpleThis; mixin SimpleThis; }
alias EX = OpenGLException;

final class ContextException : Exception
{ import raider.tools.exception : SimpleThis; mixin SimpleThis; }
alias CE = ContextException;

//////////////
//OPENGL API//
//////////////

//Constants
enum : ubyte { GL_FALSE, GL_TRUE }
enum : uint {
	GL_DEPTH_BUFFER_BIT = 0x0100, GL_COLOR_BUFFER_BIT = 0x4000, GL_VERTEX_ARRAY = 0x8074,
	GL_BYTE = 0x1400, GL_UNSIGNED_BYTE, GL_SHORT, GL_UNSIGNED_SHORT, GL_INT, GL_UNSIGNED_INT, GL_FLOAT,
	GL_LINES = 1, GL_TRIANGLES = 4, GL_RGBA = 0x1908, GL_TEXTURE_2D = 0x0DE1, GL_TEXTURE0 = 0x84C0,
	GL_FRAGMENT_SHADER = 0x8B30, GL_VERTEX_SHADER, GL_COMPILE_STATUS = 0x8B81,
	GL_DOUBLEBUFFER = 0x0C32, GL_CULL_FACE = 0x0B44, GL_DEPTH_TEST = 0x0B71, GL_CCW = 0x0901,
	GL_MAX_TEXTURE_IMAGE_UNITS = 0x8872, GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS = 0x8B4D,
	GL_INVALID_ENUM = 0x0500, GL_INVALID_VALUE, GL_INVALID_OPERATION, GL_OUT_OF_MEMORY = 0x0505,
	GL_FRONT = 0x0404, GL_BACK, GL_BLEND = 0x0BE2, GL_SRC_ALPHA = 0x0302, GL_ONE_MINUS_SRC_ALPHA,
}

//Deprecated constants (remove at earliest convenience)
enum : uint {
	GL_MODELVIEW = 0x1700, GL_PROJECTION, GL_STACK_OVERFLOW = 0x0503, GL_STACK_UNDERFLOW,
	GL_ALPHA_BITS = 0x0D55, GL_RED_BITS = 0x0D52, GL_GREEN_BITS, GL_BLUE_BITS,
	GL_STENCIL_BITS = 0x0D57, GL_DEPTH_BITS = 0x0D56, GL_POSITION = 0x1203,
	GL_LIGHTING, GL_LIGHT0, GL_LIGHT1, GL_LIGHT2, GL_LIGHT3, GL_LIGHT4, GL_LIGHT5, GL_LIGHT6, GL_LIGHT7,
	GL_AMBIENT = 0x1200, GL_DIFFUSE, GL_SPECULAR, GL_EMISSION = 0x1600, GL_SHININESS,
	GL_NORMAL_ARRAY = 0x8075, GL_TEXTURE_COORD_ARRAY = 0x8078
}

enum Stage1; //GL1.0 and 1.1, loaded with platformProc.
enum Stage2; //GL1.2 and up, laoded with contextProc.

extern(System) __gshared @nogc nothrow {
	@Stage1 {
		//OpenGL 1.0
		void function(uint) glCullFace, glFrontFace, glDrawBuffer, glEnable, glDisable, glClear;
		void function(uint, uint) glBlendFunc;
		void function(uint, int*) glGetIntegerv;
		void function(uint, ubyte*) glGetBooleanv;
		void function(int, int, int, int) glViewport;
		void function(float, float, float, float) glClearColor;
		void function(uint, int, int, int, int, int, uint, uint, const(void)*) glTexImage2D;

		//OpenGL 1.1
		void function(int, uint*) glGenTextures;
		void function(uint, uint) glBindTexture;
		void function(int, const(uint)*) glDeleteTextures;

		//Deprecated Opengl 1.0 / 1.1
		void function() glPushMatrix, glPopMatrix, glLoadIdentity;
		void function(uint) glEnableClientState, glDisableClientState, glMatrixMode;
		void function(const(double)*) glMultMatrixd, glLoadMatrixd;
		void function(uint, uint, float) glMaterialf;
		void function(uint, int, const(void)*) glNormalPointer;
		void function(uint, uint, const(float)*) glMaterialfv;
		void function(uint, uint, const(float)*) glLightfv;
		void function(int, uint, int, const(void)*) glVertexPointer, glTexCoordPointer;
		void function(uint, int, uint, const(void)*) glDrawElements;
		void function(double, double, double, double, double, double) glOrtho, glFrustum;
	}

	@Stage2 {
		//OpenGL 1.3
		void function(uint) glActiveTexture;

		//OpenGL 2.0
		uint function() glCreateProgram;
		uint function(uint) glCreateShader, glDeleteShader, glCompileShader, glDeleteProgram, glUseProgram;
		void function(int, int) glUniform1i;
		void function(int, float) glUniform1f;
		void function(uint, uint) glAttachShader;
		void function(uint, uint, int*) glGetShaderiv;
		int function(uint, const(char)*) glGetUniformLocation;
		void function(uint, int, int*, char*) glGetShaderInfoLog;
		void function(int, int, const(float)*) glUniform2fv, glUniform3fv, glUniform4fv;
		void function(int, int, ubyte, const(float)*) glUniformMatrix2fv, glUniformMatrix3fv, glUniformMatrix4fv;
		void function(uint, int, const(char*)*, const(int)*) glShaderSource;
	}
}

////////////////
//PLATFORM API//
////////////////

version(linux) { }
version(OSX) { }
version(Windows)
{
	struct PFD { ushort ns, nv; uint dwf; ubyte ipt, cb, rb, rs, gb, gs, bb, bs, ab, as,
		acb, acrb, acgb, acbb, acab, db, sb, axb, ilt, br; uint dwlm, dwvm, dwdm; }
	//alias WNDPROC = extern(Windows) int function(void*, uint, uint, int);
	//struct WNDCLASS { uint s; WNDPROC wp; int ce, we; void* hin, ico, cur, hb; const(wchar)* mn, cn; }
	struct WNDCLASS { uint s; extern(Windows) int function(void*, uint, uint, int) wp; int ce, we; void* hin, ico, cur, hb; const(wchar)* mn, cn; }
	struct RECT { int l, t, r, b; } struct POINT { int x, y; }
	struct MSG { void* w; uint m; uint wp; int lp; uint t; POINT p;}
	alias LPCSTR = const(char)*; alias LPCWSTR = const(wchar)*;
	enum { WS_POPUP = 0x80000000, WS_DISABLED = 0x08000000, WS_OVERLAPPEDWINDOW = 0x00CF0000 }
	enum { SWP_NOSIZE = 1, SWP_NOMOVE = 2, SWP_NOZORDER = 4, SWP_FRAMECHANGED = 32}
	enum { SW_SHOW = 5, SW_HIDE = 0 } enum { CS_OWNDC = 32 }
	enum { GWL_STYLE = -16, PM_REMOVE = 1, WM_CREATE = 1, WM_DESTROY, WM_CLOSE = 16, WM_QUIT = 18 }
	//alias void* HMENU, LPVOID, HDC, HGLRC, HWND, HMODULE, HINSTANCE, HICON, HCURSOR, HBRUSH
	//alias long LRESULT, LPARAM, alias uint UINT, DWORD, alias ulong WPARAM, alias ushort ATOM
	//32 BIT:
	//LRESULT, LPARAM, LONG_PTR, LONG: int
	//WPARAM: uint

	extern(Windows) nothrow @nogc
	{
		//These functions are statically linked to gdi32
		void* GetDC(void*);
		int ReleaseDC(void*, void*);
		int ChoosePixelFormat(void*, const(PFD)*);
		int SetPixelFormat(void*, int, const(PFD)*);
		int SwapBuffers(void*);
		void* GetModuleHandleW(LPCWSTR);
		ushort RegisterClassW(const(WNDCLASS)*);
		int UnregisterClassW(LPCWSTR, void*);
		void* CreateWindowExA(uint, LPCSTR,LPCSTR, uint, int, int, int, int, void*, void*, void*, void*);
		int DestroyWindow(void*);
		int SetWindowTextW(void*, LPCWSTR);
		int SetWindowPos(void*, void*, int, int, int, int, uint);
		int GetWindowRect(void*, RECT*);
		int EnableWindow(void*, int);
		int ShowWindow(void*, int);
		int PeekMessageA(MSG*, void*, uint, uint, uint);
		void PostQuitMessage(int);
		int TranslateMessage(const(MSG)*);
		int DispatchMessageW(const(MSG)*);
		int DefWindowProcA(void*, uint, uint, int);
		int SetWindowLongW(void*, int, int);
		int GetWindowLongW(void*, int);

		//These, to kernel32 or somesuch
		void* LoadLibraryA(LPCSTR);
		void* function() GetProcAddress(void*, LPCSTR);
		void FreeLibrary(void*);
		uint GetLastError();

		@Stage1 {
			void* function(void*) wglCreateContext;
			void* function() wglGetCurrentContext;
			int function(void*) wglDeleteContext;
			int function(void*, void*) wglMakeCurrent;
			void* function(LPCSTR) wglGetProcAddress;
		}

		//wglGetExtensionsStringARB must be loaded manually before Stage 2.
		const(char*) function(void*) wglGetExtensionsStringARB;

		@Stage2 {
			int function(int) wglSwapIntervalEXT;
			int function() wglGetSwapIntervalEXT;
		}
	}

	package void _createContext(void* hwnd, ref void* hdc, ref void* hrc)
	{
		/* Note: If hwnd is null, you get fullscreen windows with single monitor
		 * and weird see-through windows with multimonitor, seemingly regardless
		 * of the window style. I spent days tracking down a trivial bug because
		 * the Windows API likes to use null as a valid input with unintuitive
		 * results. */

		hdc = GetDC(hwnd);
		if(!hdc) throw new CE("Failed to acquire device context.");

		static PFD pfd = {PFD.sizeof,1,21,0,32,0,0,0,0,0,0,0,0,0,0,0,0,0,24,8,0,0,0,0,0,0};

		int pfi = ChoosePixelFormat(hdc, &pfd);
		if(!pfi) throw new CE("No compatible pixel format found.");

		if(!SetPixelFormat(hdc, pfi, &pfd)) throw new CE("Failed to set pixel format.");

		hrc = wglCreateContext(hdc);
		if(!hrc) throw new CE("Failed to create rendering context.");
	}

	package void _destroyContext(ref void* hwnd, ref void* hdc, ref void* hrc)
	{
		if(hrc == wglGetCurrentContext()) wglMakeCurrent(null, null);
		if(!wglDeleteContext(hrc)) throw new CE("Failed to delete rendering context.");
		if(!ReleaseDC(hwnd, hdc)) throw new CE("Failed to release device context.");
	}

	//Makes a GL context as quick as possible.
	@RC package final class BootstrapContext
	{
		void* hwnd, hdc, hrc;

		this()
		{
			WNDCLASS wc;
			wc.wp = &DefWindowProcA;
			wc.s = CS_OWNDC;
			wc.hin = GetModuleHandleW(null);
			wc.cn = "gl";

			RegisterClassW(&wc);

			hwnd = CreateWindowExA(0, "gl", "", WS_POPUP | WS_DISABLED, 0,0,1,1, null, null, GetModuleHandleW(null), null);
			_createContext(hwnd, hdc, hrc);
			wglMakeCurrent(hdc, hrc);
		}

		~this()
		{
			wglMakeCurrent(null, null);
			_destroyContext(hwnd, hdc, hrc);
			DestroyWindow(hwnd);
			UnregisterClassW("gl", GetModuleHandleW(null));
		}
	}
}

__gshared GL gl;
shared static this() { gl = new GL(); }

private final class GL
{
	int colourBits, stencilBits, depthBits, textureUnits;
	ubyte doubleBuffered;
	void* lib; //OpenGL.dll / libGL.so

	this()
	{
		//Link to OpenGL.
	    version(linux) { }
	    version(OSX) { }
	    version(Windows) { lib = LoadLibraryA("opengl32.dll".toStringz); }

		if(lib is null) throw new EX("Failed to locate OpenGL library.");

		//Load Stage 1 functions.
		loadAll!Stage1;

		//On Windows, create a bootstrap context to get versions above 1.1
		version(Windows) { auto bootstrap = New!BootstrapContext(); }

		//OpenGL compat check
		//if(wglGetCurrentContext && wglGetCurrentContext())
		//{ glGetString(GL_VERSION) }

		//Get wglGetExtensionsStringARB.
		version(Windows) {
			wglGetExtensionsStringARB = cast(typeof(wglGetExtensionsStringARB))load!Stage2("wglGetExtensionsStringARB");
			//wgl compat check
			//Use wglGetExtensionsStringARB to check support for WGL_EXT_swap_control.
		}

		//Stage 2 needs to repeat after each thread gains a context..
		//But the functions are all gshared?
		//We have to assume that creating the same sort of context gets the same function pointers :(
		//Perhaps we can check this by repeating Stage 2 and comparing the pointers.
		//If any don't match, it's fatal.

		//Load Stage 2 functions.
		loadAll!Stage2;

		//1.0
		int r, g, b, a;
		glGetIntegerv(GL_RED_BITS, &r);
		glGetIntegerv(GL_GREEN_BITS, &g);
		glGetIntegerv(GL_BLUE_BITS, &b);
		glGetIntegerv(GL_ALPHA_BITS, &a);
		colourBits = r + g + b + a;
		glGetIntegerv(GL_STENCIL_BITS, &stencilBits);
		glGetIntegerv(GL_DEPTH_BITS, &depthBits);
		glGetBooleanv(GL_DOUBLEBUFFER, &doubleBuffered);
		enforce(colourBits == 24 || colourBits == 32);
		enforce(stencilBits >= 8);
		enforce(depthBits >= 24);
		enforce(doubleBuffered);

		//1.3
		glGetIntegerv(GL_MAX_TEXTURE_IMAGE_UNITS, &textureUnits);
		enforce(textureUnits >= 2);
	}

	~this()
	{
		version(Windows) { FreeLibrary(lib); }
	}

	version(linux) { }
	version(OSX) { }
	version(Windows) {
		void* platformProc(string name) {
			return GetProcAddress(lib, name.toStringz); }

		void* contextProc(string name) {
			assert(wglGetProcAddress !is null);
			return wglGetProcAddress(name.toStringz); }
	}

	//Load symbol.
	void* load(stage)(string symbol)
	{
		static if(is(stage == Stage1)) void* s = platformProc(symbol);
		static if(is(stage == Stage2)) void* s = contextProc(symbol);
		if(s is null) throw new EX("Failed to load symbol '" ~ symbol ~ "'");
		return s;
	}

	//Load symbols in this module according to their stage.
	void loadAll(stage)()
	{
		import std.traits : isFunctionPointer;
		foreach(name; __traits(allMembers, raider.render.gl)) {
			mixin("alias symbol = " ~ name ~ ";");
			static if(isFunctionPointer!symbol) {
				alias attr = __traits(getAttributes, symbol);
				static if(attr.length != 0 && is(attr[0] == stage)){
					symbol = cast(typeof(symbol))load!stage(symbol.stringof); }}}
	}

/**
	static void checkError(string source) //TODO Upgrade to callback-based stuff.
	{
		int errorcode = glGetError();
		string errorstring;
		if(errorcode)
		{
			switch(errorcode)
			{
				case GL_INVALID_ENUM: errorstring = "invalid enum"; break;
				case GL_INVALID_VALUE: errorstring = "invalid value"; break;
				case GL_INVALID_OPERATION: errorstring = "invalid operation"; break;
				case GL_STACK_OVERFLOW: errorstring = "stack overflow"; break;
				case GL_STACK_UNDERFLOW: errorstring = "stack underflow"; break;
				case GL_OUT_OF_MEMORY: errorstring = "out of memory"; break;
				default: errorstring = "unknown!";
			}

			throw new GLException("OpenGL error (" ~ errorstring ~ ") occurred at " ~ source);
		}
	}
	**/
}
