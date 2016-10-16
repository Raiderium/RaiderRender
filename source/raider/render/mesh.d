module raider.render.mesh;

import std.math : sqrt;
import raider.math.vec;
import std.bitmanip;
import raider.render.gl;
import raider.render.material;
import raider.tools.array;
import raider.tools.packable;
import raider.tools.stream;
import raider.tools.reference;

/**
 * An eight-dimensional point occupying three distinct euclidean 
 * geometries with an unknown number of conjunct clones.
 * 
 * It's complicated.
 */
struct Vertex
{
	vec2f uv;
	vec3f nor;
	vec3f pos;

	union
	{
		mixin(bitfields!( //reminder: top to bottom is LSB to MSB
				bool, "part", 1,
				bool, "norPart", 1,
				bool, "uvPart", 1,
				uint, "uvGroup", 5));
		ubyte flags;
		//D is kind enough to insert 3 pad bytes after this. The GL approves.
		static assert(Vertex.sizeof == 36); //Paranoia
	}

	void pack(P!Stream s) const
	{
		s.write(flags);
		if(!part) s.write(pos);
		if(!uvPart) s.write(uv);
	}

	void unpack(P!Stream s)
	{
		s.read(flags);
		if(!part) s.read(pos);
		if(!uvPart) s.read(uv);
	}
}

/**
 * Three vertex indices defining a triangle in space.
 */
struct Tri { uint a, b, c; }

/**
 * A polygon linking an arbitrary number of vertices.
 * 
 * This struct is transient (not stored anywhere).
 */
struct Face
{ 
	Tri[] tris; //Triangles comprising this face.

	//Yield vertex indices in winding order.
	int verts(int delegate(uint vi) dg)
	{
		int result;

		uint x0; uint x1 = 1;
		while(1)
		{ //TODO test this
			x1 %= tris.length;
			dg(tris[x0].a);
			if(tris[x0].b == tris[0].a) break;
			if(tris[x0].b != tris[x1].a)
			{
				dg(tris[x0].b);
				if(tris[x1].c == tris[0].a) break;
				if(x0 == x1) { dg(tris[x0].c); break; }
			}
			x0 = x1++; //this subtle obfuscation is really quite awful
		}

		return result;
	}

	void pack(P!Stream s, bool ushort_i)
	{
		foreach(vi; &verts)
			if(ushort_i) s.write!ushort(cast(ushort)vi);
			else s.write!uint(vi);
	}

	void unpack(P!Stream s, bool ushort_i)
	{
		foreach(i, ref tri; tris)
		{
			//This generates a simple fan triangulation.
			if(i == 0) {
				tri.a = ushort_i ? s.read!ushort : s.read!uint;
				tri.b = ushort_i ? s.read!ushort : s.read!uint;
				tri.c = ushort_i ? s.read!ushort : s.read!uint;
			} else {
				tri.a = tris[i-1].c;
				tri.b = ushort_i ? s.read!ushort : s.read!uint;
				tri.c = tris[0].a;
			}
		}
	}
}

//Section describes a contiguous range of triangulated polygons of a particular size.
struct Section
{
	uint type;
	Tri[] tris;

	public int faces(int delegate(ref Face face) dg)
	{
		Face face;
		int result;

		//Triangles in each face
		uint tc = type - 2;
		assert(tris.length % tc == 0);

		//Faces in this section
		uint fc = tris.length / tc;

		for(uint x = 0; x < fc; x++)
		{
			face.tris = tris[x*tc .. (x+1)*tc];
			result = dg(face);
			if(result) break;
		}
		return result;
	}

	void pack(P!Stream s)
	{
		s.write!uint(type);
		s.write!uint(tris.length / type);
	}

	//A section is only unpacked in the context of a mesh and cursor into the tri-list.
	void unpack(P!Stream s, P!Mesh mesh, ref uint cursor)
	{
		//Indices are stored as unsigned shorts if the largest index fits in ushort.max.
		bool ushort_i = mesh.verts.length <= ushort.max;

		s.read(type);
		uint facecount = s.read!uint;
		uint tricount = facecount * (type-2);

		tris = mesh.tris[cursor .. cursor+tricount];
		cursor += tricount;
		foreach(face; &faces) s.read(face, ushort_i);
	}
}

//Page describes a contiguous range of sections (called a sub-mesh by other applications)
struct Page
{
	Tri[] tris;
	Section[] sections;

	void pack(P!Stream s)
	{
		s.write!uint(sections.length);
	}

	void unpack(P!Stream s, P!Mesh mesh, ref uint cursor)
	{
		uint sectioncount = s.read!uint;

		sections = mesh.sections[cursor .. cursor+sectioncount];
		cursor += sectioncount;

		//Horrible pointer arithmetic shenanigans to combine the contiguous sections
		uint t0 = &sections[0].tris[0] - &mesh.tris[0];
		uint t1 = &(sections[$-1].tris[$-1]) - &mesh.tris[0];

		tris = mesh.tris[t0 .. t1+1];
	}
}

