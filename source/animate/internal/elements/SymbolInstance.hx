package animate.internal.elements;

import animate.FlxAnimateJson;
import animate.internal.elements.Element;
import animate.internal.filters.Blend;
import flixel.FlxCamera;
import flixel.math.FlxMath;
import flixel.math.FlxMatrix;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import openfl.display.BlendMode;
import openfl.geom.ColorTransform;

using flixel.util.FlxColorTransformUtil;

class SymbolInstance extends AnimateElement<SymbolInstanceJson>
{
	public var libraryItem:SymbolItem;
	public var blend:BlendMode;
	public var firstFrame:Int;
	public var loopType:LoopType;
	public var symbolName(get, never):String;
	public var transformationPoint:FlxPoint;

	// 新增：Animate 实例名（IN 字段），IK 节点靠它识别
	public var instanceName:Null<String>;

	// 新增：是否 IK 节点（骨骼零件）
	public var isIKNode:Bool = false;

	var isColored:Bool;
	var transform:ColorTransform;
	var _transform:ColorTransform;

	public function new(?data:SymbolInstanceJson, ?parent:FlxAnimateFrames, ?frame:Frame)
	{
		super(data, parent, frame);
		this.elementType = GRAPHIC;

		if (data == null)
			return;

		this.libraryItem = parent.getSymbol(data.SN);
		this.instanceName = data.IN; // 新增：接收实例名
		this.matrix = data.MX.toMatrix();
		this.firstFrame = data.FF;
		this.isColored = false;

		this.loopType = switch (data.LP)
		{
			case "PO" | "playonce": LoopType.PLAY_ONCE;
			case "SF" | "singleframe": LoopType.SINGLE_FRAME;
			default: LoopType.LOOP;
		}

		// 核心修复：IK 节点是静态零件，姿态由父时间轴驱动，导出器不标 SF 时
		// 会跟着父级帧号在自身上循环，结果就是每个零件各播各的（错位）
		this.isIKNode = isIKSymbol(data);
		if (this.isIKNode)
			this.loopType = LoopType.SINGLE_FRAME;

		var trp:Null<TransformationPointJson> = data.TRP;
		this.transformationPoint = FlxPoint.get(trp?.x ?? 0.0, trp?.y ?? 0.0);

		if (libraryItem == null)
			visible = false;

		var color = data.C;
		if (color != null)
		{
			switch (color.M)
			{
				case "AD" | "Advanced":
					setColorTransform(color.RM, color.GM, color.BM, color.AM, color.RO, color.GO, color.BO, color.AO);
				case "CA" | "Alpha":
					setColorTransform(1.0, 1.0, 1.0, color.AM, 0.0, 0.0, 0.0, 0.0);
				case "CBRT" | "Brightness":
					var brightness = color.BRT;
					var colorMult = 1.0 - Math.abs(brightness);
					var colorOff = brightness >= 0.0 ? brightness * 255.0 : 0.0;
					setColorTransform(colorMult, colorMult, colorMult, 1.0, colorOff, colorOff, colorOff, 0.0);
				case "T" | "Tint":
					var tint:FlxColor = FlxColor.fromString(color.TC);
					var tintMult:Float = color.TM;
					var mult:Float = 1.0 - tintMult;
					setColorTransform(mult, mult, mult, 1.0, tint.red * tintMult, tint.green * tintMult, tint.blue * tintMult, 0.0);
			}
		}
	}

	public extern overload inline function setColorTransform(rMult:Float = 1, gMult:Float = 1, bMult:Float = 1, aMult:Float = 1, rOffset:Float = 0,
			gOffset:Float = 0, bOffset:Float = 0, aOffset:Float = 0):Void
	{
		_setColorTransform(rMult, gMult, bMult, aMult, rOffset, gOffset, bOffset, aOffset);
	}

	public extern overload inline function setColorTransform(color:FlxColor):Void
	{
		_setColorTransform(color.redFloat, color.greenFloat, color.blueFloat, 1, 0, 0, 0, 0);
	}

	/**
	 * 新增：判断一个元件实例是否为 Adobe Animate 导出的 IK 节点 / 骨骼。
	 * 导出器不同版本信息落在不同字段上，所以 IN → ST → SN 三重兜底。
	 * @param data 	The symbol instance json data.
	 * @return		Whether the instance is an IK node or not.
	 */
	public static function isIKSymbol(data:SymbolInstanceJson):Bool
	{
		if (data == null)
			return false;

		final name:Null<String> = data.IN;
		if (name != null && name.length > 0)
		{
			final lowerName = name.toLowerCase();
			if (lowerName.indexOf("iknode") == 0 || lowerName.indexOf("ik_node") == 0 || lowerName.indexOf("ik node") == 0
				|| lowerName.indexOf("ikbone") == 0)
				return true;
		}

		final type:Null<String> = data.ST;
		if (type != null)
		{
			final lowerType = type.toLowerCase();
			if (lowerType == "ik" || lowerType == "iknode" || lowerType == "ik_node" || lowerType == "ikbone")
				return true;
		}

		final symbol:Null<String> = data.SN;
		if (symbol != null)
		{
			final lowerSymbol = symbol.toLowerCase();
			if (lowerSymbol.indexOf("iknode") != -1 || lowerSymbol.indexOf("ik_node") != -1 || lowerSymbol.indexOf("ik node") != -1)
				return true;
		}

		return false;
	}

