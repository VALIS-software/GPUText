/**
	Provides text layout, vertex buffer generation and file parsing

	Dev notes:
	- Should have progressive layout where text can be appended to an existing layout
**/
class GPUText {

	// y increases from top-down (like HTML/DOM coordinates)
	// y = 0 is set to be the font's ascender: https://i.stack.imgur.com/yjbKI.png
	// https://stackoverflow.com/a/50047090/4038621
	static layout(
		text: string,
		font: GPUTextFont,
		layoutOptions: {
			kerningEnabled?: boolean,
			ligaturesEnabled?: boolean,
			lineHeight?: number,

			glyphScale?: number, // scale of characters when wrapping text
			                     // doesn't affect the scale of the generated sequence or vertices
		}
	): GlyphLayout {
		const opts = {
			glyphScale: 1.0,
			kerningEnabled: true,
			ligaturesEnabled: true,
			lineHeight: 1.0,
			...layoutOptions
		}

		// scale text-wrap container
		// @! let wrapWidth /= glyphScale;

		// pre-allocate for each character having a glyph
		const sequence = new Array(text.length);
		let sequenceIndex = 0;

		const bounds = {
			l: 0, r: 0,
			t: 0, b: 0,
		}

		let x = 0;
		let y = 0;

		for (let c = 0; c < text.length; c++) {
			let char = text[c];
			let charCode = text.charCodeAt(c);

			// @! layout
			switch (charCode) {
				case 0xA0:
				// space character that prevents an automatic line break at its position. In some formats, including HTML, it also prevents consecutive whitespace characters from collapsing into a single space.
				// @! todo
				case '\n'.charCodeAt(0): // newline
					y += opts.lineHeight;
					x = 0;
					continue;
			}

			if (opts.ligaturesEnabled) {
				// @! todo, replace char and charCode if sequence maps to a ligature
			}

			if (opts.kerningEnabled && c > 0) {
				let kerningKey = text[c - 1] + char;
				x += font.kerning[kerningKey] || 0.0;
			}

			const fontCharacter = font.characters[char];

			if (fontCharacter == null) {
				console.warn(`Font does not contain character for "${char}" (${charCode})`);
				continue;
			}

			if (fontCharacter.glyph != null) {
				// character has a glyph

				// this corresponds top-left coordinate of the glyph, like hanging letters on a line
				sequence[sequenceIndex++] = {
					char: char,
					x: x,
					y: y
				};

				// width of a character is considered to be its 'advance'
				// height of a character is considered to be the lineHeight
				bounds.r = Math.max(bounds.r, x + fontCharacter.advance);
				bounds.b = Math.max(bounds.b, y + opts.lineHeight);
			}

			// advance glyph position
			// @! layout
			x += fontCharacter.advance;
		}

		// trim empty entries
		if (sequence.length > sequenceIndex) {
			sequence.length = sequenceIndex;
		}

		return {
			font: font,
			sequence: sequence,
			bounds: bounds,
			glyphScale: opts.glyphScale,
		}
	}

	/**
		Generates OpenGL coordinates where y increases from bottom to top

		@! improve docs

		=> float32, [p, p, u, u, u], triangles with CCW face winding
	**/
	static generateVertexData(glyphLayout: GlyphLayout) {
		// memory layout details
		const elementSizeBytes = 4; // (float32)
		const positionElements = 2;
		const uvElements = 3; // uv.z = glyph.atlasScale
		const elementsPerVertex = positionElements + uvElements;
		const vertexSizeBytes = elementsPerVertex * elementSizeBytes;
		const characterVertexCount = 6;

		const vertexArray = new Float32Array(glyphLayout.sequence.length * characterVertexCount * elementsPerVertex);

		let characterOffset_vx = 0; // in terms of numbers of vertices rather than array elements

		for (let i = 0; i < glyphLayout.sequence.length; i++) {
			const item = glyphLayout.sequence[i];
			const font = glyphLayout.font;
			const fontCharacter = font.characters[item.char];
			const glyph = fontCharacter.glyph;

			// quad dimensions
			let px = item.x - glyph.offset.x;
			// y = 0 in the glyph corresponds to the baseline, which is font.ascender from the top of the glyph
			let py = -(item.y + font.ascender + glyph.offset.y);

			let w = glyph.atlasRect.w / glyph.atlasScale; // convert width to normalized font units
			let h = glyph.atlasRect.h / glyph.atlasScale;

			// uv
			// add half-text offset to map to texel centers
			let ux = (glyph.atlasRect.x + 0.5) / font.textureSize.w;
			let uy = (glyph.atlasRect.y + 0.5) / font.textureSize.h;
			let uw = (glyph.atlasRect.w - 1.0) / font.textureSize.w;
			let uh = (glyph.atlasRect.h - 1.0) / font.textureSize.h;
			// flip glyph uv y, this is different from flipping the glyph y _position_
			uy = uy + uh;
			uh = -uh;
			// two-triangle quad with ccw face winding
			vertexArray.set([
				px, py, ux, uy, glyph.atlasScale, // bottom left
				px + w, py + h, ux + uw, uy + uh, glyph.atlasScale, // top right
				px, py + h, ux, uy + uh, glyph.atlasScale, // top left

				px, py, ux, uy, glyph.atlasScale, // bottom left
				px + w, py, ux + uw, uy, glyph.atlasScale, // bottom right
				px + w, py + h, ux + uw, uy + uh, glyph.atlasScale, // top right
			], characterOffset_vx * elementsPerVertex);

			// advance character quad in vertex array
			characterOffset_vx += characterVertexCount;
		}

		return {
			vertexArray: vertexArray,
			elementsPerVertex: elementsPerVertex,
			vertexCount: characterOffset_vx,
			vertexLayout: {
				position: {
					elements: positionElements,
					elementSizeBytes: elementSizeBytes,
					strideBytes: vertexSizeBytes,
					offsetBytes: 0,
				},
				uv: {
					elements: uvElements,
					elementSizeBytes: elementSizeBytes,
					strideBytes: vertexSizeBytes,
					offsetBytes: positionElements * elementSizeBytes,
				}
			}
		}
	}

