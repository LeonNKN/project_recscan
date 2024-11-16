from yolo_trainer import YOLOTrainer


# Define the model and YAML paths
model_path = "yolo11n.pt"
yaml_path = "dataset.yaml"

# Initialize the trainer with the YAML file
trainer = YOLOTrainer(
    model_path="yolo11n.pt",
    train_images="C:/Users/USER/Desktop/YOLO/archive/SROIE2019/train/img",
    val_images="C:/Users/USER/Desktop/YOLO/archive/SROIE2019/test/img",
    class_names=['company', 'date', 'address', 'total'] 
)
trainer.train(epochs=50, img_size=640, batch_size=16)


# Train the model on the COCO8 example dataset for 100 epochs
#results = model.train(data="dataset.yaml", epochs=100, imgsz=640, batch=16)

#evaluation_results = trainer.evaluate()

#new_receipt_path = "C:/Users/USER\Desktop/FINAL_PROJECT/project_recscan/YOLO_Trainer/new_test_receipt.png"
#inference_results = trainer.predict("new_receipt_path", save_results=True)
#trainer.export_model(export_format="onnx")