import SwiftUI
import AVFoundation
import Zoomable
import Firebase
import FirebaseStorage

extension UIImage {
    func aspectFittedToHeight(_ newHeight: CGFloat) -> UIImage {
        let scale = newHeight / self.size.height
        let newWidth = self.size.width * scale
        let newSize = CGSize(width: newWidth, height: newHeight)
        let renderer = UIGraphicsImageRenderer(size: newSize)

        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

struct CustomCameraPhotoView: View {
    @State private var image: Image?
    @State private var showingCustomCamera = true
    @State private var inputImage: UIImage?
    
    @State var shouldShowImagePicker = false
    
    @Binding var isTakingPicture: Bool
    
    private func persistImageToStorage() {
        guard let imageData = self.inputImage?.aspectFittedToHeight(200).jpegData(compressionQuality: 0.5) else { return }
        DataHandler.shared.createPost(img: imageData)
    }
    
//    "cRizrR3WFEP7vxdIrwaZ4K:APA91bEk_-C9Wv8GBG5SVWuYfoc13SlDObqIHprJtUMXjSH5i0jD2eb8QIsSZqjWmLU-r9VL1OvjWU0ABZs5NzNY5yhCplsTJEWGptTrLloK3PsIPJhEzv1UOc9yx2ww3fJFBFbtBBcZ"
    
    var body: some View {
        
        VStack {
            ZStack {
                Rectangle().fill(Color.secondary.opacity(0))
                
                if image != nil
                {
                    ZStack {
                        GeometryReader { geometry in
                            image?
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .blur(radius: 15)
                                .frame(width: geometry.size.width, height: geometry.size.height)
//                                .onAppear {
//                                    image.
//                                }
                        }
                        ZoomableScrollView {
                            image?
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                            //                                    .blur(radius: 15)
                        }.ignoresSafeArea()
                        
                        VStack {
                            HStack {
                                VStack {
                                    Button(action: {
//                                        withAnimation{
//                                            image = nil
//                                            isTakingPicture = false
//                                        }
                                        image = nil
                                        isTakingPicture = false
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.title)
                                    }.padding(.bottom, 10)
                                    
                                    Button(action: {withAnimation{self.showingCustomCamera = true}}) {
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.title)
                                    }
                                }
                                
                                .padding()
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(16)
                                .padding(.top, 20)
                                Spacer()
                            }
                            Spacer()
                            HStack {
                                Spacer()
                                Button(action: {
                                    
                                    persistImageToStorage()
                                    image = nil
                                    isTakingPicture = false
                                    
                                }) {
                                    Image(systemName: "paperplane.fill")
                                        .font(.title)
                                        .padding()
                                        .background(Color.pink)
                                        .clipShape(Circle())
                                }
                                .disabled(image == nil)
                            }
                            .padding(.bottom, 10)
                        }
                        .padding()
                    }
                }
                
            }
        }
        .sheet(isPresented: $showingCustomCamera, onDismiss: loadImage) {
            ZStack {
                CustomCameraView(image: self.$inputImage)
                //                    VStack {
                //                        HStack {
                //                            VStack {
                //                                Button(action: {shouldShowImagePicker = true}) {
                //                                    Label("", systemImage: "photo.fill.on.rectangle.fill")
                //                                        .imageScale(.large)
                //                                }
                //                            }
                //                            Spacer()
                //                        }
                //                        Spacer()
                //                    }
            }
            //                .fullScreenCover(isPresented: $shouldShowImagePicker, onDismiss: nil) {
            //                    ImagePicker(image: self.$inputImage)
            //                        .ignoresSafeArea()
            //                }
        }
        .edgesIgnoringSafeArea(.all)
        
    }
    func loadImage() {
        guard let inputImage = inputImage else {
            isTakingPicture = false
            return }
        image = Image(uiImage: inputImage)
    }
}


struct CustomCameraView: View {
    
    @Binding var image: UIImage?
    @State var didTapImg: Bool = false
    @State var didTapCapture: Bool = false
    @State var flip = false
    var body: some View {
        ZStack(alignment: .bottom) {
            
            CustomCameraRepresentable(image: self.$image, didTapCapture: $didTapCapture, didTapImg: $didTapImg, flip: $flip)
            CaptureButtonView(image: $image, didTapCapture: $didTapCapture, didTapImg: $didTapImg, flip: $flip)
        }
    }
    
}


struct CustomCameraRepresentable: UIViewControllerRepresentable {
    
