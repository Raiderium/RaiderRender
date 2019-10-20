module raider.render.webp;

import core.thread : Fiber;
import raider.tools.array;
import raider.tools.huffman : Tree;
import raider.tools.stream;
import raider.tools.reference;
import raider.render.texture;
import std.conv : to, hex = hexString;

final class WEBPException : Exception
{ import raider.tools.exception : SimpleThis; mixin SimpleThis; }

alias EX = WEBPException;

/* This is the WebP Lossless (VP8L) subformat.
 *
 * The decoder is a Fiber that yields after reading the header and then at regular intervals.
 * If a destination texture is not provided, it terminates after reading the header.
 */
 
//Ceiling of value / 1<<bits.
uint bs(uint value, uint bits) { return (value + (1 << bits) - 1) >> bits; }
//Called block_xsize by the spec, which is a misnomer - it's the number of blocks, not their size (which is 1<<bits).

alias Group = Tree[5];
enum TransformType { Predictor, Colour, SubtractGreen, ColourIndexing }
struct Transform { TransformType type; Array!Pixel data; uint bits; }

//TODO: Derived ImageFiber.
Array!Pixel load(Stream s, ref uint _width, ref uint _height)
{
	//Read header
	if(s.read!(ubyte[4]) != "RIFF") throw new EX("Not a RIFF");
	auto blockSize = s.read!uint; //Should be filesize - 8
	if(s.read!(ubyte[8]) != "WEBPVP8L") throw new EX("Not a lossless WebP (WEBP-VP8L)");
	auto chunkSize = s.read!uint;
	if(s.read!ubyte != 0x2F) throw new EX("Bad VP8L signature");
	uint width = s.readb!uint(14) + 1, height = s.readb!uint(14) + 1;
	bool alphaHint = s.readb!bool;
	if(s.readb!ubyte(3)) throw new EX("Bad (non-zero) VP8L version number");

	//Fiber.yield; //check if inside fiber, or else this faults

	Transform[4] transforms;
	uint tnum; //The number of transforms (and a convenient insertion index)
	ubyte[4] seen; //Only one of each type of transform is allowed (in any order).
	uint pbits; //Pixel packing bits. Colour indexing, if present, changes this to 1, 2 or 3.

	//Read transforms
	while(s.readb!bool)
	{
		TransformType type = cast(TransformType)s.readb!uint(2);
		if(seen[type]++) throw new EX("Transform type '" ~ to!string(type) ~ "' used more than once");
		Transform* t = &transforms[tnum++]; t.type = type;

		if(t.type == TransformType.Predictor || t.type == TransformType.Colour) {
			t.bits = s.readb!uint(3) + 2; //Size bits
			t.data = readPixels(bs(bs(width, pbits), t.bits), bs(height, t.bits), false, 0, s); } //Colour transform elements

		if(t.type == TransformType.ColourIndexing) {
			uint cnum = s.readb!ubyte(8) + 1; //Colour table size
			pbits = (cnum > 16) ? 0 : (cnum > 4) ? 1 : (cnum > 2) ? 2 : 3;
			t.data = readPixels(cnum, 1, false, 0, s); //Read colour table
			foreach(i, ref p; t.data[1..$]) p += t.data[i]; } } //Apply delta coding


	//Read transformed pixels.
	auto pixels = readPixels(width, height, true, pbits, s);

	//Invert transformations
	defilter(width, height, pixels[], transforms[0..tnum], pbits);

	//Return image
	_width = width;
	_height = height;
	return pixels;
}

