module raider.render.light;

enum LightType
{
	Point,
	Spot,
	Hemisphere,
	Area
}

/**
 * Invisible floating whale-oil lantern.
 */

final class Light
{
	//TODO Implement lights. They're sort of like meshes but topographically simpler and less spiky.
}

/* A thought:
 *
 * Shadow mapping works by each fragment testing a depth map to see if there's anything between them and
 * the light source. Since the map is rendered from the light's perspective, there's only one point on
 * the map that is perspective-correct from each fragment's point of view - the one directly between it
 * and the light. Sampling this fragment is trivial.
 *
 * However, to get soft shadows we need to sample more of the object, to see how much of the light source
 * is obscured. Rendering the scene from the fragment's perspective is too expensive, but we can't just
 * sample the shadow map - to be correct it must be un-projected and re-projected, a complex task with
 * rasterised pixels. But perhaps correctness is overrated?
 *
 * From the shadow's perspective, distant shadow casters move across the light source like an eclipse.
 * No depth; just a flat shape. The task of un-projecting and re-projecting the depth map from each
 * fragment's perspective can feasibly be ignored in this situation; and for others, a noisy, adaptive
 * algorithm can at least approach a solution.
 *
 * So let's say, for each caster, we draw it from the light's perspective. Each light has an atlas texture
 * and it sizes/packs each caster's map according to some approximate weighting based on required quality.
 * Since we only generate depth values within the extent of the object, there can be fewer bits-
 * say one byte per pixel, 0 representing infinite depth, 1 the furthest depth, and 255 the closest.
 *
 * Note that concave terrain should be specified as a non-caster, and other bits should have a low
 * quality hint, otherwise they'll dominate the atlas. ..Unless the quality is dependent on facecount?
 * That could work.
 *
 * Anyway.
 *
 * In the light sorting phase where we find the lights that most strongly affect a given model,
 * we also find casters that might affect the model, through cheap bounding sphere checks.
 *
 * Then, in the fragment shader, we start by sampling the central point of the light. This gives
 * us an idea of how far away /most/ of the samples around that point will be. Then we begin
 * sampling around it. To un-project and re-project, we assume each sample has the same depth as
 * those already taken around it; if not, that is the measure of the error of the algorithm,
 * however we can't afford to discard the sample, so if it obscures the light, it obscures it.
 *
 * What this means in practice is that if the central sample is very close to the light, and thus
 * appears 'big' from its perspective, samples taken around it will read points on the depth map
 * that spread out quickly as a result of inverting the perspective.
 *
 * Sampling noise can help reduce perception of error. Objects that need dedicated shadow quality
 * can carry their own maps; the highest priority lights will render to these first instead of
 * finding space on their atlas.
 *
 * This entire process can be pipelined between the CPU and GPU. While the CPU sorts lights
 * and packs atlasses, one thread can be informed of finished work, and invoke the GPU to
 * generate depth maps. As the GPU will be the bottleneck, this can make use of more powerful
 * (and mercifully simpler) inter-thread communication tools.
 */
