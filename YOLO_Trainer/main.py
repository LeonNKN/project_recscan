from yolo_trainer import YOLOTrainer


trainer = YOLOTrainer(
    model_path="yolo11n.pt",
    yaml_path=fr"C:/Users/USER/Desktop/YOLO/2024/2024/data.yaml" # Path to dataset.yaml
)
trainer.train(epochs=50, img_size=640, batch_size=16)


evaluation_results = trainer.evaluate()
print(evaluation_results)

new_receipt_path = "receipt.jpg"
inference_results = trainer.predict(new_receipt_path, save_results=True)
trainer.export_model(export_format="onnx")