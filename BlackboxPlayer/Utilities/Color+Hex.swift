/// @file Color+Hex.swift
/// @brief Extension to create SwiftUI Color from hex strings
/// @author BlackboxPlayer Development Team
/// @details Extends SwiftUI's Color type to add functionality for creating colors from hex strings.
///
/// Purpose of this file
/// ════════════════════════════════════════════════════════════════════════════════
/// Extends SwiftUI's Color type to add the ability to create colors from hex strings.
///
/// While SwiftUI Color doesn't natively accept hex strings, this Extension enables
/// the use of web-standard color codes like "#FF0000".
///
///
/// What are Hex Color Codes?
/// ════════════════════════════════════════════════════════════════════════════════
/// Hex (hexadecimal) color codes are a color representation method widely used in web and design tools.
///
/// Supported formats:
///
///    1) 3-digit RGB (#RGB)
///       Example: "#F00" → Red
///       Each digit has a value from 0~F (0~15) and is automatically expanded 2x.
///       #F00 → #FF0000
///
///    2) 6-digit RGB (#RRGGBB)
///       Example: "#FF0000" → Red
///       Each color channel (R, G, B) has a range of 00~FF (0~255).
///       This is the most commonly used format.
///
///    3) 8-digit ARGB (#AARRGGBB)
///       Example: "#80FF0000" → Semi-transparent Red (50% transparency)
///       The first 2 digits represent the alpha (transparency) channel.
///       AA=255 (opaque), 00=0 (fully transparent)
///
///
/// What is an Extension?
/// ════════════════════════════════════════════════════════════════════════════════
/// Extension is a powerful Swift feature that allows adding new functionality to existing types.
///
/// Characteristics:
///    • Can add functionality without modifying the original code
///    • Even though SwiftUI's Color is an Apple-created type, we can add features to it
///    • Can adopt protocols, add methods, add convenience initializers, etc.
///
/// Why use Extensions?
///    1) Code organization: Can group related functionality in one place
///    2) Reusability: Can use Color(hex: "#FF0000") form throughout the project
///    3) Readability: Color definitions become clearer
///
///
/// Bit Operation Concepts (For Beginners)
/// ════════════════════════════════════════════════════════════════════════════════
/// This code uses bit operations to convert hex strings to color values.
///
/// Basic concepts:
///    Computers store all numbers in binary (0s and 1s).
///    Hex (hexadecimal) is a human-readable representation of binary.
///
///    Example: 0xFF = 11111111 (binary) = 255 (decimal)
///
/// Bit operators used:
///
///    1) >> (Right Shift)
///       Shifts bits to the right.
///       Example: 0xFF00 >> 8 = 0x00FF
///          11111111 00000000 → 00000000 11111111
///
///       Meaning: Shifting right by 8 bits = dividing by 256
///
///    2) & (Bitwise AND)
///       Returns 1 only when both bits are 1.
///       Example: 0xFF00 & 0x00FF = 0x0000
///          11111111 00000000
///        & 00000000 11111111
///        = 00000000 00000000
///
///       Meaning: Used for masking (extracting specific bits)
///
/// Practical example:
///    hex = "FF0000" (red)
///    int = 0xFF0000 (value parsed as hexadecimal)
///
///    Extract red: int >> 16 = 0xFF0000 >> 16 = 0xFF (255)
///    Extract green: (int >> 8) & 0xFF = 0x00FF00 >> 8 = 0x00FF, 0x00FF & 0xFF = 0x00
///    Extract blue: int & 0xFF = 0xFF0000 & 0xFF = 0x00
///
///
/// What is the sRGB Color Space?
/// ════════════════════════════════════════════════════════════════════════════════
/// sRGB is the standard RGB color space, the color standard used by most displays
/// and on the web.
///
/// What is a Color Space?
///    Defines the method and range for representing colors.
///    The same RGB values can appear as different colors depending on the color space.
///
/// sRGB characteristics:
///    • Web standard color space
///    • Supported by most monitors
///    • Each RGB channel uses Double values in the range 0.0~1.0
///    • We normalize the 0~255 values extracted from hex by dividing by 255 to get 0.0~1.0
///
///
/// Usage Examples
/// ════════════════════════════════════════════════════════════════════════════════
/// ```swift
/// // 1. Using 6-digit hex colors (most common)
/// let red = Color(hex: "#FF0000")
/// let green = Color(hex: "00FF00")  // # symbol can be omitted
/// let blue = Color(hex: "#0000FF")
///
/// // 2. 3-digit shorthand notation
/// let white = Color(hex: "#FFF")  // Same as #FFFFFF
/// let black = Color(hex: "#000")  // Same as #000000
///
/// // 3. 8-digit ARGB (with transparency)
/// let transparentRed = Color(hex: "#80FF0000")  // 50% transparent red
/// let opaqueBlue = Color(hex: "#FF0000FF")      // 100% opaque blue
///
/// // 4. Using in SwiftUI views
/// Text("Hello")
///     .foregroundColor(Color(hex: "#FF6B6B"))
///     .background(Color(hex: "#F0F0F0"))
///
/// // 5. EventType color display (actual project usage example)
/// Rectangle()
///     .fill(Color(hex: eventType.colorHex))
///     .frame(width: 20, height: 20)
/// ```