	/**
	 * Returns the timeline frame index needed to be rendered at a specific frame, while taking loop types into consideration.
	 * @param index 		Index of the timeline to render.
	 * @param frameIndex 	Optional, relative frame index of the current keyframe the symbol instance is stored at.
	 * @return				Found frame index for rendering at a specific frame.
	 */
	public function getFrameIndex(index:Int, frameIndex:Int = 0):Int
	{
		// 新增：symbol 缺失时兜底，避免 libraryItem.timeline 空引用
		if (libraryItem == null || libraryItem.timeline == null)
			return firstFrame;

		// 新增：IK 节点永远渲染首帧
		if (isIKNode)
			return firstFrame;

		var frameIndex = firstFrame + (index - frameIndex);
		var frameCount = libraryItem.timeline.frameCount;

		switch (loopType)
		{
			case LoopType.LOOP:
				frameIndex = FlxMath.wrap(frameIndex, 0, frameCount - 1);
			case LoopType.PLAY_ONCE:
				frameIndex = FlxMath.minInt(frameIndex, frameCount - 1);
			case LoopType.SINGLE_FRAME:
				frameIndex = firstFrame;
		}

		return frameIndex;
	}

	/**
	 * Method used internally to check if a symbol has simple rendering (one frame).
	 * @return If the symbol has simple rendering or not.
	 */
	public function isSimpleSymbol():Bool
	{
		var timeline = libraryItem.timeline;

		if (timeline.frameCount == 1)
			return true;

		if (loopType == SINGLE_FRAME)
			return true;

		// TODO: more indepth check through layers

		return false;
	}

	var _tmpMatrix:FlxMatrix = new FlxMatrix();

	override function getBounds(frameIndex:Int, ?rect:FlxRect, ?matrix:FlxMatrix, ?includeFilters:Bool = true, ?useCachedBounds:Bool = false):FlxRect
	{
		// TODO: look into this
		// Patch-on fix for a really weird fucking bug
		if (libraryItem != null && libraryItem.timeline.parent.existsSymbol(symbolName))
			libraryItem = libraryItem.timeline.parent.getSymbol(symbolName);

		// Prepare the bounds matrix
		var targetMatrix:FlxMatrix;
		if (matrix != null)
		{
			_tmpMatrix.copyFrom(this.matrix);
			_tmpMatrix.concat(matrix);
			targetMatrix = _tmpMatrix;
		}
		else
		{
			targetMatrix = this.matrix;
		}

		// Get the bounds of the symbol item timeline
		return libraryItem.timeline.getBounds(getFrameIndex(frameIndex, 0), null, rect, targetMatrix, includeFilters, useCachedBounds);
	}

	override function draw(camera:FlxCamera, index:Int, frameIndex:Int, parentMatrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode,
			?antialiasing:Bool, ?shader:FlxShader):Void
	{
		if (isColored) // Concat symbol's color to the current color transform
		{
			var t = this.transform;

			_transform.redMultiplier = t.redMultiplier;
			_transform.greenMultiplier = t.greenMultiplier;
			_transform.blueMultiplier = t.blueMultiplier;
			_transform.alphaMultiplier = t.alphaMultiplier;

			_transform.redOffset = t.redOffset;
			_transform.greenOffset = t.greenOffset;
			_transform.blueOffset = t.blueOffset;
			_transform.alphaOffset = t.alphaOffset;

			if (transform != null)
				_transform.concat(transform);

			transform = _transform;

			if (transform.alphaMultiplier <= 0)
				return;
		}

		var b = Blend.resolve(this.blend, blend);
		_drawTimeline(camera, index, frameIndex, parentMatrix, transform, b, antialiasing, shader);
	}

	function _drawTimeline(camera:FlxCamera, index:Int, frameIndex:Int, parentMatrix:FlxMatrix, transform:Null<ColorTransform>, blend:Null<BlendMode>,
			antialiasing:Null<Bool>, shader:Null<FlxShader>)
	{
		_mat.copyFrom(matrix);
		_mat.concat(parentMatrix);
		libraryItem.timeline.currentFrame = getFrameIndex(index, frameIndex);
		libraryItem.timeline.draw(camera, _mat, transform, blend, antialiasing, shader);
	}

	function _setColorTransform(rMult:Float, gMult:Float, bMult:Float, aMult:Float, rOffset:Float, gOffset:Float, bOffset:Float, aOffset:Float)
	{
		if (transform == null)
			transform = new ColorTransform();
		if (_transform == null)
			_transform = new ColorTransform();

		transform.redMultiplier = rMult;
		transform.greenMultiplier = gMult;
		transform.blueMultiplier = bMult;
		transform.alphaMultiplier = aMult;

		transform.redOffset = rOffset;
		transform.greenOffset = gOffset;
		transform.blueOffset = bOffset;
		transform.alphaOffset = aOffset;

		isColored = (transform.hasRGBAMultipliers() || transform.hasRGBAOffsets());
	}

	inline function get_symbolName():String
	{
		return libraryItem?.name;
	}

	override function destroy()
	{
		super.destroy();
		transformationPoint = FlxDestroyUtil.put(transformationPoint);
		libraryItem = null;
		transform = null;
		_transform = null;
		_tmpMatrix = null;
	}

	public function toString():String
	{
		return '{name: ${libraryItem?.name}, matrix: $matrix}';
	}
}

enum abstract LoopType(Int) to Int
{
	var LOOP;
	var PLAY_ONCE;
	var SINGLE_FRAME;

	public function toString():String
	{
		return switch (cast this : LoopType)
		{
			case LOOP: "loop";
			case PLAY_ONCE: "play_once";
			case SINGLE_FRAME: "single_frame";
		}
	}
}
