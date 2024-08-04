# listen to 6570/tcp, send SHR image to iigs
import socket

def start_server(file_path, port=6570):
    with open(file_path, 'rb') as file:
        data = file.read(32768)  # SHR dataz

    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    server_address = ('', port)
    server_socket.bind(server_address)
    
    server_socket.listen(1)
    print(f"Server listening on port {port}")
    
    while True:
        connection, client_address = server_socket.accept()
        try:
            print(f"Connection from {client_address}")
            connection.sendall(data)
        finally:
            connection.close()

if __name__ == "__main__":
    file_path = 'images/byte_sequence_file.bin'
    start_server(file_path)
