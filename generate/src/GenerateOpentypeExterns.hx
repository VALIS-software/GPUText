import haxe.macro.Expr;

using StringTools;

class GenerateOpentypeExterns {
	
	static function main() {
		// see https://github.com/nodebox/opentype.js/tree/cbf824f27b7250f287a66ed06b13700e5dc59fe2
		var jsExterns = sys.io.File.getContent('opentype-externs.js');

		var modules = ClosureExternConverter.convert(jsExterns);

		function addTypeDef(name, type: ComplexType) {
			var opentypeModule = modules.get('opentype');
			var fontOptionsDef: TypeDefinition = {
				pack: ['opentype'],
				name: name,
				pos: null,
				kind: TDAlias(type),
				fields: null
			}
			opentypeModule.set('opentype.$name', fontOptionsDef);
		}

		// manual fix-ups
		var opentypeDef = modules.get('opentype').get('opentype.Opentype');
		var load = opentypeDef.fields.filter(f -> f.name == 'load')[0];
		switch load.kind {
			case FFun({args: [_, cb = {name: callback}]}):
				cb.type = macro : String -> Font -> Void;
			default:
		}

		var fontDef = modules.get('opentype').get('opentype.Font');
		fontDef.fields = (macro class X {
			var names: {
				fontFamily: {en: String},
				fontSubfamily: {en: String},
				fullName: {en: String},
				postScriptName: {en: String},
				designer: {en: String},
				designerURL: {en: String},
				manufacturer: {en: String},
				manufacturerURL: {en: String},
				license: {en: String},
				licenseURL: {en: String},
				version: {en: String},
				description: {en: String},
				copyright: {en: String},
				trademark: {en: String},
			};
			var unitsPerEm: Int;
			var ascender: Float;
			var descender: Float;
			var createdTimestamp: Int;
			var tables:{
				os2: {
					usWeightClass: String,
					usWidthClass: String,
					fsSelection: String,
				}
			};

			var supported: Bool;
			var glyphs: {
				function get(index: Int): Glyph;
				function push(index: Int, loader: Any): Void;
				var length: Int;
			};

			// untyped fields
			var encoding: Any;
			var position: Any;
			var substitution: Any;
			var hinting: Any;
		}).fields.concat(fontDef.fields);

		// hardcoded types
		addTypeDef('FontOptions', macro : {
			empty: Bool,
			familyName: String,
			styleName: String,
			?fullName: String,
			?postScriptName: String,
			?designer: String,
			?designerURL: String,
			?manufacturer: String,
			?manufacturerURL: String,
			?license: String,
			?licenseURL: String,
			?version: String,
			?description: String,
			?copyright: String,
			?trademark: String,
			unitsPerEm: Float,
			ascender: Float,
			descender: Float,
			createdTimestamp: Float,
			?weightClass: String,
			?widthClass: String,
			?fsSelection: String,
		});
		addTypeDef('GlyphOptions', macro :{
			name: String,
			unicode: Int,
			unicodes: Array<Int>,
			xMin: Float,
			yMin: Float,
			xMax: Float,
			yMax: Float,
			advanceWidth: Float,			
		});

		// save results to disk
		var hxPrinter = new haxe.macro.Printer();

		for (modulePath in modules.keys()) {
			var module = modules.get(modulePath);

			sys.FileSystem.createDirectory(modulePath.split('.').join('/'));

			for (classPath in module.keys()) {

				var filePath = classPath.split('.').join('/') + '.hx';
				var classDef = module.get(classPath);

				sys.io.File.saveContent(filePath, hxPrinter.printTypeDefinition(classDef, true));
				trace('Saved "$filePath"');
			}

		}

	}

}


/*
	Incomplete parser for closure compiler externs
	https://github.com/google/closure-compiler/wiki
*/
class ClosureExternConverter {

