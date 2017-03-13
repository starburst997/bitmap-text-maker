# bitmap-text-maker

Bitmap Text Maker

SWF only for now, takes a font, create a Spritesheet with all letters in it, save letter's position inside a JSON and output a Zip containing the PNG + JSON.

TODO: Add a way to select font + select properties, for now you need to edit the source code.

TODO: Add retina x2, x3 image

Example output:
```json
{
  "c100": {
    "char": "d",
    "code": 100,
    "originX": 2,
    "originY": 9,
    "width": 14,
    "height": 17,
    "x": 0,
    "y": 144
  },
  "c101": {
    "char": "e",
    "code": 101,
    "height": 13,
    "originX": 2,
    "originY": 13,
    "width": 12,
    "x": 27,
    "y": 83
  },
  "c102": {
    "char": "f",
    "code": 102,
    "height": 17,
    "originX": 2,
    "originY": 9,
    "width": 9,
    "x": 14,
    "y": 128
  }
}
```