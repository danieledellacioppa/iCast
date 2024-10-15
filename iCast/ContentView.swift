import SwiftUI
import ReplayKit

struct ContentView: View {
    @State private var isRecording = false
    private let screenRecorder = RPScreenRecorder.shared()
    
    var body: some View {
        VStack {
            Text(isRecording ? "Stop Screencast" : "Start Screencast")
                .font(.title)
                .padding()
                .background(isRecording ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                .onTapGesture {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }
        }
    }
    
    func startRecording() {
        screenRecorder.startCapture(handler: { sampleBuffer, bufferType, error in
            guard error == nil else {
                print("Error during capture: \(error!.localizedDescription)")
                return
            }
            
            if bufferType == .video {
                // Send the sampleBuffer (video frame) to the Android device over network here
                sendFrameToAndroid(sampleBuffer: sampleBuffer)
            }
            
        }, completionHandler: { error in
            if let error = error {
                print("Failed to start capture: \(error.localizedDescription)")
            } else {
                isRecording = true
            }
        })
    }
    
    func stopRecording() {
        screenRecorder.stopCapture { error in
            if let error = error {
                print("Error stopping capture: \(error.localizedDescription)")
            } else {
                isRecording = false
            }
        }
    }
    
    let screencastSender = ScreencastSender(ipAddress: "192.168.0.18", port: 7000) // Use the Android device's IP and chosen port

    func sendFrameToAndroid(sampleBuffer: CMSampleBuffer) {
        screencastSender.sendFrame(sampleBuffer: sampleBuffer)
    }
}
