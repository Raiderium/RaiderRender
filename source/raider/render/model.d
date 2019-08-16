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
@RC final class Model
{package:
	R!Mesh _mesh;
	ubyte _lastPlane; //The frustum plane that culled this model in the last frame

public:
	mat3 orientation;
	vec3 position;
	double radius;

	@property R!Mesh mesh() { return _mesh; }

	uint z;
	Array!(R!Material) materials;
	int lod;
	bool dirty; //LoD or time has changed
	bool lit; //participates in lighting (sets GL_LIGHTING true for this model)

	this(R!Mesh mesh, double margin = 0.0)
	{
		_mesh = mesh;
		this.radius = mesh.radius + margin;
		orientation = mat3.identity;
	}

	~this()
	{

	}

	@property mat4 transform() { return mat4(orientation, position); }


	/*enum BlendMode
	{
		Opaque,	//Enable depth write
		Add,	//Disable depth write, additive blending
		Alpha	//Disable depth write, sort faces by Z, enable backfaces, draw last
	}*/

	// TODO: Packable! File references objects by name. Directory / loaded resource search.
}
