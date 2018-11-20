# GPU Text

Engine agnostic GPU text rendering

[Demo](https://valis-software.github.io/GPUText/example)

# Building /dist

```
npm install
npm run build
```

## GPU Text Font Generator
##### Usage
```
['--charset'] <path>              : Path of file containing character set
['--charlist'] <characters>       : List of characters
['--output-dir', '-o'] <path>     : Sets the path of the output font file. External resources will be saved in the same directory
['--technique'] <name>            : Font rendering technique, one of: msdf, sdf, bitmap
['--msdfgen'] <path>              : Path of msdfgen executable
['--size'] <glyphSize>            : Maximum dimension of a glyph in pixels
['--pxrange'] <range>             : Specifies the width of the range around the shape between the minimum and maximum representable signed distance in pixels
['--max-texture-size'] <size>     : Sets the maximum dimension of the texture atlas
['--bounds'] <enabled>            : Enables storing glyph bounding boxes in the font (default false)
['--binary'] <enabled>            : Saves the font in the binary format (experimental; default false)
['--external-textures'] <enabled> : When store textures externally when saving in the binary format
['--help']                        : Shows this help
_ <path>                          : Path of TrueType font file (.ttf)
```

##### Example Font Generation
Checkout this repo
```
> ./cli.js source-fonts/OpenSans/OpenSans-Regular.ttf --binary true
```

##### Building
The atlas tool depends on [msdfgen](https://github.com/Chlumsky/msdfgen), a command-line tool to generate MSDF distance fields for TrueType glyphs.
Checkout the msdfgen submodule and build it (after installing msdfgen dependencies)
```
git submodule init
cd msdfgen
cmake .
make
```

Then with haxe 4.0.0:
```
haxelib install build.hxml
haxe build.hxml
```

## Release Todos
- prebuilt msdfgen for windows
- Complex layout demo
	- Text of different fonts within a single layout
- Document public methods
- Manually generate signed distance atlas mipmaps (this improves quality at low font sizes)
	- Store mipmap level in alpha and use to offset uvs to precise pixel coords
- Support 3D anti-aliasing
- Create examples for other libraries
	- three.js