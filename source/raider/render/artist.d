module raider.render.artist;

import derelict.opengl3.gl;
import raider.tools.reference;
import raider.tools.array;
import raider.render.mesh;
import raider.render.model;
import raider.render.camera;
import raider.render.window;
import raider.render.light;
import raider.render.material;
import core.sync.mutex;
import std.bitmanip;

/**
 * Draws models.
 * 
 * The artist collects models and lights to draw, does a 
 * frustum check, generates a lighting list, sorts the
 * models, then draws the scene to a window.
 */
class Artist
{public:
	R!Window window;
	R!Camera camera;

private:
	Array!ModelProxy models;
	Array!LightProxy lights;
	Mutex mutex;

	struct ModelProxy
	{
		this(Model model)
		{
			this.model = P!Model(model);
		}

		P!Model model;
		union
		{
			uint flags = 0;
			mixin(bitfields!(
			uint, "z", 6,
			uint, "texture", 10,
			uint, "", 16));
		}
	}

	struct LightProxy
	{
		P!Light light;
		union
		{
			uint flags = 0;
			mixin(bitfields!(
			uint, "z", 6,
			uint, "", 26));
		}
	}

public:

	bool add(Model model)
	{
		if(camera.test(model.position, model.radius))
		{
			ModelProxy proxy;
			proxy.model = P!Model(model);
			proxy.z = model.z;
			synchronized(mutex) models.add(proxy);
			return true;
		}
		else return false;
	}

	void draw()
	{
		synchronized(mutex)
		{
			for(uint x = 0; x < models.size; x++)
			{
				Model model = models[x].model;
				Mesh mesh = model._mesh;

				uint rangeMin = 0;
				foreach(uint y, uint rangeMax; mesh.materialRanges)
				{
					if(y < model.materials.length) model.materials[y].bind();
					uint f0 = rangeMin;
					uint f1 = rangeMax;
					assert(f0 < f1 && f0 < mesh.tris.length && f1 <= mesh.tris.length);
					TriFace[] f = mesh.tris[f0..f1];

					glInterleavedArrays(GL_T2F_N3F_V3F, Vertex.sizeof, mesh.verts.ptr);
					glDrawElements(GL_TRIANGLES, f.length*3, GL_UNSIGNED_INT, f.ptr);

					rangeMin = rangeMax;
				}
			}
		}

		window.swapBuffers;
		glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
	}
}

/* 
 * 
 * For cameras
 *   Clear draw list
 *   Test frustum against world
 *     At entity spaces, switch entity parity (if unswitched)
 *     At models, set LOD (dirty = true if old value is different, and always if time has changed) and add to draw list
 * 
 *   Set draw list minimum capacity to current size
 *   (Occasionally allow it to reduce?)
 * 
 *   For entities
 *     Pose switched entities
 *   
 *   Find 8 most influencing lights per model
 */


//If smarter LOD is implemented we need the minimum distance to a model from a camera
//Divide frustum into aabb hierarchy - may speed collision, also finds LOD

//Give each entity a space geom for models. In most cases this produces a lovely hierarchy
//Automatic decimation LOD may be quite feasible - just change the face connectivity.