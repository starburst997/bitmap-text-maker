package;

import flash.text.Font;

import statistics.TraceTimer;
import statistics.Stats;

import bitmaptextmaker.BitmapTextMaker;

// Put Embedded fonts here!
@:font("assets/Montserrat-Bold.ttf") class Montserrat extends Font { }

/**
 * Demonstrate how to use bitmap-text-maker
 */
class TestBitmapTextMaker
{
  // Stats
  var stats = new Stats();

  // Create Spritesheet
  public function new()
  {
    trace("Launch");

    TraceTimer.activate();

    // Prepare Sprite
    BitmapTextMaker.prepare( true );

    // Init array
    var fonts:Array<FNT> = [];

    // Put all your fonts here with custom properties
    fonts.push( BitmapTextMaker.createFont( Montserrat, 175, 175, 18, 0x000000, false, false ) );

    // Save
    BitmapTextMaker.save( fonts );
  }

  // Main entry point
  static function main()
  {
    new TestBitmapTextMaker();
  }
}