void defilter(uint unfiltered_width, uint h, Pixel[] data, Transform[] transforms, ref uint pbits)
{
	if(unfiltered_width * h == 0) return;

	foreach_reverse(i, ref t; transforms) {
		uint w = bs(unfiltered_width, pbits); //When pbits is 0, w is the true width of the image.
		Pixel[] o = data[$-w*h..$]; //Until pixels are unpacked, w is the packed width.

		if(t.type == TransformType.Colour) {
			uint mask = (1 << t.bits) - 1, tpr = bs(w, t.bits);
			for(uint y, p; y < h; y++) { auto c = &t.data[(y >> t.bits) * tpr];
				for(uint x; x < w; x++) { if(x && (x&mask) == 0) c++;
					ubyte r = o[p].r, g = o[p].g, b = o[p].b;
					r += cast(byte)c.b * cast(byte)g >> 5;
					b += cast(byte)c.g * cast(byte)g >> 5;
					b += cast(byte)c.r * cast(byte)r >> 5;
					o[p].r = r; o[p].b = b; p++; } } }

		else if(t.type == TransformType.ColourIndexing) {
			uint xmask = (1 << pbits) - 1, vmask = (1 << (8 >> pbits)) - 1, bpps = 3-pbits;
			for(uint y, p, l; y < h; y++, l += w)
				for(uint x; x < unfiltered_width; x++)
					data[p++] = t.data[o[l + (x>>pbits)].g >> ((x&xmask) << bpps) & vmask];
			pbits = 0; }

		else if(t.type == TransformType.Predictor) {
			uint mask = (1 << t.bits) - 1, tpr = bs(w, t.bits), p = 1;
			o[0].a += 0xFF; while(p < w) o[p] += o[p++-1]; //First row has fixed modes 0111..111

			for(uint y = 1; y < h; y++) { //For each row after the first
				o[p] += o[p-w]; p++; //Leftmost pixel is mode 2 (T)
				uint pmode = t.data[tpr*(y >> t.bits)].g & 0x0F; //Initialise prediction mode (x = 0 is skipped)

				for(uint x = 1; x < w; x++) { //For each pixel after the first
					if((x&mask) == 0) //Update prediction mode on crossing block boundaries
						pmode = t.data[tpr*(y >> t.bits) + (x >> t.bits)].g & 0x0F;
					Pixel predictor;
					switch(pmode) {
						case 0: predictor.a += 0xFF; break;  //0 0 0 1
						case 1: predictor = o[p-1]; break;   //L
						case 2: predictor = o[p-w]; break;   //T
						case 3: predictor = o[p-w+1]; break; //TR
						case 4: predictor = o[p-w-1]; break; //TL
						case 5: predictor = avg(avg(o[p-1], o[p-w+1]), o[p-w]); break; //avg(avg(L, TR), T)
						case 6: predictor = avg(o[p-1], o[p-w-1]); break; //avg(L TL)
						case 7: predictor = avg(o[p-1], o[p-w]); break;   //avg(L  T)
						case 8: predictor = avg(o[p-w-1], o[p-w]); break; //avg(TL T)
						case 9: predictor = avg(o[p-w], o[p-w+1]); break; //avg(T TR)
						case 10: predictor = avg(avg(o[p-1], o[p-w-1]), avg(o[p-w], o[p-w+1])); break; //avg(avg(L, TL), avg(T, TR))
						case 11: { Pixel u = o[p-w], l = o[p-1], c = o[p-w-1]; //select(L, T, TL)
							int pl = abs(c.r - u.r) + abs(c.g - u.g) + abs(c.b - u.b) + abs(c.a - u.a);
							int pt = abs(c.r - l.r) + abs(c.g - l.g) + abs(c.b - l.b) + abs(c.a - l.a);
							predictor = pl < pt ? l : u; break; }
						case 12: predictor = casf(o[p-1], o[p-w], o[p-w-1]); break;      //casf(L, T, TL)
						case 13: predictor = cash(avg(o[p-1], o[p-w]), o[p-w-1]); break; //cash(avg(L, T), TL)
						default: throw new EX("Bad prediction mode");
					} o[p++] += predictor; } } }

		else if(t.type == TransformType.SubtractGreen)
		foreach(ref p; o) { p.r += p.g; p.b += p.g; } }
}

auto abs(int a) { return a < 0 ? -a : a; }
auto avg(in Pixel a, in Pixel b) { return cast(Pixel)((((a.v ^ b.v) & 0xFEFEFEFE) >> 1) + (a.v & b.v)); }
ubyte clamp(int a) { return a < 0 ? 0 : (a > 255) ? 255 : cast(ubyte)a; }

auto casf(in Pixel a, in Pixel b, in Pixel c) {
	Pixel o;
	o.r = clamp(a.r + b.r - c.r);
	o.g = clamp(a.g + b.g - c.g);
	o.b = clamp(a.b + b.b - c.b);
	o.a = clamp(a.a + b.a - c.a);
	return o; }

auto cash(in Pixel a, in Pixel b) {
	Pixel o;
	o.r = clamp(a.r + (a.r - b.r) / 2);
	o.g = clamp(a.g + (a.g - b.g) / 2);
	o.b = clamp(a.b + (a.b - b.b) / 2);
	o.a = clamp(a.a + (a.a - b.a) / 2);
	return o; }