	static public function convert(externContent: String) {
		// module = map of classes
		var modules = new Map<String, Map<String, TypeDefinition>>();

		function getModule(path: Array<String>) {
			var pathStr = path.join('.');
			var module = modules.get(pathStr);
			if (module == null) {
				throw 'Module "${pathStr}" has not been defined';
			}
			return module;
		}

		// everything between /** */
		var e = EReg.escape;
		var docPattern = new EReg('${ e('/**') }((.|\n)+?)(?=${ e('*/') })${ e('*/\n') }', 'm');

		var modulePattern = ~/^\s*(var|let|const)\s+(\w+)/;
		var moduleFieldPattern = ~/^\s*([\w.]*)\b([a-z_]\w+)(\s*=\s*([^\n]*))?/;
		var classPattern = ~/^\s*([\w.]*)\b([A-Z_]\w+)\s*=\s*([^\n]*)/;
		var classFieldPattern = ~/^\s*([\w.]*)\b([A-Z_]\w+)\.prototype\.(\w+)(\s*=\s*([^\n]*))?/;

		var constructorMetaPattern = ~/^@constructor\b/m;
		var extendsMetaPattern = ~/^@extends\s+{?([^}\n]*)}?/m;

		var str = externContent;
		while (docPattern.match(str)) {
			var doc = cleanDoc(docPattern.matched(1));

			str = docPattern.matchedRight();
			var nextLineEnd = str.indexOf('\n');
			var nextLine = str.substring(0, nextLineEnd);
			// skip line
			str = str.substr(nextLineEnd);
			
			if (modulePattern.match(nextLine)) {

				var modulePath = parseModulePath(modulePattern.matched(2));
				var moduleName = modulePath[modulePath.length - 1];
				// trace('Found module', modulePattern.matched(2), modulePath.join('.'));

				modules.set(modulePath.join('.'), new Map());

				// create a module class for any static methods
				var className = toClassName(moduleName);
				var classPath = modulePath.concat([className]).join('.');
				var classDef = macro class $className {};
				classDef.meta = [{name: ':jsRequire', params: [{expr: EConst(CString(moduleName)), pos: null}], pos: null}];
				classDef.isExtern = true;
				classDef.doc = doc;
				classDef.pack = modulePath;

				getModule(modulePath).set(classPath, classDef);

			} else if (classPattern.match(nextLine)) {

				var modulePath = parseModulePath(classPattern.matched(1));
				var className = classPattern.matched(2);
				var expression = classPattern.matched(3);

				var classDef = macro class $className {};

				if (constructorMetaPattern.match(doc)) {
					var ctorDef = parseFunction(expression, doc);
					ctorDef.name = 'new';
					classDef.fields.push(ctorDef);
				}

				if (extendsMetaPattern.match(doc)) {
					var superPath = extendsMetaPattern.matched(1);
					var parts = superPath.split('.');
					var superClass: TypePath = {
						pack: parts.slice(0, parts.length - 1),
						name: parts[parts.length - 1]
					}
					classDef.kind = TDClass(superClass);
				}

				classDef.isExtern = true;
				classDef.doc = doc;
				classDef.pack = modulePath;

				var classPath = modulePath.concat([className]).join('.');

				getModule(modulePath).set(classPath, classDef);

			} else if (classFieldPattern.match(nextLine)) {
				var modulePath = parseModulePath(classFieldPattern.matched(1));
				var className = classFieldPattern.matched(2);
				var fieldName = classFieldPattern.matched(3);
				var expression = classFieldPattern.matched(5);

				var classPath = modulePath.concat([className]).join('.'); 

				// trace('field', classPath, fieldName);

				var classDef = getModule(modulePath).get(classPath);
				if (classDef == null) throw 'Class $classPath not defined';

				// parse field
				var fieldDef = parseField(fieldName, expression, doc);

				classDef.fields.push(fieldDef);

			} else if (moduleFieldPattern.match(nextLine)) {
				var modulePath = parseModulePath(moduleFieldPattern.matched(1));
				var className = toClassName(modulePath[modulePath.length - 1]);
				var classPath = modulePath.concat([className]).join('.');
				var fieldName = moduleFieldPattern.matched(2);
				var expression = moduleFieldPattern.matched(3);

				// get module class
				var classDef = getModule(modulePath).get(classPath);

				var fieldDef = parseField(fieldName, expression, doc);
				fieldDef.access = [AStatic, APublic];
				classDef.fields.push(fieldDef);

			} else if (StringTools.trim(nextLine) != '') {

				trace('Unknown line format "$nextLine"');

			}
		}

