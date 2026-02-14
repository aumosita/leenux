import Foundation

#if os(macOS)
import CoreText
import CoreGraphics
import AppKit

class KoreanRenderer {
    let font: CTFont
    let fontSize: CGFloat = 12  // Match ASCII better (was 16)
    
    init() {
        // Load Korean system font
        font = CTFontCreateWithName(
            "AppleSDDGothicNeo-Regular" as CFString,
            fontSize,
            nil
        )
        
        print("✓ Korean font loaded: AppleSDDGothicNeo-Regular")
    }
    
    func renderCharacter(_ char: Character) -> [UInt8]? {
        let string = String(char)
        
        // Create attributed string
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        
        let attributedString = NSAttributedString(
            string: string,
            attributes: attributes
        )
        
        let line = CTLineCreateWithAttributedString(attributedString as CFAttributedString)
        
        // Create bitmap context
        let width = 20
        let height = 20
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        // Fill beige background (245, 245, 220)
        context.setFillColor(red: 245/255.0, green: 245/255.0, blue: 220/255.0, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        // Draw text
        context.textPosition = CGPoint(x: 2, y: 4)
        CTLineDraw(line, context)
        
        // Get pixel data
        guard let data = context.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        return Array(UnsafeBufferPointer(start: pixels, count: width * height * 4))
    }
}

#else
// Fallback for non-macOS platforms
class KoreanRenderer {
    init() {
        print("⚠️  Korean rendering not available on this platform")
    }
    
    func renderCharacter(_ char: Character) -> [UInt8]? {
        return nil
    }
}
#endif
