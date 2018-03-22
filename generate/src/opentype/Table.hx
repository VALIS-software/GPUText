package opentype;
/**
	
	@param {string} tableName
	@param {Array} fields
	@param {Object} options
	@constructor
	
**/
extern class Table {
	function new(tableName:String, fields:Array<Any>, options:haxe.DynamicAccess<Any>):Void;
	/**
		
		Encodes the table and returns an array of bytes
		@return {Array}
		
	**/
	function encode():Array<Any>;
	/**
		
		Get the size of the table.
		@return {number}
		
	**/
	function sizeOf():Float;
	/**
		
		@type {string}
		
	**/
	var tableName : String;
	/**
		
		@type {Array}
		
	**/
	var fields : Array<Any>;
}