//Weight group: Specifies a group of verts with a float value per vertex.
struct Weight { uint i; float weight; }
struct Group { string name; Array!Weight weights; }

//Morph key: Specifies a group of verts with a position key per vertex.
struct Key { uint i; vec3f pos; }
struct Morph { string name; Array!Key keys; }

/**
 * Latently visible floating triangles.
 */
class Mesh : Packable
{public:
	Array!Vertex verts;
	Array!Tri tris; //Triangulated renderable primitive faces.
	Array!Section sections; //Faces grouped by number of vertices.
	Array!Page pages; //Sections grouped into submeshes.
	Array!Group groups;
	Array!Morph morphs;
	
	public int faces(int delegate(ref Face face) dg)
	{
		int result;
		foreach(page; pages)
			foreach(section; page.sections)
			{
				result = section.faces(dg);
				if(result) break;
			}
		return result;
	}

	/**
	 * Calculate normals for all vertices.
	 */
	void updateNormals()
	{
		//Clear all normals
		foreach(ref vert; verts) vert.nor = vec3f.zero;

		foreach(ref t; tris) //Using this until face.verts is functional.
		{
			vec3f x = verts[t.a].pos - verts[t.b].pos;
			vec3f y = verts[t.c].pos - verts[t.b].pos;
			vec3f n = y.cross(x);
			n.normalize();
			//Would be nice to profile Q_rsqrt for normalization.
			
			verts[t.a].nor += n;
			verts[t.b].nor += n;
			verts[t.c].nor += n;
		}

		//Normalize
		//vec3f p;
		foreach(parts; &geometricParts)
		{
			vec3f sum;
			foreach(ref v; parts) sum += v.nor;
			sum.normalize();
			foreach(ref v; parts) v.nor = sum;
		}

		/* The following normalization algorithm looks horrible.
		 * But, it's about 7 percent faster on my computer
		 * (perhaps on account of having a witty comment).
		 * Or maybe it's because the foreach delegates above 
		 * aren't being inlined in debug builds with DMD.
		 * Let's see how long this piece of garbage hangs 
		 * around because I can't let go of preconceptions.
		 */
		/*vec3f sum;
		foreach(size_t x, ref Vertex v; verts)
		{
			if(v.part) verts[x].nor = sum;
			else
			{
				sum = v.nor;
				
				//Like an engineer driving through the post-apocalypse, we look ahead for parts
				uint y = x+1;
				while(y < verts.length && verts[y].part)
				{
					sum += verts[y].nor;
					y++;
				}
				sum.normalize();
				v.nor = sum;
				//I never said it was good wit
			}
		}*/
	}

	private int geometricParts(int delegate(ref Vertex[] x) dg)
	{
		int result;
		uint v0, v1;

		while(v1 < verts.length)
		{
			v1++;
			if(v1 == verts.length || !verts[v1].part)
			{
				auto t = verts[v0..v1];
				result = dg(t);
				if(result) break;
				v0 = v1;
			}
		}
		return result;
	}

	private int normalParts(int delegate(ref Vertex[] x) dg)
	{
		int result;
		uint v0, v1;
		
		while(v1 < verts.length)
		{
			v1++;
			if(v1 == verts.length || !verts[v1].norPart)
			{
				auto t = verts[v0..v1];
				result = dg(t);
				if(result) break;
				v0 = v1;
			}
		}
		return result;
	}

	//Update split position attributes.
	void updateGeometricParts()
	{
		foreach(parts; &geometricParts)
			foreach(uint i, ref v; parts) //at one point I forgot to put 'ref' here
				if(i) v.pos = parts[0].pos; //that was a fun half hour
	}

	//Update split UV attributes.
	void updateUVParts()
	{
		foreach(parts; &geometricParts)
			foreach(uint i, ref v; parts)
				if(!v.uvPart)
					foreach(other; parts)
						if(other.uvPart && other.uvGroup == v.uvGroup)
							other.uv = v.uv;
								//a curly brace mocked me once
	} //only once

	void updateTriangulation()
	{
		foreach(section; sections)
		{
			//Quadrilaterals: Split on shortest edge
			if(section.type == 4)
			{
				foreach(face; &section.faces)
				{
					//TODO do a thing
					//..wait, why not put this in the Face struct? updateTriangulation.
				}
			}

			if(section.type > 4)
			{
				//TODO do lots of things
			}
		}
	}

	///Returns the distance of the vertex farthest from the mesh origin.
	@property double radius()
	{
		double d = 0.0;

		foreach(v; verts)
		{
			double d2 = v.pos.lengthSquared;
			if(d2 > d) d = d2;
		}

		return sqrt(d);
	}