	/**
	 * Given buffer containing a binary GPUText file, parse it and generate a GPUTextFont object
	 * @throws string on parse errors
	 */
	static parse(buffer: ArrayBuffer): GPUTextFont {
		const dataView = new DataView(buffer);

		// read header string, expect utf-8 encoded
		// the end of the header string is marked by a null character
		let jsonHeader = '';
		let p = 0;
		for (; p < buffer.byteLength; p++) {
			let byte = dataView.getInt8(p);
			if (byte === 0) break;
			jsonHeader += String.fromCharCode(byte);
		}

		// payload is starts from the first byte after the null character
		const payloadStart = p + 1;
		const littleEndian = true;

		const header: GPUTextFontHeader = JSON.parse(jsonHeader);

		// initialize GPUTextFont object
		let gpuTextFont: GPUTextFont = {
			format: header.format,
			version: header.version,
			technique: header.technique,

			ascender: header.ascender,
			descender: header.descender,
			typoAscender: header.typoAscender,
			typoDescender: header.typoDescender,
			lowercaseHeight: header.lowercaseHeight,
			metadata: header.metadata,
			fieldRange_px: header.fieldRange_px,

			characters: {},
			kerning: {},
			glyphBounds: null,

			textures: [],
			textureSize: header.textureSize,
		};

		// parse character data payload into GPUTextFont characters map
		let characterDataView = new DataView(buffer, payloadStart + header.characters.start, header.characters.length);
		let characterBlockLength_bytes =
			4 +     // advance: F32
			2 * 4 + // atlasRect(x, y, w, h): UI16
			4 +     // atlasScale: F32
			4 * 2;  // offset(x, y): F32
		for (let i = 0; i < header.charList.length; i++) {
			let char = header.charList[i];
			let b0 = i * characterBlockLength_bytes;

			let characterData: TextureAtlasCharacter = {
				advance: characterDataView.getFloat32(b0 + 0, littleEndian),
				glyph: {
					atlasRect: {
						x: characterDataView.getUint16(b0 + 4, littleEndian),
						y: characterDataView.getUint16(b0 + 6, littleEndian),
						w: characterDataView.getUint16(b0 + 8, littleEndian),
						h: characterDataView.getUint16(b0 + 10, littleEndian),
					},
					atlasScale: characterDataView.getFloat32(b0 + 12, littleEndian),
					offset: {
						x: characterDataView.getFloat32(b0 + 16, littleEndian),
						y: characterDataView.getFloat32(b0 + 20, littleEndian),
					}
				}
			}

			// A glyph with 0 size is considered to be a null-glyph
			if (characterData.glyph.atlasRect.w === 0 || characterData.glyph.atlasRect.h === 0) {
				characterData.glyph = null;
			}

			gpuTextFont.characters[char] = characterData;
		}

		// kerning payload
		let kerningDataView = new DataView(buffer, payloadStart + header.kerning.start, header.kerning.length);
		let kerningLength_bytes = 4;
		for (let i = 0; i < header.kerningPairs.length; i++) {
			let pair = header.kerningPairs[i];
			let kerning = kerningDataView.getFloat32(i * kerningLength_bytes, littleEndian);
			gpuTextFont.kerning[pair] = kerning;
		}

		// glyph bounds payload
		if (header.glyphBounds != null) {
			gpuTextFont.glyphBounds = {};

			let glyphBoundsDataView = new DataView(buffer, payloadStart + header.glyphBounds.start, header.glyphBounds.length);
			let glyphBoundsBlockLength_bytes = 4 * 4;
			for (let i = 0; i < header.charList.length; i++) {
				let char = header.charList[i];
				let b0 = i * glyphBoundsBlockLength_bytes;
				// t r b l
				let bounds = {
					t: glyphBoundsDataView.getFloat32(b0 + 0, littleEndian),
					r: glyphBoundsDataView.getFloat32(b0 + 4, littleEndian),
					b: glyphBoundsDataView.getFloat32(b0 + 8, littleEndian),
					l: glyphBoundsDataView.getFloat32(b0 + 12, littleEndian),
				}

				gpuTextFont.glyphBounds[char] = bounds;
			}
		}

		// texture payload
		// textures may be in the payload or an external reference
		for (let p = 0; p < header.textures.length; p++) {
			let page = header.textures[p];
			gpuTextFont.textures[p] = [];

			for (let m = 0; m < page.length; m++) {
				let mipmap = page[m];

				if (mipmap.payloadBytes	!= null) {
					// convert payload's image bytes into a HTMLImageElement object
					let imageBufferView = new Uint8Array(buffer, payloadStart + mipmap.payloadBytes.start, mipmap.payloadBytes.length);
					let imageBlob = new Blob([imageBufferView], { type: "image/png" });
					let image = new Image();
					image.src = URL.createObjectURL(imageBlob);
					gpuTextFont.textures[p][m] = image;
				} else if (mipmap.localPath != null) {
					// payload contains no image bytes; the image is store externally, pass on the path
					gpuTextFont.textures[p][m] = {
						localPath: mipmap.localPath
					};
				}
			}
		}

		return gpuTextFont;
	}

}

