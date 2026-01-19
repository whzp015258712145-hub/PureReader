from PIL import Image, ImageDraw

def fix_icon_corners(image_path, corner_radius_ratio=0.22):
    try:
        img = Image.open(image_path).convert("RGBA")
        width, height = img.size
        
        # Create a transparency mask
        mask = Image.new("L", (width, height), 0)
        draw = ImageDraw.Draw(mask)
        
        # Calculate corner radius (approx 22% for macOS Big Sur+ icons)
        radius = int(min(width, height) * corner_radius_ratio)
        
        # Draw the rounded rectangle on the mask (white = opaque, black = transparent)
        draw.rounded_rectangle([(0, 0), (width, height)], radius=radius, fill=255)
        
        # Apply the mask to the image
        img.putalpha(mask)
        
        # Save the result
        img.save(image_path)
        print(f"Successfully processed {image_path}: applied rounded corner mask.")
        
    except Exception as e:
        print(f"Error processing image: {e}")
        exit(1)

if __name__ == "__main__":
    fix_icon_corners("assets/images/app_icon_macos.png")
