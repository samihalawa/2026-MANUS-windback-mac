#!/bin/bash

# Simple script to take a screenshot of the desktop
echo "Taking screenshot of the desktop..."

# Take screenshot of the entire screen
screencapture -x autorecall_screenshot.png

# Check if the screenshot was created
if [ -f "autorecall_screenshot.png" ]; then
    echo "Screenshot saved as autorecall_screenshot.png"
    echo "File size: $(du -h autorecall_screenshot.png | cut -f1)"
else
    echo "Failed to take screenshot"
fi 