    @Environment(\.presentationMode) var presentationMode
    @Binding var image: UIImage?
    @Binding var didTapCapture: Bool
    @Binding var didTapImg: Bool
    @Binding var flip: Bool
    
    func makeUIViewController(context: Context) -> CustomCameraController {
        let controller = CustomCameraController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ cameraViewController: CustomCameraController, context: Context) {

        cameraViewController.setCurrentCamera(flip: self.flip)
        
        if(self.didTapImg) {
            presentationMode.wrappedValue.dismiss()
        }
        else if(self.didTapCapture) {
            cameraViewController.didTapRecord()
        }
    }
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, AVCapturePhotoCaptureDelegate {
        let parent: CustomCameraRepresentable
        
        init(_ parent: CustomCameraRepresentable) {
            self.parent = parent
        }
        
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            
            parent.didTapCapture = false
            
            if let imageData = photo.fileDataRepresentation() {
                parent.image = UIImage(data: imageData)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
    }
}

class CustomCameraController: UIViewController {
    
    var image: UIImage?
    
    var captureSession = AVCaptureSession()
    var backCamera: AVCaptureDevice?
    var frontCamera: AVCaptureDevice?
    var currentCamera: AVCaptureDevice?
    var photoOutput: AVCapturePhotoOutput?
    var cameraPreviewLayer: AVCaptureVideoPreviewLayer?
    
    //DELEGATE
    var delegate: AVCapturePhotoCaptureDelegate?
    
    func didTapRecord() {
        
        let settings = AVCapturePhotoSettings()
        photoOutput?.capturePhoto(with: settings, delegate: delegate!)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    func setup(flip: Bool = false) {
        setupCaptureSession()
        setupDevice(flip: flip)
        setupInputOutput()
        setupPreviewLayer()
        startRunningCaptureSession()
    }
    func setupCaptureSession() {
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
    }
    
    func setupDevice(flip: Bool = false) {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera],
                                                                      mediaType: AVMediaType.video,
                                                                      position: AVCaptureDevice.Position.unspecified)
        for device in deviceDiscoverySession.devices {
            
            switch device.position {
            case AVCaptureDevice.Position.front:
                self.frontCamera = device
            case AVCaptureDevice.Position.back:
                self.backCamera = device
            default:
                break
            }
        }
        
        if (flip == false) {
            self.currentCamera = self.frontCamera
        } else {
            self.currentCamera = self.frontCamera
        }
    }
    
    func setCurrentCamera(flip: Bool) {
        print("FLIPPING CAMERA")
//        captureSession = nil
        
        if (flip == true) {
            if (self.currentCamera == self.backCamera) {
                return
            }
            do {
                self.currentCamera = self.backCamera
                //            setupInputOutput()
                for inp in captureSession.inputs {
                    captureSession.removeInput(inp)
                }
                let captureDeviceInput = try AVCaptureDeviceInput(device: currentCamera!)
                captureSession.addInput(captureDeviceInput)
            } catch {
                print("ERROR")
            }
            
            if (self.cameraPreviewLayer?.connection?.isVideoMirroringSupported == true) {
                self.cameraPreviewLayer?.connection?.automaticallyAdjustsVideoMirroring = false
                self.cameraPreviewLayer?.connection?.isVideoMirrored = false
            }
//            setupPreviewLayer()
//            startRunningCaptureSession()
        } else {
            if (self.currentCamera == self.frontCamera) {
                return
            }
            
            do {
                self.currentCamera = self.frontCamera
                //            setupInputOutput()
                for inp in captureSession.inputs {
                    captureSession.removeInput(inp)
                }
                let captureDeviceInput = try AVCaptureDeviceInput(device: currentCamera!)
                captureSession.addInput(captureDeviceInput)
                
                if (self.cameraPreviewLayer?.connection?.isVideoMirroringSupported == true) {
                    self.cameraPreviewLayer?.connection?.automaticallyAdjustsVideoMirroring = false
                    self.cameraPreviewLayer?.connection?.isVideoMirrored = true
                }
            } catch {
                print("ERROR")
            }
            
//            setupPreviewLayer()
//            startRunningCaptureSession()
        }
    }
    
