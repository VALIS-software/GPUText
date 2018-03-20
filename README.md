# GPU Text

Engine agnostic GPU text rendering

## Todo before public release
- Manually generate signed distance atlas mipmaps (this improves quality at low font sizes)
	- Store mipmap level in alpha and use to offset uvs to precise pixel coords
- Complex layout demo
	- Text of different fonts within a single layout
- Document public methods
- Binary format
- Support more techniques

Available techniques
- MSDF