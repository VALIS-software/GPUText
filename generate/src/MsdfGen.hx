/**
	(unused and incomplete - kept for future use)
**/

@:include('msdfgen.h')
@:buildXml('
<files id="haxe">
	<compilerflag value="-I../msdfgen"/>
	<compilerflag value="-I../msdfgen/include"/>

	<file name="../msdfgen/core/Bitmap.cpp" />
	<file name="../msdfgen/core/Contour.cpp" />
	<file name="../msdfgen/core/edge-coloring.cpp" />
	<file name="../msdfgen/core/edge-segments.cpp" />
	<file name="../msdfgen/core/EdgeHolder.cpp" />
	<file name="../msdfgen/core/equation-solver.cpp" />
	<file name="../msdfgen/core/msdfgen.cpp" />
	<file name="../msdfgen/core/render-sdf.cpp" />
	<file name="../msdfgen/core/save-bmp.cpp" />
	<file name="../msdfgen/core/shape-description.cpp" />
	<file name="../msdfgen/core/Shape.cpp" />
	<file name="../msdfgen/core/SignedDistance.cpp" />
	<file name="../msdfgen/core/Vector2.cpp" />

	<file name="../msdfgen/ext/import-font.cpp" />
	<file name="../msdfgen/ext/import-svg.cpp" />
	<file name="../msdfgen/ext/save-png.cpp" />

	<file name="../msdfgen/lib/lodepng.cpp" />
	<file name="../msdfgen/lib/tinyxml2.cpp" />	
</files>

<target id="haxe">
	<lib name="/usr/local/lib/libfreetype.dylib" />
</target>
')
@:native('msdfgen')
extern class MsdfGen {

	/**
		void generateMSDF(
			Bitmap<FloatRGB> &output,
			const Shape &shape,
			double range,
			const Vector2 &scale,
			const Vector2 &translate,
			double edgeThreshold = 1.00000001
		);
	**/
	static public function generateSDF(): Void {

	}

}