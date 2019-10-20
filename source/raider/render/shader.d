module raider.render.shader;

import raider.render.gl;
import raider.tools.reference;
import raider.render.texture;

/**
 * A combined fragment and vertex program.
 *
 * TODO Investigate the strategy used by dglsl.
 */
@RC class Shader
{private:
	uint _program;

public:
	this()
	{
		_program = 0;
	}

	~this()
	{
		release();
	}

	void compile(string fragSource = null, string vertSource = null)
	{
		release();

		//TODO Default shaders
		if(!fragSource)
		{
			//fragSource = defaultFragmentSource;
		}

		if(!vertSource)
		{
			//vertSource = defaultVertexSource;
		}

		//To pass inputs to a vertex shader in we use glVertexAttribPointer.

		char[400] log;

		//Create program
		_program = glCreateProgram();
		uint frag = glCreateShader(GL_FRAGMENT_SHADER);
		uint vert = glCreateShader(GL_VERTEX_SHADER);

		if(!_program || !frag || !vert)
		{
			release();
			glDeleteShader(frag);
			glDeleteShader(vert);
			throw new Exception("Could not create shader.");
		}

		//Attach shaders
		glAttachShader(_program, frag);
		glAttachShader(_program, vert);

		//Compile
		glShaderSource(frag, 1, cast(char**)fragSource.ptr, null);
		glCompileShader(frag);

		int compiled = 0;
		glGetShaderiv(frag, GL_COMPILE_STATUS, &compiled);

		//Check for compile errors
		if(!compiled)
		{
			glGetShaderInfoLog(frag, log.sizeof, null, log.ptr);
		}
	}

	void release()
	{
		if(compiled)
		{
			glDeleteProgram(_program);
			_program = 0;
		}
	}

	void bind()
	{
		if(compiled) glUseProgram(_program);
	}

	static void unbind()
	{
		glUseProgram(0);
	}

	@property bool compiled() { return cast(bool)_program; }
	@property uint program() { return _program; }

	void uniform(T)(string name, T u)
	{
		//TODO Use a string-int map to avoid GetUniformLocation calls.
		if(compiled)
		{
			glUseProgram(_program);
			int l = glGetUniformLocation(_program, name);
			static if(is(T == float)) glUniform1f(l, u);
			else static if(is(T == int)) glUniform1i(l, u);
			else static if(is(T == vec2f)) glUniform2fv(l, 1, u.ptr);
			else static if(is(T == vec3f)) glUniform3fv(l, 1, u.ptr);
			else static if(is(T == vec4f)) glUniform4fv(l, 1, u.ptr);
			else static if(is(T == vec2f[])) glUniform2fv(l, u.length, u.ptr);
			else static if(is(T == vec3f[])) glUniform3fv(l, u.length, u.ptr);
			else static if(is(T == vec4f[])) glUniform4fv(l, u.length, u.ptr);
			else static if(is(T == mat2f)) glUniformMatrix2fv(l, 1, false, u.ptr);
			else static if(is(T == mat3f)) glUniformMatrix3fv(l, 1, false, u.ptr);
			else static if(is(T == mat4f)) glUniformMatrix4fv(l, 1, false, u.ptr);
			else static if(is(T == mat2f[])) glUniformMatrix2fv(l, u.length, false, u.ptr);
			else static if(is(T == mat3f[])) glUniformMatrix3fv(l, u.length, false, u.ptr);
			else static if(is(T == mat4f[])) glUniformMatrix4fv(l, u.length, false, u.ptr);
			//probably some diamonds around here if we look hard enough
			else static assert(0);
		}
	}

	void sampler(string name, Texture texture, int textureUnit)
	{
		if(compiled)
		{
			glUseProgram(_program);

			//Give the textureUnit to the shader variable
			glUniform1i(glGetUniformLocation(_program, name.ptr), textureUnit);

			//Bind the texture to the textureUnit
			texture.bind(textureUnit);
		}
	}
}
