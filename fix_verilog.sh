#!/bin/bash
# Script to fix SystemVerilog constructs that might cause issues with Icarus Verilog

# Find all Verilog files
VERILOG_FILES=$(find rtl testbench -name "*.v")

echo "Fixing Verilog files for Icarus Verilog compatibility..."

for file in $VERILOG_FILES; do
    echo "Processing $file..."
    
    # Create a temporary file
    TMP_FILE=$(mktemp)
    
    # Replace SystemVerilog constructs with Verilog-2001 constructs
    
    # Replace "int i" style loop variables with integer declarations
    sed -E 's/for \(int ([a-zA-Z0-9_]+) = ([0-9]+)/integer \1; initial \1 = \2; for (\1 = \2/g' "$file" > "$TMP_FILE"
    mv "$TMP_FILE" "$file"
    
    # Replace $past with a workaround or comment it out
    sed -E 's/\$past\(([^)]+)\)/\/* $past(\1) - Please handle manually *\//g' "$file" > "$TMP_FILE"
    mv "$TMP_FILE" "$file"
    
    # Replace 'string' type with reg/wire as appropriate
    sed -E 's/input string ([a-zA-Z0-9_]+)/input reg [1023:0] \1/g' "$file" > "$TMP_FILE"
    mv "$TMP_FILE" "$file"
    
    # Replace arrays with unpacked dimensions
    # This is just a basic example - might need manual fixing for complex cases
    sed -E 's/reg \[([0-9]+):([0-9]+)\] ([a-zA-Z0-9_]+) \[([0-9]+):([0-9]+)\]/reg [(\4-\5)*(\1-\2+1)+(\1-\2):0] \3/g' "$file" > "$TMP_FILE"
    mv "$TMP_FILE" "$file"
    
    # Replace void function with task
    sed -E 's/function void ([a-zA-Z0-9_]+)/task \1/g' "$file" > "$TMP_FILE"
    mv "$TMP_FILE" "$file"
    
    sed -E 's/endfunction/endtask/g' "$file" > "$TMP_FILE"
    mv "$TMP_FILE" "$file"
    
    echo "Completed processing $file"
done

echo "Done."
echo "Note: Some SystemVerilog constructs may still require manual fixing."
echo "Please review the changes and make further modifications if needed." 