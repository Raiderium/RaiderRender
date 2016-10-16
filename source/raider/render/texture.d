module raider.render.texture;

import raider.render.gl;
import raider.tools;

/**
 * Electronic tapestry.
 * 
 * An RGBA 32bpp bitmap.
 */
class Texture : Packable
{private:
	uint _width;
	uint _height;
	GLuint _id;

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
	@property GLuint id() { return _id; }

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
	 */
	void bind(uint textureUnit = 0)
	{
		if(gl.version_ >= GLVersion.GL13)
		{
			assert(textureUnit < GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS);
			glActiveTexture(GL_TEXTURE0 + textureUnit);
		}
		glBindTexture(GL_TEXTURE_2D, _id);
		//glActiveTexture(GL_TEXTURE0); Set active texture back to something..?
	}

	///Bind no texture.
	static void unbind()
	{
		glBindTexture(GL_TEXTURE_2D, 0);
	}

	import imageformats;

	override void pack(P!Stream s) const
	{

	}

	override void unpack(P!Stream s)
	{
		/* HACK
		 * imageformats' memory loading requires the file to be fully loaded first.
		 * Also, its format detection requires peeking.
		 * This is incompatible with RE, where streams don't seek or peek.
		 * 
		 * Sooo. Let's do some naughty casts for now.
		 * This will support files and archives, but not network streams.
		 */
		R!FileStream fs = cast(R!FileStream)s;
		if(fs)
		{
			ubyte[] bytes = new ubyte[cast(uint)fs.size];
			fs.readBytes(bytes);
			IFImage im = read_image_from_mem(bytes, 4);
			import std.experimental.logger;
			log(im.w, " ", im.h);
		}


		/* Type detection for future reference:
		 * BMP magic 2 bytes ['B', 'M']
		 * PNG magic 8 bytes [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
		 * JPEG magic 2 bytes [0xff, 0xd8]
		 */
	}

	override uint estimatePack() { return 0; }
}
