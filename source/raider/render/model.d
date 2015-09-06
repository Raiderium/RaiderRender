module raider.render.model;

import raider.math;
import raider.tools.array;
import raider.tools.reference;
import raider.render.armature;
import raider.render.material;
import raider.render.mesh;

/**
 * An instance of a mesh.
 * 
 * A model turns a mesh into something presentable by adding 
 * transform, optimisation geometry, materials, colour 
 * modulation and blending.
 */
final class Model
{package:
	R!Mesh _mesh;
	ubyte _lastPlane; //The frustum plane that culled this model in the last frame
	
public:
	mat3 orientation;
	vec3 position;
	double radius;

	uint z;
	vec4 colour;
	Array!(R!Material) materials;
	int lod;
	bool dirty; //LoD has changed (also general purpose dirty flag).
	
	this(R!Mesh mesh, double radius)
	{
		//_mesh = mesh;
		this.radius = radius;
	}
	
	~this()
	{
		
	}
	
	//@property void radius(double value) { _radius = value; }
	//@property vec3 position() { return _position; }
	//@property void position(vec3 value) { _position = value; }
	//@property mat3 orientation() { return _orientation; }
	//@property void orientation(mat3 value) { _orientation = value; }
	@property mat4 transform() { return mat4(orientation, position); }
	
	
	/*enum BlendMode
	{
		Opaque,	//Enable depth write
		Add,	//Disable depth write, additive blending
		Alpha	//Disable depth write, sort faces by Z, enable backfaces, draw last
	}*/
}
