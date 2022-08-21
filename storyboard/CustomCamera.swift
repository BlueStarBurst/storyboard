import SwiftUI
import AVFoundation
import Zoomable
import Firebase
import FirebaseStorage

struct CustomCameraPhotoView: View {
    @State private var image: Image?
    @State private var showingCustomCamera = true
    @State private var inputImage: UIImage?
    
    @State var shouldShowImagePicker = false
    
    @Binding var isTakingPicture: Bool
    
    private func persistImageToStorage() {
        print("PERSIST")
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = Storage.storage().reference(withPath: uid)
        guard let imageData = self.inputImage?.jpegData(compressionQuality: 0.5) else { return }
        ref.putData(imageData, metadata: nil) { metadata, err in
            if let err = err {
                print("Failed to push image to Storage: \(err)")
                return
            }
            
            ref.downloadURL { url, err in
                if let err = err {
                    print("Failed to retrieve downloadURL: \(err)")
                    return
                }
                
                DataHandler.shared.createPost(url: url?.absoluteString ?? "")
               
                
                print(url?.absoluteString)
            }
        }
    }
    
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
                        }
                        ZoomableScrollView {
                            image?
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                            //                                    .blur(radius: 15)
                        }
                        
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
    var body: some View {
        ZStack(alignment: .bottom) {
            
            CustomCameraRepresentable(image: self.$image, didTapCapture: $didTapCapture, didTapImg: $didTapImg)
            CaptureButtonView(image: $image, didTapCapture: $didTapCapture, didTapImg: $didTapImg)
        }
    }
    
}


struct CustomCameraRepresentable: UIViewControllerRepresentable {
    
    @Environment(\.presentationMode) var presentationMode
    @Binding var image: UIImage?
    @Binding var didTapCapture: Bool
    @Binding var didTapImg: Bool
    
    func makeUIViewController(context: Context) -> CustomCameraController {
        let controller = CustomCameraController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ cameraViewController: CustomCameraController, context: Context) {
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
    func setup() {
        setupCaptureSession()
        setupDevice()
        setupInputOutput()
        setupPreviewLayer()
        startRunningCaptureSession()
    }
    func setupCaptureSession() {
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
    }
    
    func setupDevice() {
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
        
        self.currentCamera = self.backCamera
    }
    
    
    func setupInputOutput() {
        do {
            
            let captureDeviceInput = try AVCaptureDeviceInput(device: currentCamera!)
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
        
    }
    func startRunningCaptureSession(){
        captureSession.startRunning()
    }
}


struct CaptureButtonView: View {
    
    @Binding var image: UIImage?
    @Binding var didTapCapture: Bool
    @Binding var didTapImg: Bool
    
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
            Image(systemName: "video").font(.largeTitle)
                .padding(30)
                .background(Color.red)
                .foregroundColor(.white)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.red)
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
