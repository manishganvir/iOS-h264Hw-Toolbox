//
//  ViewController.m
//  h264v1
//
//  Created by Ganvir, Manish on 3/31/15.
//  Copyright (c) 2015 Ganvir, Manish. All rights reserved.
//

#import "ViewController.h"
#import "H264HwEncoderImpl.h"

@interface ViewController ()
{
    H264HwEncoderImpl *h264Encoder;
    AVCaptureSession *captureSession;
    bool startCalled;
    AVCaptureVideoPreviewLayer *previewLayer;
    NSString *h264File;
    int fd;
    NSFileHandle *fileHandle;
}
@property (weak, nonatomic) IBOutlet UIButton *StartStopButton;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    h264Encoder = [H264HwEncoderImpl alloc];
    [h264Encoder initWithConfiguration];
    startCalled = true;
    
    
    
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Called when start/stop button is pressed
- (IBAction)OnStartStop:(id)sender {
    
    if (startCalled)
    {
        [self startCamera];
        startCalled = false;
        [_StartStopButton setTitle:@"Stop" forState:UIControlStateNormal];
    }
    else
    {
        [_StartStopButton setTitle:@"Start" forState:UIControlStateNormal];
        startCalled = true;
        [self stopCamera];
        [h264Encoder End];
    }
    
}

- (void) startCamera
{
    // make input device
    
    NSError *deviceError;
    
    AVCaptureDevice *cameraDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    AVCaptureDeviceInput *inputDevice = [AVCaptureDeviceInput deviceInputWithDevice:cameraDevice error:&deviceError];
    
    // make output device
    
    AVCaptureVideoDataOutput *outputDevice = [[AVCaptureVideoDataOutput alloc] init];
    
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    
    NSNumber* val = [NSNumber
                     numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];
    NSDictionary* videoSettings =
    [NSDictionary dictionaryWithObject:val forKey:key];
    outputDevice.videoSettings = videoSettings;
    
    [outputDevice setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    // initialize capture session
    
    captureSession = [[AVCaptureSession alloc] init];
    
    [captureSession addInput:inputDevice];
    [captureSession addOutput:outputDevice];
    
    // begin configuration for the AVCaptureSession
    [captureSession beginConfiguration];
    
    // picture resolution
    [captureSession setSessionPreset:[NSString stringWithString:AVCaptureSessionPreset640x480]];
    
    [captureSession commitConfiguration];
    
    // make preview layer and add so that camera's view is displayed on screen
    
    previewLayer = [AVCaptureVideoPreviewLayer    layerWithSession:captureSession];
    previewLayer.frame = self.view.bounds;
    [self.view.layer addSublayer:previewLayer];
    
    // go!
    
    [captureSession startRunning];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    h264File = [documentsDirectory stringByAppendingPathComponent:@"test3.h264"];
    [fileManager createFileAtPath:h264File contents:nil attributes:nil];
    
    // Open the file using POSIX as this is anyway a test application
    //fd = open([h264File UTF8String], O_RDWR);
    fileHandle = [NSFileHandle fileHandleForWritingAtPath:h264File];
    
    
    [h264Encoder initEncode:640 height:480];
    h264Encoder.delegate = self;
    
    
    
}

- (void) stopCamera
{
    [captureSession stopRunning];
    [previewLayer removeFromSuperlayer];
    //close(fd);
    [fileHandle closeFile];
    fileHandle = NULL;
}
-(void) captureOutput:(AVCaptureOutput*)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection*)connection

{
    //CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer( sampleBuffer );
    
    //CGSize imageSize = CVImageBufferGetEncodedSize( imageBuffer );
    
    // also in the 'mediaSpecific' dict of the sampleBuffer
    
    NSLog( @"frame captured at ");
    [h264Encoder encode:sampleBuffer];
    
}

#pragma mark -  H264HwEncoderImplDelegate delegare

- (void)gotSpsPps:(NSData*)sps pps:(NSData*)pps
{
    NSLog(@"gotSpsPps %d %d", (int)[sps length], (int)[pps length]);
    //[sps writeToFile:h264File atomically:YES];
    //[pps writeToFile:h264File atomically:YES];
   // write(fd, [sps bytes], [sps length]);
    //write(fd, [pps bytes], [pps length]);
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
    [fileHandle writeData:ByteHeader];
    [fileHandle writeData:sps];
    [fileHandle writeData:pps];

}
- (void)gotEncodedData:(NSData*)data
{
    NSLog(@"gotEncodedData %d", (int)[data length]);

   // [data writeToFile:h264File atomically:YES];
    //write(fd, [data bytes], [data length]);
    if (fileHandle != NULL)
    {
        const char bytes[] = "\x00\x00\x00\x01";
        size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
        NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
        [fileHandle writeData:ByteHeader];
        [fileHandle writeData:data];
    }
}


@end
