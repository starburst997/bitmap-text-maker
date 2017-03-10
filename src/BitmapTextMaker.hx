package;

import haxe.Json;
import haxe.ds.StringMap;
import haxe.io.Bytes;
import haxe.io.BytesOutput;

import file.load.FileLoad;
import file.save.FileSave;

import zip.Zip;
import zip.ZipReader;
import zip.ZipWriter;
import zip.ZipEntry;

import statistics.TraceTimer;
import statistics.Stats;

import binpacking.Rect;
import binpacking.SimplifiedMaxRectsPacker;

// Flash
import flash.Lib;
import flash.events.Event;
import flash.utils.ByteArray;
import flash.text.Font;
import flash.text.AntiAliasType;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.display.Sprite;
import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.StageQuality;
import flash.display.PNGEncoderOptions;
import flash.geom.Rectangle;
import flash.geom.Point;

using StringTools;

// Embedded font
@:font("assets/Montserrat-Bold.ttf") class FontTTF extends Font { }

// Trim
typedef Trim = 
{
  var bmpd:BitmapData;
  var rect:Rectangle;
};

/**
 * SWF only for now, takes a font, create a Spritesheet with all letters in it, 
 * save letter's position inside a JSON and output a Zip containing the PNG + JSON.
 * 
 * TODO: Selection of font, size, color
 * TODO: Better selection of Texture dimension to optimize space
 * TODO: Add retina version x2, x3 to Zip
 */
class BitmapTextMaker
{
  // Glyphs to include
  public static var GLYPHS:String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789|!\"/$%?&*()_+-=#;:<>,.'.\\";
  
  // Padding
  public static inline var LETTER_PADDING:Int = 1;
  
  // Texture (make it big enough but will be trimmed at the end)
  public static inline var TEXTURE_WIDTH = 175;
  public static inline var TEXTURE_HEIGHT = 175;
  
  // Font properties
  public static inline var SIZE = 18;
  public static inline var COLOR = 0x000000;
  public static inline var BOLD = false;
  public static inline var ITALIC = false;
  
  // Create new ZIP
  var writer = new ZipWriter();
  var date = new Date(1988, 11, 2, 12, 45, 0); // Easter egg on NOTE font file
  
  // Stats
  var stats = new Stats();

  // Text Field
  var textField:TextField;
  
  // Spritesheet
  var texture:BitmapData;
  
  // Bin packing algorithm
  var packer:SimplifiedMaxRectsPacker;
  
  // JSON object
  var json:Dynamic;
  
  // Create Spritesheet
  public function new()
  {
    trace("Launch");
    
    TraceTimer.activate();
    
    // Get font info
    Font.registerFont(FontTTF);
    var name = new FontTTF().fontName;
    
    trace("FONT", name);
    
    // Create Sprite for bounds
    var sprite = new Sprite();
    
    sprite.x = 100;
    sprite.y = 100;
    
    Lib.current.stage.addChild( sprite );
    
    // Create TextField
    var textFormat = new TextFormat(name, SIZE, COLOR, BOLD, ITALIC);
    textField = new TextField();
    textField.defaultTextFormat = textFormat;
    textField.embedFonts = true;
    textField.selectable = false;
    textField.antiAliasType = AntiAliasType.NORMAL;
    
    textField.width = 1000;
    textField.height = 1000;
    
    textField.x = 0;
    textField.y = 0;
    
    sprite.addChild( textField );
    
    // Test
    textField.text = "Hello!";
    
    // Create BitmapData
    texture = new BitmapData( TEXTURE_WIDTH, TEXTURE_HEIGHT, true, 0x00000000 );
    
    // Add Bitmap Data test
    var bmp = new Bitmap(texture);
    bmp.x = 100;
    bmp.y = 150;
    Lib.current.addChild( bmp );
    
    // Create bin-packing
    packer = new SimplifiedMaxRectsPacker( TEXTURE_WIDTH, TEXTURE_HEIGHT );
    
    // Init JSON
    json = {};
    json.name = name;
    
    // Loop each letter
    for ( i in 0...GLYPHS.length )
    {
      var info:Dynamic = {};
      var char = GLYPHS.charAt(i);
      var code:Int = GLYPHS.charCodeAt(i);
      
      info.char = char;
      info.code = code;
      
      textField.text = char;
      
      // BitmapData of single letter
      var bmpd = new BitmapData( Std.int(textField.textWidth + LETTER_PADDING * 2), Std.int(textField.textHeight + LETTER_PADDING * 2), true, 0x00000000 );
      
      bmpd.drawWithQuality( textField, null, null, null, null, true, StageQuality.HIGH_16X16 );
      
      // Trim
      var trim = trimAlpha(bmpd);
      bmpd.dispose();
      
      bmpd = trim.bmpd;
      
      // Add to bin-packing
      var rect = packer.insert( bmpd.width + LETTER_PADDING * 2, bmpd.height + LETTER_PADDING * 2 );
      
      // Add to Texture
      texture.copyPixels( bmpd, bmpd.rect, new Point(rect.x + LETTER_PADDING, rect.y + LETTER_PADDING) );
      
      // Add rect to JSON
      info.x = rect.x;
      info.y = rect.y;
      info.width = rect.width;
      info.height = rect.height;
      
      // Add origin
      info.originX = trim.rect.x;
      info.originY = trim.rect.y;
      
      //trace(info.originX, info.originY);
      
      // Save into JSON
      Reflect.setField(json, 'c$code', info);
      
      // Clean
      bmpd.dispose();
    }
    
    // Trim BitmapData
    var trimmed = trimAlpha( texture ).bmpd;
    texture.dispose();
    
    bmp.bitmapData = trimmed;
    
    trace( "TEXTURE", trimmed.width, trimmed.height );
    
    // Convert to PNG
    var byteArray:ByteArray = new ByteArray();
    var png = trimmed.encode(trimmed.rect, new PNGEncoderOptions(), byteArray);
    
    // Add file to Zip
    writer.addBytes( Bytes.ofData( byteArray ), "texture.png", false, date );
    writer.addString( Json.stringify(json), "texture.json", false, date );
    
    // Save Zip
    FileSave.saveBytes( writer.finalize(), name + ".zip" );
  }

  // http://stackoverflow.com/a/17723163
  function trimAlpha( source:BitmapData ):Trim 
  {
    var notAlphaBounds = source.getColorBoundsRect(0xFF000000, 0x00000000, false);
    var trimed:BitmapData = new BitmapData(Std.int(notAlphaBounds.width), Std.int(notAlphaBounds.height), true, 0x00000000);
    trimed.copyPixels(source, notAlphaBounds, new Point(0, 0));
    return {bmpd: trimed, rect: notAlphaBounds};  
  }
  
  // Main entry point
  static function main()
  {
    new BitmapTextMaker();
  }
}