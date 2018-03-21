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

		const groups = new Array(textGroups.length);

		// character layout state
		let x = 0;
		let y = 0;
		let characterOffset_vx = 0; // in terms of numbers of vertices rather than array elements
		
		for (let i = 0; i < textGroups.length; i++) {
			const font  = textGroups[i].font;
			const text = textGroups[i].text;

			const groupOffset_vx = characterOffset_vx;

			for (let c = 0; c < text.length; c++) {
				const char = text[c];
				const charCode = text.charCodeAt(c);

				// @! layout
				/*
				switch (charCode) {
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
					console.warn(`Font does not contain character for code "${charCode}"`);
					continue;
				}

				const glyph = fontCharacter.glyph;
				if (glyph != null) {
					// character has a glyph; add it to the vertexArray

					// quad dimensions
					const px = x - glyph.shapeOffset.x;
					const py = y - glyph.shapeOffset.y;
					const w = glyph.atlasRect.w / glyph.atlasScale; // convert width to normalized font units
					const h = glyph.atlasRect.h / glyph.atlasScale;
					// uv
					// add half-text offset to map to texel centers
					let ux = (glyph.atlasRect.x + 0.5) / font.textureSize.w;
					let uy = (glyph.atlasRect.y + 0.5) / font.textureSize.h;
					let uw = (glyph.atlasRect.w - 1) / font.textureSize.w;
					let uh = (glyph.atlasRect.h - 1) / font.textureSize.h;
					// flip glyph y
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
					], characterOffset_vx * vertexElements);
					// advance character quad in vertex array
					characterOffset_vx += characterVertexCount;
				}

				// advance glyph position
				// @! layout
				x += fontCharacter.advance;
			}

			groups[i] = {
				vertexOffset: groupOffset_vx,
				vertexCount: characterOffset_vx - groupOffset_vx
			};
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
