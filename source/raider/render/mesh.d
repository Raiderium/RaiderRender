module raider.render.mesh;

import derelict.opengl3.gl;
import raider.math.vec;
import std.bitmanip;
import raider.render.material;
import raider.tools.array;
import raider.tools.packable;
import raider.tools.reference;

struct Vertex
{
	vec2f uv;
	vec3f nor;
	vec3f pos;

	union
	{
		mixin(bitfields!(
			bool, "part", 1,
			bool, "uvPart", 1,
			bool, "norPart", 1,
			uint, "", 5));
		ubyte flags;
	}

	void toPack(P!Pack pack) const
	{
		pack.write(uv);
		pack.write(nor);
		pack.write(pos);
		pack.write(flags);
	}

	void fromPack(P!Pack pack)
	{
		pack.read(uv);
		pack.read(nor);
		pack.read(pos);
		pack.read(flags);
	}

	//TODO Fix the inherited normal thing not actually allowing arbitrary splitting
}

struct TriFace { uint a, b, c; }
struct QuadFace { uint a, b, c, d; }
struct Weight { uint i; float weight; }
struct Group { string name; Array!Weight weights; }
struct Key { uint i; vec3f pos; }
struct Morph { string name; Array!Key keys; }

/**
 * Latently visible floating triangles and quadrilaterals.
 */
class Mesh : Packable
{public:
	Array!Vertex verts;
	Array!TriFace tris;
	Array!QuadFace quads;
	Array!Group groups;
	Array!Morph morphs;
	Array!uint materialRanges;

	/**
	 * Calculate smoothed normals for all vertices.
	 */
	void calculateNormals()
	{
		//Set all vertex normals to (0,0,0)
		foreach(ref Vertex v; verts) v.nor = vec3f(0,0,0);

		//Sum triface normals to vertices
		foreach(ref TriFace f; tris)
		{
			vec3f x = verts[f.a].pos - verts[f.b].pos;
			vec3f y = verts[f.c].pos - verts[f.b].pos;
			vec3f n = y.cross(x);
			n.normalize();

			verts[f.a].nor += n;
			verts[f.b].nor += n;
			verts[f.c].nor += n;
		}

		//Sum quadface normals to vertices
		foreach(ref QuadFace f; quads)
		{
			vec3f x = verts[f.a].pos - verts[f.b].pos;
			vec3f y = verts[f.c].pos - verts[f.b].pos;
			vec3f n = y.cross(x);

			x = verts[f.c].pos - verts[f.d].pos;
			y = verts[f.a].pos - verts[f.d].pos;
			n += y.cross(x);
			n.normalize();
			
			verts[f.a].nor += n;
			verts[f.b].nor += n;
			verts[f.c].nor += n;
			verts[f.d].nor += n;
		}

		//Normalize 
		vec3f sum;
		foreach(size_t x, ref Vertex v; verts)
		{
			if(v.part) verts[x].nor = sum;
			else
			{
				sum = v.nor;

				//Like an engineer driving through the post-apocalypse, we look ahead for parts
				uint y = x+1;
				while(y < verts.length && verts[y].part)
					sum += verts[y].nor;
				sum.normalize();
				v.nor = sum;
			}
		}
	}

	override void toPack(P!Pack pack)
	{
		pack.writeArray(verts);
		pack.writeArray(tris);
		pack.writeArray(quads);
	}

	override void fromPack(P!Pack pack)
	{
		pack.readArray(verts);
		pack.readArray(tris);
		pack.readArray(quads);
	}

	override uint estimatePackSize()
	{
		return 0;
	}
}

/*
* Regarding geometrically defined vertices...
*
* The OpenGL defines a vertex as a vector of attributes, including 
* position, normal, color and position in texture space. If any of 
* these attributes change, it is considered a different vertex.
* 
* However, it is often desireable to define a vertex by
* position only (a 'geometric' vertex) and attach other 
* attributes to the face elements instead.
* 
* An example is texture mapping, where seams are necessary to 
* unwrap the model - neighbouring elements have different UV
* coordinates at the same vertex.
* 
* To submit geometric vertices, it is necessary to create and 
* track additional vertices with the same position. I refer to
* these as 'partial vertices' or 'parts'.
* 
* To keep track of them, they are lumped together in the 
* vertex stream. The 'part' flag is used to indicate a vertex
* inherits its position from the last unflagged vertex. 
* The 'uvPart' and 'norPart' flags might also be set, indicating
* the vertex also inherits those attributes from the same source.
* 
* Algorithms that modify vertex attributes can process the first
* part in the lump, cache the result, and copy it to inheriting parts.
* Non-inheriting parts can be processed without updating the cache.
* 
* Algorithms must be written with an understanding of the part flags.
*/

/*
 * Regarding UV coordinates...
 * 
 * The purpose of the UV coordinate pair is to provide a definitive
 * unwrapping of the mesh to a 2D space, nothing more. Thus there
 * is only one coordinate pair per vertex.
 * 
 * Effects that traditionally require additional UV coords must be
 * implemented by other means.
 */