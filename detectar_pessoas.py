import cv2
import numpy as np

# Carregar a rede YOLO pré-treinada
net = cv2.dnn.readNet("yolov4.weights", "yolov4.cfg")  # Baixe esses arquivos antes
classes = open("coco.names").read().strip().split("\n")  # Baixe o arquivo coco.names


video = cv2.VideoCapture(0)  # Para webcam, use 0

while True:
    ret, frame = video.read()
    if not ret:
        break  # Sai se o vídeo acabar

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
            scores = detecao[3:]
            classe_id = np.argmax(scores)
            confianca = scores[classe_id]

            if confianca > 0.3 and classes[classe_id] == "person":  # Filtrar apenas pessoas
                contador_pessoas += 1
                cx, cy, w, h = (detecao[0:4] * np.array([largura, altura, largura, altura])).astype("int")
                x = int(cx - (w / 2))
                y = int(cy - (h / 2))

                caixas.append([x, y, w, h])
                confiancas.append(float(confianca))
                ids_classes.append(classe_id)

    # Aplicar Non-Maximum Suppression (NMS) para remover detecções duplicadas
    indices = cv2.dnn.NMSBoxes(caixas, confiancas, 0.5, 0.4)

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

    # Mostrar resultado
    cv2.imshow("Detecção de Pessoas - YOLO", frame)

    # Parar ao pressionar "q"
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

# Liberar recursos
video.release()
cv2.destroyAllWindows()