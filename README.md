# GPU Text

Engine agnostic GPU text rendering

## Font Atlas Generator
**Usage**
```
['--charset'] <path>          : Path of file containing character set
['--charlist'] <characters>   : List of characters
['--output-dir', '-o'] <path> : Sets the path of the output font file. External resources will be saved in the same directory
['--technique'] <name>        : Font rendering technique, one of: msdf, sdf, bitmap
['--msdfgen'] <path>          : Path of msdfgen executable
['--size'] <glyphSize>        : Maximum dimension of a glyph in pixels
['--pxrange'] <range>         : Specifies the width of the range around the shape between the minimum and maximum representable signed distance in pixels
['--max-texture-size'] <size> : Sets the maximum dimension of the texture atlas
['--help']                    : Shows this help
_ <path>                      : Path of TrueType font file
```

**Example**
```
> node font-atlas.js source-fonts/OpenSans/OpenSans-Regular.ttf
```

**Building**
With haxe 4.0.0:
```
haxelib install build.hxml
haxe build.hxml
```

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