import sys
import os
from PIL import Image

def png_to_ppm(png_file, ppm_file):
    """Convert a PNG file to PPM format (P3)"""
    # Check if input file exists
    if not os.path.exists(png_file):
        print(f"Error: {png_file} does not exist")
        return False
    
    try:
        # Open the PNG file
        img = Image.open(png_file)
        
        # Get image dimensions
        width, height = img.size
        
        # If image is not RGB, convert it
        if img.mode != "RGB":
            print(f"Converting image from {img.mode} to RGB")
            img = img.convert("RGB")
        
        # Open output file
        with open(ppm_file, 'w') as f:
            # Write PPM header
            f.write("P3\n")
            f.write(f"# Converted from {os.path.basename(png_file)}\n")
            f.write(f"{width} {height}\n")
            f.write("255\n")
            
            # Write pixel data
            pixels = list(img.getdata())
            count = 0
            
            for y in range(height):
                for x in range(width):
                    pixel = pixels[y * width + x]
                    f.write(f"{pixel[0]} {pixel[1]} {pixel[2]} ")
                    count += 1
                    
                    # Add newline after every 5 pixels for readability
                    if count % 5 == 0:
                        f.write("\n")
                
                # Ensure each row ends with a newline
                if width % 5 != 0:
                    f.write("\n")
        
        print(f"Converted {png_file} to {ppm_file}")
        print(f"Image dimensions: {width}x{height}")
        return True
    
    except Exception as e:
        print(f"Error converting {png_file} to {ppm_file}: {e}")
        return False

if __name__ == "__main__":
    # Check if input and output files were provided
    if len(sys.argv) != 3:
        print("Usage: python png_to_ppm.py input.png output.ppm")
        sys.exit(1)
    
    # Convert PNG to PPM
    png_file = sys.argv[1]
    ppm_file = sys.argv[2]
    
    if png_to_ppm(png_file, ppm_file):
        print("Conversion successful")
    else:
        print("Conversion failed")
        sys.exit(1) 