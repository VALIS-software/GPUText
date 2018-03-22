package opentype;
/**
	
	@param {GlyphOptions}
	@constructor
	
**/
extern class Glyph {
	function new(options:GlyphOptions):Void;
	/**
		
		@param {number}
		
	**/
	function addUnicode(unicode:Float):Void;
	/**
		
		Calculate the minimum bounding box for this glyph.
		@return {opentype.BoundingBox}
		
	**/
	function getBoundingBox():opentype.BoundingBox;
	/**
		
		Convert the glyph to a Path we can draw on a drawing context.
		@param  {number} [x=0] - Horizontal position of the beginning of the text.
		@param  {number} [y=0] - Vertical position of the *baseline* of the text.
		@param  {number} [fontSize=72] - Font size in pixels. We scale the glyph units by `1 / unitsPerEm * fontSize`.
		@param  {Object=} options - xScale, yScale to strech the glyph.
		@return {opentype.Path}
		
	**/
	function getPath(x:Float, y:Float, fontSize:Float, ?options:haxe.DynamicAccess<Any>):opentype.Path;
	/**
		
		Split the glyph into contours.
		This function is here for backwards compatibility, and to
		provide raw access to the TrueType glyph outlines.
		@return {Array}
		
	**/
	function getContours():Array<Any>;
	/**
		
		Calculate the xMin/yMin/xMax/yMax/lsb/rsb for a Glyph.
		@return {Object}
		
	**/
	function getMetrics():haxe.DynamicAccess<Any>;
	/**
		
		Draw the glyph on the given context.
		@param  {CanvasRenderingContext2D} ctx - A 2D drawing context, like Canvas.
		@param  {number} [x=0] - Horizontal position of the beginning of the text.
		@param  {number} [y=0] - Vertical position of the *baseline* of the text.
		@param  {number} [fontSize=72] - Font size in pixels. We scale the glyph units by `1 / unitsPerEm * fontSize`.
		@param  {Object=} options - xScale, yScale to strech the glyph.
		
	**/
	function draw(ctx:js.html.CanvasRenderingContext2D, x:Float, y:Float, fontSize:Float, ?options:haxe.DynamicAccess<Any>):Void;
	/**
		
		Draw the points of the glyph.
		On-curve points will be drawn in blue, off-curve points will be drawn in red.
		@param  {CanvasRenderingContext2D} ctx - A 2D drawing context, like Canvas.
		@param  {number} [x=0] - Horizontal position of the beginning of the text.
		@param  {number} [y=0] - Vertical position of the *baseline* of the text.
		@param  {number} [fontSize=72] - Font size in pixels. We scale the glyph units by `1 / unitsPerEm * fontSize`.
		
	**/
	function drawPoints(ctx:js.html.CanvasRenderingContext2D, x:Float, y:Float, fontSize:Float):Void;
	/**
		
		Draw lines indicating important font measurements.
		Black lines indicate the origin of the coordinate system (point 0,0).
		Blue lines indicate the glyph bounding box.
		Green line indicates the advance width of the glyph.
		@param  {CanvasRenderingContext2D} ctx - A 2D drawing context, like Canvas.
		@param  {number} [x=0] - Horizontal position of the beginning of the text.
		@param  {number} [y=0] - Vertical position of the *baseline* of the text.
		@param  {number} [fontSize=72] - Font size in pixels. We scale the glyph units by `1 / unitsPerEm * fontSize`.
		
	**/
	function drawMetrics(ctx:js.html.CanvasRenderingContext2D, x:Float, y:Float, fontSize:Float):Void;
}