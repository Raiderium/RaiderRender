module raider.render.texture;

import raider.tools.array;
import raider.tools.packable : Packable;
import raider.tools.stream : Stream;
import raider.tools.reference;
import std.conv : to;
import raider.render.gl;

final class TextureException : Exception
{ import raider.tools.exception : SimpleThis; mixin SimpleThis; }

alias EX = TextureException;


/**
 * Electronic tapestry.
 *
 * An RGBA 32bpp texture.
 */
@RC class Texture : Packable
{private:
	uint _width;
	uint _height;
	uint _id;
	Array!Pixel _data; //Textures in RAM are supported but not the primary focus of this class

	// Generates a GL texture if not present, and uploads anything in _data.
	void upload()
	{
		assert(_width && _height);
		assert(_data.size == _width*_height);
		if(!_id) glGenTextures(1, &_id);
		bind;
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, _width, _height, 0, GL_RGBA, GL_UNSIGNED_BYTE, _data.ptr);
	}

	void release()
	{
		/*"glDeleteTextures silently ignores 0's and names that
		do not correspond to existing textures." - the OpenGL reference */
		glDeleteTextures(1, &_id);
		_id = 0;
		_width = 0;
		_height = 0;
	}

public:
	@property uint width() { return _width; }
	@property uint height() { return _height; }
	@property uint id() { return _id; }

	this() { }
	~this() { release; }

	/**
	 * Bind texture.
	 *
	 * If gl version >=1.3, specifying a texture unit will bind to
	 * that unit, and it will become available in any systems that
	 * are aware of multiple units (multitexturing, GLSL, etc).
	 *
	 * If unsupported, binds to non-zero units will do nothing.
	 *
	 * TODO Just bite this bullet and REQUIRE a certain level.
	 * Do NOT try to go THIS FAR BACK with optional versions.
	 * If you're going to depend on texture units, depend on them.
	 */
	void bind(uint textureUnit = 0)
	{
		///if(gl.version_ >= GLVersion.GL13)
		assert(textureUnit < GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS);
		glActiveTexture(GL_TEXTURE0 + textureUnit);
		glBindTexture(GL_TEXTURE_2D, _id);
		//glActiveTexture(GL_TEXTURE0); Set active texture back to something..?
	}

	///Bind no texture.
	static void unbind()
	{
		glBindTexture(GL_TEXTURE_2D, 0);
	}

	override void pack(Stream s) const
	{
		//How can this specify what format to use?
		//R!FileStream f = New!FileStream("eco_prefilter.ppm", Stream.Mode.Write);
		//f.write("P6 702 425 255\n");
		//foreach(p; pixels) { f.write(p.r); f.write(p.g); f.write(p.b); }

		//This appears to be a deficiency in packable.
		//Structs can pass arguments, but the interface cannot..
		//Perhaps we simply store the arguments in the texture.
		//That WOULD make sense. There are no questions about HOW to pack an item.
		//It's just implicit in the state. And upon reading, the format would
		//be stored in the same variable.
		//A class is its own context.

		//R!FileStream f = New!FileStream("line.ppm", Stream.Mode.Write);
		//f.write("P6 702 425 255\n");
		//foreach(p; pixels) f.write(p.rgb);
	}

	override void unpack(Stream s)
	{
		import raider.render.webp : load;
		_data = load(s, _width, _height);
		upload;

		/* Type detection for future reference:
		 * BMP magic 2 bytes ['B', 'M']
		 * PNG magic 8 bytes [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
		 * JPEG magic 2 bytes [0xff, 0xd8]
		 */
	}
}

union Pixel
{
	uint v; struct { ubyte r, g, b, a; }

	this(ubyte r, ubyte g, ubyte b, ubyte a) { this.r = r; this.g = g; this.b = b; this.a = a; }
	this(uint v) { this.v = v; }

	@property ubyte[3] rgb() const { return [r, g, b]; }
	void opOpAssign(string op)(in Pixel o) { mixin("r"~op~"=o.r; g"~op~"=o.g; b"~op~"=o.b; a"~op~"=o.a;"); }
	string toString() { return "["~to!string(r)~" "~to!string(g)~" "~to!string(b)~" "~to!string(a)~"]"; }
}
