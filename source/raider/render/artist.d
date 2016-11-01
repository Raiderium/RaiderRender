module raider.render.artist;

import raider.tools.reference;
import raider.tools.array;
import raider.render;

import raider.math;

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
	R!Window window; //TODO Replace with a 'Surface' to support off-screen drawing.
	R!Camera camera;

private:
	Array!ModelProxy models;
	Array!LightProxy lights;
	//Array!Material materials; //Build this list from matching model materials
	Mutex mutex;

	struct ModelProxy
	{
		this(Model model)
		{
			this.model = P!Model(model);
			z = model.z;
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

	this()
	{
		mutex = new Mutex();
		models.cached = true;
		lights.cached = true;
	}

	/**
	 * Add a model to be drawn.
	 * 
	 * Compares the camera frustum to a model's bounding
	 * sphere and returns the result. If true, the model
	 * is scheduled for render, and the user should make
	 * expensive updates to its appearance.
	 * 
	 * Pass force=true to skip the test.
	 * 
	 * This method is thread-safe.
	 */
	bool add(Model model, bool force = false)
	{
		if(force || camera.test(model.position, model.radius))
		{
			ModelProxy proxy = ModelProxy(model);
			synchronized(mutex) models.add(proxy);
			//Use concurrent bag.
			return true;
		}
		else return false;
	}

	void draw()
	{
		synchronized(mutex)
		{
			window.bind;
			camera.bind(window.viewportAspect);
			
			for(uint x = 0; x < models.size; x++)
			{
				auto model = models[x].model;
				auto mesh = model._mesh;
				Camera.modelTransform = model.transform;

				foreach(i, page; mesh.pages)
				{
					if(i < model.materials.length)
						model.materials[i].bind;

					glInterleavedArrays(GL_T2F_N3F_V3F, Vertex.sizeof, mesh.verts.ptr);
					glDrawElements(GL_TRIANGLES, page.tris.length*3, GL_UNSIGNED_INT, page.tris.ptr);
				}
			}
		}
	}

	void clear()
	{
		models.clear;
		lights.clear;
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
