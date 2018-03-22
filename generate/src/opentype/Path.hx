package opentype;
/**
	
	A bézier path containing a set of path commands similar to a SVG path.
	Paths can be drawn on a context using `draw`.
	@constructor
	
**/
extern class Path {
	function new():Void;
	/**
		
		@param  {number} x
		@param  {number} y
		
	**/
	function moveTo(x:Float, y:Float):Void;
	/**
		
		@param  {number} x
		@param  {number} y
		
	**/
	function lineTo(x:Float, y:Float):Void;
	/**
		
		Draws cubic curve
		@param  {number} x1 - x of control 1
		@param  {number} y1 - y of control 1
		@param  {number} x2 - x of control 2
		@param  {number} y2 - y of control 2
		@param  {number} x - x of path point
		@param  {number} y - y of path point
		
	**/
	function curveTo(x1:Float, y1:Float, x2:Float, y2:Float, x:Float, y:Float):Void;
	/**
		
		Draws cubic curve
		@param  {number} x1 - x of control 1
		@param  {number} y1 - y of control 1
		@param  {number} x2 - x of control 2
		@param  {number} y2 - y of control 2
		@param  {number} x - x of path point
		@param  {number} y - y of path point
		
	**/
	function bezierCurveTo(x1:Float, y1:Float, x2:Float, y2:Float, x:Float, y:Float):Void;
	/**
		
		Draws quadratic curve
		@param  {number} x1 - x of control
		@param  {number} y1 - y of control
		@param  {number} x - x of path point
		@param  {number} y - y of path point
		
	**/
	function quadTo(x1:Float, y1:Float, x:Float, y:Float):Void;
	/**
		
		Draws quadratic curve
		@param  {number} x1 - x of control
		@param  {number} y1 - y of control
		@param  {number} x - x of path point
		@param  {number} y - y of path point
		
	**/
	function quadraticCurveTo(x1:Float, y1:Float, x:Float, y:Float):Void;
	/**
		
		Close the path
		
	**/
	function close():Void;
	/**
		
		Closes the path
		
	**/
	function closePath():Void;
	/**
		
		Add the given path or list of commands to the commands of this path.
		@param  {Array} pathOrCommands - another opentype.Path, an opentype.BoundingBox, or an array of commands.
		
	**/
	function extend(pathOrCommands:Array<Any>):Void;
	/**
		
		Calculate the bounding box of the path.
		@returns {opentype.BoundingBox}
		
	**/
	function getBoundingBox():Void;
	/**
		
		@param {CanvasRenderingContext2D} ctx - A 2D drawing context.
		
	**/
	function draw(ctx:js.html.CanvasRenderingContext2D):Void;
	/**
		
		@param  {number} [decimalPlaces=2] - The amount of decimal places for floating-point values
		@return {string}
		
	**/
	function toPathData(decimalPlaces:Float):String;
	/**
		
		@param  {number} [decimalPlaces=2] - The amount of decimal places for floating-point values
		@return {string}
		
	**/
	function toSVG(decimalPlaces:Float):String;
	/**
		
		Convert the path to a DOM element.
		@param  {number} [decimalPlaces=2] - The amount of decimal places for floating-point values
		@return {SVGPathElement}
		
	**/
	function toDOMElement(decimalPlaces:Float):js.html.svg.PathElement;
}