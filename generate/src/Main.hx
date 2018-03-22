/**

	# GPUText Font Atlas Generator

	Font units are normalized so that a value of 1 corresponds to the font's ascender and 0 the the descender

	Definitions
		su
			shape units, specific to msdfgen
		FUnits
			values directly stored in the truetype file
		fontHeight
			|font.ascender| + |font.descender|
		normalized units
			FUnits / fontHeight
		
		glyph bounds in pixels
			(left + translateX) * atlasScale
			(right + translateX) * atlasScale
			glyph-height-px - (bottom + translateY) * atlasScale
			glyph-height-px - (top + translateY) * atlasScale

	References
		https://docs.microsoft.com/en-gb/typography/opentype/spec/ttch01
		http://chanae.walon.org/pub/ttf/ttf_glyphs.htm

**/

using StringTools;

@:enum abstract GPUTextFormat(String) {
	var TEXTURE_ATLAS_FONT = 'TextureAtlasFont';
}

@:enum abstract TextureFontTechnique(String) from String {
	var MSDF = 'msdf';
	var SDF = 'sdf';
	var BITMAP = 'bitmap';
}

typedef ResourceReference = {
	// range of bytes within the file's binary payload
	?payloadByteRange: {
		start: Int,
		length: Int
	},

	// path relative to font file
	// an implementation should not allow resource paths to be in directories _above_ the font file
	?localPath: String, 
}

typedef TextureAtlasGlyph = {
	// location of glyph within the text atlas, in units of pixels
	atlasRect: {x: Int, y: Int, w: Int, h: Int},
	atlasScale: Float, // (normalized font units) * atlasScale = (pixels in texture atlas)

	// the following are in normalized font units
	shapeBounds: {left: Float, bottom: Float, right: Float, top: Float},
	// the shape offset within the atlasRect
	shapeOffset: {x: Float, y: Float},
}

typedef TextureAtlasCharacter = {
	// the distance from the glyph's x = 0 coordinate to the x = 0 coordinate of the next glyph, in normalized font units
	advance: Float,
	?glyph: TextureAtlasGlyph,
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

	ascender: Float,
	descender: Float,

	metadata: {
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
	},

	fieldRange_px: Float
}

class Main {

	static var textureAtlasFontVersion = 0;

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

			// misc
			@doc('Shows this help')
			['--help'] => () -> {
				showHelp = true;
			},

			@doc('Path of TrueType font file')
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

		// whitespace has no symbols - filter out whitespace but add metrics in later
		var glyphList = charList.filter(c -> whitespaceCharacters.indexOf(c) == -1);

		for (ttfPath in sourceTtfPaths) {
			sys.FileSystem.createDirectory(localTmpDir);

			var font = opentype.Opentype.loadSync(ttfPath);
			var fontHeight = font.ascender - font.descender;
			var fontFileName = haxe.io.Path.withoutDirectory(haxe.io.Path.withoutExtension(ttfPath));
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
						shapeBounds: null,
						shapeOffset: null,
					}
				});
			}

			// parse the generated metric files and copy values into the atlas character map
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
							atlasCharacter.glyph.shapeBounds = {left: norm(value[0]) , bottom: norm(value[1]), right: norm(value[2]), top: norm(value[3])};
						case 'translate':
							atlasCharacter.glyph.shapeOffset = {x: norm(value[0]), y: norm(value[1])};
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

			// save png
			var textureFileName = '$fontFileName-0.png';
			var textureFilePath = haxe.io.Path.join([fontOutputDirectory, textureFileName]);
			writeRgbPng(mapRgbBytes, atlasW, atlasH, textureFilePath);
			Console.success('Saved <b>"$textureFilePath"</b> (${atlasW}x${atlasH}, ${glyphList.length} glyphs)');

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

			var font: TextureAtlasFont = {
				format: TEXTURE_ATLAS_FONT,
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
				metadata: {
					family: font.names.fontFamily.en.trim(),
					subfamily: font.names.fontSubfamily.en.trim(),
					version: font.names.version.en.trim(),
					postScriptName: font.names.postScriptName.en.trim(),

					copyright: font.names.copyright.en.trim(),
					trademark: font.names.trademark.en.trim(),
					manufacturer: font.names.manufacturer.en.trim(),
					manufacturerURL: font.names.manufacturerURL.en.trim(),
					designerURL: font.names.designerURL.en.trim(),
					license: font.names.license.en.trim(),
					licenseURL: font.names.licenseURL.en.trim(),

					height_funits: fontHeight,
					funitsPerEm: font.unitsPerEm
				},
				fieldRange_px: fieldRange_px
			}

			if (fontOutputDirectory != '') sys.FileSystem.createDirectory(fontOutputDirectory);
			var fontOutputPath = haxe.io.Path.join([fontOutputDirectory, fontFileName + '.json']);
			sys.io.File.saveContent(fontOutputPath, haxe.Json.stringify(font, null, '\t'));
			Console.success('Saved <b>"$fontOutputPath"</b>');
		}
	}

	static function ceilPot(x: Float) {
		return Std.int(Math.pow(2, Math.ceil(Math.log(x)/Math.log(2))));
	}

	static function writeRgbPng(rgbBytes: haxe.io.Bytes, w: Int, h: Int, name: String) {
		var pngData = format.png.Tools.buildRGB(w, h, rgbBytes, 9);
		var pngBytes = new haxe.io.BytesOutput();
		new format.png.Writer(pngBytes).write(pngData);
		sys.io.File.saveBytes(name, pngBytes.getBytes());
	}

}