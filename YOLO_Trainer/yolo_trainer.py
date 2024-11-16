from ultralytics import YOLO
import yaml

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
        Returns a dictionary containing dataset paths and class metadata.
        """
        return {
            'train': self.train_images,
            'val': self.val_images,
            'names': self.class_names,
            'nc': len(self.class_names)
        }

    def train(self, data_yaml_path=None, epochs: int = 50, img_size: int = 640, batch_size: int = 16):
        """
        Train the YOLO model.

        Args:
            epochs (int): Number of training epochs. Default is 50.
            img_size (int): Image size for training. Default is 640.
            batch_size (int): Batch size for training. Default is 16.
        """
        data_config = self.prepare_data()
        print(f"Starting training with the following configuration: {data_config}")
        
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

    def predict(self, image_path: str, save_results: bool = False):
        """
        Run inference on a given image.

        Args:
            image_path (str): Path to the input image.
            save_results (bool): Whether to save the inference results. Default is False.
        """
        print(f"Running inference on image: {image_path}")
        results = self.model(image_path)
        results.show()

        if save_results:
            results.save()
            print(f"Results saved to {results.files}")

        return results

    def export_model(self, export_format: str = 'onnx'):
        """
        Export the trained model to a specific format.

        Args:
            export_format (str): Format to export the model. Default is 'onnx'.
        """
        print(f"Exporting model to {export_format} format...")
        self.model.export(format=export_format)
        print(f"Model exported to {export_format} format successfully!")