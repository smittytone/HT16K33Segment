/**
 * HT16K33 registers and HT16K33-specific variables
 */ 
const HT16K33_SEG_CLASS_REGISTER_DISPLAY_ON  = "\x81";
const HT16K33_SEG_CLASS_REGISTER_DISPLAY_OFF = "\x80";
const HT16K33_SEG_CLASS_REGISTER_SYSTEM_ON   = "\x21";
const HT16K33_SEG_CLASS_REGISTER_SYSTEM_OFF  = "\x20";
const HT16K33_SEG_CLASS_DISPLAY_ADDRESS      = "\x00";
const HT16K33_SEG_CLASS_I2C_ADDRESS          = 0x70;
const HT16K33_SEG_CLASS_BLANK_CHAR           = 16;
const HT16K33_SEG_CLASS_MINUS_CHAR           = 17;
const HT16K33_SEG_CLASS_DEGREE_CHAR          = 18;
const HT16K33_SEG_CLASS_CHAR_COUNT           = 19;

/**
 * Display specific constants
 */
const HT16K33_SEG_CLASS_LED_MAX_ROWS         = 4;
const HT16K33_SEG_CLASS_LED_COLON_ROW        = 2;

/**
 * Hardware driver for Adafruit 0.56-inch 4-digit, 7-segment LED display based on the Holtek HT16K33 controller.
 * For example: http://www.adafruit.com/products/1854
 *
 * Bus          I2C
 * Availibility Device
 * @author      Tony Smith (@smittytone)
 * @license     MIT
 *
 * @class
 */
class HT16K33Segment {
    
    /**
     * @property {string} VERSION - The library version
     * 
     */    
    static VERSION = "2.0.0";

    // *********** Private Properties **********

    _buffer = null;
    _digits = null;
    _led = null;
    _ledAddress = 0;
    _debug = false;
    _logger = null;

    /**
     *  Initialize the segment LED
     *
     *  @constructor
     *
     *  @param {imp::i2c} impI2Cbus    - Whichever configured imp I2C bus is to be used for the HT16K33
     *  @param {integer}  [i2cAddress] - The HT16K33's I2C address. Default: 0x70
     *  @param {bool}     [debug ]     - Set/unset to log/silence error messages. Default: false
     *  
     *  @returns {instance} The instance
     */
    constructor(i2cBus = null, i2cAddress = 0x70, debug = false) {
        if (i2cBus == null || i2cAddress == 0) throw "HT16K33Segment() requires a non-null imp I2C bus object and a non-zero I2C address";
        if (i2cAddress < 0x00 || i2cAddress > 0xFF) throw "HT16K33Segment() requires a valid I2C address";

        _led = i2cBus;
        _ledAddress = i2cAddress << 1;
        
        if (typeof debug != "bool") debug = false;
        _debug = debug;

        // Select logging target, which stored in '_logger', and will be 'seriallog' if 'seriallog.nut'
        // has been loaded BEFORE HT16K33SegmentBig is instantiated on the device, otherwise it will be
        // the imp API object 'server'
        if ("seriallog" in getroottable()) { _logger = seriallog; } else { _logger = server; }

        // _buffer stores the character matrix values for each row of the display,
        // Including the center colon character
        //
        //  buffer index   0    1   2   3    4
        //                [ ]  [ ]     [ ]  [ ]
        //  character      -    -   .   -    -
        //                [ ]  [ ]  .  [ ]  [ ]
        _buffer = blob(5);

        // _digits store character matrices for 0-9, A-F, blank and minus
        _digits = "\x3F\x06\x5B\x4F\x66\x6D\x7D\x07\x7F\x6F"; // 0-9
        _digits = _digits + "\x5F\x7C\x58\x5E\x7B\x71";       // A-F
        _digits = _digits + "\x00\x40\x63";                   // Space, minus, degree signs
    }

