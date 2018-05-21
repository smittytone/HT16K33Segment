# HT16K33Segment 1.3.3 #

Hardware driver for [Adafruit 0.56-inch 4-digit, 7-segment LED display](http://www.adafruit.com/products/878) based on the Holtek HT16K33 controller. The LED communicates over any imp I&sup2;C bus.

## Characters ##

The class incorporates its own (limited) character set, accessed through the following codes:

- Digits 0 through 9: codes 0 through 9
- Characters A through F: codes 10 through 15
- Space character: code 16
- Minus character: code 17

## Release Notes ##

- 1.3.3
    - Add support for [`seriallog.nut`](https://github.com/smittytone/generic/blob/master/seriallog.nut) to enable serial logging if the application makes use of it
- 1.3.2
    - Minor code change: rename constants to be class-specific
- 1.3.1
    - Streamline brightness control as per other HT16K33 libraries
- 1.3.0
    - Add *writeGlyph()* method to replace *writeChar()* to avoid confusion over method’s role
        - *writeChar()* still included so old code will not break
    - *init()* returns *this*; *init()* code errors fixed
    - Clarifications made to Read Me
- 1.2.0
    - Add *setDisplayFlash()*
    - Add `return this;` missing from *writeNumber()*
    - *setBrightness()* code simplified; code that belongs in *init()* placed in that method
- 1.1.0
    - From version 1.1.0, the methods *clearBuffer()*, *setColon()*, *writeChar()* and *writeNumber()* return the context object, *this*, allowing these methods to be chained. For example:

```squirrel
led.clearBuffer(17).setColon(true).writeChar(0, 0x6D).updateDisplay();
```

## Class Usage ##

### Constructor: HT16K33Segment(*impI2cBus[, i2cAddress][, debug]*) ###

To instantiate a HT16K33Segment object pass the I&sup2;C bus to which the display is connected and, optionally, its I&sup2;C address. If no address is passed, the default value, `0x70` will be used. Pass an alternative address if you have changed the display’s address using the solder pads on rear of the LED’s circuit board.

The third parameter allows you to receive extra debugging information in the log. It defaults to `false` (no messages).

The passed imp I&sup2;C bus must be configured before the HT16K33Segment object is created.

#### Example ####

```squirrel
hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
led <- HT16K33Segment(hardware.i2c89);
led.init();
```

## Class Methods ##

### init(*[character][, brightness][, showColon]*) ###

Call *init()* to bring up the display. All parameters are optional. The first is a character to display across all the digits; the default is no character. The *brightness* parameters is a value between 0 (low) and 15 (high); the default value is 15. Finally, *showColon* is a boolean: pass `true` to display the colon between digits 1 and 3, or `false` (the default);

### clearBuffer(*[clearChar]*) ###

Call *clearBuffer()* to zero the class’ internal display buffer. If the optional *clearChar* parameter is not passed, no characters will be displayed. Pass a character code *(see [above](#characters))* to zero the display to a specific character.

*clearBuffer()* does not update the display, only the buffer. Call *updateDisplay()* to refresh the LED.

#### Example ####

```squirrel
// Set the display to -- --
led.clearBuffer(17)
   .updateDisplay();
```

### setColon(*set*) ###

Call *setColon()* to specify whether the display’s center colon symbol is illuminated (`true`) or not (`false`).

```squirrel
// Set the display to --:--
led.clearBuffer(17)
   .setColon(true)
   .updateDisplay();
```

### writeGlyph(*digit, pattern[, hasDot]*) ###

To write a character that is not in the character set *(see [above](#characters))* to a single digit, call *writeGlyph()* and pass the digit number (0, 1, 3 or 4) and a glyph-definition pattern as its parameters. You can also provide a third, optional parameter: a boolean value indicating whether the decimal point to the right of the specified digit should be illuminated. By default, the decimal point is not lit.

Calculate the glyph pattern value using the following chart. The segment number is the bit that must be set to illuminate it (or unset to keep it unlit):

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

For example, to define the letter 'P', we need to set segments 0, 1, 4, 5 and 6. In bit form that makes 0x73, and this is the value passed into *pattern*.

```squirrel
// Display 'SYNC' on the LED
local letters = [0x6D, 0x6E, 0x37, 0x39];

foreach (index, character in letters) {
    if (index != 2) led.writeGlyph(index, character);
}

led.updateDisplay();
```

### writeNumber(*digit, number[, hasDot]*) ###

To write a number to a single digit, call *writeNumber()* and pass the digit number (0, 1, 3 or 4) and the number to be displayed (0 to 9, A to F) as its parameters. You can also provide a third, optional parameter: a boolean value indicating whether the decimal point to the right of the specified segment should be illuminated. By default, the decimal point is not lit.

#### Example ####

```squirrel
// Display '42.42' on the LED
led.writeNumber(0, 4)
   .writeNumber(1, 2, true)
   .writeNumber(3, 4)
   .writeNumber(4, 2)
   .updateDisplay();
```

### clearDisplay() ###

Call *clearDisplay()* to completely wipe the display, including the colon. Unlike *clearBuffer()*, this method can’t be used to set all the segments to a specific character, but it does automatically update the display.

### updateDisplay() ###

Call *updateDisplay()* after changing any or all of the internal display buffer contents in order to reflect those changes on the display itself.

### setBrightness(*[brightness]*) ###

To set the LED’s brightness (its duty cycle), call *setBrightness()* and pass an integer value between 0 (dim) and 15 (maximum brightness). If you don’t pass a value, the method will default to maximum brightness.

### setDisplayFlash(*flashRate*) ###

This method can be used to flash the display. The value passed into *flashRate* is the flash rate in Hertz. This value must be one of the following values, fixed by the HT16K33 controller: 0.5Hz, 1Hz or 2Hz. You can also pass in 0 to disable flashing, and this is the default value.

#### Example ####

```squirrel
// Blink the display every second
led.setDisplayFlash(1);
```

### powerDown() ###

The display can be turned off by calling *powerDown()*.

### powerUp() ###

The display can be turned on by calling *powerup()*.

## License ##

The HTK16K33Segment library is licensed under the [MIT License](./LICENSE).
