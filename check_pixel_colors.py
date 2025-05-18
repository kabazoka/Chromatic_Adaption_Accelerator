import sys
import os

def read_ppm_pixels(ppm_file, num_pixels=5):
    """Read the first few pixels from a PPM file"""
    with open(ppm_file, 'r') as f:
        lines = f.readlines()
    
    # Skip header (P3, comments, dimensions, max value)
    data_line_idx = 4  # Usually the 5th line has the pixel data
    
    # Find first non-comment line after P3
    i = 1
    while i < len(lines) and lines[i].startswith('#'):
        i += 1
    
    # Read dimensions
    i += 1  # Skip dimensions line
    i += 1  # Skip max value line
    
    # Start reading pixel data
    pixels = []
    pixel_count = 0
    values = []
    
    for line in lines[i:]:
        values.extend([int(val) for val in line.strip().split()])
        while len(values) >= 3 and pixel_count < num_pixels:
            pixels.append((values[0], values[1], values[2]))
            values = values[3:]
            pixel_count += 1
        
        if pixel_count >= num_pixels:
            break
    
    return pixels

def print_pixel_info(pixels, label):
    """Display pixel information with RGB and hex values"""
    print(f"\n{label} Pixels:")
    print("-" * 40)
    for i, (r, g, b) in enumerate(pixels):
        hex_color = f"#{r:02x}{g:02x}{b:02x}"
        print(f"Pixel {i+1}: RGB({r}, {g}, {b}) = {hex_color}")

def compare_pixel_colors(input_file, output_file, num_pixels=10):
    """Compare the first few pixels from input and output PPM files"""
    if not os.path.exists(input_file):
        print(f"Error: Input file {input_file} not found")
        return False
    
    if not os.path.exists(output_file):
        print(f"Error: Output file {output_file} not found")
        return False
    
    print(f"Analyzing the first {num_pixels} pixels from:")
    print(f"- Input: {input_file}")
    print(f"- Output: {output_file}")
    
    input_pixels = read_ppm_pixels(input_file, num_pixels)
    output_pixels = read_ppm_pixels(output_file, num_pixels)
    
    print_pixel_info(input_pixels, "Input")
    print_pixel_info(output_pixels, "Output")
    
    # Check for channel swapping
    if len(input_pixels) > 0 and len(output_pixels) > 0:
        in_px = input_pixels[0]
        out_px = output_pixels[0]
        
        print("\nChannel Analysis (first pixel):")
        print("-" * 40)
        
        # Check original order
        print("Original: Input RGB -> Output RGB")
        print(f"R: {in_px[0]} -> {out_px[0]}")
        print(f"G: {in_px[1]} -> {out_px[1]}")
        print(f"B: {in_px[2]} -> {out_px[2]}")
        
        # Check BGR interpretation
        print("\nBGR Interpretation: Input BGR -> Output RGB")
        print(f"R: {in_px[2]} -> {out_px[0]}")
        print(f"G: {in_px[1]} -> {out_px[1]}")
        print(f"B: {in_px[0]} -> {out_px[2]}")
        
        # Check other possible swaps
        print("\nRBG Interpretation: Input RBG -> Output RGB")
        print(f"R: {in_px[0]} -> {out_px[0]}")
        print(f"G: {in_px[2]} -> {out_px[1]}")
        print(f"B: {in_px[1]} -> {out_px[2]}")
        
        print("\nGRB Interpretation: Input GRB -> Output RGB")
        print(f"R: {in_px[1]} -> {out_px[0]}")
        print(f"G: {in_px[0]} -> {out_px[1]}")
        print(f"B: {in_px[2]} -> {out_px[2]}")
    
    return True

if __name__ == "__main__":
    # Default files in the simulation directory
    input_file = "simulation/modelsim/input_image.ppm"
    output_file = "simulation/modelsim/output_image.ppm"
    
    # Allow custom files via command line arguments
    if len(sys.argv) >= 3:
        input_file = sys.argv[1]
        output_file = sys.argv[2]
    
    compare_pixel_colors(input_file, output_file) 