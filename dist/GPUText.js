"use strict";
var __assign = (this && this.__assign) || Object.assign || function(t) {
    for (var s, i = 1, n = arguments.length; i < n; i++) {
        s = arguments[i];
        for (var p in s) if (Object.prototype.hasOwnProperty.call(s, p))
            t[p] = s[p];
    }
    return t;
};
Object.defineProperty(exports, "__esModule", { value: true });
/**
    Provides text layout, vertex buffer generation and file parsing

    Dev notes:
    - Should have progressive layout where text can be appended to an existing layout
**/
var GPUText = /** @class */ (function () {
    function GPUText() {
    }
    // y increases from top-down (like HTML/DOM coordinates)
    // y = 0 is set to be the font's ascender: https://i.stack.imgur.com/yjbKI.png
    // https://stackoverflow.com/a/50047090/4038621
    GPUText.layout = function (text, font, layoutOptions) {
        var opts = __assign({ glyphScale: 1.0, kerningEnabled: true, ligaturesEnabled: true, lineHeight: 1.0 }, layoutOptions);
        // scale text-wrap container
        // @! let wrapWidth /= glyphScale;
        // pre-allocate for each character having a glyph
        var sequence = new Array(text.length);
        var sequenceIndex = 0;
        var bounds = {
            l: 0, r: 0,
            t: 0, b: 0,
        };
        var x = 0;
        var y = 0;
        for (var c = 0; c < text.length; c++) {
            var char = text[c];
            var charCode = text.charCodeAt(c);
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
                var kerningKey = text[c - 1] + char;
                x += font.kerning[kerningKey] || 0.0;
            }
            var fontCharacter = font.characters[char];
            if (fontCharacter == null) {
                console.warn("Font does not contain character for \"" + char + "\" (" + charCode + ")");
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
        };
    };
    /**
        Generates OpenGL coordinates where y increases from bottom to top

        @! improve docs

        => float32, [p, p, u, u, u], triangles with CCW face winding
    **/
    GPUText.generateVertexData = function (glyphLayout) {
        // memory layout details
        var elementSizeBytes = 4; // (float32)
        var positionElements = 2;
        var uvElements = 3; // uv.z = glyph.atlasScale
        var elementsPerVertex = positionElements + uvElements;
        var vertexSizeBytes = elementsPerVertex * elementSizeBytes;
        var characterVertexCount = 6;
        var vertexArray = new Float32Array(glyphLayout.sequence.length * characterVertexCount * elementsPerVertex);
        var characterOffset_vx = 0; // in terms of numbers of vertices rather than array elements
        for (var i = 0; i < glyphLayout.sequence.length; i++) {
            var item = glyphLayout.sequence[i];
            var font = glyphLayout.font;
            var fontCharacter = font.characters[item.char];
            // skip null-glyphs
            if (fontCharacter == null || fontCharacter.glyph == null)
                continue;
            var glyph = fontCharacter.glyph;
            // quad dimensions
            var px = item.x - glyph.offset.x;
            // y = 0 in the glyph corresponds to the baseline, which is font.ascender from the top of the glyph
            var py = -(item.y + font.ascender + glyph.offset.y);
            var w = glyph.atlasRect.w / glyph.atlasScale; // convert width to normalized font units
            var h = glyph.atlasRect.h / glyph.atlasScale;
            // uv
            // add half-text offset to map to texel centers
            var ux = (glyph.atlasRect.x + 0.5) / font.textureSize.w;
            var uy = (glyph.atlasRect.y + 0.5) / font.textureSize.h;
            var uw = (glyph.atlasRect.w - 1.0) / font.textureSize.w;
            var uh = (glyph.atlasRect.h - 1.0) / font.textureSize.h;
            // flip glyph uv y, this is different from flipping the glyph y _position_
            uy = uy + uh;
            uh = -uh;
            // two-triangle quad with ccw face winding
            vertexArray.set([
                px, py, ux, uy, glyph.atlasScale,
                px + w, py + h, ux + uw, uy + uh, glyph.atlasScale,
                px, py + h, ux, uy + uh, glyph.atlasScale,
                px, py, ux, uy, glyph.atlasScale,
                px + w, py, ux + uw, uy, glyph.atlasScale,
                px + w, py + h, ux + uw, uy + uh, glyph.atlasScale,
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
        };
    };
    /**
     * Given buffer containing a binary GPUText file, parse it and generate a GPUTextFont object
     * @throws string on parse errors
     */
    GPUText.parse = function (buffer) {
        var dataView = new DataView(buffer);
        // read header string, expect utf-8 encoded
        // the end of the header string is marked by a null character
        var jsonHeader = '';
        var p = 0;
        for (; p < buffer.byteLength; p++) {
            var byte = dataView.getInt8(p);
            if (byte === 0)
                break;
            jsonHeader += String.fromCharCode(byte);
        }
        // payload is starts from the first byte after the null character
        var payloadStart = p + 1;
        var littleEndian = true;
        var header = JSON.parse(jsonHeader);
        // initialize GPUTextFont object
        var gpuTextFont = {
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
            glyphBounds: undefined,
            textures: [],
            textureSize: header.textureSize,
        };
        // parse character data payload into GPUTextFont characters map
        var characterDataView = new DataView(buffer, payloadStart + header.characters.start, header.characters.length);
        var characterBlockLength_bytes = 4 + // advance: F32
            2 * 4 + // atlasRect(x, y, w, h): UI16
            4 + // atlasScale: F32
            4 * 2; // offset(x, y): F32
        for (var i = 0; i < header.charList.length; i++) {
            var char = header.charList[i];
            var b0 = i * characterBlockLength_bytes;
            var glyph = {
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
            };
            // A glyph with 0 size is considered to be a null-glyph
            var isNullGlyph = glyph.atlasRect.w === 0 || glyph.atlasRect.h === 0;
            var characterData = {
                advance: characterDataView.getFloat32(b0 + 0, littleEndian),
                glyph: isNullGlyph ? undefined : glyph
            };
            gpuTextFont.characters[char] = characterData;
        }
        // kerning payload
        var kerningDataView = new DataView(buffer, payloadStart + header.kerning.start, header.kerning.length);
        var kerningLength_bytes = 4;
        for (var i = 0; i < header.kerningPairs.length; i++) {
            var pair = header.kerningPairs[i];
            var kerning = kerningDataView.getFloat32(i * kerningLength_bytes, littleEndian);
            gpuTextFont.kerning[pair] = kerning;
        }
        // glyph bounds payload
        if (header.glyphBounds != null) {
            gpuTextFont.glyphBounds = {};
            var glyphBoundsDataView = new DataView(buffer, payloadStart + header.glyphBounds.start, header.glyphBounds.length);
            var glyphBoundsBlockLength_bytes = 4 * 4;
            for (var i = 0; i < header.charList.length; i++) {
                var char = header.charList[i];
                var b0 = i * glyphBoundsBlockLength_bytes;
                // t r b l
                var bounds = {
                    t: glyphBoundsDataView.getFloat32(b0 + 0, littleEndian),
                    r: glyphBoundsDataView.getFloat32(b0 + 4, littleEndian),
                    b: glyphBoundsDataView.getFloat32(b0 + 8, littleEndian),
                    l: glyphBoundsDataView.getFloat32(b0 + 12, littleEndian),
                };
                gpuTextFont.glyphBounds[char] = bounds;
            }
        }
        // texture payload
        // textures may be in the payload or an external reference
        for (var p_1 = 0; p_1 < header.textures.length; p_1++) {
            var page = header.textures[p_1];
            gpuTextFont.textures[p_1] = [];
            for (var m = 0; m < page.length; m++) {
                var mipmap = page[m];
                if (mipmap.payloadBytes != null) {
                    // convert payload's image bytes into a HTMLImageElement object
                    var imageBufferView = new Uint8Array(buffer, payloadStart + mipmap.payloadBytes.start, mipmap.payloadBytes.length);
                    var imageBlob = new Blob([imageBufferView], { type: "image/png" });
                    var image = new Image();
                    image.src = URL.createObjectURL(imageBlob);
                    gpuTextFont.textures[p_1][m] = image;
                }
                else if (mipmap.localPath != null) {
                    // payload contains no image bytes; the image is store externally, pass on the path
                    gpuTextFont.textures[p_1][m] = {
                        localPath: mipmap.localPath
                    };
                }
            }
        }
        return gpuTextFont;
    };
    return GPUText;
}());
exports.default = GPUText;