export interface GPUTextFont extends GPUTextFontBase {
	characters: { [character: string]: TextureAtlasCharacter | null },
	kerning: { [characterPair: string]: number },
	// glyph bounding boxes in normalized font units
	// not guaranteed to be included in the font file
	glyphBounds?: { [character: string]: { l: number, b: number, r: number, t: number } },
	textures: Array<Array<{ localPath: string } | HTMLImageElement>>,
}

export interface GlyphLayout {
	font: GPUTextFont,
	sequence: Array<{
		char: string,
		x: number,
		y: number
	}>,
	bounds: { l: number, r: number, t: number, b: number },
	glyphScale: number,
}

export interface TextureAtlasGlyph {
	// location of glyph within the text atlas, in units of pixels
	atlasRect: { x: number, y: number, w: number, h: number },
	atlasScale: number, // (normalized font units) * atlasScale = (pixels in texture atlas)

	// the offset within the atlasRect in normalized font units
	offset: { x: number, y: number },
}

export interface TextureAtlasCharacter {
	// the distance from the glyph's x = 0 coordinate to the x = 0 coordinate of the next glyph, in normalized font units
	advance: number,
	glyph?: TextureAtlasGlyph,
}

export interface ResourceReference {
	// range of bytes within the file's binary payload
	payloadBytes?: {
		start: number,
		length: number
	},

	// path relative to font file
	// an implementation should not allow resource paths to be in directories _above_ the font file
	localPath?: string,
}

type GPUTextFormat = 'TextureAtlasFontJson' | 'TextureAtlasFontBinary';
type GPUTextTechnique = 'msdf' | 'sdf' | 'bitmap';

interface GPUTextFontMetadata {
	family: string,
	subfamily: string,
	version: string,
	postScriptName: string,

	copyright: string,
	trademark: string,
	manufacturer: string,
	manufacturerURL: string,
	designerURL: string,
	license: string,
	licenseURL: string,

	// original authoring height
	// this can be used to reproduce the unnormalized source values of the font
	height_funits: number,
	funitsPerEm: number,
}

interface GPUTextFontBase {
	format: GPUTextFormat,
	version: number,

	technique: GPUTextTechnique,

	textureSize: {
		w: number,
		h: number,
	},

	// the following are in normalized font units where (ascender - descender) = 1.0
	ascender: number,
	descender: number,
	typoAscender: number,
	typoDescender: number,
	lowercaseHeight: number,

	metadata: GPUTextFontMetadata,

	fieldRange_px: number,
}

// binary text file JSON header
interface GPUTextFontHeader extends GPUTextFontBase {
	charList: Array<string>,
	kerningPairs: Array<string>,
	characters: {
		start: number,
		length: number,
	},
	kerning: {
		start: number,
		length: number,
	},
	glyphBounds?: {
		start: number,
		length: number,
	},
	textures: Array<Array<ResourceReference>>,
}

export default GPUText;