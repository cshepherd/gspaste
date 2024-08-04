# listen to 6569/tcp, receive SHR screen from iigs
import socket
import uuid

def handle_connection(conn, addr):
    filename = f"{uuid.uuid4()}.bin"
    
    with open('images/'+filename, 'wb') as file:
        print(f"Connection from {addr}. Writing to {filename}.")
        
        while True:
            data = conn.recv(1024)  # Receive data in chunks of 1024 bytes
            if not data:
                break
            file.write(data)

    print(f"Connection from {addr} closed. Data written to {filename}.")
    conn.close()

def main():
    host = '0.0.0.0'  # Listen on all interfaces
    port = 6569       # Port to listen on

    # Create a socket object
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server_socket:
        server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

        server_socket.bind((host, port))
        
        server_socket.listen(5)
        print(f"Server listening on {host}:{port}")

        while True:
            conn, addr = server_socket.accept()
            handle_connection(conn, addr)

if __name__ == '__main__':
    main()
