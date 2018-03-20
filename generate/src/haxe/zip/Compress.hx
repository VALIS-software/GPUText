package haxe.zip;

class Compress {

	public static function run( s : haxe.io.Bytes, level : Int ) : haxe.io.Bytes {
		var result = pako.Pako.deflate(haxe.io.UInt8Array.fromBytes(s), {level: level});
		return result.view.buffer;
	}

}