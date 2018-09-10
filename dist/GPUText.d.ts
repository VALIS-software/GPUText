/**
    Provides text layout, vertex buffer generation and file parsing

    Dev notes:
    - Should have progressive layout where text can be appended to an existing layout
**/
declare class GPUText {
    static layout(text: string, font: GPUTextFont, layoutOptions: {
        kerningEnabled?: boolean;
        ligaturesEnabled?: boolean;
        lineHeight?: number;
        glyphScale?: number;
    }): GlyphLayout;
    /**
        Generates OpenGL coordinates where y increases from bottom to top

        @! improve docs

        => float32, [p, p, u, u, u], triangles with CCW face winding
    **/
    static generateVertexData(glyphLayout: GlyphLayout): {
        vertexArray: Float32Array;
        elementsPerVertex: number;
        vertexCount: number;
        vertexLayout: {
            position: {
                elements: number;
                elementSizeBytes: number;
                strideBytes: number;
                offsetBytes: number;
            };
            uv: {
                elements: number;
                elementSizeBytes: number;
                strideBytes: number;
                offsetBytes: number;
            };
        };
    };
    /**
     * Given buffer containing a binary GPUText file, parse it and generate a GPUTextFont object
     * @throws string on parse errors
     */
    static parse(buffer: ArrayBuffer): GPUTextFont;
}
export interface GPUTextFont extends GPUTextFontBase {
    characters: {
        [character: string]: TextureAtlasCharacter | null;
    };
    kerning: {
        [characterPair: string]: number;
    };
    glyphBounds?: {
        [character: string]: {
            l: number;
            b: number;
            r: number;
            t: number;
        };
    };
    textures: Array<Array<{
        localPath: string;
    } | HTMLImageElement>>;
}
export interface GlyphLayout {
    font: GPUTextFont;
    sequence: Array<{
        char: string;
        x: number;
        y: number;
    }>;
    bounds: {
        l: number;
        r: number;
        t: number;
        b: number;
    };
    glyphScale: number;
}
export interface TextureAtlasGlyph {
    atlasRect: {
        x: number;
        y: number;
        w: number;
        h: number;
    };
    atlasScale: number;
    offset: {
        x: number;
        y: number;
    };
}
export interface TextureAtlasCharacter {
    advance: number;
    glyph?: TextureAtlasGlyph;
}
export interface ResourceReference {
    payloadBytes?: {
        start: number;
        length: number;
    };
    localPath?: string;
}
declare type GPUTextFormat = 'TextureAtlasFontJson' | 'TextureAtlasFontBinary';
declare type GPUTextTechnique = 'msdf' | 'sdf' | 'bitmap';
interface GPUTextFontMetadata {
    family: string;
    subfamily: string;
    version: string;
    postScriptName: string;
    copyright: string;
    trademark: string;
    manufacturer: string;
    manufacturerURL: string;
    designerURL: string;
    license: string;
    licenseURL: string;
    height_funits: number;
    funitsPerEm: number;
}
interface GPUTextFontBase {
    format: GPUTextFormat;
    version: number;
    technique: GPUTextTechnique;
    textureSize: {
        w: number;
        h: number;
    };
    ascender: number;
    descender: number;
    typoAscender: number;
    typoDescender: number;
    lowercaseHeight: number;
    metadata: GPUTextFontMetadata;
    fieldRange_px: number;
}
export default GPUText;
