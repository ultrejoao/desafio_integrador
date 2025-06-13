from flask import Flask, Response, request, jsonify
from flask_cors import CORS
import cv2
import numpy as np
import base64
import io
from PIL import Image

app = Flask(__name__)
CORS(app)  # Permite requisições de qualquer origem

# Carregar a rede YOLO pré-treinada
net = cv2.dnn.readNet("yolov4.weights", "yolov4.cfg")
classes = open("coco.names").read().strip().split("\n")

def processar_imagem(imagem_bytes):
    # Converter bytes para imagem OpenCV
    nparr = np.frombuffer(imagem_bytes, np.uint8)
    frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    
    altura, largura = frame.shape[:2]

    # Pré-processamento da imagem para YOLO
    blob = cv2.dnn.blobFromImage(frame, 1/255.0, (416, 416), swapRB=True, crop=False)
    net.setInput(blob)

    # Obter saídas da rede
    camadas = net.getUnconnectedOutLayersNames()
    saidas = net.forward(camadas)

    # Listas para armazenar dados da detecção
    caixas = []
    confiancas = []
    ids_classes = []
    contador_pessoas = 0

    # Processamento das detecções
    for saida in saidas:
        for detecao in saida:
            scores = detecao[5:]
            classe_id = np.argmax(scores)
            confianca = scores[classe_id]

            if confianca > 0.3 and classes[classe_id] == "person":
                cx, cy, w, h = (detecao[0:4] * np.array([largura, altura, largura, altura])).astype("int")
                x = int(cx - (w / 2))
                y = int(cy - (h / 2))

                caixas.append([x, y, w, h])
                confiancas.append(float(confianca))
                ids_classes.append(classe_id)

    # Aplicar Non-Maximum Suppression (NMS) para remover detecções duplicadas
    indices = cv2.dnn.NMSBoxes(caixas, confiancas, 0.3, 0.3)

    # Contar pessoas e desenhar as caixas
    contador_pessoas = len(indices) if len(indices) > 0 else 0

    # Desenhar as caixas nas pessoas detectadas
    if len(indices) > 0:
        for i in indices.flatten():
            x, y, w, h = caixas[i]
            cv2.rectangle(frame, (x, y), (x + w, y + h), (0, 255, 0), 2)
            texto = f"Pessoa {confiancas[i]:.2f}"
            cv2.putText(frame, texto, (x, y - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)

    # Exibir contagem de pessoas na tela
    cv2.putText(frame, f"Pessoas detectadas: {contador_pessoas}", (20, 50),
                cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)

    # Converter a imagem processada para base64
    _, buffer = cv2.imencode('.jpg', frame)
    imagem_base64 = base64.b64encode(buffer).decode('utf-8')

    return {
        'imagem': imagem_base64,
        'contador_pessoas': contador_pessoas
    }

@app.route('/detectar', methods=['POST'])
def detectar():
    if 'imagem' not in request.files:
        return jsonify({'erro': 'Nenhuma imagem enviada'}), 400
    
    imagem = request.files['imagem']
    resultado = processar_imagem(imagem.read())
    return jsonify(resultado)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000) 