package opentype;
typedef FontOptions = {
	var empty : Bool;
	var familyName : String;
	var styleName : String;
	@:optional
	var fullName : String;
	@:optional
	var postScriptName : String;
	@:optional
	var designer : String;
	@:optional
	var designerURL : String;
	@:optional
	var manufacturer : String;
	@:optional
	var manufacturerURL : String;
	@:optional
	var license : String;
	@:optional
	var licenseURL : String;
	@:optional
	var version : String;
	@:optional
	var description : String;
	@:optional
	var copyright : String;
	@:optional
	var trademark : String;
	var unitsPerEm : Float;
	var ascender : Float;
	var descender : Float;
	var createdTimestamp : Float;
	@:optional
	var weightClass : String;
	@:optional
	var widthClass : String;
	@:optional
	var fsSelection : String;
};