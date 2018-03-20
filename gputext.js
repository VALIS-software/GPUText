"use strict";

var GPUText = {
	/**
		Todo: docs

		returns a vertex array that contains vertex data for all groups
		along with an array of group indexes and lengths within the vertex array
		 => float32, [p, p, u, u], triangles with CCW face winding
	**/
	generateVertexData: function(textGroups, containerLayout) {
		textGroups = Array.isArray(textGroups) ? textGroups : [textGroups];

		// @! could save 33% vertices with index buffer but adds to complexity a bit

		const elementSizeBytes = 4; // (float32)
		const positionElements = 2;
		const uvElements = 3;
		const vertexElements = positionElements + uvElements;
		const vertexSizeBytes = vertexElements * elementSizeBytes;
		const characterVertexCount = 6;

		const totalTextLength = textGroups.reduce(function(acc, g) { return acc + g.text.length; }, 0);

		const vertexArray = new Float32Array(totalTextLength * characterVertexCount * vertexElements);

		const groups = new Array();

		// character layout state
		let x = 0;
		let y = 0;
		let characterOffset = 0; // in terms of numbers of vertices rather than elements
		
		for (let i = 0; i < textGroups.length; i++) {
			const font  = textGroups[i].font;
			const text = textGroups[i].text;

			const groupOffset = characterOffset;

			for (let c = 0; c < text.length; c++) {
				const char = text[c];
				const characterCode = text.charCodeAt(c);

				// @! layout
				/*
				switch (characterCode) {
					case 0xA0: // non-breaking space, fixed width
						x += 1;
						continue;
					case '\n'.charCodeAt(0): // newline
						y -= 1.3/scale;
						x = 0;
						continue;
				}
				*/

				const fontCharacter = font.characters[char];

				if (fontCharacter == null) {
					console.warn(`Font does not contain character for code "${characterCode}"`);
					continue;
				}

				const glyph = fontCharacter.glyph;
				if (glyph != null) {
					// character has a glyph; add it to the vertexArray

					// quad dimensions
					const px = x - glyph.translate.x;
					const py = y - glyph.translate.y;
					const w = glyph.atlasRect.w / glyph.atlasScale;
					const h = glyph.atlasRect.h / glyph.atlasScale;
					// uv
					// add half-text offset for texel centers
					let ux = (glyph.atlasRect.x + 0.5) / font.textureSize.w;
					let uy = (glyph.atlasRect.y + 0.5) / font.textureSize.h;
					let uw = (glyph.atlasRect.w - 1) / font.textureSize.w;
					let uh = (glyph.atlasRect.h - 1) / font.textureSize.h;
					// flip glyph y
					uy = uy + uh;
					uh = -uh;
					// field range in normalized units for this character
					const fieldRange = font.fieldRange_px / glyph.atlasScale;
					// two-triangle quad with ccw face winding
					vertexArray.set([
						px     , py     , ux      , uy      , glyph.atlasScale, // bottom left
						px + w , py + h , ux + uw , uy + uh , glyph.atlasScale, // top right
						px     , py + h , ux      , uy + uh , glyph.atlasScale, // top left

						px     , py     , ux      , uy      , glyph.atlasScale, // bottom left
						px + w , py     , ux + uw , uy      , glyph.atlasScale, // bottom right
						px + w , py + h , ux + uw , uy + uh , glyph.atlasScale, // top right
					], characterOffset * vertexElements);
					// advance character in vertex array
					characterOffset += characterVertexCount;
				}

				// advance glyph position
				// @! layout
				x += fontCharacter.advance;
			}

			if (characterOffset > groupOffset) { // skip empty groups
				groups.push({
					vertexOffset: groupOffset,
					vertexCount: characterOffset - groupOffset
				});
			}
		}

		return {
			vertexArray: vertexArray,
			vertexElements: vertexElements,
			groups: groups,
			layout: {
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
