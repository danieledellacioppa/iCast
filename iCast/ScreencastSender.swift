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
        let port = NWEndpoint.Port(integerLiteral: port)
        
        connection = NWConnection(host: host, port: port, using: .tcp)
        
        connection?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Connected to Android device")
            case .failed(let error):
                print("Connection failed: \(error.localizedDescription)")
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

        var dataSize = UInt32(imageData.count)
        var dataWithSizePrefix = Data()
        dataWithSizePrefix.append(Data(bytes: &dataSize, count: 4)) // Prepend size of data
        dataWithSizePrefix.append(imageData)
        
        connection.send(content: dataWithSizePrefix, completion: .contentProcessed { error in
            if let error = error {
                print("Failed to send data: \(error.localizedDescription)")
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
