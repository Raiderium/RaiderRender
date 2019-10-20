module raider.render.gi;

/++
ILLUMINATION AND IMAGE PROCESSING
20/20/2019

There's an opportunity here. Modern engines have a problem, in that they're expected to support
high polygon counts while simultaneously making them look good. The fastest techniques are used,
usually limited to screen-space algorithms requiring tremendously complex shaders that achieve
results hampered by artifacts. All of these stacked together - motion blur, antialiasing, ambient
occlusion, reflective and indirect lighting - are becoming a standard package, noxious to artists.

Screen-space motion blur struggles to give good results; it always has. Aside from developers
abusing the actual blurring factor, gamers frequently disable it because artifacts around
overlapping objects and lights damage the effect. They prefer a clean, stable image.

There are many AA techniques, some better than others. All are motivated by performance concerns.
FXAA is acceptable given its low cost, SMAA is also acceptable, MSAA prohibits sharp texture
transparencies (ubiquitous in foliage), SSAA is 'true' AA but costly. As for temporal methods,
I'm not going to temper my disgust. Temporal antialiasing is hot garbage. Monitor manufacturers
have worked hard for decades to make pixel smearing a thing of the past, and we're going to add
it back in with software? The wikipedia page has 'factual accuracy is disputed' on it. Good grief.

Screen-space ambient occlusion and reflections are similar to motion blur. They only work when the
pixels they require are visible, and if not used in appropriate situations, their usage is very
apparent and unpleasant. Again, a stable image is preferable if the techniques are used poorly.

Indirect lighting is usually done with probes, and it's decent. I can't fault techniques that
attempt to reduce the computational cost of global illumination, or simply choose to ignore
it and stick with baked results, because the real thing is incomprehensibly intensive.

Modern games are pushing so many primitives it's become nearly impossible to perceive them; which
is certainly an achievement, but it comes at the cost of everything else. Polycount is nice, but
art direction is better. Wind Waker still looks amazing. So does Mirror's Edge.

SO.

As an alternative to pushing polygons then meekly applying image-based effects, RaiderEngine takes
two big hits to performance, and tries to extract the maximum amount of visual niceness from each.
If not better, it will at least be different.

The first is: it renders the scene multiple times and accumulates the result. This allows 'true'
implementation of motion blur, antialiasing, depth of field and soft shadows, with obvious but
comparatively less offensive artifacts that can be reduced by increasing the number of samples.

The second is: a near-realtime radiosity system. You might call it 'half-baked' radiosity; a static
lighting algorithm that can update fast enough for slow-moving emitters like the sun, incrementally
updating lightmaps instead of streaming them from storage. This also reduces the size of the game.

In-game lighting calculations support in-game player-generated content, not just static environments.
Any light that remains unmoving relative to a mesh, can have its lightmaps baked - such as interior
lights on a vehicle, or lamps placed on the ground, etc. A dynamic lighting solution substitutes for
moving lights and temporarily for bakeable lights until the first lightmap is complete.

Now, briefly, consider the difference between Mirror's Edge, and Mirror's Edge: Catalyst. The first
used a lot of baked lighting and had many diffuse surfaces, like concrete. This video elaborates:
https://www.youtube.com/watch?v=2TNSaEJHBrQ

The second was set in the City of Glass, and accordingly, featured realtime screen-space reflections
much more than diffuse surfaces. My opinion is that the baked radiosity made better use of available
resources. Reflective surfaces are nice, but I think radiosity has a greater impact on the perceived
quality of a room. And besides, it's all too easy to break the reflection effect.

--- Notes on implementation ---

The basic technique is to render the scene from the perspective of a light-receiving texel and sum
the irradiant light. Once this is done for all lightmaps, it can be repeated to simulate a second
bounce, then a third, etc. However, because work must be focused around the area of the viewer, it
will be necessary to repeat the bounces at differing levels of detail, refining adaptively.
Not sure how errors will manifest. High-detail work done when surrounds are still low-detail..?
It's all a bit unclear.

Gathering irradiant light
Drawing the hemispherical scene visible from a surface point requires non-linear projection to a
hemisphere, which is nontrivial when computers prefer linear projection. The simplest option is
five linear projections, generating five faces of a cubemap. The pixels must then be multiplied
by certain factors to remove distortion. Frustum culling can be optimised so that it costs less
than five independent culls. (May also benefit from multiple threads.)

Another option is a single wide-angle projection, taking in at most ~80% of the scene. This can
be 'tilted' toward parts of the scene known to emit more light. Particularly on the first gather,
we can zoom in on lights and portals to outside when indoors. CPU analysis of structure is key.

It is imperative to cull and draw the scene quickly. No textures on the first run, and as much
culling of non-interposed dark objects as possible. For objects that remain static relative to
each other, it might be useful to keep lists of visible objects, to avoid checking them unless
they move. A list could include all objects visible from a region of texels, not just one.

Parallax interpolation
Rather than perform a full gather at every texel, we can get accurate results at a few texels
then interpolate. This doesn't have to be a simple linear interpolation of the total irradiance;
instead, we consider the four nearby rendered scenes and morph between them using cheaper image
processing techniques.

In the current theory, the rendered scene is broken into multiple parallax layers, each covering
a range of pixel depths. Then, shifting these layers according to their depth permits a shader
to crudely reproduce the scene as seen by each texel. To do this without storing the layers,
the shader shifts the rendered scene, and checks the depth. To avoid sampling layers known to
be empty, the full gather is analysed (as it must be to find total irradiance) and the range of
utilised depths is found and subdivided. This analysis must find isolated ranges and produce a
layer for them with a precise depth. Sometimes, there may be only two layers - the light, and
an object passing in front of it. Additionally, lights may be rendered to a separate target to
allow accurate 'revealing' of them as dark objects pass in front.

Summing bounces
Unless I'm mistaken, two additional lightmaps are required when baking. We start with light
emitters on the first lightmap. A second lightmap receives the first bounce, and adds to the
final output on a third. We clear the first and use it to receive the second bounce, with the
second lightmap now acting as emitter.

Alternatively, we can have two textures and only two bounces.

Caching
Valid lightmaps need not be discarded when no longer needed. Download from GPU and store in
fixed-size RAM cache. Could also evict to disk for later reuse, but that's probably unnecessary.
In a linear map, lighting should capable of buffering ahead. Otherwise, loading hallways have
new purpose..

Realtime substitution
The realtime lighting must, at infinite quality, match the near-realtime's direct lighting at
infinite quality, as closely as possible. This will be difficult, because realtime shadows are
normally subtracted from a lit scene, while lightmaps are additive. There may be some wisdom
to translating the results of shadow mapping into a lightmap, to simplify the pipeline.

lightmaps would then roam through the scene, adding their contribution without touching
fixed maps. Dynamic lights would receive additional bounces whenever they sat reasonably still,
and the dynamic shadow updates would cease, leaving the latest results in the lightmap. This
would blur the line between dynamic and fixed lighting, automatically switching between them.

Remember to use a physical basis for all lighting calculations. A texture cannot simply emit an
RGB light level - it must be mapped to a physical luminance range.

Realtime omission
We may even omit realtime shadows, in favour of scrambling to get a low-detail lightmap. However,
the system is unlikely to be so generously performant on low-end hardware.


Static world lightmaps should be generated without moving objects. If the sun is fixed, they
are known to be valid.

Separate lightmaps can be used for dynamic changes to static light properties. This is important
for interior lights that might flicker or change colour independently.

Lightmap UV generation
A problem that must be solved. We cannot, ever, ask the artist to create UV maps for lighting.
++/
