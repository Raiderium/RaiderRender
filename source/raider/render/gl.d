///Provides the OpenGL API
module raider.render.gl;

import raider.tools.reference;
import std.exception;

public import derelict.opengl3.gl;
import std.stdio;

__gshared GL gl;

shared static this()
{
	gl = new GL();
}

private final class GL
{
	GLVersion version_;
	int colourBits, stencilBits, depthBits;
	ubyte doubleBuffered;
	int textureUnits;

	this()
	{
		//Link to OpenGL.
		DerelictGL.load();
		auto bootstrap = New!Context(); //A context is required to get versions above 1.1.
		version_ = DerelictGL.reload(GLVersion.None, GLVersion.GL31);

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
		if(version_ >= 13)
		{
			glGetIntegerv(GL_MAX_TEXTURE_IMAGE_UNITS, &textureUnits);
			enforce(textureUnits >= 2);
		}
	}

	static void checkError(string source)
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
}

final class GLException : Exception
{ import raider.tools.exception; mixin SimpleThis; }

//Context just makes a GL context as quick as possible.
private final class Context
{
	version(Windows)
	{
		import raider.render.windowImpl;

		HWND hwnd;
		HDC hdc;
		HGLRC hrc;

		this()
		{
			WNDCLASS wc;
			wc.lpfnWndProc = &DefWindowProcA;
			wc.style = CS_OWNDC;
			wc.hInstance = GetModuleHandleW(null);
			wc.lpszClassName = "gl";
			
			RegisterClassW(&wc);

			hwnd = CreateWindowA("gl", "", WS_POPUP | WS_DISABLED, 0,0,1,1, null, null, GetModuleHandleW(null), null);
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
