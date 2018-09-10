"use strict";

const GPUTextWebGL = (function(){

	function createShader(gl, code, type) {
		let s = gl.createShader(type);
		gl.shaderSource(s, code);
		gl.compileShader(s);
		if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
			let typename = null;
			switch (type) {
				case gl.VERTEX_SHADER: typename = 'vertex'; break;
				case gl.FRAGMENT_SHADER: typename = 'fragment'; break;
			}
			throw `[${typename} compile]: ${gl.getShaderInfoLog(s)}`;
		}
		return s;
	}

	return {
		generateMsdfShaderCode: function (options) {
			return {
				vertexCode: `
					#version 100

					precision mediump float;

					attribute vec2 position;
					attribute vec3 uv;

					uniform mat4 transform;
					uniform float fieldRange;
					uniform vec2 resolution;

					varying vec2 vUv;
					varying float vFieldRangeDisplay_px;

					void main() {
						vUv = uv.xy;

						// determine the field range in pixels when drawn to the framebuffer
						vec2 scale = abs(vec2(transform[0][0], transform[1][1]));
						float atlasScale = uv.z;
						vFieldRangeDisplay_px = fieldRange * scale.y * (resolution.y * 0.5) / atlasScale;
						vFieldRangeDisplay_px = max(vFieldRangeDisplay_px, 1.0);

						vec2 p = vec2(position.x * resolution.y / resolution.x, position.y);

						gl_Position = transform * vec4(p, 0.0, 1.0);
					}
				`,
				fragmentCode: `
					#version 100

					precision mediump float;     

					uniform vec4 color;
					uniform sampler2D glyphAtlas;

					uniform mat4 transform;

					varying vec2 vUv;
					varying float vFieldRangeDisplay_px;

					float median(float r, float g, float b) {
					    return max(min(r, g), min(max(r, g), b));
					}

					void main() {
						vec3 sample = texture2D(glyphAtlas, vUv).rgb;

						float sigDist = median(sample.r, sample.g, sample.b);

						// spread field range over 1px for antialiasing
						sigDist = clamp((sigDist - 0.5) * vFieldRangeDisplay_px + 0.5, 0.0, 1.0);

						float alpha = sigDist;

						gl_FragColor = color * alpha;
					}
				`,
				vertexAttribute: {
					position: {
						name: 'position',
						type: 'vec2',
					},
					uv: {
						name: 'uv',
						type: 'vec2',
					},
					atlasScale: {
						name: 'atlasScale',
						type: 'float',
					}
				},
				uniform: {
					transform: {
						name: 'transform',
						type: 'mat4'
					},
					color: {
						name: 'color',
						type: 'vec4'
					},
					glyphAtlas: {
						name: 'glyphAtlas',
						type: 'sampler2D'
					},
					fieldRange: {
						name: 'fieldRange',
						type: 'float'
					},
					resolution: {
						name: 'resolution',
						type: 'vec2'
					}
				}
			}
		},

		createTextProgram: function(gl, options, vertexCodeOverride, fragmentCodeOverride) {
			let msdfShaders = GPUTextWebGL.generateMsdfShaderCode({});

			let p = gl.createProgram();

			let vs = createShader(gl, vertexCodeOverride || msdfShaders.vertexCode, gl.VERTEX_SHADER);
			let fs = createShader(gl, fragmentCodeOverride || msdfShaders.fragmentCode, gl.FRAGMENT_SHADER);
			gl.attachShader(p, vs);
			gl.attachShader(p, fs);

			// must set bindings before linking
			gl.bindAttribLocation(p, 0, 'position');
			gl.bindAttribLocation(p, 1, 'uv');

			gl.linkProgram(p);

			gl.deleteShader(vs);
			gl.deleteShader(fs);

			if (!gl.getProgramParameter(p, gl.LINK_STATUS)) {
				throw `[program link]: ${gl.getProgramInfoLog(p)}`;
			}
			
			return {
				deviceHandle: p,
				attributeLocations: {
					position: 0,
					uv: 1,
				},
				uniformLocations: {
					transform: gl.getUniformLocation(p, msdfShaders.uniform.transform.name),
					color: gl.getUniformLocation(p, msdfShaders.uniform.color.name),
					glyphAtlas: gl.getUniformLocation(p, msdfShaders.uniform.glyphAtlas.name),
					fieldRange: gl.getUniformLocation(p, msdfShaders.uniform.fieldRange.name),
					resolution: gl.getUniformLocation(p, msdfShaders.uniform.resolution.name),
				}
			}
		},

		deleteTextProgram: function(gl, program) {
			gl.deleteProgram(program.deviceHandle);
			program.deviceHandle = null;
		},

		createTextBuffer: function(gl, vertexData) {
			let buffer = gl.createBuffer();
			gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
			gl.bufferData(gl.ARRAY_BUFFER, vertexData.vertexArray, gl.STATIC_DRAW);

			return {
				deviceHandle: buffer,
				vertexCount: vertexData.vertexCount,
				vertexLayout: vertexData.vertexLayout,
				drawMode: gl.TRIANGLES,
				frontFace: gl.CCW,
			};
		},

		deleteTextBuffer: function(gl, buffer) {
			gl.deleteBuffer(buffer.deviceHandle);
			buffer.deviceHandle = null;
		},

		createGlyphAtlas: function(gl, textureSource) {
			let mapTexture = gl.createTexture();
			gl.bindTexture(gl.TEXTURE_2D, mapTexture);
			gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, false);
			gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false);
			// gl.pixelStorei(gl.UNPACK_COLORSPACE_CONVERSION_WEBGL, gl.NONE); // @! review

			gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, textureSource);

			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

			// mip-map filtering
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
			gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
			gl.generateMipmap(gl.TEXTURE_2D);

			return mapTexture;
		},

		deleteGlyphAtlas: function(gl, textMap) {
			gl.deleteTexture(textMap);
		},
	}
})();

if (typeof module != 'undefined' && module.exports != null) {
	module.exports = GPUTextWebGL;
}