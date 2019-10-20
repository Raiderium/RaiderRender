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

@RC class Bones
{
	Array!Bone v;
}

@RC class BoneTransforms
{
	Array!BoneTransform v;
}

@RC class Groups
{
	Array!Group v;
}

/**
 * A hierarchy of named transformations.
 */
@RC class Armature
{
	//R!BoneTransforms transforms;

	this()
	{
		//..
	}

	void doConstraints()
	{
		//um
	}
}

@RC class Binding
{
	R!Bones bones;
	R!Groups groups;
	//Array!uint links;
}


R!Binding bind(R!Bones bones, R!Groups groups)
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

	/*
	 * The purpose of the system stack is to facilitate function
	 * calls. Its depth is sufficient for function calls. It is
	 * optimised for function calls. It is used for function calls.
	 *
	 * It is not for algorithm semantics.
	 *
	 * If it were possible to create stacks on the heap - to control
	 * the memory as an object, to be able to hold it in your hand,
	 * catch exceptions from it, configure it and provide guarantees
	 * regarding it - if the recursion happened in userspace, as a
	 * tool with syntactic sugar - or if the language automatically
	 * allocated on the heap and was tuned to support recursion -
	 * then I would call it the Right Solution.
	 *
	 * But recursion with the system stack feels fraudulent, to me.
	 * It has no robustness. It shouts 'look what I can do'. It's a
	 * forkbomb. It's a hack. It's like saying, 'the system has a
	 * while loop here. I will use that instead of making my own'
	 * or 'the system has a chunk of memory here. I will use that
	 * instead of making my own' or 'the system has a stack here...'
	 */
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
