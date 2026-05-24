import SwiftUI
import AVFoundation
import UIKit

struct CameraCaptureView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> CameraHostViewController {
        let host = CameraHostViewController()
        let coordinator = context.coordinator
        host.onFirstAppear = { [weak host] in
            guard let host else { return }
            coordinator.presentCamera(from: host)
        }
        return host
    }

    func updateUIViewController(_ uiViewController: CameraHostViewController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraCaptureView
        private var didPresent = false
        private var didFinish = false

        init(parent: CameraCaptureView) {
            self.parent = parent
        }

        func presentCamera(from host: UIViewController) {
            guard !didPresent else { return }
            didPresent = true

            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                fail("Camera not available on this device.")
                return
            }

            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .authorized:
                showPicker(from: host)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self, weak host] granted in
                    DispatchQueue.main.async {
                        guard let self, let host else { return }
                        if granted {
                            self.showPicker(from: host)
                        } else {
                            self.fail("Camera access denied.")
                        }
                    }
                }
            case .denied, .restricted:
                fail("Camera access denied. Enable it in Settings.")
            @unknown default:
                fail("Camera unavailable.")
            }
        }

        private func showPicker(from host: UIViewController) {
            guard host.presentedViewController == nil else { return }

            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
            picker.modalPresentationStyle = .fullScreen
            host.present(picker, animated: false)
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage
            finish(picker: picker, image: image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            finish(picker: picker, image: nil)
        }

        private func finish(picker: UIImagePickerController, image: UIImage?) {
            guard !didFinish else { return }
            didFinish = true

            picker.dismiss(animated: true) {
                if let image {
                    self.parent.capturedImage = image
                }
                self.parent.dismiss()
            }
        }

        private func fail(_ message: String) {
            parent.errorMessage = message
            parent.dismiss()
        }
    }
}

final class CameraHostViewController: UIViewController {
    var onFirstAppear: (() -> Void)?
    private var hasAppeared = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasAppeared else { return }
        hasAppeared = true
        onFirstAppear?()
    }
}
