module raider.render.window;

import raider.render.gl;
import raider.math.vec;
import raider.tools.array;
import raider.tools.reference;
import raider.render.texture;
import raider.render.windowImpl;

mixin WindowModuleImpl;

/**
 * A thing for stuff to happen in.
 * 
 * Provides an OpenGL context for drawing. 
 */
@RC final class Window
{
	/* Platform-specific junk.
	 * Implementation details are prefixed with 'i_' */
	mixin WindowImpl;

private:
	static Window _activeWindow;
	vec4 _viewport;

	//Call glViewport with the coordinates specified by _viewport.
	void updateViewport()
	{
		bind;
		uint x = cast(uint)(_viewport[0]*width); //USE CLIENT WIDTH. GetClientRect on Windows
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
	@property void title(string value) { i_title = value; }
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
