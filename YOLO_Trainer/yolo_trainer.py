from ultralytics import YOLO
import yaml
import os
import tempfile  # To create temporary YAML files
import matplotlib.pyplot as plt
from PIL import Image, ImageEnhance

class YOLOTrainer:
    def __init__(self, model_path: str, yaml_path: str = None, train_images: str = None, val_images: str = None, class_names: list = None):
        """
        Initialize the YOLOTrainer class.

        Args:
            model_path (str): Path to the pre-trained YOLO model.
            yaml_path (str, optional): Path to the YAML configuration file. Default is None.
            train_images (str, optional): Path to the training images directory. Default is None.
            val_images (str, optional): Path to the validation images directory. Default is None.
            class_names (list, optional): List of class names. Default is None.
        """
        self.model_path = model_path
        self.yaml_path = yaml_path

        if self.yaml_path:
            # Load dataset configuration from YAML file
            with open(self.yaml_path, 'r') as file:
                yaml_data = yaml.safe_load(file)
                self.train_images = yaml_data['train']
                self.val_images = yaml_data['val']
                self.class_names = yaml_data['names']
        else:
            # Use parameters directly if YAML file is not provided
            self.train_images = train_images
            self.val_images = val_images
            self.class_names = class_names

        # Set the number of classes
        self.num_classes = len(self.class_names) if self.class_names else 0

        # Initialize the YOLO model
        self.model = YOLO(self.model_path)

    def prepare_data(self):
        """
        Prepares the dataset configuration for YOLO training.
        Returns the path to the temporary YAML file containing dataset paths and class metadata.
        """
        data_config = {
            'train': self.train_images,
            'val': self.val_images,
            'names': self.class_names,
            'nc': len(self.class_names)
        }

        # Save the configuration to a temporary YAML file
        temp_yaml_path = tempfile.NamedTemporaryFile(delete=False, suffix=".yaml").name
        with open(temp_yaml_path, 'w') as file:
            yaml.dump(data_config, file)

        print(f"Temporary dataset YAML saved to: {temp_yaml_path}")
        return temp_yaml_path

    def train(self, data_yaml_path=None, epochs: int = 50, img_size: int = 640, batch_size: int = 16):
        """
        Train the YOLO model.

        Args:
            data_yaml_path (str, optional): Path to the dataset YAML file. Default is None.
            epochs (int): Number of training epochs. Default is 50.
            img_size (int): Image size for training. Default is 640.
            batch_size (int): Batch size for training. Default is 16.
        """
        if not data_yaml_path:
            # Generate dataset YAML dynamically if not provided
            data_yaml_path = self.prepare_data()

        print(f"Starting training with dataset YAML: {data_yaml_path}")
        self.model.train(
            data=data_yaml_path,
            epochs=epochs,
            imgsz=img_size,
            batch=batch_size
        )
        print("Training completed!")

    def evaluate(self):
        """
        Evaluate the YOLO model on the validation set.
        """
        print("Evaluating the model on the validation dataset...")
        results = self.model.val()
        print(f"Evaluation results:\n{results}")
        return results

    def predict(self, image_path, save_results: bool = False, conf: float = 0.1):
        """
        Run inference on a given image with preprocessing.

        Args:
            image_path (str): Path to the input image.
            save_results (bool): Whether to save the inference results. Default is False.
            conf (float): Confidence threshold for detections. Default is 0.1.

        Returns:
            annotated_images (List[np.ndarray]): List of images with bounding boxes drawn.
        """
        print(f"Running inference on: {image_path}")

        # Preprocess the image
        img = Image.open(image_path).convert("L")  # Convert to grayscale
        enhancer = ImageEnhance.Contrast(img)
        img = enhancer.enhance(2)  # Enhance contrast
        preprocessed_path = "preprocessed_receipt.png"
        img.save(preprocessed_path)

        # Perform object detection
        results = self.model.predict(source=preprocessed_path, conf=conf, imgsz=640)

        annotated_images = []

        # Process results
        for result in results:
            print(result.boxes)  # Debug: Print detection boxes
            annotated_image = result.plot()  # Generate annotated image
            annotated_images.append(annotated_image)

        if save_results:
            # Save annotated images
            saved_dir = results[0].save()
            print(f"Annotated results saved to: {saved_dir}")

        # Return the annotated image(s)
        return annotated_images

    def export_model(self, export_format: str = 'onnx'):
        """
        Export the trained model to a specific format.

        Args:
            export_format (str): Format to export the model. Default is 'onnx'.
        """
        print(f"Exporting model to {export_format} format...")
        self.model.export(format=export_format)
        print(f"Model exported to {export_format} format successfully!")
