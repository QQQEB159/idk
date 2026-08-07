package funkin.backend.assets;

import haxe.io.Path;
import lime.graphics.Image;
import lime.media.AudioBuffer;
import lime.text.Font;
import lime.utils.Bytes;
import openfl.utils.AssetLibrary;
import openfl.utils.Assets;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

#if MOD_SUPPORT
class EmbeddedModsFolderLibrary extends AssetLibrary implements IModsAssetLibrary {
	public var basePath:String;
	public var modName:String;
	public var libName:String;
	public var prefix = 'assets/';

	public var assets:Map<String, String> = [];
	public var nameMap:Map<String, String> = [];
	public var _parsedAsset:String = null;

	public function new(basePath:String, libName:String, ?modName:String) {
		this.basePath = normalizePath(basePath);
		this.libName = libName;
		this.modName = modName == null ? Path.withoutDirectory(this.basePath) : modName;

		for (asset in Assets.list()) {
			var cleanAsset = asset;
			var separator = cleanAsset.indexOf(":");
			if (separator != -1)
				cleanAsset = cleanAsset.substr(separator + 1);

			if (!cleanAsset.startsWith(this.basePath + "/"))
				continue;

			var relative = cleanAsset.substr(this.basePath.length + 1);
			if (relative.length <= 0 || relative.endsWith("/"))
				continue;

			var lower = relative.toLowerCase();
			assets.set(lower, asset);
			nameMap.set(lower, relative);
		}

		super();
	}

	function toString():String {
		return '(EmbeddedModsFolderLibrary: $modName @ $basePath)';
	}

	public override function getAudioBuffer(id:String):AudioBuffer {
		if (!exists(id, "SOUND"))
			return null;
		return AudioBuffer.fromBytes(readAssetBytes(getAssetID()));
	}

	public override function getBytes(id:String):Bytes {
		if (!exists(id, "BINARY"))
			return null;
		return readAssetBytes(getAssetID());
	}

	public override function getFont(id:String):Font {
		if (!exists(id, "FONT"))
			return null;
		return ModsFolder.registerFont(Font.fromBytes(readAssetBytes(getAssetID())));
	}

	public override function getImage(id:String):Image {
		if (!exists(id, "IMAGE"))
			return null;
		return Image.fromBytes(readAssetBytes(getAssetID()));
	}

	public override function getPath(id:String):String {
		if (!__parseAsset(id))
			return null;

		var assetID = getAssetID();
		if (assetID == null)
			return null;

		var path = Assets.getPath(assetID);
		#if sys
		if (path != null && path != "" && FileSystem.exists(path))
			return path;
		#end

		return extractAssetPath(assetID, _parsedAsset);
	}

	public inline function getFolders(folder:String):Array<String>
		return getContent(folder, true);

	public inline function getFiles(folder:String):Array<String>
		return getContent(folder, false);

	public override function exists(asset:String, type:String):Bool {
		if (!__parseAsset(asset))
			return false;
		return getAssetID() != null;
	}

	public override function list(type:String):Array<String> {
		return [for (relative in nameMap) '$prefix$relative'];
	}

	private function extractAssetPath(assetID:String, relative:String):String {
		#if sys
		var targetPath = Path.join([".temp", "embeddedmods", modName, relative]);
		var directory = Path.directory(targetPath);
		if (!FileSystem.exists(directory))
			FileSystem.createDirectory(directory);
		if (!FileSystem.exists(targetPath))
			File.saveBytes(targetPath, readAssetBytes(assetID));
		return targetPath;
		#else
		return Assets.getPath(assetID);
		#end
	}

	private function getAssetID():String {
		if (_parsedAsset == null)
			return null;
		return assets.get(_parsedAsset.toLowerCase());
	}

	private function getAssetPath():String {
		return getAssetID();
	}

	private function getContent(folder:String, folders:Bool = false):Array<String> {
		if (!folder.endsWith("/"))
			folder += "/";
		if (!__parseAsset(folder))
			return [];

		var content:Array<String> = [];
		var checkPath = _parsedAsset.toLowerCase();

		for (relativeLower => _ in assets) {
			if (!relativeLower.startsWith(checkPath))
				continue;

			var relative = nameMap.get(relativeLower);
			if (relative == null)
				continue;

			var fileName = relative.substr(_parsedAsset.length);
			var slashIndex = fileName.indexOf("/");

			if (folders) {
				if (slashIndex != -1 && fileName.length > 0) {
					var folderName = fileName.substr(0, slashIndex);
					if (!content.contains(folderName))
						content.push(folderName);
				}
			} else if (slashIndex == -1 && fileName.length > 0 && !content.contains(fileName)) {
				content.push(fileName);
			}
		}

		return content;
	}

	private function normalizePath(path:String):String {
		path = StringTools.replace(path, "\\", "/");
		while (path.endsWith("/"))
			path = path.substr(0, path.length - 1);
		return path;
	}

	private function readAssetBytes(assetID:String):Bytes {
		try {
			var bytes = Assets.getBytes(assetID);
			if (bytes != null)
				return Bytes.fromBytes(bytes);
		} catch (e:Dynamic) {}

		try {
			var text = Assets.getText(assetID);
			if (text != null)
				return Bytes.ofString(text);
		} catch (e:Dynamic) {}

		return null;
	}

	private function __isCacheValid(cache:Map<String, Dynamic>, asset:String, isLocal:Bool = false):Bool {
		var key = isLocal ? asset : '$libName:$asset';
		return cache.exists(key) || cache.exists(asset);
	}

	private function __parseAsset(asset:String):Bool {
		if (!asset.startsWith(prefix))
			return false;
		_parsedAsset = asset.substr(prefix.length);
		if (ModsFolder.useLibFile) {
			var file = new Path(_parsedAsset);
			if (file.file.startsWith("LIB_")) {
				var library = file.file.substr(4);
				if (library != modName)
					return false;

				_parsedAsset = file.dir + "." + file.ext;
			}
		}
		return true;
	}
}
#end
