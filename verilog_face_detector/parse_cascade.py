# parse_cascade.py
from lxml import etree
import struct

xml_file = 'data/haarcascade_frontalface_default.xml'
mem_file = 'data/cascade_data.mem'

print(f"Parsing {xml_file}...")
tree = etree.parse(xml_file)
root = tree.getroot()

# Extract cascade information
cascade = root.find('.//cascade')
if cascade is None:
    print("Error: Could not find cascade in XML")
    exit(1)

# Get image dimensions
width_elem = cascade.find('width')
height_elem = cascade.find('height')
if width_elem is not None and height_elem is not None:
    width = int(width_elem.text)
    height = int(height_elem.text)
    print(f"Base window size: {width}x{height}")
else:
    # Default OpenCV face cascade size
    width = 24
    height = 24
    print(f"Using default base window size: {width}x{height}")

# Parse all features first
features_elem = cascade.find('features')
feature_list = features_elem.findall('_')
print(f"Found {len(feature_list)} features")

# Store all features
features = []
for feature in feature_list:
    rects = feature.find('rects')
    rect_list = rects.findall('_')
    
    feature_rects = []
    for rect in rect_list:
        rect_data = rect.text.strip().split()
        x = int(rect_data[0])
        y = int(rect_data[1])
        w = int(rect_data[2])
        h = int(rect_data[3])
        weight = float(rect_data[4].rstrip('.'))
        feature_rects.append((x, y, w, h, weight))
    
    features.append(feature_rects)

# Parse all stages
stages_elem = cascade.find('stages')
stage_list = stages_elem.findall('_')

print(f"Found {len(stage_list)} stages")

# Open output file
with open(mem_file, 'w') as f:
    # Write header information
    f.write(f"// Haar Cascade Data for Face Detection\n")
    f.write(f"// Number of stages: {len(stage_list)}\n")
    f.write(f"// Number of features: {len(feature_list)}\n")
    f.write(f"// Base window: {width}x{height}\n")
    f.write(f"//\n")
    f.write(f"// Format:\n")
    f.write(f"// Stage threshold (32-bit float as hex)\n")
    f.write(f"// Number of weak classifiers in stage\n")
    f.write(f"// For each weak classifier:\n")
    f.write(f"//   Feature index, threshold, left_val, right_val (32-bit values)\n")
    f.write(f"//\n")
    f.write(f"// Features are stored separately at the end\n")
    f.write(f"//\n\n")
    
    total_weak_classifiers = 0
    
    for stage_idx, stage in enumerate(stage_list):
        # Get stage threshold
        stage_threshold_elem = stage.find('stageThreshold')
        stage_threshold = float(stage_threshold_elem.text)
        
        # Convert float to hex (IEEE 754)
        threshold_hex = format(struct.unpack('>I', struct.pack('>f', stage_threshold))[0], '08x')
        f.write(f"// Stage {stage_idx}\n")
        f.write(f"{threshold_hex}\n")
        
        # Get weak classifiers
        weak_classifiers = stage.find('weakClassifiers')
        classifiers = weak_classifiers.findall('_')
        
        # Write number of weak classifiers
        f.write(f"{len(classifiers):08x}\n")
        total_weak_classifiers += len(classifiers)
        
        for classifier in classifiers:
            # Get internal nodes - format: "0 -1 featureIndex threshold"
            internal_nodes_elem = classifier.find('internalNodes')
            internal_data = internal_nodes_elem.text.strip().split()
            feature_idx = int(internal_data[2])
            threshold = float(internal_data[3])
            
            # Get leaf values - format: "leftValue rightValue"
            leaf_values_elem = classifier.find('leafValues')
            leaf_data = leaf_values_elem.text.strip().split()
            left_val = float(leaf_data[0])
            right_val = float(leaf_data[1])
            
            # Convert to hex
            feature_idx_hex = format(feature_idx, '08x')
            threshold_hex = format(struct.unpack('>I', struct.pack('>f', threshold))[0], '08x')
            left_hex = format(struct.unpack('>I', struct.pack('>f', left_val))[0], '08x')
            right_hex = format(struct.unpack('>I', struct.pack('>f', right_val))[0], '08x')
            
            f.write(f"{feature_idx_hex} {threshold_hex} {left_hex} {right_hex}\n")
        
        f.write(f"\n")  # Blank line between stages
    
    # Write features section
    f.write(f"// === FEATURES SECTION ===\n")
    f.write(f"// Total features: {len(features)}\n\n")
    
    for feat_idx, feature_rects in enumerate(features):
        f.write(f"// Feature {feat_idx} - {len(feature_rects)} rectangles\n")
        f.write(f"{len(feature_rects):08x}\n")
        
        for x, y, w, h, weight in feature_rects:
            weight_hex = format(struct.unpack('>I', struct.pack('>f', weight))[0], '08x')
            f.write(f"{x:08x} {y:08x} {w:08x} {h:08x} {weight_hex}\n")
        
        f.write(f"\n")

print(f"Parsing complete!")
print(f"Total weak classifiers: {total_weak_classifiers}")
print(f"Total features: {len(features)}")
print(f"Output written to {mem_file}")