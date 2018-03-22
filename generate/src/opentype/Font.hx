package opentype;
/**
	
	A Font represents a loaded OpenType font file.
	It contains a set of glyphs and methods to draw text on a drawing context,
	or to get a path representing the text.
	@param {FontOptions}
	@constructor
	
**/
extern class Font {
	var names : { var fontFamily : { var en : String; }; var fontSubfamily : { var en : String; }; var fullName : { var en : String; }; var postScriptName : { var en : String; }; var designer : { var en : String; }; var designerURL : { var en : String; }; var manufacturer : { var en : String; }; var manufacturerURL : { var en : String; }; var license : { var en : String; }; var licenseURL : { var en : String; }; var version : { var en : String; }; var description : { var en : String; }; var copyright : { var en : String; }; var trademark : { var en : String; }; };
	var unitsPerEm : Int;
	var ascender : Float;
	var descender : Float;
	var createdTimestamp : Int;
	var tables : { var os2 : { var usWeightClass : String; var usWidthClass : String; var fsSelection : String; }; };
	var supported : Bool;
	var glyphs : { function get(index:Int):Glyph; function push(index:Int, loader:Any):Void; var length : Int; };
	var encoding : Any;
	var position : Any;
	var substitution : Any;
	var hinting : Any;
	function new(options:FontOptions):Void;
	/**
		
		Check if the font has a glyph for the given character.
		@param  {string}
		@return {Boolean}
		
	**/
	function hasChar(c:String):Bool;
	/**
		
		Convert the given character to a single glyph index.
		Note that this function assumes that there is a one-to-one mapping between
		the given character and a glyph; for complex scripts this might not be the case.
		@param  {string}
		@return {Number}
		
	**/
	function charToGlyphIndex(s:String):Float;
	/**
		
		Convert the given character to a single Glyph object.
		Note that this function assumes that there is a one-to-one mapping between
		the given character and a glyph; for complex scripts this might not be the case.
		@param  {string} c
		@return {opentype.Glyph}
		
	**/
	function charToGlyph(c:String):opentype.Glyph;
	/**
		
		Convert the given text to a list of Glyph objects.
		Note that there is no strict one-to-one mapping between characters and
		glyphs, so the list of returned glyphs can be larger or smaller than the
		length of the given string.
		@param  {string} s
		@param  {Object=} options
		@return {opentype.Glyph[]}
		
	**/
	function stringToGlyphs(s:String, ?options:haxe.DynamicAccess<Any>):Array<opentype.Glyph>;
	/**
		
		@param  {string}
		@return {Number}
		
	**/
	function nameToGlyphIndex(name:String):Float;
	/**
		
		@param  {string}
		@return {opentype.Glyph}
		
	**/
	function nameToGlyph(name:String):opentype.Glyph;
	/**
		
		@param  {Number}
		@return {String}
		
	**/
	function glyphIndexToName(gid:Float):String;
	/**
		
		Retrieve the value of the kerning pair between the left glyph (or its index)
		and the right glyph (or its index). If no kerning pair is found, return 0.
		The kerning value gets added to the advance width when calculating the spacing
		between glyphs.
		@param  {opentype.Glyph} leftGlyph
		@param  {opentype.Glyph} rightGlyph
		@return {Number}
		
	**/
	function getKerningValue(leftGlyph:opentype.Glyph, rightGlyph:opentype.Glyph):Float;
	/**
		
		Helper function that invokes the given callback for each glyph in the given text.
		The callback gets `(glyph, x, y, fontSize, options)`.* @param  {string} text
		@param  {number} x - Horizontal position of the beginning of the text.
		@param  {number} y - Vertical position of the *baseline* of the text.
		@param  {number} fontSize - Font size in pixels. We scale the glyph units by `1 / unitsPerEm * fontSize`.
		@param  {Object} options
		@param  {Function} callback
		
	**/
	function forEachGlyph(text:Any, x:Float, y:Float, fontSize:Float, options:haxe.DynamicAccess<Any>, callback:Any):Void;
	/**
		
		Create a Path object that represents the given text.
		@param  {string} text - The text to create.
		@param  {number} [x=0] - Horizontal position of the beginning of the text.
		@param  {number} [y=0] - Vertical position of the *baseline* of the text.
		@param  {number} [fontSize=72] - Font size in pixels. We scale the glyph units by `1 / unitsPerEm * fontSize`.
		@param  {Object=} options
		@return {opentype.Path}
		
	**/
	function getPath(text:String, x:Float, y:Float, fontSize:Float, ?options:haxe.DynamicAccess<Any>):opentype.Path;
	/**
		
		Create an array of Path objects that represent the glyps of a given text.
		@param  {string} text - The text to create.
		@param  {number} [x=0] - Horizontal position of the beginning of the text.
		@param  {number} [y=0] - Vertical position of the *baseline* of the text.
		@param  {number} [fontSize=72] - Font size in pixels. We scale the glyph units by `1 / unitsPerEm * fontSize`.
		@param  {Object=} options
		@return {opentype.Path[]}
		
	**/
	function getPaths(text:String, x:Float, y:Float, fontSize:Float, ?options:haxe.DynamicAccess<Any>):Array<opentype.Path>;
	/**
		
		Draw the text on the given drawing context.
		@param  {CanvasRenderingContext2D} ctx - A 2D drawing context, like Canvas.
		@param  {string} text - The text to create.
		@param  {number} [x=0] - Horizontal position of the beginning of the text.
		@param  {number} [y=0] - Vertical position of the *baseline* of the text.
		@param  {number} [fontSize=72] - Font size in pixels. We scale the glyph units by `1 / unitsPerEm * fontSize`.
		@param  {Object=} options
		
	**/
	function draw(ctx:js.html.CanvasRenderingContext2D, text:String, x:Float, y:Float, fontSize:Float, ?options:haxe.DynamicAccess<Any>):Void;
	/**
		
		Draw the points of all glyphs in the text.
		On-curve points will be drawn in blue, off-curve points will be drawn in red.
		@param {CanvasRenderingContext2D} ctx - A 2D drawing context, like Canvas.
		@param {string} text - The text to create.
		@param {number} [x=0] - Horizontal position of the beginning of the text.
		@param {number} [y=0] - Vertical position of the *baseline* of the text.
		@param {number} [fontSize=72] - Font size in pixels. We scale the glyph units by `1 / unitsPerEm * fontSize`.
		@param {Object=} options
		
	**/
	function drawPoints(ctx:js.html.CanvasRenderingContext2D, text:String, x:Float, y:Float, fontSize:Float, ?options:haxe.DynamicAccess<Any>):Void;
	/**
		
		Draw lines indicating important font measurements for all glyphs in the text.
		Black lines indicate the origin of the coordinate system (point 0,0).
		Blue lines indicate the glyph bounding box.
		Green line indicates the advance width of the glyph.
		@param {CanvasRenderingContext2D} ctx - A 2D drawing context, like Canvas.
		@param {string} text - The text to create.
		@param {number} [x=0] - Horizontal position of the beginning of the text.
		@param {number} [y=0] - Vertical position of the *baseline* of the text.
		@param {number} [fontSize=72] - Font size in pixels. We scale the glyph units by `1 / unitsPerEm * fontSize`.
		@param {Object=} options
		
	**/
	function drawMetrics(ctx:js.html.CanvasRenderingContext2D, text:String, x:Float, y:Float, fontSize:Float, ?options:haxe.DynamicAccess<Any>):Void;
	/**
		
		@param  {string}
		@return {string}
		
	**/
	function getEnglishName(name:String):String;
	/**
		
		Validate
		
	**/
	function validate():Void;
	/**
		
		Convert the font object to a SFNT data structure.
		This structure contains all the necessary tables and metadata to create a binary OTF file.
		@return {opentype.Table}
		
	**/
	function toTables():opentype.Table;
	/**
		
		@deprecated Font.toBuffer is deprecated. Use Font.toArrayBuffer instead.
		
	**/
	function toBuffer():Void;
	/**
		
		Converts a `opentype.Font` into an `ArrayBuffer`
		@return {ArrayBuffer}
		
	**/
	function toArrayBuffer():js.html.ArrayBuffer;
	/**
		
		Initiate a download of the OpenType font.
		@param {string=} fileName
		
	**/
	function download(?fileName:String):Void;
}