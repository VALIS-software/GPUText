/**

	# GPUText Font-atlas Generator

	Definitions
		character
			An entry in the character set, may not have an associated glyph (e.g. tab character)
		glyph
			A printable shape associated with a character

	Units
		su
			shape units, specific to msdfgen
		FUnits
			values directly stored in the truetype file
		fontHeight
			|font.ascender| + |font.descender|
		normalized units
			FUnits / fontHeight
			Normalized so that a value of 1 corresponds to the font's ascender and 0 the the descender

	References
		https://docs.microsoft.com/en-gb/typography/opentype/spec/ttch01
		http://chanae.walon.org/pub/ttf/ttf_glyphs.htm

**/

using StringTools;
using Lambda;

@:enum abstract GPUTextFormat(String) {
	var TEXTURE_ATLAS_FONT_JSON = 'TextureAtlasFontJson';
	var TEXTURE_ATLAS_FONT_BINARY = 'TextureAtlasFontBinary';
}

@:enum abstract TextureFontTechnique(String) from String {
	var MSDF = 'msdf';
	var SDF = 'sdf';
	var BITMAP = 'bitmap';
}

typedef ResourceReference = {
	// @! add format, i.e., png, or byte field descriptor

	// range of bytes within the file's binary payload
	?payloadBytes: {
		start: Int,
		length: Int,
	},

	// path relative to font file
	// an implementation should not allow resource paths to be in directories _above_ the font file
	?localPath: String, 
}

typedef TextureAtlasGlyph = {
	// location of glyph within the text atlas, in units of pixels
	atlasRect: {x: Int, y: Int, w: Int, h: Int},
	atlasScale: Float, // (normalized font units) * atlasScale = (pixels in texture atlas)

	// the offset within the atlasRect in normalized font units
	offset: {x: Float, y: Float},
}

typedef TextureAtlasCharacter = {
	// the distance from the glyph's x = 0 coordinate to the x = 0 coordinate of the next glyph, in normalized font units
	advance: Float,
	?glyph: TextureAtlasGlyph,
}

typedef FontMetadata = {
	family: String,
	subfamily: String,
	version: String,
	postScriptName: String,

	copyright: String,
	trademark: String,
	manufacturer: String,
	manufacturerURL: String,
	designerURL: String,
	license: String,
	licenseURL: String,

	// original authoring height
	// this can be used to reproduce the unnormalized source values of the font
	height_funits: Float,
	funitsPerEm: Float,
}

typedef TextureAtlasFont = {
	format: GPUTextFormat,
	version: Int,

	technique: TextureFontTechnique,

	characters: haxe.DynamicAccess<TextureAtlasCharacter>,
	kerning: haxe.DynamicAccess<Float>,

	textures: Array<
		// array of mipmap levels, where 0 = largest and primary texture (mipmaps may be omitted)
		Array<ResourceReference>
	>,

	textureSize: {
		w: Int,
		h: Int,
	},

	// normalized font units
	ascender: Float,
	descender: Float,
	typoAscender: Float,
	typoDescender: Float,
	lowercaseHeight: Float,

	metadata: FontMetadata,

	fieldRange_px: Float,

	// glyph bounding boxes in normalized font units
	// not guaranteed to be included in the font file
	?glyphBounds: haxe.DynamicAccess<{l: Float, b: Float, r: Float, t: Float}>
}

typedef TextureAtlasFontBinaryHeader = {
	format: GPUTextFormat,
	version: Int,

	technique: TextureFontTechnique,

	ascender: Float,
	descender: Float,
	typoAscender: Float,
	typoDescender: Float,
	lowercaseHeight: Float,

	metadata: FontMetadata,

	fieldRange_px: Float,

	charList: Array<String>,
	kerningPairs: Array<String>,

	// payload data
	textures: Array<
		// array of mipmap levels, where 0 = largest and primary texture (mipmaps may be omitted)
		Array<ResourceReference>
	>,

	textureSize: {
		w: Int,
		h: Int,
	},

	characters: {
		start: Int,
		length: Int,
	},
	kerning: {
		start: Int,
		length: Int,
	},
	?glyphBounds: {
		start: Int,
		length: Int,
	},
}

