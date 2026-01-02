#!/usr/bin/swift
import Cocoa
import Foundation

// Function to create a modern, enhanced app icon
func createEnhancedIcon() {
    guard let originalImage = NSImage(contentsOfFile: "original_icon.png") else {
        print("Failed to load original icon")
        return
    }
    
    let size = CGSize(width: 1024, height: 1024)
    let newImage = NSImage(size: size)
    
    newImage.lockFocus()
    
    // Draw gradient background
    let gradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.1, green: 0.2, blue: 0.4, alpha: 1.0), // Deep blue
            NSColor(calibratedRed: 0.2, green: 0.3, blue: 0.7, alpha: 1.0)  // Brighter blue
        ]
    )
    
    let gradientRect = NSRect(x: 0, y: 0, width: size.width, height: size.height)
    gradient?.draw(in: gradientRect, angle: 45)
    
    // Create rounded rectangle for the base
    let baseRect = NSRect(x: size.width * 0.15, y: size.width * 0.15, 
                         width: size.width * 0.7, height: size.height * 0.7)
    let baseShape = NSBezierPath(roundedRect: baseRect, xRadius: 80, yRadius: 80)
    
    NSColor(calibratedWhite: 1.0, alpha: 0.25).setFill()
    baseShape.fill()
    
    // Draw a "brain" or memory circuit pattern (simplified)
    let circuitColor = NSColor(calibratedRed: 0.9, green: 0.9, blue: 1.0, alpha: 0.9)
    circuitColor.setStroke()
    
    // Draw stylized "AR" letters with a tech-memory theme
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size.width * 0.4, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraphStyle,
        .strokeWidth: -5,
        .strokeColor: NSColor(calibratedRed: 0.1, green: 0.3, blue: 0.6, alpha: 1.0)
    ]
    
    let text = "AR" // AutoRecall
    let textRect = NSRect(x: 0, y: size.height * 0.25, width: size.width, height: size.height * 0.5)
    text.draw(in: textRect, withAttributes: attributes)
    
    // Add a circular "memory" dot accent
    let dotPath = NSBezierPath(ovalIn: NSRect(x: size.width * 0.7, 
                                             y: size.height * 0.25, 
                                             width: size.width * 0.15, 
                                             height: size.width * 0.15))
    NSColor(calibratedRed: 0.9, green: 0.4, blue: 0.4, alpha: 1.0).setFill() // Red dot
    dotPath.fill()
    
    // Add a subtle shine/reflection
    let shineColor = NSColor(calibratedWhite: 1.0, alpha: 0.3)
    shineColor.setFill()
    
    let shinePath = NSBezierPath()
    shinePath.move(to: NSPoint(x: size.width * 0.3, y: size.height * 0.7))
    shinePath.curve(to: NSPoint(x: size.width * 0.7, y: size.height * 0.8),
                   controlPoint1: NSPoint(x: size.width * 0.5, y: size.height * 0.85),
                   controlPoint2: NSPoint(x: size.width * 0.6, y: size.height * 0.85))
    shinePath.line(to: NSPoint(x: size.width * 0.75, y: size.height * 0.6))
    shinePath.curve(to: NSPoint(x: size.width * 0.3, y: size.height * 0.7),
                   controlPoint1: NSPoint(x: size.width * 0.6, y: size.height * 0.65),
                   controlPoint2: NSPoint(x: size.width * 0.4, y: size.height * 0.65))
    shinePath.fill()
    
    newImage.unlockFocus()
    
    // Save the enhanced icon
    if let tiffData = newImage.tiffRepresentation,
       let bitmapImage = NSBitmapImageRep(data: tiffData),
       let pngData = bitmapImage.representation(using: .png, properties: [:]) {
        try? pngData.write(to: URL(fileURLWithPath: "enhanced_icon.png"))
        print("Enhanced icon created successfully")
    } else {
        print("Failed to save enhanced icon")
    }
}

// Execute the icon enhancement
createEnhancedIcon() 