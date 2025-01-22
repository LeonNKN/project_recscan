from yolo_trainer import YOLOTrainer
from ultralytics import YOLO
import os
import cv2

def get_yaml_path(yaml_file_name:str):
    # Get the current working directory dynamically
    current_working_directory = os.getcwd()
    print("Current Working Directory:", current_working_directory)

    # Construct the path to the target file
    relative_path = os.path.join(current_working_directory, "dataset",  yaml_file_name)

    # Normalize the path to use forward slashes
    normalized_path = relative_path.replace("\\", "/")
    print("Normalized Path:", normalized_path)

    # Check if the file exists
    if os.path.exists(relative_path):
        print("The file path is valid.")
    else:
        print("The file path is invalid.")
    return normalized_path

def train_entire_receipt_model(yaml_file_name:str="data.yaml"):
    #os.chdir(rf"C:\Users\USER\Desktop\FINAL_PROJECT\test\project_recscan\YOLO_Trainer\dataset")
    
    trainer = YOLOTrainer(
        model_path="yolov8x.pt",
        #yaml_path=get_yaml_path(yaml_file_name) # Path to dataset.yaml
        yaml_path=rf"C:\Users\USER\Desktop\FINAL_PROJECT\test\project_recscan\YOLO_Trainer\dataset\item_price_data.yaml"
    )

    trainer.train(epochs=50, img_size=640, batch_size=16)

    # Save class labels to a text file
    if trainer.class_names:
        with open("labels.txt", "w") as f:
            f.write("\n".join(trainer.class_names))
        print("Class labels saved to labels.txt")

    evaluation_results = trainer.evaluate()
    print(evaluation_results)

    new_receipt_path = "receipt.jpg"
    inference_results = trainer.predict(new_receipt_path, save_results=True)
    trainer.export_model(export_format="tflite")

def train_itemized_model(yaml_file_name:str="data.yaml"):
    trainer = YOLOTrainer(
        model_path="yolo11n.pt",
        yaml_path=get_yaml_path(yaml_file_name) # Path to dataset.yaml
    )

    trainer.train(data_yaml_path=trainer.yaml_path, epochs=50, img_size=640, batch_size=16)

    # Save class labels to a text file
    if trainer.class_names:
        with open("labels_item.txt", "w") as f:
            f.write("\n".join(trainer.class_names))
        print("Class labels saved to labels_item.txt")

    evaluation_results = trainer.evaluate()
    print(evaluation_results)

    new_receipt_path = fr"C:\Users\USER\Desktop\FINAL_PROJECT\test\project_recscan\YOLO_Trainer\receipt.jpg"
    trainer.export_model(export_format="tflite")
    inference_results = trainer.predict(new_receipt_path, save_results=True)
    

    # Run inference
    #results = tflite_model(new_receipt_path)

def inference_item_receipt():
    new_receipt_path = "item_receipt.png"
    path = r"D:\\Project_Reap\\project_recscan\\YOLO_Trainer\\dataset\\best_model_itemized\\best_saved_model\\best_float32.tflite"
    # Load the YOLO11 model

    tflite_model = YOLO(path)
    # Run inference
    results = tflite_model.predict(new_receipt_path, save_crop=True, save_txt=True, save_frames=True, conf=0.1)
    saved_dir = "item_receipt_result.png"
    # Save annotated images
    saved_dir = results[0].save()
    json = results[0].tojson()
    print(f"Annotated results saved to: {saved_dir}")
    # train_entire_receipt_model(yaml_file_name="data.yaml")
    # train_itemized_model(yaml_file_name="item_price_data.yaml")
    # inference_item_receipt()

def organize_crop_receipt_bboxes():
    # label - 0 (item), 3 (price)
    # Example format: (label, [x_center, y_center, width, height])
    # Initialize containers for items and prices
    items = []
    prices = []
    # Open the file and parse line by line
    with open("item_receipt.txt", "r") as file:
        lines = file.readlines()
        for line in lines:
            parts = line.split()

            # Ensure we are correctly unpacking the values
            if len(parts) == 5:  # Make sure there are exactly 5 elements in each line
                class_id = int(parts[0])
                x_center, y_center, box_width, box_height = map(float, parts[1:])
                
                # Append the parsed data as a flat tuple
                if class_id == 3:  # Price
                    prices.append((class_id, x_center, y_center, box_width, box_height))
                elif class_id == 0:  # Item
                    items.append((class_id, x_center, y_center, box_width, box_height))

    # Sort items and prices by y_center (vertical position)
    sorted_items = sorted(items, key=lambda x: x[2])  # Sort by y_center (index 2)
    sorted_prices = sorted(prices, key=lambda x: x[2])  # Sort by y_center (index 2)
    # print(type(items))
    # print("Items:", items)
    # print("Prices:", prices)

    # Load the receipt image
    image_path = "item_receipt.png"  # Replace with your receipt image path
    image = cv2.imread(image_path)
    height, width, _ = image.shape

    # Parse the bounding box data
    bounding_boxes = []
    bounding_boxes.extend(sorted_items)
    bounding_boxes.extend(sorted_prices)

    # Debug print to ensure bounding_boxes is correct
    print("Bounding Boxes:", bounding_boxes)
    # Create folders to save cropped items and prices
    import os
    os.makedirs("cropped_items", exist_ok=True)
    os.makedirs("cropped_prices", exist_ok=True)

    # Crop items and prices
    item_count = 1
    price_count = 1

    # Iterate through bounding boxes and crop
    for class_id, x_center, y_center, box_width, box_height in bounding_boxes:
        # Convert normalized coordinates to pixel values
        x_center_pixel = int(x_center * width)
        y_center_pixel = int(y_center * height)
        box_width_pixel = int(box_width * width)
        box_height_pixel = int(box_height * height)

        # Calculate top-left and bottom-right corners
        x1 = max(0, x_center_pixel - box_width_pixel // 2)
        y1 = max(0, y_center_pixel - box_height_pixel // 2)
        x2 = min(width, x_center_pixel + box_width_pixel // 2)
        y2 = min(height, y_center_pixel + box_height_pixel // 2)

        # Crop the region
        cropped_region = image[y1:y2, x1:x2]

        # Save the cropped region based on class ID
        if class_id == 0:  # Item
            cv2.imwrite(f"cropped_items/Item_{item_count}.jpg", cropped_region)
            item_count += 1
        elif class_id == 3:  # Price
            cv2.imwrite(f"cropped_prices/Price_{price_count}.jpg", cropped_region)
            price_count += 1

    print("Cropping completed. Check 'cropped_items' and 'cropped_prices' folders.")

#organize_crop_receipt_bboxes()
train_entire_receipt_model()
#train_itemized_model()

