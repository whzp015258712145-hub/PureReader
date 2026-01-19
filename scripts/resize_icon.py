from PIL import Image

def resize_icon(image_path, scale_factor=0.83): # 0.83 is approx standard for fitting inside the safe zone if the icon is full bleed
    try:
        # Open the image (should already have transparent corners from previous step)
        img = Image.open(image_path).convert("RGBA")
        original_width, original_height = img.size
        
        # Calculate new size
        new_width = int(original_width * scale_factor)
        new_height = int(original_height * scale_factor)
        
        # Resize the image using Lanczos filter for quality
        resized_img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
        
        # Create a new blank transparent canvas of the original size
        final_img = Image.new("RGBA", (original_width, original_height), (0, 0, 0, 0))
        
        # Calculate centering position
        x_offset = (original_width - new_width) // 2
        y_offset = (original_height - new_height) // 2
        
        # Paste the resized image onto the center of the canvas
        final_img.paste(resized_img, (x_offset, y_offset))
        
        # Save the result
        final_img.save(image_path)
        print(f"Successfully resized {image_path} to {scale_factor*100}% centered.")
        
    except Exception as e:
        print(f"Error processing image: {e}")
        exit(1)

if __name__ == "__main__":
    resize_icon("assets/images/app_icon_macos.png", scale_factor=0.8)