//This helps translate distance codes to actual distances
immutable dcp = cast(ubyte[120])hex!"
				1807171928062729161A262A38053739151B363A252B48044749141C353B464A242C58454B343C03
				5759131D565A232D444C555B333D68026769121E666A222E545C434D656B323E78017779535D111F
				646C424E767A212F757B313F636D525E00747C414F1020626E30737D515F40727E616F50717F6070";

Array!Pixel readPixels(uint w, uint h, bool meta, uint pbits, Stream s)
{
	typeof(return) output; output.size = w*h;

	//If pixels are packed, we store the smaller image at the end of the output.
	if(meta) w = bs(w, pbits);
	auto o = output[$-w*h..$];

	//Colour cache
	uint cbits, cshift; Array!Pixel cache; //Cache bits, cache shift, and the cache itself
	if(s.readb!bool) { cbits = s.readb!uint(4);
		if(cbits < 1 || 11 < cbits) throw new EX("Bad colour cache size bits");
		cshift = 32 - cbits; cache.size = 1 << cbits; }

	//Huffman groups
	uint hbits; Array!Pixel hpix; //Huffman bits (meta-huffman tile size), entropy image
	auto groups = readHuffgroups(w, h, cbits, meta, hbits, hpix, s); //Fills hbits and hpix if meta == true
	uint mask = (1 << hbits) - 1; //Huffman group mask
	uint tpr = bs(w, hbits); //Tiles per row
	Group* group = &groups[0];

	for(uint x, y, p, p0; p < o.length;) {

		//Update huffman group on crossing block boundaries (or after back-reference copy)
		if(hbits && (((x&mask) == 0) || p-p0 != 1)) group = &groups[hpix[tpr*(y >> hbits) + (x>>hbits)].v];

		if(cbits) //Update cache
		foreach(rgba; o[p0..p]) {
			uint argb = rgba.r << 16 | rgba.g << 8 | rgba.b | rgba.a << 24;
			cache[(argb*0x1E35A7BD) >> cshift] = cast(Pixel)argb; }

		p0 = p; auto green = (*group)[0].next(s);

		if(green < 256) { //Literal
			o[p++].v =  (*group)[1].next(s) | green<<8 | (*group)[2].next(s)<<16 | (*group)[3].next(s)<<24;
			if(++x == w) { x = 0; y++; } }

		else if(green < 280) { //Back reference
			uint prefix(uint sy) { return sy < 4 ? sy + 1 : (((2+(sy&1)) << ((sy-2)>>1)) + s.readb!uint((sy-2)>>1) + 1); }
			uint l = prefix(green - 256); //Number of copied pixels
			uint dc = prefix((*group)[4].next(s)); //Distance code
			int d; if(dc > 120) d = dc - 120; //Turn distance code into a distance
			else { d = (dcp[dc-1] >> 4) * w + 8 - (dcp[dc-1] & 15); if(d < 1) d = 1; }
			if(o.length < p+l || p<d) throw new EX("Bad back reference");
			foreach(i; p..p+l) o[i] = o[i-d]; //Copy previous pixels
			p += l; x += l; while(x >= w) { x -= w; y++; } }

		else { //Colour cache lookup
			if(!cbits) throw new EX("Cache used when not initialised");
			if(green - 280 > cache.size) throw new EX("Bad colour cache reference");
			Pixel argb = cache[green - 280];
			o[p++] = Pixel(argb.b, argb.g, argb.r, argb.a);
			if(++x == w) { x = 0; y++; } }
	} return output;
}

