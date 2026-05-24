import UIKit

/// Extracts the dominant vivid colour from image data.
enum ColorExtractor {

    /// Returns a hex string for the most prominent vivid hue in `data`.
    /// Skips near-grey, very dark, and very light pixels so the result is always
    /// a usable accent colour.  Returns `nil` when no sufficiently vivid pixel
    /// is found (e.g. pure-grey or fully-transparent images).
    static func dominant(from data: Data) -> String? {
        guard let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else { return nil }

        // Downscale to 24×24 for speed — enough to capture the colour palette
        let side  = 24
        let bpp   = 4
        var pixels = [UInt8](repeating: 0, count: side * side * bpp)
        guard let ctx = CGContext(
            data: &pixels,
            width: side, height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * bpp,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        // Bucket pixels by hue into 36 bins (one per 10°)
        // Each bin accumulates: count, sum-R, sum-G, sum-B
        var buckets = [(count: Int, rSum: Int, gSum: Int, bSum: Int)](
            repeating: (0, 0, 0, 0), count: 36
        )

        for i in 0 ..< (side * side) {
            let base = i * bpp
            let r = CGFloat(pixels[base])   / 255
            let g = CGFloat(pixels[base+1]) / 255
            let b = CGFloat(pixels[base+2]) / 255
            var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
            UIColor(red: r, green: g, blue: b, alpha: 1).getHue(&h, saturation: &s, brightness: &v, alpha: &a)
            // Skip greys, blacks, and washed-out whites
            guard s > 0.22, v > 0.22, v < 0.97 else { continue }
            let bin = min(Int(h * 36), 35)
            buckets[bin].count += 1
            buckets[bin].rSum  += Int(r * 255)
            buckets[bin].gSum  += Int(g * 255)
            buckets[bin].bSum  += Int(b * 255)
        }

        // Pick the most populated bin
        guard let best = buckets.enumerated().max(by: { $0.element.count < $1.element.count }),
              best.element.count > 0
        else { return nil }

        let n  = best.element.count
        let aR = CGFloat(best.element.rSum / n) / 255
        let aG = CGFloat(best.element.gSum / n) / 255
        let aB = CGFloat(best.element.bSum / n) / 255

        // Boost saturation slightly so the result pops as an accent
        var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
        UIColor(red: aR, green: aG, blue: aB, alpha: 1).getHue(&h, saturation: &s, brightness: &v, alpha: &a)
        let boosted = UIColor(
            hue:        h,
            saturation: min(s * 1.35, 0.92),
            brightness: max(v, 0.52),
            alpha:      1
        )
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0
        boosted.getRed(&fr, green: &fg, blue: &fb, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(fr * 255), Int(fg * 255), Int(fb * 255))
    }
}