import SwiftUI

// MARK: - Color Extension

/// @extension Color
/// @brief Extension to create SwiftUI Color from hex strings
/// @details Supports 3-digit (#RGB), 6-digit (#RRGGBB), and 8-digit (#AARRGGBB) hex formats,
///          and creates Color objects in the sRGB color space by extracting each color channel through bit operations.
extension Color {

    // MARK: Hex String Initializer

    /// @brief Create a Color from a hex string
    /// @details Creates a SwiftUI Color object from a hex string.
    ///
    /// Initializer Explanation (For Beginners)
    /// ─────────────────────────────────────────────────────────────────
    /// An initializer is a special method called when creating an instance of a struct or class.
    /// It's defined with the `init` keyword and doesn't specify a return type.
    ///
    /// This initializer takes a hex parameter of type String and creates a Color instance.
    /// Usage example: let red = Color(hex: "#FF0000")
    ///
    ///
    /// Overall Operation Flow
    /// ─────────────────────────────────────────────────────────────────
    /// Step 1: Sanitize input string (trimming)
    /// Step 2: Parse hex string to 64-bit integer
    /// Step 3: Extract color channels (A, R, G, B) using bit operations
    /// Step 4: Normalize 0~255 values to 0.0~1.0 range
    /// Step 5: Create Color object using sRGB color space
    ///
    /// @param hex Hex color string (e.g., "#FF0000", "FF0000", "#F00")
    ///            Supported formats: 3-digit (#RGB), 6-digit (#RRGGBB), 8-digit (#AARRGGBB)
    init(hex: String) {
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Step 1: Sanitize input string
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        //
        // Purpose:
        //    Sanitizes the string so it can be correctly processed regardless of whether
        //    the user enters "#FF0000", "FF0000", "#ff0000", etc.
        //
        // How it works:
        //    The trimmingCharacters(in:) method removes characters that are not
        //    in the specified character set.
        //
        //    CharacterSet.alphanumerics is a character set containing letters (a-z, A-Z)
        //    and digits (0-9).
        //
        //    .inverted reverses this to mean "things that are not letters or digits".
        //    That is, #, spaces, special characters, etc. are all removed.
        //
        // Examples:
        //    Input: "#FF0000"  → After sanitization: "FF0000"
        //    Input: "FF 00 00" → After sanitization: "FF0000"
        //    Input: "#ff0000"  → After sanitization: "ff0000" (lowercase allowed)
        //
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Step 2: Convert hex string to integer
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        //
        // Why UInt64 type was chosen:
        //    UInt64 is an unsigned (no negative values) 64-bit integer.
        //    It can store values from 0 to 18,446,744,073,709,551,615.
        //
        //    8-digit hex (#AARRGGBB) has a maximum of 0xFFFFFFFF (4,294,967,295),
        //    so UInt64 can safely store it.
        //
        // Initial value of 0:
        //    A variable must be given an initial value when declared.
        //    If Scanner fails to parse, int remains 0.
        //
        var int: UInt64 = 0

        // What is Scanner?
        //    A Foundation framework class that is a tool for parsing strings.
        //    scanHexInt64(_:) converts hexadecimal strings to UInt64.
        //
        // Meaning of the & operator:
        //    In Swift, & is used when passing inout parameters.
        //    inout means that if the parameter is modified inside the function, the original variable is also changed.
        //
        //    scanHexInt64 stores the converted value directly in the int variable.
        //
        // Example:
        //    hex = "FF0000"
        //    → Scanner parses it
        //    → int = 0xFF0000 = 16,711,680 (decimal)
        //
        Scanner(string: hex).scanHexInt64(&int)

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Step 3: Extract color channels (bit operations)
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        //
        // Variable declaration style:
        //    let a, r, g, b: UInt64
        //    This is syntax for declaring 4 variables at once.
        //    All are of type UInt64 and no values have been assigned yet.
        //
        // Why use let?
        //    The a, r, g, b values don't change once set, so they're declared as constants (let).
        //    This ensures immutability and prevents accidentally changing values.
        //
        let a, r, g, b: UInt64

        // Classifying hex length with switch:
        //    Applies different parsing logic depending on the length of the hex string.
        //
        switch hex.count {

        // ─────────────────────────────────────────────────────────────────
        // Case 1: 3-digit RGB (#RGB)
        // ─────────────────────────────────────────────────────────────────
        //
        // Format example: "#F0A" → #FF00AA
        //
        // Conversion principle:
        //    Each hex digit (0~F) is expanded 2x.
        //    F(15) → FF(255)
        //    0(0)  → 00(0)
        //    A(10) → AA(170)
        //
        // Bit structure:
        //    int = 0x0RGB (only 12 bits used)
        //    Example: 0xF0A = 0000 1111 0000 1010
        //
        // Channel extraction process:
        //
        //    1) Alpha (transparency): Always 255 (fully opaque)
        //       a = 255
        //
        //    2) Red: Extract upper 8 bits then multiply by 17
        //       int >> 8 = 0xF0A >> 8 = 0x00F (0000 0000 0000 1111)
        //       0x00F * 17 = 15 * 17 = 255
        //
        //       Why multiply by 17?
        //       Formula to expand one hex digit (0~F) to two digits (00~FF):
        //       value * 17 = value * 16 + value = value << 4 | value
        //       Example: F * 17 = 15 * 17 = 255 = 0xFF
        //
        //    3) Green: Extract middle 4 bits then multiply by 17
        //       (int >> 4) & 0xF = (0xF0A >> 4) & 0xF
        //                        = 0x0F0 & 0x00F
        //                        = 0x000 (0)
        //       0x000 * 17 = 0
        //
        //    4) Blue: Extract lower 4 bits then multiply by 17
        //       int & 0xF = 0xF0A & 0x00F = 0x00A (10)
        //       0x00A * 17 = 10 * 17 = 170
        //
        // Final result:
        //    #F0A → RGBA(255, 0, 170, 255) = opaque pink
        //
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)

        // ─────────────────────────────────────────────────────────────────
        // Case 2: 6-digit RGB (#RRGGBB) - Most common
        // ─────────────────────────────────────────────────────────────────
        //
        // Format example: "#FF0000" → red
        //
        // Bit structure:
        //    int = 0xRRGGBB (24 bits)
        //    Example: 0xFF0000 = 11111111 00000000 00000000
        //
        // Channel extraction process:
        //
        //    1) Alpha: Always 255 (fully opaque)
        //       a = 255
        //
        //    2) Red: Shift upper 16 bits
        //       int >> 16 = 0xFF0000 >> 16 = 0x0000FF (255)
        //
        //       Bit representation:
        //       11111111 00000000 00000000 >> 16
        //       = 00000000 00000000 11111111
        //
        //    3) Green: Extract middle 8 bits
        //       (int >> 8) & 0xFF = (0xFF0000 >> 8) & 0xFF
        //                         = 0x00FF00 & 0x0000FF
        //                         = 0x000000 (0)
        //
        //       Bit representation:
        //       11111111 00000000 00000000 >> 8
        //       = 00000000 11111111 00000000
        //       & 00000000 00000000 11111111
        //       = 00000000 00000000 00000000
        //
        //    4) Blue: Extract lower 8 bits
        //       int & 0xFF = 0xFF0000 & 0x0000FF = 0x000000 (0)
        //
        //       Bit representation:
        //       11111111 00000000 00000000
        //       & 00000000 00000000 11111111
        //       = 00000000 00000000 00000000
        //
        // Final result:
        //    #FF0000 → RGBA(255, 0, 0, 255) = opaque red
        //
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)

