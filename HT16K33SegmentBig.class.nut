class HT16K33SegmentBig {
    // Hardware driver for Adafruit 1.2-inch 4-digit, 7-segment LED display
    // based on the Holtek HT16K33 controller.
    // The LED communicates over any imp I2C bus.

    // Written by Tony Smith (smittytone) 2014-16
    // Copyright Electric Imp, Inc. 2014-2016.
    // https://electricimp.com/
    // Licence: MIT

    // HT16K33 registers and HT16K33-specific variables
    static HT16K33_REGISTER_DISPLAY_ON  = "\x81";
    static HT16K33_REGISTER_DISPLAY_OFF = "\x80";
    static HT16K33_REGISTER_SYSTEM_ON   = "\x21";
    static HT16K33_REGISTER_SYSTEM_OFF  = "\x20";
    static HT16K33_DISPLAY_ADDRESS      = "\x00";
    static HT16K33_I2C_ADDRESS = 0x70;
    static HT16K33_BLANK_CHAR = 16;
    static HT16K33_MINUS_CHAR = 17;
    static HT16K33_CHAR_COUNT = 17;

    // Display specific constants
    static LED_MAX_ROWS = 4;
    static LED_COLON_ROW = 2;

    static version = [1,2,0];

    // Class properties; null for those defined in the Constructor
    _buffer = null;
    _digits = null;
    _led = null;
    _ledAddress = 0;
    _debug = false;

    constructor(i2cBus = null, i2cAddress = 0x70, debug = false) {
        // Parameters:
        //   1. A CONFIGURED imp I2C bus is to be used for the HT16K33
        //   2. The HT16K33's 7-bit I2C address (default: 0x70)
        //   3. Boolean to invoke extra debug log information (default: false)

        if (i2cBus == null || i2cAddress == 0) {
            server.error("HT16K33SegmentBig requires a valid imp I2C object and non-zero I2C address");
            return null;
        }

        _led = i2cBus;
        _ledAddress = i2cAddress << 1;
        _debug = debug;

        // _buffer stores the character matrix values for each row of the display
        // Including the center colon character:
        //
        //     0    1   2   3    4
        //    [ ]  [ ]     [ ]  [ ]
        //     -    -   .   -    -
        //    [ ]  [ ]  .  [ ]  [ ]
        _buffer = [0x00, 0x00, 0x00, 0x00, 0x00];

        // _digits store character matrices for 0-9, A-F, blank and minus
        _digits = [
            0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F,  // 0 - 9
            0x5F, 0x7C, 0x58, 0x5E, 0x7B, 0x71,                          // A - F
            0x00, 0x40                                                   // space, minus sign
        ];

        init();
    }

    function init(character = 16, brightness = 15) {
        // Parameters:
        //   1. Integer index for the digits[] character matrix to zero the display to
        //   2. Integer value for the initial display brightness, between 0 and 15
        // Returns:
        //   this

        // Initialise the display
        powerUp();
        setBrightness(brightness);
        clearBuffer(character);
        return this;
    }

    function updateDisplay() {
        // Converts the row-indexed buffer[] values into a single, combined
        // string and writes it to the HT16K33 via I2C
        local dataString = HT16K33_DISPLAY_ADDRESS;

        for (local i = 0 ; i < 5 ; ++i) {
            dataString = dataString + _buffer[i].tochar() + "\x00";
        }

        _led.write(_ledAddress, dataString);
    }

    function clearDisplay() {
        // Clears the display buffer and colon and updates the display - all in one
        clearBuffer().setColon().updateDisplay();
    }

    function clearBuffer(character = 16) {
        // Fills the buffer with a blank character, or the digits[] character matrix whose index is provided
        if (character < 0 || character > HT16K33_CHAR_COUNT - 1) {
            character = HT16K33_BLANK_CHAR;
            if (_debug) server.error("HT16K33SegmentBig.clearBuffer() passed out-of-range character value (0-16)");
        }

        // Put the clear_character into the buffer except row 2 (colon row)
        _buffer[0] = _digits[character];
        _buffer[1] = _digits[character];
        _buffer[3] = _digits[character];
        _buffer[4] = _digits[character];

        return this;
    }

    function setColon(colonPattern = 0) {
        // Sets the LED’s colon and decimal point lights
        // Parameter:
        //   1. An integer indicating which elements to light (OR the values required)
        //      0x00 - no colon
        //      0x02 - centre colon
        //      0x04 - left colon, lower dot
        //      0x08 - left colon, upper dot
        //      0x10 - decimal point (upper)
        // Returns:
        //   this

        if (colonPattern < 0 || colonPattern > 0x1E) {
            server.error("HT16K33SegmentBig.setColon() passed out-of-range colon pattern");
            return this;
        }

        _buffer[LED_COLON_ROW] = colonPattern;
        return this;
    }

    function writeChar(digit, pattern) {
        return writeGlyph(digit, pattern);
    }

    function writeGlyph(digit, pattern) {
        // Puts the character pattern into the buffer at the specified row.
        // Parameters:
        //   1. Integer specify the digit number from the left (0 - 4)
        //   2. Integer bit pattern that defines the character
        //      Bit-to-segment mapping runs clockwise from the top around the
        //      outside of the matrix; the inner segment is bit 6:
        //
        //           0
        //           _
        //       5 |   | 1
        //         |   |
        //           - <----- 6
        //       4 |   | 2
        //         | _ |
        //           3
        //
        // Returns:
        //   this

        if (pattern < 0 || pattern > 127) {
            server.error("HT16K33SegmentBig.writeGlyph() passed out-of-range character value (0-127)");
            return this;
        }

        if (digit < 0 || digit > LED_MAX_ROWS) {
            server.error("HT16K33SegmentBig.writeGlyph() passed out-of-range digit number (0-4)");
            return this;
        }

        _buffer[digit] = pattern;
        return this;
    }

    function writeNumber(digit, number) {
        // Sets the specified digit to the number
        // Parameters:
        //   1. The digit number (0 - 4)
        //   2. The number to be displayed (0 - 15 for '0' - 'F')
        // Returns:
        //   this

        if (digit < 0 || digit > LED_MAX_ROWS || digit == 2) {
            server.error("HT16K33SegmentBig.writeNumber() passed out-of-range digit number (0-1, 3-4)");
            return this;
        }

        if (number < 0x00 || number > 0x0F) {
            server.error("HT16K33SegmentBig.writeNumber() passed out-of-range number value (0x00-0x0F)");
            return this;
        }

        _buffer[digit] = _digits[number];
        return this;
    }

    function setBrightness(brightness = 15) {
        // Set the LED brightness
        // Parameters:
        //   1. Integer specifying the brightness (0 - 15; default 15)

        if (brightness > 15) {
            if (_debug) server.log("HT16K33SegmentBig.setBrightness() passed out-of-range brightness value (0-15)");
            brightness = 15;
        }

        if (brightness < 0) {
            if (_debug) server.log("HT16K33SegmentBig.setBrightness() passed out-of-range brightness value (0-15)");
            brightness = 0;
        }

        if (_debug) server.log("Setting brightness to " + brightness);
        brightness = brightness + 224;

        // Write the new brightness value to the HT16K33
        _led.write(_ledAddress, brightness.tochar() + "\x00");
    }

    function setDisplayFlash(flashRate = 0) {
        // Parameters:
        //    1. Flash rate in Herz. Must be 0.5, 1 or 2 for a flash, or 0 for no flash
        // Returns:
        //    Nothing

        local values = [0, 2, 1, 0.5];
        local match = -1;
        foreach (i, value in values) {
            if (value == flashRate) {
                match = i;
                break;
            }
        }

        if (match == -1) {
            server.error("HT16K33SegmentBig.setDisplayFlash() passed an invalid blink frequency");
            return this;
        }

        match = 0x81 + (match << 1);
        _led.write(_ledAddress, match.tochar() + "\x00");
        if (_debug) server.log(format("Display flash set to %d Hz", ((match - 0x81) >> 1)));
    }

    function powerDown() {
        if (_debug) server.log("Powering HT16K33SegmentBig display down");
        _led.write(_ledAddress, HT16K33_REGISTER_DISPLAY_OFF);
        _led.write(_ledAddress, HT16K33_REGISTER_SYSTEM_OFF);
    }

    function powerUp() {
        if (_debug) server.log("Powering HT16K33SegmentBig display up");
        _led.write(_ledAddress, HT16K33_REGISTER_SYSTEM_ON);
        _led.write(_ledAddress, HT16K33_REGISTER_DISPLAY_ON);
    }
}