    func setupInputOutput() {
        do {
            
            let captureDeviceInput = try AVCaptureDeviceInput(device: currentCamera!)
            
//            for ou in captureSession.outputs {
//                captureSession.removeOutput(ou)
//            }
            
            captureSession.addInput(captureDeviceInput)
            photoOutput = AVCapturePhotoOutput()
            photoOutput?.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])], completionHandler: nil)
            captureSession.addOutput(photoOutput!)
            
        } catch {
            print(error)
        }
        
    }
    func setupPreviewLayer()
    {
        self.cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.cameraPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.cameraPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        self.cameraPreviewLayer?.frame = self.view.frame
        self.view.layer.insertSublayer(cameraPreviewLayer!, at: 0)
        
        if (self.cameraPreviewLayer?.connection?.isVideoMirroringSupported == true) {
            self.cameraPreviewLayer?.connection?.automaticallyAdjustsVideoMirroring = false
            self.cameraPreviewLayer?.connection?.isVideoMirrored = true
        }
        
    }
    func startRunningCaptureSession(){
        captureSession.startRunning()
    }
    
    func stopRunningCaptureSession() {
        captureSession.stopRunning()
    }
}


struct CaptureButtonView: View {
    
    @Binding var image: UIImage?
    @Binding var didTapCapture: Bool
    @Binding var didTapImg: Bool
    @Binding var flip: Bool
    
    @State private var animationAmount: CGFloat = 1
    @State private var shouldShowImagePicker = false
    var body: some View {
        HStack {
            Button(action: {shouldShowImagePicker = true}) {
                Label("", systemImage: "photo.fill.on.rectangle.fill")
                    .foregroundColor(Color.white)
                    .font(.largeTitle)
                    .onAppear {
                        didTapImg = false
                    }
            }
            Image(systemName: "camera").font(.largeTitle)
                .padding(30)
                .background(Color.pink)
                .foregroundColor(.white)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.pink)
                        .scaleEffect(animationAmount)
                        .opacity(Double(2 - animationAmount))
                        .animation(Animation.easeOut(duration: 1)
                            .repeatForever(autoreverses: false))
                )
                .onAppear
            {
                self.animationAmount = 2
            }.onTapGesture {
                self.didTapCapture = true
            }
            Button(action: {withAnimation {
                flip.toggle()
            }}) {
                Label("", systemImage: "arrow.triangle.2.circlepath.camera.fill")
                    .foregroundColor(Color.white)
                    .font(.largeTitle)
            }
        }.fullScreenCover(isPresented: $shouldShowImagePicker, onDismiss: nil) {
            ImagePicker(image: $image)
                .ignoresSafeArea()
                .onChange(of: image, perform: {_ in
                    didTapImg = true
                })
        }
    }
}


struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    private var content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        // set up the UIScrollView
        UIScrollView.appearance().backgroundColor = UIColor.clear
        let scrollView = UIScrollView()
        UIScrollView.appearance().backgroundColor = UIColor.clear
        scrollView.delegate = context.coordinator  // for viewForZooming(in:)
        scrollView.maximumZoomScale = 20
        scrollView.minimumZoomScale = 1
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = UIColor.clear
        
        
        // create a UIHostingController to hold our SwiftUI content
        let hostedView = context.coordinator.hostingController.view!
        hostedView.backgroundColor = UIColor.clear
        hostedView.translatesAutoresizingMaskIntoConstraints = true
        hostedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostedView.frame = scrollView.bounds
        scrollView.addSubview(hostedView)
        
        return scrollView
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(hostingController: UIHostingController(rootView: self.content))
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // update the hosting controller's SwiftUI content
        context.coordinator.hostingController.rootView = self.content
        assert(context.coordinator.hostingController.view.superview == uiView)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>
        
        init(hostingController: UIHostingController<Content>) {
            self.hostingController = hostingController
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController.view
        }
    }
}
