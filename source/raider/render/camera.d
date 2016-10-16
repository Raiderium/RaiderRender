module raider.render.camera;

import raider.render.gl;
import std.math;
import raider.math;

/*
 * Invisible floating eye.
 */
final class Camera
{public:
	vec3 position;              /// Position in world space.
	mat3 orientation;           /// Orientation in world space. Camera points along -Z.
	vec2 orthographicScale;     /// Width and height of the orthographic projection frustum.
	double fov;                 /// Field-of-view.
	double aspect;              /// Aspect ratio.
	double near;               	/// Distance of near clipping plane.
	double far;                	/// Distance of far clipping plane.

public:
	this()
	{
		position = vec3(0,0,1);
		orientation = mat3.identity;
		orthographicScale = vec2(1, 1);
		fov = 60;
		aspect = 4.0/3.0;
		near = 0.1;
		far = 500;
	}

	@property static modelTransform(mat4 value)
	{
		glMatrixMode(GL_MODELVIEW);
		glPopMatrix(); glPushMatrix(); //Copy the inverse camera matrix
		glMultMatrixd(value.ptr); //Multiply by transform
	}

	void bind(double viewportAspect)
	{
		//Update inverse camera matrix
		glMatrixMode(GL_MODELVIEW);
		glPopMatrix();

		mat4 m = mat4(orientation, position);
		m.invertAffine;
		glLoadMatrixd(m.ptr);

		glPushMatrix();

		//Update projection matrix
		if(fov != 0.0)
		{
			double fW, fH;
			fH = fW = tan(fov/360*PI) * near;
			fW *= aspect*viewportAspect;
			glMatrixMode(GL_PROJECTION);
			glLoadIdentity();
			glFrustum(-fW, fW, -fH, fH, near, far);
		}
		else
		{
			//TODO Orthographic projection matrix setup
		}
	}

	/**
	 * Test a bounding sphere against the camera frustum.
	 * 
	 * Returns true if any part of the sphere is visible.
	 */
	bool test(vec3 position, double radius)
	{
		//This checks if any part of the sphere occupies space in front of the camera.
		vec3 pos = position - this.position;
		double dot = pos.dot(orientation[2]);
		return (dot - radius) < 0.0;
		//TODO Six-plane frustum intersection check.
		//For each model, start by checking the plane that excluded it in the previous frame.
	}
}
