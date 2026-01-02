#!/bin/bash

# capture_app_screenshot.sh
# Script to capture a screenshot of the AutoRecall app and paste it into Cursor chat
# 
# Usage: ./capture_app_screenshot.sh

echo "Taking a screenshot of AutoRecall application..."

# Build and run the app in the background if not already running
if ! pgrep -x "AutoRecall" > /dev/null; then
    echo "AutoRecall is not running. Building and launching..."
    make build
    open .build/release/AutoRecall &
    # Wait for app to launch
    sleep 5
fi

# Use AppleScript to find and screenshot the window
osascript <<EOF
tell application "System Events"
    # Try to find AutoRecall window
    set appName to "AutoRecall"
    
    # If app is running, take screenshot of its window
    if exists process appName then
        # Set the app to frontmost
        tell process appName
            set frontmost to true
            delay 1
            
            # Take screenshot of the window
            tell application "System Events"
                keystroke "4" using {command down, shift down}
                delay 0.5
                # Press space to select window mode
                keystroke space
                delay 0.5
                # Click on the window to capture it
                click at {400, 400}
            end tell
            
            # Wait for screenshot to be taken
            delay 1
            
            # Switch to Cursor
            tell application "Cursor" to activate
            delay 1
            
            # Paste the screenshot into Cursor chat
            tell application "System Events"
                keystroke "v" using {command down}
                delay 0.5
                # Press return to send
                keystroke return
            end tell
        end tell
        
        # Output success message
        return "Screenshot captured and pasted to Cursor chat!"
    else
        return "Could not find AutoRecall window."
    end if
end tell
EOF

echo "Process completed. Check Cursor chat for the screenshot." 