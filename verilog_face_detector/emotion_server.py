import socket
import sys
import argparse
import time
import random

def main():
    parser = argparse.ArgumentParser(description='Emotion Classification Server')
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to')
    parser.add_argument('--port', type=int, default=8888, help='Port to bind to')
    parser.add_argument('--model', help='Path to model file (optional, uses mock if not provided)')
    args = parser.parse_args()

    print(f"Starting Emotion Server on {args.host}:{args.port}...")
    if args.model:
        print(f"Loading model from {args.model}...")
        # Real model loading would go here (tensorflow/keras)
        # For this test script, we'll use a mock to avoid dependencies/memory issues
        print("Model loaded (MOCK).")
    else:
        print("No model provided. Using MOCK classifier.")

    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    try:
        server_socket.bind((args.host, args.port))
        server_socket.listen(1)
        print("Listening for connections...")

        while True:
            client_socket, addr = server_socket.accept()
            print(f"Connection from {addr}")
            
            try:
                # Expect header: "ROI x y w h\n"
                header = ""
                while '\n' not in header:
                    chunk = client_socket.recv(1).decode('utf-8')
                    if not chunk: break
                    header += chunk
                
                print(f"Received header: {header.strip()}")
                
                if header.startswith("ROI"):
                    parts = header.strip().split()
                    if len(parts) >= 5:
                        x, y, w, h = map(int, parts[1:5])
                        print(f"Processing ROI: x={x}, y={y}, w={w}, h={h}")
                        
                        # Expect 4096 bytes of pixel data (64x64 image)
                        # In a real scenario, we might only send the ROI, 
                        # but for simplicity we assume the VPI sends the full 64x64 frame 
                        # or the ROI pixels. Let's assume full frame for now or just mock it.
                        # We'll just read some bytes to clear buffer if needed.
                        # client_socket.recv(4096) 
                        
                        # Simulate processing time
                        time.sleep(0.1)
                        
                        # Return result
                        emotions = ["Happy", "Sad", "Neutral", "Surprise", "Angry"]
                        result = random.choice(emotions)
                        confidence = 80.0 + random.random() * 19.9
                        response = f"{result} (confidence: {confidence:.2f}%)"
                        
                        print(f"Sending result: {response}")
                        client_socket.sendall((response + "\n").encode('utf-8'))
                    else:
                        print("Invalid ROI format")
                else:
                    print("Unknown command")
                    
            except Exception as e:
                print(f"Error handling client: {e}")
            finally:
                client_socket.close()
                print("Connection closed")
                
    except KeyboardInterrupt:
        print("\nStopping server...")
    finally:
        server_socket.close()

if __name__ == "__main__":
    main()