module raider.render.material;

import derelict.opengl3.gl;
import raider.math.vec;
import raider.render.shader;
import raider.render.texture;
import raider.tools.array;
import raider.tools.reference;

/**
 * Controls the colour of rasterized pixels.
 * 
 * On limited hardware, the fixed function pipeline is 
 * used. This means standard Ambient-Diffuse-Specular 
 * shading, with a single texture blended in according 
 * to various settings. Only the first texture in the
 * texture stack will be used. In future, multitexturing
 * may be available, but it is not a priority.
 * 
 * If shaders are available, a supershader replaces
 * fixed function and replicates it per-pixel. More
 * textures can be accessed and used in more ways.
 * 
 * However, this supershader only does a few things.
 * If a custom shader is linked, the developer has
 * much more control.
 * 
 * Z sorting is available for transparency, and the depth 
 * write mode can be manipulated as desired.
 */
class Material
{
	vec4f ambient;
	vec4f diffuse;
	vec4f specular;
	vec4f emission;
	double sharpness;

	R!Shader shader;
	Array!(R!Texture) textures;

	this()
	{
		ambient = vec4f(0,0,0,1);
		diffuse = vec4f(1,1,1,1);
		specular = vec4f(1,1,1,1);
		emission = vec4f(0,0,0,1);
		sharpness = 10.0;
	}

	void bind()
	{
		/* 'Here,' said the GL, 'are some functions that do not accept double precision.'
	    I looked and was concerned, and about to speak, but it interrupted.
	    'Shushush. Don't be querulous. These are special. They must defy convention.'
	    I was distressed, but went about my business. */
		glMaterialfv(GL_FRONT, GL_AMBIENT, ambient.ptr);
		glMaterialfv(GL_FRONT, GL_DIFFUSE, diffuse.ptr);
		glMaterialfv(GL_FRONT, GL_SPECULAR, specular.ptr);
		glMaterialfv(GL_FRONT, GL_EMISSION, emission.ptr);
		glMaterialf(GL_FRONT,  GL_SHININESS, sharpness);
	}
}
