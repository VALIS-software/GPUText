package opentype;
/**
	
	@extends {opentype.Table}
	@param {opentype.Table} lookupListTable
	@param {Object} subtableMakers
	@constructor
	
**/
extern class LookupList extends opentype.Table {
	function new(lookupListTable:opentype.Table, subtableMakers:haxe.DynamicAccess<Any>):Void;
}