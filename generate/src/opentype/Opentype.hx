package opentype;
/**
	@const
**/
@:jsRequire("opentype") extern class Opentype {
	/**
		
		@param  {string} url - The URL of the font to load.
		@param  {Function} callback - The callback.
		
	**/
	static public function load(url:String, callback:String -> Font -> Void):Void;
	/**
		
		@param  {string} url - The URL of the font to load.
		@return {opentype.Font}
		
	**/
	static public function loadSync(url:String):opentype.Font;
}