enum DataType {
	Float;
	Int;
	UInt;
}

typedef BinaryDataField = {key: String, type: DataType, length_bytes: Int};

class Main {

	static var textureAtlasFontVersion = 1;

	static var technique:TextureFontTechnique = MSDF;

	static var prebuiltBinariesDir = 'prebuilt';
	static var msdfgenPath = 'prebuilt/msdfgen'; // search at runtime
	static var charsetPath = 'charsets/ascii.txt';
	static var localTmpDir = '__glyph-cache';
	static var fontOutputDirectory = '';

	static var sourceTtfPaths = new Array<String>();
	static var charList = null;
	static var size_px: Int = 32;
	static var fieldRange_px: Int = 2;
	static var maximumTextureSize = 4096;
	static var storeBounds = false;
	static var saveBinary = true;
	static var externalTextures = false;

	static var whitespaceCharacters = [
		' ', '\t'
	];

	// not sure why msdfgen divides truetype's FUnits by 64 but it does
	static inline var suToFUnits = 64.0;

	static function main() {
		Console.errorPrefix = '<b><red>></b> ';
		Console.warnPrefix = '<b><yellow>></b> ';

		// search for msdfgen binary
		var msdfBinaryName = Sys.systemName() == 'Windows' ? 'msdfgen.exe' : 'msdfgen';
		var msdfSearchDirectories = ['.', 'msdfgen', 'prebuilt'];
		for (dir in msdfSearchDirectories) {
			var path = haxe.io.Path.join([dir, msdfBinaryName]);
			if (sys.FileSystem.exists(path) && !sys.FileSystem.isDirectory(path)) {
				msdfgenPath = path;
				break;
			}
		}

		var showHelp = false;
		var argHandler = hxargs.Args.generate([
			@doc('Path of file containing character set')
			['--charset'] => (path: String) -> charsetPath = path,

			@doc('List of characters')
			['--charlist'] => (characters: String) -> charList = characters.split(''),

			@doc('Sets the path of the output font file. External resources will be saved in the same directory')
			['--output-dir', '-o'] => (path: String) -> fontOutputDirectory = path,

			@doc('Font rendering technique, one of: msdf, sdf, bitmap')
			['--technique'] => (name: String) -> technique = name,

			// texture atlas mode options
			@doc('Path of msdfgen executable')
			['--msdfgen'] => (path: String) -> msdfgenPath = path,

			@doc('Maximum dimension of a glyph in pixels')
			['--size'] => (glyphSize: Int) -> size_px = glyphSize,

			@doc('Specifies the width of the range around the shape between the minimum and maximum representable signed distance in pixels')
			['--pxrange'] => (range: Int) -> fieldRange_px = range,

			@doc('Sets the maximum dimension of the texture atlas')
			['--max-texture-size'] => (size: Int) -> maximumTextureSize = size,

			@doc('Enables storing glyph bounding boxes in the font (default false)')
			['--bounds'] => (enabled: Bool) -> storeBounds = enabled,

			@doc('Saves the font in the binary format (default true)')
			['--binary'] => (enabled: Bool) -> saveBinary = enabled,

			@doc('When store textures externally when saving in the binary format')
			['--external-textures'] => (enabled: Bool) -> externalTextures = enabled,

			// misc
			@doc('Shows this help')
			['--help'] => () -> {
				showHelp = true;
			},

			@doc('Path of TrueType font file (.ttf)')
			_ => (path: String) -> {
				// catch any common aliases for help
				if (path.charAt(0) == '-') {
					if (['-help', '-h', '-?'].indexOf(path) != -1) {
						showHelp = true;
					} else {
						throw 'Unrecognized argument <b>"$path"</b>';
					}
				}
				// assume it's a ttf path
				sourceTtfPaths.push(path);
			}
		]);

		function printUsage() {
			Console.printlnFormatted('<b>Usage:</b>\n');
			Console.print(argHandler.getDoc());
			Console.println('');
			Console.println('');
		}

		try {
			argHandler.parse(Sys.args());

			if (showHelp) {
				printUsage();
				Sys.exit(0);
				return;
			}

			// validate args
			if (!sys.FileSystem.exists(msdfgenPath)) {
				throw 'msdfgen executable was not found at <b>"$msdfgenPath"</b> – ensure it is built';
			}

			if (sourceTtfPaths.length == 0) {
				throw 'Path of source TrueType font file is required';
			}

			for (ttfPath in sourceTtfPaths) {
				if (!sys.FileSystem.exists(ttfPath)) {
					throw 'Font file <b>"$ttfPath"</b> does not exist';
				}
			}

			if (charList == null) {
				charList = sys.io.File.getContent(charsetPath).split('');
			}

			switch technique {
				case MSDF:
				default: throw 'Font technique <b>"$technique"</b> is not implemented';
			}

		} catch (e: Any) {
			Console.error(e);
			Console.println('');
			printUsage();
			Sys.exit(1);
			return;
		}

		for (ttfPath in sourceTtfPaths) {
			sys.FileSystem.createDirectory(localTmpDir);

			var font = opentype.Opentype.loadSync(ttfPath);
			// notes on metrics
			// https://glyphsapp.com/tutorials/vertical-metrics
			// https://silnrsi.github.io/FDBP/en-US/Line_Metrics.html

			// font.ascender = font.table.hhea.ascender
			// font.descender = font.table.hhea.descender

			var fontHeight = font.ascender - font.descender;
			var fontFileName = haxe.io.Path.withoutDirectory(haxe.io.Path.withoutExtension(ttfPath));

			// filter all characters without glyphs into a separate list
			var glyphList = charList.filter(c -> {
				var g = font.charToGlyph(c);
				return font.hasChar(c) && untyped g.xMin != null && untyped g.name != '.notdef';
			});

			// liga = ligatures which you want to be on by default, but which can be deactivated by the user.
			// dlig = ligatures which you want to be off by default, but which can be activated by the user.
			// rlig = ligatures which you want to be on and which cannot be turned off. Or at least that's the theory. Unfortunately, this feature is not implemented 
			// trace(font.substitution.getLigatures('liga', null, null));
			// trace(font.substitution.getLigatures('dlig', null, null));
			// trace(font.substitution.getLigatures('rlig', null, null));

			function normalizeFUnits(fUnit: Float) return fUnit / fontHeight;

			Console.log('Generating glyphs for <b>"$ttfPath"</b>');

			function imagePath(charCode:Int) return '$localTmpDir/$charCode-$size_px.bmp';
			function metricsPath(charCode:Int) return '$localTmpDir/$charCode-$size_px-metrics.txt';

			for (char in charList) {
				var charCode = char.charCodeAt(0);
				var e = Sys.command(
					'$msdfgenPath -font $ttfPath $charCode -size $size_px $size_px -printmetrics -pxrange $fieldRange_px -autoframe -o "${imagePath(charCode)}"> "${metricsPath(charCode)}"'
				);
				if (e != 0) {
					Console.error('$msdfgenPath exited with code $e');
					Sys.exit(e);
					return;
				}
			}

			Console.log('Reading glyph metrics');

			var atlasCharacters = new haxe.DynamicAccess<TextureAtlasCharacter>();
			// initialize each character
			for (char in charList) {
				atlasCharacters.set(char, {
					advance: 1,
					glyph: {
						atlasScale: 0,
						atlasRect: null,
						offset: null,
					}
				});
			}

			// parse the generated metric files and copy values into the atlas character map
			var glyphBounds = new haxe.DynamicAccess<{l: Float, b: Float, r: Float, t: Float}>();
			for (char in charList) {
				var charCode = char.charCodeAt(0);
				var metricsFileContent = sys.io.File.getContent(metricsPath(charCode));

				// parse metrics
				var atlasCharacter = atlasCharacters.get(char);

				var varPattern = ~/^\s*(\w+)\s*=([^\n]+)/; // name = a, b
				var str = metricsFileContent;
				while (varPattern.match(str)) {
					var name = varPattern.matched(1);
					var value = varPattern.matched(2).split(',').map(f -> Std.parseFloat(f));

					// multiply all values by a conversion factor from msdfgen to recover font's original values in FUnits
					// divide all values by the number of FUnits that make up one side of the 'em' square to get normalized values
					inline function norm(x: Float) return normalizeFUnits((x * suToFUnits));

					switch name {
						case 'advance':
							atlasCharacter.advance = norm(value[0]);
						case 'scale':
							atlasCharacter.glyph.atlasScale = 1/norm(1/value[0]);
						case 'bounds':
							glyphBounds.set(char, {l: norm(value[0]), b: norm(value[1]), r: norm(value[2]), t: norm(value[3])});
						case 'translate':
							atlasCharacter.glyph.offset = {x: norm(value[0]), y: norm(value[1])};
						// case 'range':
							// atlasCharacter.glyph.fieldRange = norm(value[0]);
					}

					str = varPattern.matchedRight();
				}
			}

			Console.log('Packing glyphs into texture');

			// find nearest power-of-two texture atlas dimensions that encompasses all glyphs
			var blocks = [for (_ in glyphList) {w: size_px, h: size_px}];
			var atlasW = ceilPot(size_px);
			var atlasH = ceilPot(size_px);
			var mode: Int = -1;
			var fitSucceeded = false;
			while (atlasW <= maximumTextureSize && atlasH <= maximumTextureSize) {
				var nodes = BinPacker.fit(cast blocks, atlasW, atlasH);
				if (nodes.indexOf(null) != -1) {
					// not all blocks could fit, double one of the dimensions
					if (mode == -1) atlasW = atlasW * 2;
					else atlasH = atlasH * 2;
					mode *= -1;
				} else {
					// copy results into the atlas characters
					for (i in 0...glyphList.length) {
						var char = glyphList[i];
						var block = blocks[i];
						var node = nodes[i];
						atlasCharacters.get(char).glyph.atlasRect = {
							x: Math.floor(node.x), y: Math.floor(node.y),
							w: block.w, h: block.h,
						}
					}
					fitSucceeded = true;
					break;
				}
			}

			if (!fitSucceeded) {
				Console.error('Could not fit glyphs into ${maximumTextureSize}x${maximumTextureSize} texture - try a smaller character set or reduced glyph size (multi-atlas is not implemented)');
				Sys.exit(1);
			}

			// delete .glyph fields from characters that have no glyph (like whitespace)
			for (char in charList) {
				var hasGlyph = glyphList.indexOf(char) != -1;
				if (!hasGlyph) {
					Reflect.deleteField(atlasCharacters.get(char), 'glyph');
				}
			}

			// blit all glyphs into a png with no padding
			var channels = 3;
			var bytesPerChannel = 1;
			var mapRgbBytes = haxe.io.Bytes.ofData(new haxe.io.BytesData(channels * bytesPerChannel * atlasW * atlasH));

			for (char in glyphList) {
				var charCode = char.charCodeAt(0);
				var input = sys.io.File.read(imagePath(charCode), true);
				var bmpData = new format.bmp.Reader(input).read();
				var glyphHeader = bmpData.header;
				var glyphBGRA = format.bmp.Tools.extractBGRA(bmpData);//format.png.Tools.extract32(pngData, null, false);

				var rect = atlasCharacters.get(char).glyph.atlasRect;

				inline function getIndex(x: Int, y: Int, channels: Int, width: Int) {
					return (y * width + x) * channels;
				}

				for (x in 0...glyphHeader.width) {
					for (y in 0...glyphHeader.height) {
						var i = getIndex(x, y, 4, glyphHeader.width);
						var b = glyphBGRA.get(i + 0);
						var g = glyphBGRA.get(i + 1);
						var r = glyphBGRA.get(i + 2);
						//var a = glyphBGRA.get(i + 3);

						// blit to map
						var mx = x + Std.int(rect.x);
						var my = y + Std.int(rect.y);
						var mi = getIndex(mx, my, 3, atlasW);
						mapRgbBytes.set(mi + 0, b);
						mapRgbBytes.set(mi + 1, g);
						mapRgbBytes.set(mi + 2, r);
					}
				}
			}

			Console.log('Deleting glyph cache');
			var tmpFiles = sys.FileSystem.readDirectory(localTmpDir);
			for (name in tmpFiles) {
				try sys.FileSystem.deleteFile(haxe.io.Path.join([localTmpDir, name])) catch(e:Any) {}
			}
			sys.FileSystem.deleteDirectory(localTmpDir);

			// build png atlas bytes
			var textureFileName = '$fontFileName-0.png';
			var textureFilePath = haxe.io.Path.join([fontOutputDirectory, textureFileName]);

			var pngData = format.png.Tools.buildRGB(atlasW, atlasH, mapRgbBytes, 9);
			var pngOutput = new haxe.io.BytesOutput();
			new format.png.Writer(pngOutput).write(pngData);
			var pngBytes = pngOutput.getBytes();

			// create font descriptor
			// generate kerning map
			var kerningMap = new haxe.DynamicAccess<Float>();
			for (first in charList) {
				for (second in charList) {
					var kerningAmount_fu = font.getKerningValue(font.charToGlyph(first), font.charToGlyph(second));
					if (kerningAmount_fu != null && kerningAmount_fu != 0) {
						kerningMap.set(first + second, normalizeFUnits(kerningAmount_fu));
					}
				}
			}

			function processFontNameField(field: Null<{?en: String}>): String {
				if (field == null) return null;
				if (field.en == null) return null;
				return field.en.trim();
			}

			var jsonFont: TextureAtlasFont = {
				format: TEXTURE_ATLAS_FONT_JSON,
				version: textureAtlasFontVersion,
				technique: MSDF,
				characters: atlasCharacters,
				kerning: kerningMap,
				textures: [
					[{localPath: textureFileName}]
				],
				textureSize: {
					w: atlasW,
					h: atlasH
				},
				ascender: font.ascender / fontHeight,
				descender: font.descender / fontHeight,
				typoAscender: font.tables.os2.sTypoAscender / fontHeight,
				typoDescender: font.tables.os2.sTypoDescender / fontHeight,
				lowercaseHeight: font.tables.os2.sxHeight / fontHeight,
				metadata: {
					family: processFontNameField(font.names.fontFamily),
					subfamily: processFontNameField(font.names.fontSubfamily),
					version: processFontNameField(font.names.version),
					postScriptName: processFontNameField(font.names.postScriptName),

					copyright: processFontNameField(font.names.copyright),
					trademark: processFontNameField(font.names.trademark),
					manufacturer: processFontNameField(font.names.manufacturer),
					manufacturerURL: processFontNameField(font.names.manufacturerURL),
					designerURL: processFontNameField(font.names.designerURL),
					license: processFontNameField(font.names.license),
					licenseURL: processFontNameField(font.names.licenseURL),

					height_funits: fontHeight,
					funitsPerEm: font.unitsPerEm
				},
				glyphBounds: storeBounds ? glyphBounds : null,
				fieldRange_px: fieldRange_px,
			}

			// Output file writing

			if (fontOutputDirectory != '') sys.FileSystem.createDirectory(fontOutputDirectory);

			if (!saveBinary) {
				var fontJsonOutputPath = haxe.io.Path.join([fontOutputDirectory, fontFileName + '.json']);
				sys.io.File.saveContent(fontJsonOutputPath, haxe.Json.stringify(jsonFont, null, '\t'));
				Console.success('Saved <b>"$fontJsonOutputPath"</b>');

				sys.io.File.saveBytes(textureFilePath, pngBytes);
				Console.success('Saved <b>"$textureFilePath"</b> (${atlasW}x${atlasH}, ${glyphList.length} glyphs)');
			} else {
				// convert to binary format

				var header: TextureAtlasFontBinaryHeader = {
					format: TEXTURE_ATLAS_FONT_BINARY,
					version: textureAtlasFontVersion,
					technique: jsonFont.technique,
					ascender: jsonFont.ascender,
					descender: jsonFont.descender,
					typoAscender: jsonFont.typoAscender,
					typoDescender: jsonFont.typoDescender,
					lowercaseHeight: jsonFont.lowercaseHeight,
					metadata: jsonFont.metadata,
					fieldRange_px: jsonFont.fieldRange_px,
					textureSize: jsonFont.textureSize,

					charList: charList,
					kerningPairs: jsonFont.kerning.keys(),

					// payload data
					characters: null,
					kerning: null,
					glyphBounds: null,
					textures: null,
				};

				// build payload
				var payload = new haxe.io.BytesOutput();
				var payloadPos = 0;

				// character data payload
				var characterDataBytes = new haxe.io.BytesOutput();
				var characterDataLength_bytes = 4 + (4 * 2) + (3 * 4);
				characterDataBytes.prepare(charList.length * characterDataLength_bytes);
				for (character in charList) {
					var characterData = atlasCharacters.get(character);

					characterDataBytes.writeFloat(characterData.advance);

					var glyph = characterData.glyph != null ? characterData.glyph : {
						atlasRect: {x: 0, y: 0, w: 0, h: 0},
						atlasScale: 0.0,
						offset: {x: 0.0, y: 0.0},
					};

					characterDataBytes.writeUInt16(glyph.atlasRect.x);
					characterDataBytes.writeUInt16(glyph.atlasRect.y);
					characterDataBytes.writeUInt16(glyph.atlasRect.w);
					characterDataBytes.writeUInt16(glyph.atlasRect.h);
					characterDataBytes.writeFloat(glyph.atlasScale);
					characterDataBytes.writeFloat(glyph.offset.x);
					characterDataBytes.writeFloat(glyph.offset.y);
				}

				// write character payload
				payload.write(characterDataBytes.getBytes());
				header.characters = {
					start: payloadPos, length: characterDataBytes.length
				}
				payloadPos = payload.length;

				// kerning payload
				var kerningBytes = new haxe.io.BytesOutput();
				var kerningDataLength_bytes = 4;
				kerningBytes.prepare(kerningDataLength_bytes * jsonFont.kerning.keys().length);
				for (k in jsonFont.kerning.keys()) {
					kerningBytes.writeFloat(jsonFont.kerning.get(k));
				}
				payload.write(kerningBytes.getBytes());
				header.kerning = {
					start: payloadPos, length: kerningBytes.length
				}
				payloadPos = payload.length;

				// glyph bounds payload
				if (storeBounds) {
					var boundsBytes = new haxe.io.BytesOutput();
					var boundsDataLength_bytes = 4 * 4;
					boundsBytes.prepare(boundsDataLength_bytes * glyphBounds.keys().length);
					for (character in charList) {
						var bounds = glyphBounds.get(character);
						if (bounds == null) {
							bounds = { l: 0, r: 0, t: 0, b: 0, } 
						}
						boundsBytes.writeFloat(bounds.t);
						boundsBytes.writeFloat(bounds.r);
						boundsBytes.writeFloat(bounds.b);
						boundsBytes.writeFloat(bounds.l);
					}
					header.glyphBounds = {
						start: payloadPos, length: boundsBytes.length
					}
					payloadPos = payload.length;
				}

				// atlas textures png payload (or external file)
				if (externalTextures) {
					sys.io.File.saveBytes(textureFilePath, pngBytes);
					Console.success('Saved <b>"$textureFilePath"</b> (${atlasW}x${atlasH}, ${glyphList.length} glyphs)');

					header.textures = [[
						{
							{localPath: textureFileName}
						}
					]];
				} else {
					payload.write(pngBytes);
					header.textures = [[
						{
							payloadBytes: {
								start: payloadPos, length: pngBytes.length
							}
						}
					]];
					payloadPos = payload.length;
				}

				var binaryFontOutput = new haxe.io.BytesOutput();
				binaryFontOutput.writeString(haxe.Json.stringify(header));
				binaryFontOutput.writeByte(0x00);
				binaryFontOutput.write(payload.getBytes());

				var fontBinOutputPath = haxe.io.Path.join([fontOutputDirectory, fontFileName + '.' + technique + '.bin']);
				sys.io.File.saveBytes(fontBinOutputPath, binaryFontOutput.getBytes());
				Console.success('Saved <b>"$fontBinOutputPath"</b>');
			}
		}
	}

	static function ceilPot(x: Float) {
		return Std.int(Math.pow(2, Math.ceil(Math.log(x)/Math.log(2))));
	}

}