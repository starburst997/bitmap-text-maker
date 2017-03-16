package bitmaptextmaker;

import haxe.Json;
import haxe.ds.StringMap;
import haxe.io.Bytes;
import haxe.io.BytesOutput;

import file.save.FileSave;

import zip.Zip;
import zip.ZipReader;
import zip.ZipWriter;
import zip.ZipEntry;

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

// Trim
typedef Trim =
{
  var bmpd:BitmapData;
  var rect:Rectangle;
};

// FNT File
typedef FNT =
{
  var bytes:Bytes;
  var name:String;
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

  // ZIP
  private static var date = new Date(1988, 11, 2, 12, 45, 0); // Easter egg on NOTE font file

  // Text Field
  private static var textField:TextField = null;

  // Bitmap
  private static var bitmap:Bitmap = null;

  // Do not instantiate
  private function new() { }

  // Prepare sprite
  public static function prepare( display:Bool = false )
  {
    if ( textField != null ) return;

    // Create Sprite for bounds
    var sprite = new Sprite();

    sprite.x = 100;
    sprite.y = 100;

    if ( display )
    {
      Lib.current.stage.addChild( sprite );

      // Add Bitmap Data test
      bitmap = new Bitmap();
      bitmap.x = 100;
      bitmap.y = 150;
      Lib.current.addChild( bitmap );
    }

    // Init TextField
    textField = new TextField();
    textField.embedFonts = true;
    textField.selectable = false;
    textField.antiAliasType = AntiAliasType.NORMAL;

    textField.width = 1000;
    textField.height = 1000;

    textField.x = 0;
    textField.y = 0;

    sprite.addChild( textField );
  }

  // Save file
  public static function save( fonts:Array<FNT> )
  {
    if ( fonts.length == 1 )
    {
      // Simple 1 file save
      FileSave.saveBytes( fonts[0].bytes, fonts[0].name + ".fnt" );
    }
    else if ( fonts.length > 1 )
    {
      // Create a big zip with all fonts inside
      var zip = new ZipWriter();
      for ( fnt in fonts )
      {
        zip.addBytes( fnt.bytes, fnt.name + ".fnt", false, date );
      }

      FileSave.saveBytes( zip.finalize(), "fonts.zip" );
    }
  }

  // Create texture
  public static function createFont( font:Class<Font>, width:Int, height:Int, size:Float, color:UInt, bold:Bool, italic:Bool, glyphs:String = null ):FNT
  {
    if ( textField == null ) prepare();
    if ( glyphs == null ) glyphs = GLYPHS;

    // Vars
    var writer = new ZipWriter();

    // Get font info
    Font.registerFont( font );
    var name = Type.createInstance(font, []).fontName;

    trace("FONT", name);

    // Set format
    var textFormat = new TextFormat(name, size, color, bold, italic);
    textField.defaultTextFormat = textFormat;

    // Test
    //textField.text = "Hello!";

    // Create BitmapData
    var texture = new BitmapData( width, height, true, 0x00000000 );

    // Display
    if ( bitmap != null ) bitmap.bitmapData = texture;

    // Create bin-packing
    var packer = new SimplifiedMaxRectsPacker( width, height );

    // Init JSON
    var json:Dynamic = {};
    json.name = name;

    json.size = size;
    json.color = color;
    json.bold = bold;
    json.italic = italic;

    json.glyphs = [];

    // Loop each letter
    for ( i in 0...glyphs.length )
    {
      var info:Dynamic = {};
      var char = glyphs.charAt(i);
      var code:Int = glyphs.charCodeAt(i);

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
      //Reflect.setField(json, 'c$code', info);
      json.glyphs.push( info );

      // Clean
      bmpd.dispose();
    }

    // Trim BitmapData
    texture.setPixel32( 0, 0, 0xFF000000 );
    var trimmed = trimAlpha( texture ).bmpd;
    trimmed.setPixel32( 0, 0, 0x00000000 );
    texture.dispose();

    if ( bitmap != null ) bitmap.bitmapData = trimmed;

    trace( "TEXTURE", trimmed.width, trimmed.height );

    // Add to JSON
    json.width = trimmed.width;
    json.height = trimmed.height;

    // Convert to PNG
    var byteArray:ByteArray = new ByteArray();
    var png = trimmed.encode(trimmed.rect, new PNGEncoderOptions(), byteArray);

    // Add file to Zip
    writer.addBytes( Bytes.ofData( byteArray ), "texture.png", false, date );
    writer.addString( Json.stringify(json), "texture.json", true, date );

    // Save Zip
    //FileSave.saveBytes( writer.finalize(), name + ".zip" );

    return
    {
      bytes: writer.finalize(),
      name: name
    };
  }

  // http://stackoverflow.com/a/17723163
  private static function trimAlpha( source:BitmapData ):Trim
  {
    var notAlphaBounds = source.getColorBoundsRect(0xFF000000, 0x00000000, false);
    var trimed:BitmapData = new BitmapData(Std.int(notAlphaBounds.width), Std.int(notAlphaBounds.height), true, 0x00000000);
    trimed.copyPixels(source, notAlphaBounds, new Point(0, 0));
    return {bmpd: trimed, rect: notAlphaBounds};
  }
}