    /**
     *  Initialize the segment LED display
     *
     *  @param {integer} [character]  - A character to display on every segment. Default: clear space
     *  @param {integer} [brightness] - The LED brightness in range 0 to 15. Default: 15
     *  @param {bool}    [showColon]  - Whether the central colon should be lit. Default: false
     *
     *  @returns {intance} this  
     */
    function init(character = HT16K33_SEG_CLASS_BLANK_CHAR, brightness = 15, showColon = false) {
        powerUp();
        setBrightness(brightness);
        clearBuffer(character);
        setColon(showColon);
        return this;
    }

    /**
     *  Initialize the segment LED display
     *
     *  @param {integer} [brightness] - The LED brightness in range 0 to 15. Default: 15
     * 
     */
    function setBrightness(brightness = 15) {
        if (typeof brightness != "integer" && typeof brightness != "float") brightness = 15;
        brightness = brightness.tointeger();

        if (brightness > 15) {
            brightness = 15;
            if (_debug) _logger.error("HT16K33Segment.setBrightness() brightness value out of range");
        }

        if (brightness < 0) {
            brightness = 0;
            if (_debug) _logger.error("HT16K33Segment.setBrightness() brightness value out of range");
        }

        if (_debug) _logger.log("Brightness set to " + brightness);
        brightness = brightness + 224;

        // Write the new brightness value to the HT16K33
        _led.write(_ledAddress, brightness.tochar() + "\x00");
    }

    /**
     *  Set or unset the segment LED display's central colon symbol
     *
     *  @param {bool} [showColon] - Whether the central colon should be lit. Default: true
     *
     *  @returns {intance} this  
     */
    function setColon(set = true) {
        if (typeof set != "bool") set = true;
        _buffer[HT16K33_SEG_CLASS_LED_COLON_ROW] = set ? 0xFF : 0x00;
        if (_debug) _logger.log(format("Colon set %s", (set ? "on" : "off")));
        return this;
    }

    /**
     *  Set the segment LED to flash at one of three pre-defined rates
     *
     *  @param {integer} [flashRate] - Flash rate in Herz. Must be 0.5, 1 or 2 for a flash, or 0 for no flash. Default: 0
     * 
     */
    function setDisplayFlash(flashRate = 0) {
        local values = [0, 2, 1, 0.5];
        local match = -1;
        foreach (i, value in values) {
            if (value == flashRate) {
                match = i;
                break;
            }
        }

        if (match == -1) {
            _logger.error("HT16K33Segment.setDisplayFlash() blink frequency invalid");
        } else {
            match = 0x81 + (match << 1);
            _led.write(_ledAddress, match.tochar() + "\x00");
            if (_debug) _logger.log(format("Display flash set to %d Hz", ((match - 0x81) >> 1)));
        }
    }

    /**
     *  Set the specified segment LED buffer row to a given numeric character, with a decimal point if required
     *
     *  Character matrix value is calculated by setting the bit(s) representing the segment(s) you want illuminated.
     *  Bit-to-segment mapping runs clockwise from the top around the outside of the matrix; the inner segment is bit 6:
     *
     *         0
     *         _
     *     5 |   | 1
     *       |   |
     *         - <----- 6
     *     4 |   | 2
     *       | _ |
     *         3
     * 
     *
     *  @param {integer} [digit]        - The display digit to be written to (0 - 4)
     *  @param {integer} [glyphPattern] - The integer index value of the character required
     *  @param {bool}    [hasDot]       - Whether the dot pixel to the right of the digit should be lit. Default: false
     *
     *  @returns {intance} this
     *
     */
    function writeGlyph(digit, glyphPattern, hasDot = false) {
        if (glyphPattern < 0x00 || glyphPattern > 0x7F) {
            _logger.error("HT16K33Segment.writeGlyph() glyph pattern value out of range");
            return this;
        }

        if (digit < 0 || digit > HT16K33_SEG_CLASS_LED_MAX_ROWS || digit == HT16K33_SEG_CLASS_LED_COLON_ROW) {
            _logger.error("HT16K33Segment.writeGlyph() row value out of range");
            return this;
        }
        
        _buffer[digit] = hasDot ? (glyphPattern | 0x80) : glyphPattern;
        if (_debug) _logger.log(format("Row %d set to character defined by pattern 0x%02x %s", digit, glyphPattern, (hasDot ? "with period" : "without period")));
        return this;
    }

