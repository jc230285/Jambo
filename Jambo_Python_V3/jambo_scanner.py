import math
from PIL import ImageGrab

def decode_5x5(pos, square_size):
    x0, y0 = pos
    # Calculate cell size based on 5x5 grid
    cell_size = math.floor(square_size / 5)
    
    try:
        # Grab the area
        img = ImageGrab.grab(bbox=(x0, y0, x0 + square_size, y0 + square_size))
    except OSError:
        return []

    bytes_out = []
    for idx in range(25):
        row = idx // 5
        col = idx % 5
        
        # Sample the center of each cell
        cx = col * cell_size + cell_size // 2
        cy = row * cell_size + cell_size // 2
        
        try:
            # Get RGB values
            r, g, b = img.getpixel((cx, cy))[:3]
            bytes_out.extend([r, g, b])
        except IndexError:
            bytes_out.extend([0, 0, 0])
            
    return bytes_out

def validate_checksum(vals):
    # We expect at least 18 bytes (1 Checksum + 17 Data Fields)
    # The Lua script now sends 18 specific bytes (Slot...Combat) plus the checksum.
    if not vals or len(vals) < 18: 
        return False
    
    # Python Index 0 is the Checksum.
    # Python Indices 1 to 17 are the data fields.
    # Slice [1:18] captures indices 1 through 17.
    data_chunk = vals[1:18] 
    
    calc = sum(data_chunk) % 256
    read = vals[0]
    
    return calc == read

# Timestamp: 2023-12-02 10:45:00