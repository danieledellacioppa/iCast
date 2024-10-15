import Network
import AVFoundation
import CoreImage
import UniformTypeIdentifiers

class ScreencastSender {
    private var connection: NWConnection?
    private let ipAddress: String
    private let port: UInt16

    init(ipAddress: String, port: UInt16) {
        self.ipAddress = ipAddress
        self.port = port
        setupConnection()
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
                print("Connected to Android device")
            case .failed(let error):
                print("Connection failed: \(error.localizedDescription)")
                self?.connection?.cancel()
            case .waiting(let error):
                print("Connection waiting: \(error.localizedDescription)")
            case .cancelled:
                print("Connection cancelled")
            default:
                break
            }
        }
        
        connection?.start(queue: .global())
    }

    func sendFrame(sampleBuffer: CMSampleBuffer) {
        guard let connection = connection, connection.state == .ready else {
            print("Connection is not ready")
            return
        }
        
        guard let imageData = convertSampleBufferToJPEG(sampleBuffer) else {
            print("Failed to convert sample buffer to JPEG data")
            return
        }

        var dataSize = UInt32(imageData.count).bigEndian
        var dataWithSizePrefix = Data()
        dataWithSizePrefix.append(Data(bytes: &dataSize, count: MemoryLayout<UInt32>.size))
        dataWithSizePrefix.append(imageData)
        
        connection.send(content: dataWithSizePrefix, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("Failed to send data: \(error.localizedDescription)")
                // Se necessario, gestisci la riconnessione
                self?.connection?.cancel()
                self?.setupConnection()
            } else {
                print("Frame sent successfully")
            }
        })
    }

    private func convertSampleBufferToJPEG(_ sampleBuffer: CMSampleBuffer) -> Data? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        
        // Convert CVPixelBuffer to CGImage
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        // Create a mutable data object for JPEG output
        let jpegData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(jpegData as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        
        // Set JPEG compression quality
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.5]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        
        // Finalize the destination
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return jpegData as Data
    }

    func closeConnection() {
        connection?.cancel()
    }
}
