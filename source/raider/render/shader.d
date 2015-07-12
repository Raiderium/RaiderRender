module raider.render.shader;

import derelict.opengl3.gl;
import raider.render.texture;

/**
 * A combined fragment and vertex program.
 */
class Shader
{private:
	GLuint _program;

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
		if(supported)
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
			GLuint frag = glCreateShader(GL_FRAGMENT_SHADER);
			GLuint vert = glCreateShader(GL_VERTEX_SHADER);

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
	}

	void release()
	{
		if(supported && compiled)
		{
			glDeleteProgram(_program);
			_program = 0;
		}
	}

	void bind()
	{
		if(supported && compiled) glUseProgram(_program);
	}

	static void unbind()
	{
		if(supported) glUseProgram(0);
	}

	@property bool compiled() { return cast(bool)_program; }
	@property GLuint program() { return _program; }
	@property static bool supported() { return DerelictGL.loadedVersion >= GLVersion.GL20; }

	void uniform(T)(string name, T u)
	{
		//TODO Use a string-int map to avoid GetUniformLocation calls.
		if(supported && compiled)
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
		if(supported && compiled)
		{
			glUseProgram(_program);

			//Give the textureUnit to the shader variable
			glUniform1i(glGetUniformLocation(_program, name.ptr), textureUnit);

			//Bind the texture to the textureUnit
			texture.bind(textureUnit);
		}
	}
}