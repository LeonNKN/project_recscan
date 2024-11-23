import cv2
import numpy as np
import pytesseract
from PIL import Image, ImageDraw, ImageEnhance
from yolo_trainer import YOLOTrainer

# Example Usage
if __name__ == "__main__":
    # Paths to resources
    image_path = "receipt.jpg"  # Replace with your receipt image path
    detection_model = fr"C:\Users\USER\Desktop\FINAL_PROJECT\project_recscan\YOLO_Trainer\model\train15\weights\best.onnx"

    model = YOLOTrainer(model_path=detection_model)
    result=model.predict(image_path=image_path,save_results=True,save_crop=True)
