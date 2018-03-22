package opentype;
/**
	
	@constructor
	
**/
extern class Layout {
	function new(font:Any, tableName:Any):Void;
	/**
		
		Binary search an object by "tag" property
		@param  {Array} arr
		@param  {string} tag
		@return {number}
		
	**/
	function searchTag(arr:Array<Any>, tag:String):Float;
	/**
		
		Binary search in a list of numbers
		@param  {Array} arr
		@param  {number} value
		@return {number}
		
	**/
	function binSearch(arr:Array<Any>, value:Float):Float;
	/**
		
		Get or create the Layout table (GSUB, GPOS etc).
		@param  {boolean} create - Whether to create a new one.
		@return {Object} The GSUB or GPOS table.
		
	**/
	function getTable(create:Bool):haxe.DynamicAccess<Any>;
	/**
		
		Returns all scripts in the substitution table.
		@instance
		@return {Array}
		
	**/
	function getScriptNames():Array<Any>;
	/**
		
		Returns all LangSysRecords in the given script.
		@instance
		@param {string} script - Use 'DFLT' for default script
		@param {boolean} create - forces the creation of this script table if it doesn't exist.
		@return {Array} Array on names
		
	**/
	function getScriptTable(script:String, create:Bool):Array<Any>;
	/**
		
		Returns a language system table
		@instance
		@param {string} script - Use 'DFLT' for default script
		@param {string} language - Use 'dlft' for default language
		@param {boolean} create - forces the creation of this langSysTable if it doesn't exist.
		@return {Object} An object with tag and script properties.
		
	**/
	function getLangSysTable(script:String, language:String, create:Bool):haxe.DynamicAccess<Any>;
	/**
		
		Get a specific feature table.
		@instance
		@param {string} script - Use 'DFLT' for default script
		@param {string} language - Use 'dlft' for default language
		@param {string} feature - One of the codes listed at https://www.microsoft.com/typography/OTSPEC/featurelist.htm
		@param {boolean} create - forces the creation of the feature table if it doesn't exist.
		@return {Object}
		
	**/
	function getFeatureTable(script:String, language:String, feature:String, create:Bool):haxe.DynamicAccess<Any>;
	/**
		
		Get the lookup tables of a given type for a script/language/feature.
		@instance
		@param {string} [script='DFLT']
		@param {string} [language='dlft']
		@param {string} feature - 4-letter feature code
		@param {number} lookupType - 1 to 8
		@param {boolean} create - forces the creation of the lookup table if it doesn't exist, with no subtables.
		@return {Object[]}
		
	**/
	function getLookupTables(script:String, language:String, feature:String, lookupType:Float, create:Bool):Array<haxe.DynamicAccess<Any>>;
	/**
		
		Returns the list of glyph indexes of a coverage table.
		Format 1: the list is stored raw
		Format 2: compact list as range records.
		@instance
		@param  {Object} coverageTable
		@return {Array}
		
	**/
	function expandCoverage(coverageTable:haxe.DynamicAccess<Any>):Array<Any>;
}