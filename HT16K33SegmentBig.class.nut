class HT16K33SegmentBig {

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

    static version = [1,1,0];

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
        //    0    1   2   3    4
        //   [ ]  [ ]  .  [ ]  [ ]
        //    -    -       -    -
        //   [ ]  [ ]  .  [ ]  [ ]

        _buffer = [0x00, 0x00, 0x00, 0x00, 0x00];

        // _digits store character matrices for 0-9, A-F, blank and minus
        _digits = [
            0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F,  // 0 - 9
            0x5F, 0x7C, 0x58, 0x5E, 0x7B, 0x71,                          // A - F
            0x00, 0x40                                                   // space, minus sign
        ];

        init();
    }

    function init(clearChar = 16, brightness = 15) {
        // Parameters:
        //   1. Integer index for the digits[] character matrix to zero the display to
        //   2. Integer value for the initial display brightness, between 0 and 15

        // Set the brightness, which wipes and power cyles the dispay
        setBrightness(brightness);

        // Clear the screen to the chosen character
        setColon(0x00);
        clearBuffer(clearChar);
        updateDisplay();
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

    function clearBuffer(clearChar = 16) {
        // Fills the buffer with a blank character, or the digits[] character matrix whose index is provided
        if (clearChar < 0 || clearChar > HT16K33_CHAR_COUNT - 1) clearChar = HT16K33_BLANK_CHAR;

        // Put the clear_character into the buffer except row 2 (colon row)
        _buffer[0] = _digits[clearChar];
        _buffer[1] = _digits[clearChar];
        _buffer[3] = _digits[clearChar];
        _buffer[4] = _digits[clearChar];
        return this;
    }

    function clearDisplay(clearChar = 16) {
        clearBuffer(clearChar).updateDisplay();
    }

    function setColon(bitVal = 0) {
        // Sets the colon (row 2) to the required pattern; also sets the initial
        // colon and the raised decimal point at row 3
        //  0x00 - no colon
        //  0x02 - centre colon
        //  0x04 - left colon, lower dot
        //  0x08 - left colon, upper dot
        //  0x10 - decimal point (upper)
        _buffer[2] = bitVal;
        return this;
    }

    function writeChar(row , charVal) {
        // Puts the input character matrix (an 8-bit integer) into the specified row,
        // adding a decimal point if required. Character matrix value is calculated by
        // setting the bit(s) representing the segment(s) you want illuminated.
        // Bit-to-segment mapping runs clockwise from the top around the outside of the
        // matrix; the inner segment is bit 6:
        //
        //      0
        //      _
        //  5 |   | 1
        //    |   |
        //      - <----- 6
        //  4 |   | 2
        //    | _ |
        //      3
        //

        if (charVal < 0 || charVal > 127) {
            if (_debug) server.error("HT16K33SegmentBig.writeChar() passed out-of-range character value (0-127)");
            return this;
        }

        if (row < 0 || row > 4 || row == 2) {
            if (_debug) server.error("HT16K33SegmentBig.writeChar() passed out-of-range row value (0, 1, 3, 4)");
            return this;
        }

        _buffer[row] = charVal;
        return this;
    }

    function writeNumber(row, number) {
        // Puts the number glyph into the specified row, adding a decimal point if required
        if (row < 0 || row > 4 || row == 2) {
            if (_debug) server.error("HT16K33SegmentBig.writeNumber() passed out-of-range row value (0, 1, 3, 4)");
            return this;
        }

        if (number < 0x00 || number > 0x0F) {
            if (_debug) server.error("HT16K33SegmentBig.writeNumber() passed out-of-range number value (0x00-0x0F)");
            return this;
        }

        _buffer[row] = _digits[number];
        return this;
    }

    function setBrightness(brightness = 15) {
        // This function is called when the app changes the clock's brightness
        // Default: 15

        if (brightness > 15) {
            if (_debug) server.log("HT16K33SegmentBig.setBrightness() passed out-of-range brightness value (0-15)");
            brightness = 15;
        }

        if (brightness < 0) {
            if (_debug) server.log("HT16K33SegmentBig.setBrightness() passed out-of-range brightness value (0-15)");
            brightness = 0;
        }

        brightness = brightness + 224;

        // Power cycle the display
        powerDown();
        powerUp();

        // Write the new brightness value to the HT16K33
        _led.write(_ledAddress, brightness.tochar() + "\x00");

        // Restore the current _buffer contents
        updateDisplay();
    }

    function powerDown() {
        if (_debug) server.log("Powering HT16K33SegmentBig display down");
        _led.write(_ledAddress, HT16K33_REGISTER_DISPLAY_OFF);
        _led.write(_ledAddress, HT16K33_REGISTER_SYSTEM_OFF);
    }

    function powerUp() {
        if (_debug) server.log("Powering up HT16K33SegmentBig display");
        _led.write(_ledAddress, HT16K33_REGISTER_SYSTEM_ON);
        _led.write(_ledAddress, HT16K33_REGISTER_DISPLAY_ON);
    }
}
