from yolo_trainer import YOLOTrainer
import os

def get_yaml_path(yaml_file_name:str):
    # Get the current working directory dynamically
    current_working_directory = os.getcwd()
    print("Current Working Directory:", current_working_directory)

    # Construct the path to the target file
    relative_path = os.path.join(current_working_directory, "dataset", yaml_file_name)

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
    trainer = YOLOTrainer(
        model_path="yolo11n.pt",
        yaml_path=get_yaml_path(yaml_file_name) # Path to dataset.yaml
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
    trainer.export_model(export_format="onnx", dynamic=False, simplify=True)

def train_itemized_model(yaml_file_name:str="item_price_data.yaml"):
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

    new_receipt_path = "item_receipt.png"
    inference_results = trainer.predict(new_receipt_path, save_results=True)
    trainer.export_model(export_format="onnx", dynamic=False, simplify=True)

# train_entire_receipt_model(yaml_file_name="data.yaml")
train_itemized_model(yaml_file_name="item_price_data.yaml")