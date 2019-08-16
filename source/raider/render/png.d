module raider.render.png;

import raider.tools.reference;
import raider.tools.stream : Stream;
import raider.tools.crc : CRC32;
import raider.render.texture;

import std.bitmanip : bigEndianToNative;
import core.bitop : popcnt;
import core.thread : Fiber;

/++

//import std.zlib; Cannot use D's zlib, as it allocates, and uses the (large) reference C implementation.

/* Abstract away the PNG chunking system.
 * Reading, it yields the contents of IHDR, then all IDAT chunks concatenated and decompressed.
 * Checks CRCs and Adler checksums.
 */
private @RC class DechunkStream : Stream
{
	Stream s;
	Fiber f; //TODO Unresolved use case: How to add @RC to external classes?


//STOP WORKING ON THIS AND WORK ON WEBP LOSSLESS


	ubyte[64] buffer; //Buffer to reduce invocations of fiber.call() 
	uint bp; //buffer pointer 

	this(Stream stream)
	{
		super("PNG chunks", Mode.Read);
		s = stream;
		f = new Fiber(&dechunk);
	}

	override void writeBytes(const(ubyte)[] bytes) { }

	override void readBytes(ubyte[] bytes) {
		//buffer must be FILLED and EMPTIED completely in each exchange,
		//except when there is no more data (IEND chunk).
		//
		foreach(ref b; bytes)
		{
			if(f.state == Fiber.State.TERM) throw new PNGException("Read beyond end-of-stream.");
			//b = g.popFront;
		}
	}
	
	void dechunk()
	{
		uint size; ubyte[4] type; //Type and size of current chunk
		uint stage; //0 = IHDR, 1 = finding IDAT, 2 = IDAT, 3 = IEND.

		//Main loop (essentially a foreach over the chunks)
		while(stage < 3)
		{
			//Read chunk size and type
			s.read(size); s.read(type);
			
			foreach(b; type) //Chunk type must be ascii (65-90, 97-122)
				if(b < 65 || (90 < b && b < 97) || 122 < b)
					throw new PNGException("Bad non-ascii chunk type (" ~ type ~ ")");
			
			//Start CRC
			CRC32 crc;
			crc.add(type);
			
			if(state == 0) 
			{
				//IHDR chunk
				if(type != "IHDR" || size != 13) //IHDR must come first
					throw new PNGException("Bad IHDR, found chunk type '" ~ type ~ "' with size " ~ size);

				s.read(buffer[0..13]); //this should work..
				bp = 13; state = 1; continue;
				//
			}
			
			//state 1 - expecting IDAT, skipping unknowns
			if(state == 1)
			{
				if(type == "IDAT")
				{
					//Yield decompressed bytes
				}
				else
				{
					while(size--)
					{
						while(bp< buffer.sizeof)
						{
						b = s.read!ubyte;
						crc.add(b);
						buffer[bp++] = b;
						}
						Fiber.yield;
					}
				}
			}
			
			//Check CRC
			ubyte[4] crcb; s.read(crcb);
			auto crc = bigEndianToNative!uint(crcb); //crc is MSB-first, big-endian, network byte order, etc.
			
			if(mcrc != crc)
				throw new PNGException("CRC failed on " ~ type ~ " (read " ~ crc ~ ", calculated " ~ mcrc ~ ")");

			//IEND chunk
			if(type == "IEND")
			{
				state = 2;
			}
			
			//Ancillary and PLTE chunks are skipped
			if(type[0] & 32 || type == "PLTE") while(size--) update_crc(mcrc, s.read!ubyte());
			
			//Unrecognised critical chunks
			if(!(type[0] & 32)) throw new PNGException("Unsupported critical chunk " ~ type);
			
			//Reserved chunks
			if(type[3] & 32) throw new PNGException("Bad reserved bit");
		}
	}
}

/* This is the Portable Network Graphics format.
 * 
 * This encoder/decoder:
 * - Checks CRCs 
 * - Checks IHDR conforms to the PNG spec
 * - Complains about non-spec errors before complaining about features it doesn't support
 * - Correctly handles ancillary/private/non-copyable/reserved
 * - Calls Fiber.yield after reading the header, then at regular intervals.
 */

/* We want to upload the texture scanline-by-scanline, calling Fiber.yield occasionally. */
void load(Texture texture, Stream stream)
{
	auto s = New!DechunkStream(stream);

	//Check magic
	ubyte[8] magic; s.read(magic);
	if(magic != [137, 80, 78, 71, 13, 10, 26, 10])
		throw new PNGException("Bad magic, found " ~ magic);

	//Decoding state
	ubyte[2][8192*4] lines; //Two scanlines
	ubyte* prev; //Previous scanline
	ubyte* scan; //Current scanline
	uint cursor = 0; //Index into current scanline
	ubyte filter; //Filter type on current scanline

	uint width, height; ubyte bits, colour, compression, filter, interlace;
	s.read(width, height, bits, colour, compression, filter, interlace);

	if(width == 0 || height == 0) throw new PNGException("Bad dimensions " ~ width ~ "x" ~ height);
	if(width > 8192 || height > 8192) throw new PNGException("Unsupported dimensions (>8192) " ~ width ~ "x" ~ height); 
	if(popcnt(bits) != 1 || bits > 16) throw new PNGException("Bad bit-depth (" ~ bits ~ ")");
	if(colour > 6 || colour == 1 || colour == 5) throw new PNGException("Bad colour type (" ~ colour ~ ")");
	if((colour == 2 || colour == 6) && bits < 8) throw new PNGException("Bad truecolour bit-depth (" ~ bits ~ ")");
	if(colour == 4 && bits < 8) throw new PNGException("Bad greyscale-alpha bit depth (" ~ bits ~ ")");
	if(colour == 3 && bits > 8) throw new PNGException("Bad indexed-colour bit depth (" ~ bits ~ ")");
	if(colour == 3) throw new PNGException("Unsupported colour type (indexed)");
	if(bits != 8) throw new PNGException("Unsupported bit-depth (" ~ bits ~ ")");
	if(compression != 0) throw new PNGException("Bad compression method (" ~ compression ~ ")"); 
	if(filter != 0) throw new PNGException("Bad filter method (" ~ filter ~ ")"); 
	if(interlace > 1) throw new PNGException("Bad interlace method (" ~ interlace ~ ")");
	if(interlace == 1) throw new PNGException("Unsupported interlace method (Adam7)");
	
	//update_crc(mcrc, width, height, bits, colour, compression, filter, interlace);
	//state = 1;
	//else if(state > 0) //mono-d plugin doesn't like else, period
	/*
	{
		//IDAT chunk
		if(type == "IDAT")
		{
			state = 2;
			//We must continue reading IDAT chunks (even zero-length) and concatenate them.
			//We uncompress until a line is completed, then unfilter and upload it. 
			//When a line is completed, we upload it.
			//Let's assume for argument that the data is uncompressed
			while(size--)
			{
				if(cursor == 0) stream.read(filter);
				else scan[cursor] = stream.read!ubyte;
			}
			//Eventually:
			state = 3;
		}
	}
	*/
}

ubyte paeth(ubyte a, ubyte b, ubyte c)
{
	int p = a + b - c;
	int pa = p > a ? p - a : a - p;
	int pb = p > b ? p - b : b - p;
	int pc = p > c ? p - c : c - p;
	return (pa <= pb && pa <= pc) ? a : pb <= pc ? b : c;
}




final class PNGException : Exception
{ import raider.tools.exception; mixin SimpleThis; }


++/