    function writeChar(digit, pattern, hasDot = false) {
        return writeGlyph(digit, pattern, hasDot);
    }

    /**
     *  Set the specified segment LED buffer row to a given character, with a decimal point if required
     *
     *  @param {integer} [digit]  - The display digit to be written to (0 - 4)
     *  @param {integer} [number] - The integer required (0 - 16, 0-F)
     *  @param {bool}    [hasDot] - Whether the dot pixel to the right of the digit should be lit. Default: false
     *
     *  @returns {intance} this
     *
     */
    function writeNumber(digit, number, hasDot = false) {
        if (digit < 0 || digit > HT16K33_SEG_CLASS_LED_MAX_ROWS || digit == HT16K33_SEG_CLASS_LED_COLON_ROW) {
            _logger.error("HT16K33Segment.writeNumber() row value out of range");
            return this;
        }

        if (number < 0x00 || number > 0x0F) {
            _logger.error("HT16K33Segment.writeNumber() number value out of range");
            return this;
        }

        _buffer[digit] = hasDot ? (_digits[number] | 0x80) : _digits[number];
        if (_debug) _logger.log(format("Row %d set to integer %d %s", digit, number, (hasDot ? "with period" : "without period")));
        return this;
    }

    /**
     *  Set each row in the segment LED buffer to a specific character
     *
     *  @param {integer} [character] - The character to display on every segment. Default: clear space
     *
     *  @returns {intance} this
     *
     */
    function clearBuffer(character = HT16K33_SEG_CLASS_BLANK_CHAR) {
        if (character < 0 || character > HT16K33_SEG_CLASS_CHAR_COUNT - 1) {
            character = HT16K33_SEG_CLASS_BLANK_CHAR;
            _logger.error("HT16K33Segment.clearBuffer() character value out of range");
        }

        // Put 'character' into the buffer except row 2 (colon row)
        _buffer[0] = _digits[character];
        _buffer[1] = _digits[character];
        _buffer[3] = _digits[character];
        _buffer[4] = _digits[character];

        return this;
    }

    /**
     *  Set each row in the segment LED buffer to a specific character and update the display
     *
     */
    function clearDisplay() {
        clearBuffer().setColon().updateDisplay();
    }

    /**
     *  Write the segment LED buffer out to the display itself
     *
     */
    function updateDisplay() {
        local dataString = HT16K33_SEG_CLASS_DISPLAY_ADDRESS;
        for (local i = 0 ; i < 5 ; i++) dataString += _buffer[i].tochar() + "\x00";
        _led.write(_ledAddress, dataString);
    }

    /**
     *  Turn the segment LED display off
     * 
     */
    function powerDown() {
        if (_debug) _logger.log("Powering HT16K33Segment display down");
        _led.write(_ledAddress, HT16K33_SEG_CLASS_REGISTER_DISPLAY_OFF);
        _led.write(_ledAddress, HT16K33_SEG_CLASS_REGISTER_SYSTEM_OFF);
    }

    /**
     *  Turn the segment LED display on
     * 
     */
    function powerUp() {
        if (_debug) _logger.log("Powering HT16K33Segment display up");
        _led.write(_ledAddress, HT16K33_SEG_CLASS_REGISTER_SYSTEM_ON);
        _led.write(_ledAddress, HT16K33_SEG_CLASS_REGISTER_DISPLAY_ON);
    }

    /**
     *  Set the segment LED display to log extra debug info
     *
     *  @param {bool} [state] - Whether extra debugging is enabled (true) or not (false). Default: true
     *  
     */
    function setDebug(state = true) {
        if (typeof state != "bool") state = true;
        _debug = state;
    }
}
