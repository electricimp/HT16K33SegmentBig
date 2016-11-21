# HT16K33SegmentBig 1.2.0

Hardware driver for [Adafruit 1.2-inch 4-digit, 7-segment LED display](http://www.adafruit.com/products/1270) based on the Holtek HT16K33 controller. The LED communicates over any imp I&sup2;C bus.

**To add this library to your project, add** `#require "HT16K33SegmentBig.class.nut:1.2.0"` **to the top of your device code**

## Characters

The class incorporates its own (limited) character set, accessed through the following codes:

* Digits 0 through 9: codes 0 through 9
* Characters A through F: codes 10 through 15
* Space character: code 16
* Minus character: code 17

## Release Notes

### 1.2.0

- Add *writeGlyph()* method to replace *writeChar()* to avoid confusion over method’s role
    - *writeChar()* still included so old code will not break
- Add *setDisplayFlash()*
- *setBrightness()* code simplified; code that belongs in *init()* placed in that method
- *init()* returns *this*

### 1.1.0

From version 1.1.0, the methods *clearBuffer()*, *setColon()*, *writeChar()* and *writeNumber()* return the context object, *this*, allowing them to be chained:

```squirrel
// Set the display to :--:--
led.clearBuffer(17).setColon(0x0E).updateDisplay();
```

## Class Usage

### Constructor: HT16K33Segment(*impI2cBus[, i2cAddress][, debug]*)

To instantiate an HT16K33Segment object pass the I&sup2;C bus to which the display is connected and, optionally, its I&sup2;C address. If no address is passed, the default value, `0x70` will be used. Pass an alternative address if you have changed the display’s address using the solder pads on rear of the LED’s circuit board.

The passed imp I&sup2;C bus must be configured before the HT16K33Segment object is created.

You can also pass `true` into in a third parameter, *debug*, to gain extra debugging information in the log. It defaults to `false`.

```squirrel
#require "HT16K33SegmentBig.class.nut:1.1.0"

hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
led <- HT16K33Segment(hardware.i2c89);
```

## Class Methods

### clearBuffer(*[character]*)

Call *clearBuffer()* to zero the internal display buffer. If the optional *character* parameter is not passed, no characters will be displayed. Pass a character code *(see [above](#characters))* to zero the display to a specific character.

*clearBuffer()* does not update the display, only its buffer &mdash; Call *updateDisplay()* to refresh the LED.

```squirrel
// Set the display to -- --
led.clearBuffer(17).updateDisplay();
```

### clearDisplay()

Call *clearDisplay()* to completely wipe the display, including the colon. Unlike *clearBuffer()*, this method can’t be used to set all the segments to a specific character, but it does automatically update the display.

### setColon(*colonPattern*)

Call *setColon()* to specify whether the display’s initial and center colon symbols are illuminated, and the raised point between the third and fourth characters. The parameter is an integer that combines any or all of the following values:

* 0x02 &ndash; centre colon
* 0x04 &ndash; left colon, lower dot
* 0x08 &ndash; left colon, upper dot
* 0x10 &ndash; decimal point (upper)

```squirrel
// Set the display to :--:--
led.clearBuffer(17)
   .setColon(0x0E)
   .updateDisplay();

// Set the display to .--'--
led.setColon(0x18)
   .updateDisplay();
```

### writeGlyph(*digit, pattern*)

To write a character that is not in the built-in character set *(see [above](#characters))* to a single digit, call *writeGlyph()* and pass the digit number (0, 1, 3 or 4) and a pattern value as its parameters.

Calculate pattern values using the following chart. The segment number is the bit that must be set to illuminate it (or unset to keep it unlit):

```
     0
     _
 5 |   | 1
   |   |
     - <----- 6
 4 |   | 2
   | _ |
     3
```

```squirrel
// Display 'SYNC' on the LED
local characters = [0x6D, 0x6E, 0x37, 0x39];

foreach (index, character in characters) {
    if (index != 2) led.writeGlyph(index, character);
}

led.updateDisplay();
```

### writeNumber(*digit, number*)

To write a number to a single digit, call *writeNumber()* and pass the digit number (0, 1, 3 or 4) and the number you want to display (0 to 9, 10 (A) to 15 (F)) as its parameters.

```squirrel
// Display '42 42' on the LED
led.writeNumber(0, 4)
   .writeNumber(1, 2)
   .writeNumber(3, 4)
   .writeNumber(4, 2)
   .updateDisplay();
```

### updateDisplay()

Call *updateDisplay()* after changing any or all of the display buffer contents in order to reflect those changes on the display itself.

### setBrightness(*[brightness]*)

To set the LED’s brightess (its duty cycle), call *setBrightness()* and pass an integer value between 0 (dim) and 15 (maximum brightness). If you don’t pass a value, the method will default to maximum brightness.

### setDisplayFlash(*flashRate*)

This method can be used to flash the display. The value passed into *flashRate* is the flash rate in Hertz. This value must be one of the following values, fixed by the HT16K33 controller: 0.5Hz, 1Hz or 2Hz. You can also pass in 0 to disable flashing, and this is the default value.

```squirrel
// Blink the display every second
led.setDisplayFlash(1);
```

### powerDown()

The display can be turned off by calling *powerDown()*.

### powerUp()

The display can be turned on by calling *powerup()*.

## License

The HTK16K33SegmentBig library is licensed under the [MIT License](./LICENSE).