		return modules;
	}

	static function parseType(typeStr: String): ComplexType {
		typeStr = StringTools.trim(typeStr);
		var builtIn = switch typeStr.toLowerCase() {
			case 'string': macro :String;
			case 'number': macro :Float;
			case 'boolean': macro :Bool;
			case 'array': macro :Array<Any>;
			case 'object': macro :haxe.DynamicAccess<Any>;
			case 'function': macro :Any;

			// convert js type names into haxe type names
			// this list could be fully completed by iterating all items in js and finding their @:native metadata
			case 'canvasrenderingcontext2d': macro :js.html.CanvasRenderingContext2D;
			case 'arraybuffer': macro :js.html.ArrayBuffer;
			case 'svgpathelement': macro :js.html.svg.PathElement;

			default: null;
		}

		if (builtIn != null) return builtIn;

		var arrayPattern = ~/^(\[(.*)\]|(.*)\[\]|Array<(.*)>)$/;
		if (arrayPattern.match(typeStr)) {
			var innerTypeStr =
				arrayPattern.matched(2) != null ? arrayPattern.matched(2) : 
					(arrayPattern.matched(3) != null ? arrayPattern.matched(3) : arrayPattern.matched(4));
			var innerType = parseType(innerTypeStr);
			return macro :Array<$innerType>;
		}

		if (!~/^[\w.]+$/.match(typeStr)) {
			throw 'Unhandled type syntax: "$typeStr"';
		}

		return TPath({pack: [], name: typeStr});
	}

	static function parseFunction(functionDeclExpression: String, doc: String): Field {
		var functionDecl = ~/function\s*(\w+)?\s*\(([^)]*)\)/m;
		var paramMetaPattern = ~/^@param\s+{([^}]*)}(\s+\[?(\w+))?/mg;
		var returnMetaPattern = ~/^@return\s+{([^}]*)}/m;

		if (!functionDecl.match(functionDeclExpression)) {
			throw 'Unhandled function declaration';
		}

		var funcName = functionDecl.matched(1);
		var argNames = functionDecl.matched(2)
			.split(',').map(s -> StringTools.trim(s))
			.filter(s -> s != '');
		var argTypes = new Map<String, {t: ComplexType, opt: Bool}>();
		var returnType = macro :Void;

		// match function hints
		paramMetaPattern.map(doc, s -> {
			var typeStr = paramMetaPattern.matched(1).trim();

			var optional = false;
			if (typeStr.charAt(typeStr.length - 1) == '=') {
				typeStr = typeStr.substr(0, typeStr.length - 1);
				optional = true;
			}

			var type = parseType(typeStr);
			var name = paramMetaPattern.matched(3);
			if (name == null) name = argNames[0];

			argTypes.set(name, {t: type, opt: optional});

			return s.matched(0);
		});

		if (returnMetaPattern.match(doc)) {
			returnType = parseType(returnMetaPattern.matched(1));
		}

		return {
			name: funcName,
			kind: FFun({
				args: argNames.map(name -> {
					name: name,
					type: argTypes.exists(name) ? argTypes.get(name).t : macro :Any,
					meta: null,
					opt: argTypes.exists(name) ? argTypes.get(name).opt : false,
					value: null,
				}),
				expr: null,
				ret: returnType,
			}),
			pos: null
		}
	}

	static function parseField(fieldName: String, expression: String, doc: String) {
		var typeMetaPattern = ~/^@type\s+{([^}]*)}/m;

		// default to var $fieldName:Any
		var fieldDef = (macro class X {
			var $fieldName: Any;
		}).fields[0];

		if (typeMetaPattern.match(doc)) {
			var type = parseType(typeMetaPattern.matched(1));
			fieldDef = (macro class X {
				var $fieldName: $type;
			}).fields[0];
		} else {
			fieldDef = parseFunction(expression, doc);
			fieldDef.name = fieldName;
		}

		fieldDef.doc = doc;

		return fieldDef;
	}

	static function parseModulePath(str: String) {
		return str.split('.').filter(s -> s != '');
	}

	static function toClassName(str: String) {
		return str.charAt(0).toUpperCase() + str.substr(1);
	}

	static function cleanDoc(doc: String) {
		return doc.split('\n')
			.map(l -> StringTools.trim(l))
			.map(l -> l.charAt(0) == '*' ? StringTools.trim(l.substr(1)) : l)
			.join('\n');
	}

}