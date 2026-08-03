package funkin.options.categories;

import flixel.input.keyboard.FlxKey;
import lime.system.System as LimeSystem;
#if sys
import sys.io.File;
#end

class MobileOptions extends TreeMenuScreen
{
	#if android
	final lastStorageType:String = Options.storageType;
	var externalPaths:Array<String> = StorageUtil.checkExternalPaths(true);
	var typeNames:Array<String> = ['Data', 'Obb', 'Media', 'External'];
	var typeVars:Array<String> = ['EXTERNAL_DATA', 'EXTERNAL_OBB', 'EXTERNAL_MEDIA', 'EXTERNAL'];
	#end

	public function new()
	{
        #if android
		if (!externalPaths.contains('\n'))
		{
			typeNames = typeNames.concat(externalPaths);
			typeVars = typeVars.concat(externalPaths);
		}
		#end
        
        super('optionsTree.mobile-name', 'optionsTree.mobile-name', 'MobileOptions.', ['LEFT_FULL', 'A_B']);

		#if TOUCH_CONTROLS
		add(new ArrayOption(getNameID('extraHints'), getDescID('extraHints'), ['NONE', 'SINGLE', 'DOUBLE'], ["None", "Single", "Double"], 'extraHints'));
		add(new NumOption(getNameID('hitboxAlpha'), getDescID('hitboxAlpha'), 0.0, 1.0, 0.1, "hitboxAlpha"));
		add(new Checkbox(getNameID('oldPadTexture'), getDescID('oldPadTexture'), "oldPadTexture", () ->
		{
			MusicBeatState.getState().removeTouchPad();
			MusicBeatState.getState().addTouchPad("LEFT_FULL", "A_B");
		}));
		add(new NumOption(getNameID('touchPadAlpha'), getDescID('touchPadAlpha'), 0.0, 1.0, 0.1, "touchPadAlpha", (alpha:Float) ->
		{
			MusicBeatState.getState().touchPad.alpha = alpha;
			if (funkin.backend.system.Controls.instance.touchC)
			{
				FlxG.sound.volumeUpKeys = [];
				FlxG.sound.volumeDownKeys = [];
				FlxG.sound.muteKeys = [];
			}
			else
			{
				FlxG.sound.volumeUpKeys = [FlxKey.PLUS, FlxKey.NUMPADPLUS];
				FlxG.sound.volumeDownKeys = [FlxKey.MINUS, FlxKey.NUMPADMINUS];
				FlxG.sound.muteKeys = [FlxKey.ZERO, FlxKey.NUMPADZERO];
			}
		}));
		add(new ArrayOption(getNameID('hitboxType'), getDescID('hitboxType'), ['noGradient', 'noGradientOld', 'gradient', 'hidden'],
			["No Gradient", "No Gradient (Old)", "Gradient", "Hidden"], 'hitboxType'));
		add(new Checkbox(getNameID('hitboxPos'), getDescID('hitboxPos'), "hitboxPos"));
		#end
		#if mobile
		add(new Checkbox(getNameID('screenTimeOut'), getDescID('screenTimeOut'), "screenTimeOut", () ->
		{
			LimeSystem.allowScreenTimeout = Options.screenTimeOut;
		}));
		#end
		#if android
		add(new ArrayOption(
			"Storage Type",
			"Choose which folder Codename Engine should use! (CHANGING THIS MAKES DELETE YOUR OLD FOLDER!!)",
			typeVars,
			typeNames,
			'storageType'));
		#end
	}

	override function close()
	{
		super.close();

		#if android
		if (lastStorageType != Options.storageType) {
			Options.save();
			onStorageChange();
			funkin.backend.utils.NativeAPI.showMessageBox('Notice!', 'Storage Type has been changed and you needed restart the game!!\nPress OK to close the game.');
			LimeSystem.exit(0);
		}
		#end
	}
	
	#if android
	function onStorageChange():Void
	{
		File.saveContent(LimeSystem.applicationStorageDirectory + 'storagetype.txt', Options.storageType);
	
		var lastStoragePath:String = StorageType.fromStrForce(lastStorageType) + '/';
	
		try
		{
			if (Options.storageType != "EXTERNAL")
				Sys.command('rm', ['-rf', lastStoragePath]);
		}
		catch (e:haxe.Exception)
			trace('Failed to remove last directory. (${e.message})');
	}
	#end
}
