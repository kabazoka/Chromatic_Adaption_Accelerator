import sys
import os
from PIL import Image

def ppm_to_png(ppm_file, png_file):
    """Convert a PPM file to PNG"""
    # Read PPM file
    with open(ppm_file, 'r') as f:
        lines = f.readlines()

    # Extract header info
    magic = lines[0].strip()
    if magic != 'P3':
        print(f"Error: {ppm_file} is not a P3 PPM file")
        return False

    # Skip comments
    i = 1
    while lines[i].startswith('#'):
        i += 1

    # Get dimensions
    width, height = map(int, lines[i].split())
    i += 1

    # Get max value
    max_val = int(lines[i].strip())
    i += 1

    # Create image
    img = Image.new('RGB', (width, height))
    pixels = img.load()

    # Read pixel data
    data = []
    for j in range(i, len(lines)):
        data.extend(lines[j].split())

    # Fill image with pixel data
    data_idx = 0
    for y in range(height):
        for x in range(width):
            r = int(data[data_idx])
            g = int(data[data_idx + 1])
            b = int(data[data_idx + 2])
            pixels[x, y] = (r, g, b)
            data_idx += 3

    # Save as PNG
    img.save(png_file)
    print(f"Converted {ppm_file} to {png_file}")
    return True

def main():
    # Check if input and output files were provided
    if len(sys.argv) != 3:
        print("Usage: python ppm_to_png.py input.ppm output.png")
        sys.exit(1)

    # Convert PPM to PNG
    ppm_file = sys.argv[1]
    png_file = sys.argv[2]
    
    if not os.path.exists(ppm_file):
        print(f"Error: {ppm_file} does not exist")
        sys.exit(1)

    if ppm_to_png(ppm_file, png_file):
        print("Conversion successful")
    else:
        print("Conversion failed")
        sys.exit(1)

if __name__ == '__main__':
    main() 