Array!Group readHuffgroups(uint w, uint h, uint cbits, bool meta, ref uint hbits, ref Array!Pixel hpix, Stream s)
{
	ushort ngroup; //Number of meta huffman codes
	if(meta) { //If meta, pixel data is storing actual RGBA pixels, which can use meta huffman codes
		if(s.readb!bool) { //If true, image uses multiple meta huffman codes, stored as an 'entropy image'.
			hbits = s.readb!uint(3) + 2; //Otherwise, image uses only one group, and no entropy image.
			hpix = readPixels(bs(w, hbits), bs(h, hbits), false, 0, s);
			foreach(ref i; hpix) { i.v = i.r << 8 | i.g; if(ngroup < (i.v&0xFFFF)) ngroup = i.v&0xFFFF; } } }

	//The maximum memory consumption here is 2**16 * sizeof(Tree[5]), which is approximately 16mb on 32-bit.
	typeof(return) r; r.length = ngroup + 1; //TODO Confirm 1<<16 * sizeof(Tree[5])..
	foreach(ref g; r) {
		readTree(g[0], 256 + 24 + (cbits ? 1 << cbits : 0), s); //Green
		readTree(g[1], 256, s); //Red
		readTree(g[2], 256, s); //Blue
		readTree(g[3], 256, s); //Alpha
		readTree(g[4], 40, s); } //Distance
	return r; }

//Code length code order
immutable ubyte[19] clco = [17,18,0,1,2,3,4,5,16,6,7,8,9,10,11,12,13,14,15];
immutable ubyte[3] extra = [2, 3, 7], offset = [3, 3, 11];

/* https://dlang.org/spec/const.html: 'The initializer for a non-static local immutable
 * declaration is evaluated at run time'. Do not put immutable arrays inside functions. */

void readTree(ref Tree t, uint size, Stream s) {
	assert(size <= 2328); ubyte[2328] l; //Maximum number of symbols is 256 + 24 + 1 << 11 = 2328

	if(s.readb!bool) { //Simple code length code (encodes 1 or 2 symbols in 0..256)
		uint s0, s1; //The spec calls these symbols 'code lengths', which seemingly makes no sense.
		auto n = s.readb!uint + 1; //1 or 2 symbols
		s0 = s.readb!uint(7*s.readb!uint + 1); //First symbol is either 1 or 8 bits long
		if(n == 2) s1 = s.readb!uint(8); // SPEC: 'The second code (if present), is always 8 bit long.'
		if(s0 >= size || s1 >= size) throw new EX("Bad simple huffman tree");
		l[s0] = 1; if(n == 2) l[s1] = 1; }

	else {
		//Normal code length code (encodes this tree's code lengths with another, smaller tree)
		uint n = s.readb!uint(4) + 4; if(n > 19) throw new EX("Bad code count");
		ubyte[19] clcl; //Code length code lengths (lol)
		foreach(i; 0..n) clcl[clco[i]] = s.readb!ubyte(3); //Read 'em

		//Read code lengths
		Tree clt; clt.build(clcl); //Build code length tree
		uint max_sym = size;
		if(s.readb!bool) { //Use length
			max_sym = s.readb!uint(s.readb!uint(3) * 2 + 2) + 2;
			if(max_sym > size) throw new EX("Bad code lengths"); }

		uint prev = 8;
		for(uint symbol; symbol < size;) {
			if(!max_sym--) break;
			uint cl = clt.next(s);
			if(cl < 16) { l[symbol++] = cast(ubyte)cl; if(cl) prev = cl; }
			else {
				uint repeat = s.readb!uint(extra[cl-16]) + offset[cl-16];
				if(symbol + repeat > size) throw new EX("Bad code lengths");
				ubyte copy = (cl == 16) ? cast(ubyte)prev : 0;
				while(repeat--) l[symbol++] = copy; } } }
	t.build(l[0..size]);
}

/* Regarding WEBP Lossless (VP8L)..
 *
 * VP8L is implemented with two core methods that intertwine aggressively.
 * Here, they are called readPixels and readHuffgroups.
 *
 * So-called pixel encoding is better understood as a general compression method.
 * It uses huffman codes, requiring it to use readHuffgroups. The aggressive part
 * is that readHuffgroups also uses things called 'meta huffman codes'.
 *
 * Which are encoded as pixels.
 *
 * Fortunately, the nesting ends there. Only proper ARGB pixels can be compressed
 * with meta huffman codes, so the codes happily never encode themselves. But this
 * still results in readPixels and readHuffgroups calling each other in a style
 * that at first glance appears to be recursive. The 'meta' argument prevents it.
 *
 * Other fun details include reversible transformations of the ARGB pixels encoded
 * as pixels, and canonical huffman code lengths being encoded with huffman codes,
 * but that's situation normal for huffman coding.
 *
 * I will stress that this format is very well designed, better than PNG in every
 * way that matters while still using the same basic principle (transform to improve
 * compressibility, encode with huffman). You just have to get over the mind bend.
 */
