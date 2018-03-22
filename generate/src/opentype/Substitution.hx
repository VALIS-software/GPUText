package opentype;
/**
	
	@extends opentype.Layout
	@constructor
	@param {opentype.Font}
	
**/
extern class Substitution extends opentype.Layout {
	function new(font:opentype.Font):Void;
	/**
		
		Create a default GSUB table.
		@return {Object} gsub - The GSUB table.
		
	**/
	function createDefaultTable():haxe.DynamicAccess<Any>;
	/**
		
		List all single substitutions (lookup type 1) for a given script, language, and feature.
		@param {string} script
		@param {string} language
		@param {string} feature - 4-character feature name ('aalt', 'salt', 'ss01'...)
		@return {Array} substitutions - The list of substitutions.
		
	**/
	function getSingle(feature:String, script:String, language:String):Array<Any>;
	/**
		
		List all alternates (lookup type 3) for a given script, language, and feature.
		@param {string} feature - 4-character feature name ('aalt', 'salt'...)
		@param {string} script
		@param {string} language
		@return {Array} alternates - The list of alternates
		
	**/
	function getAlternates(feature:String, script:String, language:String):Array<Any>;
	/**
		
		List all ligatures (lookup type 4) for a given script, language, and feature.
		The result is an array of ligature objects like { sub: [ids], by: id }
		@param {string} feature - 4-letter feature name ('liga', 'rlig', 'dlig'...)
		@param {string} script
		@param {string} language
		@return {Array} ligatures - The list of ligatures.
		
	**/
	function getLigatures(feature:String, script:String, language:String):Array<Any>;
	/**
		
		Add or modify a single substitution (lookup type 1)
		Format 2, more flexible, is always used.
		@param {string} feature - 4-letter feature name ('liga', 'rlig', 'dlig'...)
		@param {Object} substitution - { sub: id, delta: number } for format 1 or { sub: id, by: id } for format 2.
		@param {string} [script='DFLT']
		@param {string} [language='dflt']
		
	**/
	function addSingle(feature:String, substitution:haxe.DynamicAccess<Any>, script:String, language:String):Void;
	/**
		
		Add or modify an alternate substitution (lookup type 1)
		@param {string} feature - 4-letter feature name ('liga', 'rlig', 'dlig'...)
		@param {Object} substitution - { sub: id, by: [ids] }
		@param {string} [script='DFLT']
		@param {string} [language='dflt']
		
	**/
	function addAlternate(feature:String, substitution:haxe.DynamicAccess<Any>, script:String, language:String):Void;
	/**
		
		Add a ligature (lookup type 4)
		Ligatures with more components must be stored ahead of those with fewer components in order to be found
		@param {string} feature - 4-letter feature name ('liga', 'rlig', 'dlig'...)
		@param {Object} ligature - { sub: [ids], by: id }
		@param {string} [script='DFLT']
		@param {string} [language='dflt']
		
	**/
	function addLigature(feature:String, ligature:haxe.DynamicAccess<Any>, script:String, language:String):Void;
	/**
		
		List all feature data for a given script and language.
		@param {string} feature - 4-letter feature name
		@param {string} [script='DFLT']
		@param {string} [language='dflt']
		@return {[type]} [description]
		@return {Array} substitutions - The list of substitutions.
		
	**/
	function getFeature(feature:String, script:String, language:String):Array<Any>;
	/**
		
		Add a substitution to a feature for a given script and language.
		@param {string} feature - 4-letter feature name
		@param {Object} sub - the substitution to add (an Object like { sub: id or [ids], by: id or [ids] })
		@param {string} [script='DFLT']
		@param {string} [language='dflt']
		
	**/
	function add(feature:String, sub:haxe.DynamicAccess<Any>, script:String, language:String):Void;
}