#!/bin/bash
# Enhanced cleanup script to remove old test and fix scripts
# and also clean up disk space

echo "Enhanced cleanup script running..."

# Check disk space
echo "Checking disk space..."
FREE_SPACE=$(df -k . | awk 'NR==2 {print $4}')
FREE_SPACE_MB=$((FREE_SPACE / 1024))
echo "Available space: ${FREE_SPACE_MB}MB"

if [ $FREE_SPACE_MB -lt 1024 ]; then
  echo "⚠️ Warning: Less than 1GB of free space available"
  echo "Performing additional cleanup..."
  
  # Clean Swift package manager caches
  if [ -d ~/Library/Caches/org.swift.swiftpm ]; then
    echo "Cleaning Swift Package Manager caches..."
    rm -rf ~/Library/Caches/org.swift.swiftpm
  fi
  
  # Clean Xcode derived data if it exists
  if [ -d ~/Library/Developer/Xcode/DerivedData ]; then
    echo "Cleaning Xcode DerivedData..."
    rm -rf ~/Library/Developer/Xcode/DerivedData/*
  fi
  
  # Clean build directory
  if [ -d .build ]; then
    echo "Removing .build directory..."
    rm -rf .build
  fi
fi

# List of scripts to remove
SCRIPTS_TO_REMOVE=(
  "fix_critical_issues.sh"
  "fix_memory_management.sh"
  "memory_leak_analyzer.sh"
  "optimize_performance.sh"
  "test_all_fixes.sh"
  "test_app_functionality.swift"
  "test_app_status.swift"
  "test_clipboard.swift"
)

# Remove each script if it exists
for script in "${SCRIPTS_TO_REMOVE[@]}"; do
  if [ -f "$script" ]; then
    echo "Removing $script"
    rm "$script"
  fi
done

# Move any useful test content to the test directory if needed
if [ -d "temp_icon_design" ]; then
  echo "Moving temp_icon_design to Resources"
  mkdir -p Resources/design
  mv temp_icon_design/* Resources/design/ 2>/dev/null
  rmdir temp_icon_design
fi

echo "Creating the Tools directory if it doesn't exist"
mkdir -p Tools

# Check if we have enough space now
FREE_SPACE_AFTER=$(df -k . | awk 'NR==2 {print $4}')
FREE_SPACE_MB_AFTER=$((FREE_SPACE_AFTER / 1024))
echo "Available space after cleanup: ${FREE_SPACE_MB_AFTER}MB"

echo "Done! All old scripts have been removed and disk space has been cleaned up."
echo "The new build system is now available via the Makefile."
echo "Run 'make help' to see all available commands." 