	override void pack(P!Stream s) const
	{
		//s.write(verts);
		//s.write(tris);
		//s.write(quads);
		//s.write(groups);
		//s.write(ranges);
	}

	override void unpack(P!Stream s)
	{
		string header = s.read!(char[8]);
		if(header != "MESH0001")
			throw new MeshException("Bad header. Expected MESH0001, found '" ~ header ~ "'");
		//I don't really think a version number will ever be useful, it's just a precaution

		s.read(verts);

		tris.length = s.read!uint; //Tricount hint

		uint cursor;
		s.read(sections, P!Mesh(this), cursor);

		cursor = 0;
		s.read(pages, P!Mesh(this), cursor);

		//Make data consistent
		updateGeometricParts;
		updateTriangulation;
		updateUVParts;
		updateNormals;
	}

	override uint estimatePack() { return 0; }
}

final class MeshException : Exception
{ import raider.tools.exception; mixin SimpleThis; }

/*
 * Regarding geometrically defined vertices...
 *
 * The OpenGL defines a vertex as a vector of attributes, including 
 * position, normal, color and position in texture space. If any of 
 * these attributes change, it is considered a different vertex.
 * 
 * However, it is often desireable to define a vertex by
 * position only (a 'geometric' vertex) and attach attributes 
 * to the faces connecting them instead.
 * 
 * An example is texture mapping, where neighbouring faces can 
 * have different UV coordinates at the same vertex. 
 * 
 * To submit geometric vertices, it is necessary to create and 
 * track additional vertices with the same position. I refer to
 * these as 'partial vertices' or 'parts'.
 * 
 * To keep track of them, they are lumped together in the 
 * vertex stream. The 'part' flag is used to indicate a vertex
 * inherits its position from the last unflagged vertex.
 * 
 * The 'norPart' flag behaves the same, indicating the vertex
 * is part of a contiguous group of vertices contributing to and
 * sharing the same normal vector. These are always sub-groups
 * within the group of geometric parts.
 * 
 * The 'uvPart' flag behaves similarly, but the groups are not
 * necessarily contiguous. Instead, a 5-bit 'uvGroup' field 
 * describes which group a part belongs to. This makes uv parts
 * more expensive to reassemble, but normal groups are used more 
 * intensively, so they take priority.
 * 
 * Algorithms that modify shared vertex attributes can process the first
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

/* 13-9-2016
 * Regarding triangulation of faces (aka polygons)...
 * 
 * GL_QUADS (the constant responsible for passing quad primitives
 * to OpenGL) has been deprecated as of 3.x. This improves the API
 * because it restricts it to dealing with unambiguous triangles.
 * 
 * Rest in pieces, GL_QUADS.
 * 
 * On the faces of things, this makes our job a little harder.
 * Instead of four verts and four indices, we have to send four 
 * verts and six indices, and maintain this triangulation when
 * the mesh changes. New questions of performance arise.
 * 
 * Because 'normal' normal calculations find a single normal per 
 * face and add it to all verts (as here and in Blender), the 
 * look of a triangulated non-planar face changes slightly if 
 * we treat the triangles as individual faces. This is simpler
 * in code, but subtly breaks WYSIWYG with Blender. We need to 
 * choose which approach to take.
 * 
 * Both will be profiled; if finding one normal for each face
 * has reasonably similar performance to finding one normal for
 * each triangle, we'll prefer the former.
 * 
 * I note my driver implements quad triangulation equivalent to
 * Blender's 'Fixed' method - splitting across vertices 1 and 3.
 * We have an opportunity to improve on this by splitting across
 * the shortest diagonal (the simplest dynamic triangulation) to
 * get better-looking deformations and concave quads.
 * 
 * As for the question of supporting quads, they're indispensable.
 * Supporting the general case of n-gons is a happy bonus.
 */

/* 20-9-2016
 * Regarding faces..
 * 
 * You will notice the Face struct isn't actually stored anywhere.
 * It's a transient struct, created by the section.faces delegate.
 * 
 * Note that face has the face.verts delegate, which must yield
 * the vertex indices of the face's edge loop, in winding order.
 * However, this loop isn't stored anywhere either!
 * 
 * Tris belonging to the same face are grouped together in the
 * tri stream. mesh.sections remembers where they start and end.
 * These grouped triangles are stored in a way that allows fast 
 * reconstruction of the edge loop.
 * 
 * 1. Tris are rotated so the first edge shared with the loop
 * (in winding order) comes first.
 * 2. Tris are sorted according to their order of appearance
 * in the loop. (Interior tris come last.)
 * 
 * By comparing one tri to the next, it is trivial to identify the 
 * interior edges and follow the exterior loop.
 * 
 * No constraint is placed on where the edge loop starts. The tris
 * with exterior edges can be shuffled around as long as they stay
 * in winding order.
 */
