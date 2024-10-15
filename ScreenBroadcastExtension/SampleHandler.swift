// SampleHandler.swift

import ReplayKit
import Network
import AVFoundation
import CoreImage
import ImageIO
import MobileCoreServices

class SampleHandler: RPBroadcastSampleHandler {

    private var connection: NWConnection?
    private let ipAddress = "192.168.0.18" // Sostituisci con l'indirizzo IP del dispositivo Android
    private let port: UInt16 = 7000

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // Inizia la connessione al dispositivo Android
        setupConnection()
    }

    override func broadcastPaused() {
        // La trasmissione è stata messa in pausa dall'utente
        print("Trasmissione in pausa")
    }

    override func broadcastResumed() {
        // La trasmissione è stata ripresa
        print("Trasmissione ripresa")
    }

    override func broadcastFinished() {
        // La trasmissione è terminata
        print("Trasmissione terminata")
        connection?.cancel()
        connection = nil
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        sendSampleBuffer(sampleBuffer)
    }

    private func setupConnection() {
        let host = NWEndpoint.Host(ipAddress)
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            print("Porta non valida")
            return
        }

        connection = NWConnection(host: host, port: nwPort, using: .tcp)

        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("Connesso al dispositivo Android")
            case .failed(let error):
                print("Connessione fallita: \(error.localizedDescription)")
                self?.connection?.cancel()
                self?.connection = nil
            case .cancelled:
                print("Connessione cancellata")
                self?.connection = nil
            default:
                break
            }
        }

        connection?.start(queue: DispatchQueue(label: "ScreenCastConnection"))
    }

    private func sendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let connection = connection, connection.state == .ready else {
            print("Connessione non pronta")
            return
        }

        guard let imageData = convertSampleBufferToJPEG(sampleBuffer) else {
            print("Impossibile convertire il frame in JPEG")
            return
        }

        var dataSize = UInt32(imageData.count).bigEndian
        var dataWithSizePrefix = Data()
        dataWithSizePrefix.append(Data(bytes: &dataSize, count: MemoryLayout<UInt32>.size))
        dataWithSizePrefix.append(imageData)

        connection.send(content: dataWithSizePrefix, completion: .contentProcessed { error in
            if let error = error {
                print("Errore nell'invio dei dati: \(error.localizedDescription)")
            }
        })
    }

    private func convertSampleBufferToJPEG(_ sampleBuffer: CMSampleBuffer) -> Data? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        // Converti CVPixelBuffer in CGImage
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        // Crea un oggetto data per l'output JPEG
        let jpegData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(jpegData as CFMutableData, kUTTypeJPEG, 1, nil) else {
            return nil
        }

        // Imposta la qualità di compressione JPEG
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.5]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        // Finalizza la destinazione
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return jpegData as Data
    }
}
