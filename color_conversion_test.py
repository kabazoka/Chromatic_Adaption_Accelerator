import sys
import os
from PIL import Image

def test_color_conversion():
    """Test the PNG to PPM to PNG color conversion to verify channel ordering"""
    # Create a small test image with known colors
    width, height = 3, 1
    test_img = Image.new('RGB', (width, height))
    
    # Set colors: Red, Green, Blue
    test_colors = [(255, 0, 0), (0, 255, 0), (0, 0, 255)]
    for x in range(width):
        test_img.putpixel((x, 0), test_colors[x])
    
    # Save as PNG
    test_png = "test_colors.png"
    test_img.save(test_png)
    print(f"Created test PNG with colors: {test_colors}")
    
    # Convert to PPM using png_to_ppm.py
    test_ppm = "test_colors.ppm"
    # Import the conversion function from png_to_ppm.py
    from png_to_ppm import png_to_ppm
    png_to_ppm(test_png, test_ppm)
    
    # Read the PPM file contents
    with open(test_ppm, 'r') as f:
        ppm_lines = f.readlines()
    
    # Skip header (P3, comment, dimensions, max value)
    data_line = ppm_lines[4].strip()  # Line with actual color values
    values = [int(val) for val in data_line.split()]
    
    # Check if RGB values are in the correct order
    # Each pixel has 3 values (R, G, B)
    pixel_values = [(values[i], values[i+1], values[i+2]) for i in range(0, len(values), 3)]
    print(f"PPM color values: {pixel_values}")
    
    # Convert back to PNG
    test_png2 = "test_colors_2.png"
    # Import the conversion function from ppm_to_png.py
    from ppm_to_png import ppm_to_png
    ppm_to_png(test_ppm, test_png2)
    
    # Verify the colors in the new PNG
    verify_img = Image.open(test_png2)
    output_colors = [verify_img.getpixel((x, 0)) for x in range(width)]
    print(f"Converted PNG color values: {output_colors}")
    
    # Check if colors match the original
    if output_colors == test_colors:
        print("✓ SUCCESS: Color values preserved correctly through conversion")
    else:
        print("✗ ERROR: Color values changed during conversion")
        for i, (original, converted) in enumerate(zip(test_colors, output_colors)):
            if original != converted:
                print(f"  Pixel {i}: Original {original} → Converted {converted}")
    
    # Clean up
    print("\nTest files created for inspection:")
    print(f"- {test_png}")
    print(f"- {test_ppm}")
    print(f"- {test_png2}")

if __name__ == "__main__":
    test_color_conversion() 