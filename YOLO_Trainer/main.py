from yolo_trainer import YOLOTrainer


trainer = YOLOTrainer(
    model_path="yolo11n.pt",
    yaml_path=fr"C:/Users/USER/Desktop/YOLO/2024/2024/data.yaml" # Path to dataset.yaml
)


trainer.train(epochs=2, img_size=640, batch_size=16)

# Save class labels to a text file
if trainer.class_names:
    with open("labels.txt", "w") as f:
        f.write("\n".join(trainer.class_names))
    print("Class labels saved to labels.txt")

evaluation_results = trainer.evaluate()
print(evaluation_results)

new_receipt_path = "receipt.jpg"
inference_results = trainer.predict(new_receipt_path, save_results=True)
trainer.export_model(export_format="onnx", opset=12, dynamic=False, simplify=True)