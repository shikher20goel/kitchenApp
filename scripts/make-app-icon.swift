#!/usr/bin/env swift
//
//  Draws Rasoi's app icon and writes it into the asset catalog.
//
//      swift scripts/make-app-icon.swift
//
//  A warm saffron ground, a simple covered pot, and one sage leaf rising from it — the app in one
//  glyph. No mascot, no text, nothing that dates (SPEC §8). Re-run after changing the palette;
//  the output is deterministic.
//
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024.0
let outputPath = CommandLine.arguments.dropFirst().first
    ?? "Rasoi/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

func color(_ hex: UInt32) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

let saffron = color(0xE8A33D)
let saffronDeep = color(0xD4862A)
let cream = color(0xFBF6EC)
let sage = color(0x6F8F66)
let ink = color(0x3A2E1E)

guard let space = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(
          data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8,
          bytesPerRow: 0, space: space,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else {
    fatalError("could not create a drawing context")
}

// Ground: a soft saffron gradient, top-left lighter.
if let gradient = CGGradient(colorsSpace: space, colors: [saffron, saffronDeep] as CFArray,
                             locations: [0, 1]) {
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size),
                               end: CGPoint(x: size, y: 0), options: [])
}

// The pot: a rounded body with a lid and two handles, in cream.
let bodyWidth = size * 0.52
let bodyHeight = size * 0.30
let bodyRect = CGRect(x: (size - bodyWidth) / 2, y: size * 0.24, width: bodyWidth, height: bodyHeight)
let body = CGPath(roundedRect: bodyRect, cornerWidth: size * 0.06, cornerHeight: size * 0.06,
                  transform: nil)
context.setFillColor(cream)
context.addPath(body)
context.fillPath()

// Handles.
let handleWidth = size * 0.09
let handleHeight = size * 0.07
for x in [bodyRect.minX - handleWidth * 0.75, bodyRect.maxX - handleWidth * 0.25] {
    let handle = CGPath(roundedRect: CGRect(x: x, y: bodyRect.midY, width: handleWidth, height: handleHeight),
                        cornerWidth: handleHeight / 2, cornerHeight: handleHeight / 2, transform: nil)
    context.setFillColor(cream)
    context.addPath(handle)
    context.fillPath()
}

// Lid: a flatter rounded bar sitting on the body, plus a knob.
let lidRect = CGRect(x: bodyRect.minX - size * 0.03, y: bodyRect.maxY - size * 0.01,
                     width: bodyRect.width + size * 0.06, height: size * 0.055)
context.setFillColor(cream)
context.addPath(CGPath(roundedRect: lidRect, cornerWidth: size * 0.027, cornerHeight: size * 0.027,
                       transform: nil))
context.fillPath()

let knob = CGRect(x: size / 2 - size * 0.035, y: lidRect.maxY - size * 0.005,
                  width: size * 0.07, height: size * 0.045)
context.setFillColor(cream)
context.addPath(CGPath(roundedRect: knob, cornerWidth: size * 0.022, cornerHeight: size * 0.022,
                       transform: nil))
context.fillPath()

// A leaf rising from the lid: two arcs meeting at the tip, with a stem.
let leafBottom = CGPoint(x: size / 2, y: knob.maxY + size * 0.01)
let leafTop = CGPoint(x: size / 2 + size * 0.09, y: size * 0.83)
let leaf = CGMutablePath()
leaf.move(to: leafBottom)
leaf.addQuadCurve(to: leafTop, control: CGPoint(x: size * 0.40, y: size * 0.72))
leaf.addQuadCurve(to: leafBottom, control: CGPoint(x: size * 0.62, y: size * 0.64))
context.setFillColor(sage)
context.addPath(leaf)
context.fillPath()

// Leaf vein, in the ground colour so it reads at small sizes.
context.setStrokeColor(saffronDeep)
context.setLineWidth(size * 0.012)
context.setLineCap(.round)
context.move(to: leafBottom)
context.addQuadCurve(to: leafTop, control: CGPoint(x: size * 0.51, y: size * 0.68))
context.strokePath()

// A shadow line under the pot grounds the whole thing.
context.setFillColor(ink.copy(alpha: 0.10) ?? ink)
context.addPath(CGPath(roundedRect: CGRect(x: bodyRect.minX + size * 0.04, y: bodyRect.minY - size * 0.02,
                                           width: bodyRect.width - size * 0.08, height: size * 0.025),
                       cornerWidth: size * 0.012, cornerHeight: size * 0.012, transform: nil))
context.fillPath()

guard let image = context.makeImage() else { fatalError("could not render the icon") }
let url = URL(fileURLWithPath: outputPath)
guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("could not open \(outputPath) for writing")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("could not write \(outputPath)") }
print("wrote \(outputPath) at \(Int(size))×\(Int(size))")
