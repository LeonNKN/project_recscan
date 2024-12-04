import os
from PIL import Image  # To get image dimensions

def get_image_dimensions(image_path):
    """
    Get the dimensions (width, height) of an image.

    Args:
        image_path (str): Path to the image file.
    Returns:
        tuple: (width, height) of the image.
    """
    with Image.open(image_path) as img:
        return img.width, img.height

def convert_to_yolo(annotation_path, image_dir, output_path):
    """
    Convert a single annotation file to YOLO format using dynamic image dimensions.

    Args:
        annotation_path (str): Path to the input annotation file.
        image_dir (str): Directory containing the corresponding images.
        output_path (str): Path to save the converted YOLO annotation file.
    """
    # Get corresponding image filename
    annotation_filename = os.path.basename(annotation_path)
    image_filename = annotation_filename.replace('.txt', '.jpg')  # Assuming .jpg images
    image_path = os.path.join(image_dir, image_filename)

    # Get image dimensions
    if not os.path.exists(image_path):
        print(f"Image not found for annotation: {annotation_path}")
        return
    image_width, image_height = get_image_dimensions(image_path)

    # Read annotation file
    with open(annotation_path, 'r') as file:
        lines = file.readlines()

    yolo_annotations = []
    for line in lines:
        parts = line.strip().split(',')
        if len(parts) < 9:
            continue

        # Extract bounding box coordinates
        x1, y1 = int(parts[0]), int(parts[1])
        x2, y2 = int(parts[2]), int(parts[3])
        x3, y3 = int(parts[4]), int(parts[5])
        x4, y4 = int(parts[6]), int(parts[7])

        # Calculate YOLO bounding box format
        x_center = (x1 + x2 + x3 + x4) / (4 * image_width)
        y_center = (y1 + y2 + y3 + y4) / (4 * image_height)
        width = (max(x1, x2, x3, x4) - min(x1, x2, x3, x4)) / image_width
        height = (max(y1, y2, y3, y4) - min(y1, y2, y3, y4)) / image_height

        # Append the YOLO annotation with class ID 0
        yolo_annotations.append(f"0 {x_center:.6f} {y_center:.6f} {width:.6f} {height:.6f}")

    # Write YOLO annotations to file
    with open(output_path, 'w') as output_file:
        output_file.write("\n".join(yolo_annotations))
        print(f"Converted annotations saved to: {output_path}")

def batch_convert(input_annotations_dir, image_dir, output_annotations_dir):
    """
    Loop through all annotation files and convert them to YOLO format using dynamic image dimensions.

    Args:
        input_annotations_dir (str): Directory containing input annotation files.
        image_dir (str): Directory containing the corresponding images.
        output_annotations_dir (str): Directory to save converted YOLO annotation files.
    """
    os.makedirs(output_annotations_dir, exist_ok=True)

    for annotation_filename in os.listdir(input_annotations_dir):
        if annotation_filename.endswith('.txt'):
            annotation_path = os.path.join(input_annotations_dir, annotation_filename)
            output_path = os.path.join(output_annotations_dir, annotation_filename)
            print(f"Processing {annotation_filename}...")
            convert_to_yolo(annotation_path, image_dir, output_path)

# Define paths
input_annotations_dir = "C:/Users/USER/Desktop/YOLO/archive/SROIE2019/train/annotations"  # Directory with input annotation files
image_dir = "C:/Users/USER/Desktop/YOLO/archive/SROIE2019/train/img" # Directory containing corresponding images
output_annotations_dir = "C:/Users/USER/Desktop/YOLO/archive/SROIE2019/train/annotations_2"  # Directory for YOLO annotations

# Run batch conversion
batch_convert(input_annotations_dir, image_dir, output_annotations_dir)
