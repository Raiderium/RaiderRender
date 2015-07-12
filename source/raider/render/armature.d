module raider.render.armature;

import raider.math.mat;
import raider.render.mesh;
import raider.tools.array;
import raider.tools.reference;

struct Bone
{
	string name;
	Bone* parent;
}

struct BoneTransform
{
	mat4 local; //Relative to parent
	mat4 pose; //Relative to armature root
}

/**
 * A hierarchy of named transformations.
 */
class Armature
{
	R!(Array!Bone) bones;
	R!(Array!BoneTransform) transforms;

	this()
	{
		//..
	}

	void doConstraints()
	{
		//um
	}
}

class Binding
{
	R!(Array!Bone) bones;
	R!(Array!Group) groups;
	Array!uint links;
}

R!Binding bind(R!(Array!Bone) bones, R!(Array!Group) groups)
{
	R!Binding binding = New!Binding();
	binding.bones = bones;
	binding.groups = groups;

	return binding;
}

void deform(R!Mesh mesh, R!Mesh dest, R!Armature armature, R!Binding binding)
{
	//assert(armature.bones is binding.bones);
	//assert(mesh.groups is binding.groups);
	//assert(dest.groups is binding.groups);

	//Do deformation!
}

//void deform(R!Armature armature, R!Armature dest, animation stuff)

/* Miscellaneous ramblings
When a bone transform is changed, a flag is set that indicates 
children are invalid. Getting pose transform requires recursion 
into parents. Must find deepest flagged parent and recalculate.

How to armature:
1. Load mesh.
2. Load armature.
3. Create poseable mesh linking attributes with the first, except for vert position.
4. Ditto for the armature and bone transform.
5. Create binding from vertex groups to bones.
6. Deform poseable armature with animations.
7. Deform poseable mesh with armature and binding.
*/