        // ─────────────────────────────────────────────────────────────────
        // Case 3: 8-digit ARGB (#AARRGGBB)
        // ─────────────────────────────────────────────────────────────────
        //
        // Format example: "#80FF0000" → 50% transparent red
        //
        // Bit structure:
        //    int = 0xAARRGGBB (32 bits)
        //    Example: 0x80FF0000 = 10000000 11111111 00000000 00000000
        //
        // Channel extraction process:
        //
        //    1) Alpha: Uppermost 8 bits
        //       int >> 24 = 0x80FF0000 >> 24 = 0x00000080 (128)
        //
        //       Bit representation:
        //       10000000 11111111 00000000 00000000 >> 24
        //       = 00000000 00000000 00000000 10000000
        //
        //       Meaning of alpha values:
        //       0 = Fully transparent (invisible)
        //       128 = 50% transparent (semi-transparent)
        //       255 = Fully opaque (opaque)
        //
        //    2) Red: Shift upper 16 bits then mask
        //       (int >> 16) & 0xFF = (0x80FF0000 >> 16) & 0xFF
        //                          = 0x000080FF & 0x000000FF
        //                          = 0x000000FF (255)
        //
        //    3) Green: Shift upper 8 bits then mask
        //       (int >> 8) & 0xFF = (0x80FF0000 >> 8) & 0xFF
        //                         = 0x0080FF00 & 0x000000FF
        //                         = 0x00000000 (0)
        //
        //    4) Blue: Extract lower 8 bits
        //       int & 0xFF = 0x80FF0000 & 0x000000FF = 0x00000000 (0)
        //
        // Final result:
        //    #80FF0000 → RGBA(255, 0, 0, 128) = 50% transparent red
        //
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)

        // ─────────────────────────────────────────────────────────────────
        // Case 4: Invalid format handling
        // ─────────────────────────────────────────────────────────────────
        //
        // Occurs when:
        //    hex length is not 3, 6, or 8 (e.g., 1, 2, 4, 5, 7, 9+ digits)
        //
        // Default value:
        //    Returns black (R=0, G=0, B=0) but fully opaque (A=255)
        //
        // Error handling strategy:
        //    In Swift, errors can be thrown, but for usability we've chosen
        //    to return a safe default value.
        //
        //    Advantages: Invalid inputs like Color(hex: "invalid") are handled without crashes
        //    Disadvantages: Developers may have difficulty noticing typos
        //
        // Alternative designs:
        //    Could return Optional Color (init?(hex: String))
        //    or throw an error, but the current design prioritizes convenience.
        //
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Steps 4~5: Create sRGB Color object
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        //
        // What is Normalization?
        //    The process of converting integers in the 0~255 range to real numbers in the 0.0~1.0 range.
        //
        //    SwiftUI Color accepts color channel values in the 0.0~1.0 range.
        //    Therefore, we divide by 255 to convert:
        //    • 0 ÷ 255 = 0.0 (minimum value)
        //    • 128 ÷ 255 ≈ 0.502 (middle value)
        //    • 255 ÷ 255 = 1.0 (maximum value)
        //
        // Double type conversion:
        //    UInt64 must be converted to Double for division results to be real numbers.
        //    Integer division discards the decimal portion.
        //
        //    Example: Int(255) / Int(255) = 1 (integer)
        //             Double(255) / 255.0 = 1.0 (real number)
        //
        // .sRGB color space:
        //    The first parameter of Color is RGBColorSpace.
        //    .sRGB is the standard RGB color space used on the web and most displays.
        //
        //    Other color spaces:
        //    • .sRGBLinear: Linear RGB without gamma correction
        //    • .displayP3: Supports wider color gamut (recent Apple devices)
        //
        // Meaning of self.init:
        //    Calls another initializer of the original type from within an Extension.
        //    self refers to "the instance being created".
        //
        //    SwiftUI Color provides the following default initializer:
        //    init(_ colorSpace: RGBColorSpace,
        //         red: Double,
        //         green: Double,
        //         blue: Double,
        //         opacity: Double)
        //
        // Actual conversion example:
        //    r = 255, g = 0, b = 0, a = 128 (red, 50% transparent)
        //    → red: 255/255 = 1.0
        //      green: 0/255 = 0.0
        //      blue: 0/255 = 0.0
        //      opacity: 128/255 ≈ 0.502
        //
        //    Result: 50% transparent red Color object
        //
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
