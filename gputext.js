/**

	# GPU Text Core

	Provides text layout and vertex buffer generation

	Dev notes:
	- Should have progressive layout, where text can be appended to an existing layout

**/

"use strict";

const GPUText = {

	// y increases from top-down (like HTML/DOM coordinates)
	layout: function(text, font, layoutOptions) {
		const opts = layoutOptions != null ? layoutOptions : {};

		const kerningEnabled = opts.kerningEnabled != null ? opts.kerningEnabled : true;
		const ligaturesEnabled = opts.ligaturesEnabled != null ? opts.ligaturesEnabled : false;
		const lineHeight = opts.lineHeight != null ? opts.lineHeight : 1.0;

		const sequence = new Array();
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
					y += lineHeight;
					x = 0;
					continue;
			}

			if (ligaturesEnabled) {
				// @! todo, replace char and charCode if sequence maps to a ligature
			}

			if (kerningEnabled && c > 0) {
				let kerningKey = text[c - 1] + char;
				x += font.kerning[kerningKey] || 0.0;
			}

			const fontCharacter = font.characters[char];
			const glyph = fontCharacter.glyph;

			if (fontCharacter == null) {
				console.warn(`Font does not contain character for "${char}" (${charCode})`);
				continue;
			}

			if (glyph != null) {
				// character has a glyph

				// this corresponds top-left coordinate of the glyph, like hanging letters on a line
				sequence.push({
					char: char,
					x: x,
					y: y
				});

				// width of a character is considered to be its 'advance'
				// height of a character is considered to be the lineHeight
				bounds.r = Math.max(bounds.r, x + fontCharacter.advance);
				bounds.b = Math.max(bounds.b, y + lineHeight);
			}

			// advance glyph position
			// @! layout
			x += fontCharacter.advance;
		}

		return {
			font: font,
			sequence: sequence,
			bounds: bounds,
		}
	},

	/**
		Todo: docs

		Generates OpenGL coordinates where y increases from bottom to top

		 => float32, [p, p, u, u, u], triangles with CCW face winding
	**/
	generateVertexData: function(glyphLayout) {
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
			let px =   item.x - glyph.offset.x;
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
				px     , py     , ux      , uy      , glyph.atlasScale, // bottom left
				px + w , py + h , ux + uw , uy + uh , glyph.atlasScale, // top right
				px     , py + h , ux      , uy + uh , glyph.atlasScale, // top left

				px     , py     , ux      , uy      , glyph.atlasScale, // bottom left
				px + w , py     , ux + uw , uy      , glyph.atlasScale, // bottom right
				px + w , py + h , ux + uw , uy + uh , glyph.atlasScale, // top right
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
}

if (typeof module != 'undefined' && module.exports != null) {
	module.exports = GPUText;
}