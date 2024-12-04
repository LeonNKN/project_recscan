import cv2
import numpy as np
import pytesseract
from PIL import Image, ImageDraw, ImageEnhance
import onnxruntime as ort


def preprocess_image(image_path, input_size=(640, 640)):
    """
    Preprocess the image for RGB input.
    Args:
        image_path (str): Path to the receipt image.
        input_size (tuple): The size to resize the image to (width, height).
    Returns:
        np.ndarray: Preprocessed image ready for model input.
        PIL.Image: Original image for later use.
    """
    img = Image.open(image_path).convert("L")  # Convert to grayscale
    enhancer = ImageEnhance.Contrast(img)
    img = enhancer.enhance(2)  # Enhance contrast
    img_resized = img.resize(input_size)  # Resize image to model input size

    # Convert grayscale to 3-channel RGB by duplicating the single channel
    img_np = np.asarray(img_resized, dtype="float32") / 255.0  # Normalize to [0, 1]
    img_np = np.stack([img_np, img_np, img_np], axis=-1)  # Convert 1-channel to 3-channel RGB
    img_np = np.transpose(img_np, (2, 0, 1))  # Convert HWC to CHW
    img_np = np.expand_dims(img_np, axis=0)  # Add batch dimension

    return img_np, img


def detect_regions_with_nms(image_path, detection_model, labels, conf_threshold=0.1, iou_threshold=0.5):
    """
    Detect regions of interest using the ONNX model with manual NMS.
    Args:
        image_path (str): Path to the receipt image.
        detection_model (str): Path to the ONNX object detection model.
        labels (list): List of class labels.
        conf_threshold (float): Confidence threshold for filtering detections.
        iou_threshold (float): IOU threshold for NMS.
    Returns:
        list: Detected regions with labels and bounding boxes.
    """
    # Load the ONNX model
    session = ort.InferenceSession(detection_model)

    # Preprocess the image
    input_data, original_img = preprocess_image(image_path)
    input_name = session.get_inputs()[0].name
    output_name = session.get_outputs()[0].name

    # Run inference
    detections = session.run([output_name], {input_name: input_data})[0]
    print("Raw Detections Output Shape:", detections.shape)

    # Process YOLO grid output (assuming no NMS applied)
    boxes, confidences, class_ids = [], [], []
    for detection in detections[0]:
        x_center, y_center, width, height, conf = detection[:5]
        scores = detection[5:]
        class_id = np.argmax(scores)
        confidence = scores[class_id] * conf

        if confidence > conf_threshold:
            x1 = int((x_center - width / 2) * original_img.width)
            y1 = int((y_center - height / 2) * original_img.height)
            x2 = int((x_center + width / 2) * original_img.width)
            y2 = int((y_center + height / 2) * original_img.height)

            boxes.append([x1, y1, x2, y2])
            confidences.append(float(confidence))
            class_ids.append(class_id)

    # Apply Non-Maximum Suppression (NMS)
    indices = cv2.dnn.NMSBoxes(boxes, confidences, conf_threshold, iou_threshold)
    detected_regions = []
    for i in indices.flatten():
        detected_regions.append({
            "label": labels[class_ids[i]],
            "confidence": confidences[i],
            "box": boxes[i]
        })

    return detected_regions, original_img


def extract_text_from_regions(image, regions):
    """
    Extract text from detected regions using OCR.
    Args:
        image (PIL.Image): The original receipt image.
        regions (list): Detected regions with bounding boxes and labels.
    Returns:
        dict: Extracted text for each region.
    """
    extracted_data = {"Items": [], "Total": None, "Address": None}

    for region in regions:
        box = region["box"]
        cropped_img = image.crop((box[0], box[1], box[2], box[3]))
        text = pytesseract.image_to_string(cropped_img).strip()
        print(f"Extracted Text for {region['label']}: {text}")  # Debugging

        if region["label"] == "Item":
            extracted_data["Items"].append(text)
        elif region["label"] == "Total":
            extracted_data["Total"] = text
        elif region["label"] == "Address":
            extracted_data["Address"] = text

    return extracted_data


def parse_receipt_data(extracted_data):
    """
    Parse the OCR results to structure receipt data.
    Args:
        extracted_data (dict): Raw text data extracted from OCR.
    Returns:
        dict: Parsed receipt data.
    """
    items = []
    total = None

    # Process items
    for item_text in extracted_data["Items"]:
        try:
            name, price = item_text.rsplit(" ", 1)  # Split text into name and price
            price = float(price.replace(",", "."))
            items.append({"name": name, "price": price})
        except ValueError:
            continue  # Skip invalid items

    # Process total
    if extracted_data["Total"]:
        try:
            total = float(extracted_data["Total"].replace(",", "."))
        except ValueError:
            pass

    return {"items": items, "total": total, "address": extracted_data["Address"]}


def process_receipt(image_path, detection_model, labels, conf_threshold=0.1):
    """
    Full receipt processing pipeline: detection, OCR, and parsing.
    Args:
        image_path (str): Path to the receipt image.
        detection_model (str): Path to the ONNX object detection model.
        labels (list): List of class labels.
        conf_threshold (float): Confidence threshold for filtering detections.
    Returns:
        dict: Parsed receipt data.
    """
    # Step 1: Detect regions
    detected_regions, original_img = detect_regions_with_nms(image_path, detection_model, labels, conf_threshold)
    print("Detected Regions:", detected_regions)

    # Step 2: Extract text from regions
    extracted_data = extract_text_from_regions(original_img, detected_regions)
    print("Extracted Text:", extracted_data)

    # Step 3: Parse receipt data
    receipt_data = parse_receipt_data(extracted_data)
    return receipt_data


# Example Usage
if __name__ == "__main__":
    # Paths to resources
    image_path = "receipt.jpg"  # Replace with your receipt image path
    detection_model = fr"C:\Users\USER\Desktop\FINAL_PROJECT\project_recscan\YOLO_Trainer\model\train15\weights\best.onnx"

    detection_model.pred
    labels = ["Item", "Total", "Address"]  # Define your class labels

    # Process the receipt
    receipt_data = process_receipt(image_path, detection_model, labels, conf_threshold=0.1)

    # Print results
    print("\nFinal Parsed Receipt Data:")
    print("Items:")
    for item in receipt_data["items"]:
        print(f"- {item['name']}: ${item['price']:.2f}")
    if receipt_data["total"] is not None:
        print(f"Total: ${receipt_data['total']:.2f}")
    else:
        print("Total: Not detected")
    if receipt_data["address"] is not None:
        print(f"Address: {receipt_data['address']}")
    else:
        print("Address: Not detected")
