#import "CameraControlAppDelegate.h"


@implementation CameraControlAppDelegate

-(void)connectToVideoDevice:(QTCaptureDevice*)device {
	[captureSession release];
	
	[[NSUserDefaults standardUserDefaults] setObject: [device uniqueID] forKey:@"deviceId"];

	videoDevice = device;
	[videoDevice open:nil];
	
	if( !videoDevice ) {
		NSLog( @"No video input device" );
		exit( 1 );
	}
	
	videoInput = [[QTCaptureDeviceInput alloc] initWithDevice:videoDevice];
	
	captureSession = [[QTCaptureSession alloc] init];
	[captureSession addInput:videoInput error:nil];	
	[captureSession startRunning];
	
	[captureView setCaptureSession:captureSession];
	[captureView setVideoPreviewConnection:[[captureView availableVideoPreviewConnections] objectAtIndex:0]];
	captureView.delegate = self;
	
	
	// Setting a lower resolution for the CaptureOutput here, since otherwise QTCaptureView
	// pulls full-res frames from the camera, which is slow. This is just for cosmetics.
	
	// NOTE: for Logitech QuickCam Pro 9000 Webcam everythin >=1280 or > 720  puts camera into widescreen
	NSDictionary * pixelBufferAttr = [NSDictionary dictionaryWithObjectsAndKeys:
									  [NSNumber numberWithInt:1200], kCVPixelBufferWidthKey,
									  [NSNumber numberWithInt:720], kCVPixelBufferHeightKey, nil];
	[[[captureSession outputs] objectAtIndex:0] setPixelBufferAttributes:pixelBufferAttr];
	
	
	
	
	// Ok, this might be all kinds of wrong, but it was the only way I found to map a 
	// QTCaptureDevice to a IOKit USB Device. The uniqueID method seems to always(?) return 
	// the locationID as a HEX string in the first few chars, but the format of this string 
	// is not documented anywhere and (knowing Apple) might change sooner or later.
	//
	// In most cases you'd be probably better of using the UVCCameraControls
	// - (id)initWithVendorID:(long) productID:(long) 
	// method instead. I.e. for the Logitech QuickCam9000 
	// cameraControl = [[UVCCameraControl alloc] initWithVendorID:0x046d productID:0x0990];
	//
	// You can use USB Prober (should be in /Developer/Applications/Utilities/USB Prober.app) 
	// to find the values of your camera.
	
	UInt32 locationID = 0;
	sscanf( [[videoDevice uniqueID] UTF8String], "0x%8x", (unsigned int*)&locationID );
	cameraControl = [[UVCCameraControl alloc] initWithLocationID:locationID];
	
	[cameraControl setAutoExposure:YES];
	[cameraControl setAutoWhiteBalance:YES];
	[cameraControl setAutoFocus:YES];
}

-(NSString*)selectedDeviceId {
	int idx = [deviceCombobox indexOfSelectedItem];
	if(idx >= 0 && idx < [allDevices count])
		return [(QTCaptureDevice*)[allDevices objectAtIndex: idx] uniqueID];
	return nil;
}

-(void)setSelectedDeviceId:(NSString*)id {
	QTCaptureDevice* device = [QTCaptureDevice deviceWithUniqueID:id];
	if(device) {
		int idx = [allDevices indexOfObject:device];
		[deviceCombobox selectItemAtIndex: idx];
	} else {
		[deviceCombobox selectItemAtIndex: 0];
	}
}

-(void)populateDevices {
	NSString *selected = [self selectedDeviceId];
	if(!selected)
		selected = [[NSUserDefaults standardUserDefaults] stringForKey:@"deviceId"];
	
	[allDevices release];
	allDevices = [[QTCaptureDevice inputDevicesWithMediaType:QTMediaTypeVideo] copy];
	[deviceCombobox removeAllItems];
	for (QTCaptureDevice* d in allDevices) {
		[deviceCombobox addItemWithObjectValue: [d localizedDisplayName]];
	}
	
	[self setSelectedDeviceId: selected];
	[self deviceChanged:deviceCombobox];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {		
	[self populateDevices];
	originalWindowStyleMask = [window styleMask];
}

-(BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	return YES;
}


- (IBAction)sliderMoved:(id)sender {
	
	// Exposure Time
	if( [sender isEqualTo:exposureSlider] ) {		
		[cameraControl setExposure:exposureSlider.floatValue];
	}
	
	// White Balance Temperature
	else if( [sender isEqualTo:whiteBalanceSlider] ) {
		[cameraControl setWhiteBalance:whiteBalanceSlider.floatValue];
	}
	
	// Gain Value
	else if( [sender isEqualTo:gainSlider] ) {
		[cameraControl setBrightness:gainSlider.floatValue];
	}
	
	// Focus Value
	else if( [sender isEqualTo:focusSlider] ) {
		[cameraControl setAbsoluteFocus:focusSlider.floatValue];
	}
}


- (IBAction)checkBoxChanged:(id)sender {
	
	// Auto Exposure
	if( [sender isEqualTo:autoExposureCheckBox] ) {
		if( autoExposureCheckBox.state == NSOnState ) {
			[cameraControl setAutoExposure:YES];
			[exposureSlider setEnabled:NO];
		} 
		else {
			[cameraControl setAutoExposure:NO];
			[exposureSlider setEnabled:YES];
			[cameraControl setExposure:exposureSlider.floatValue];
		}
	}
	
	// Auto White Balance
	else if( [sender isEqualTo:autoWhiteBalanceCheckBox] ) {
		if( autoWhiteBalanceCheckBox.state == NSOnState ) {
			[cameraControl setAutoWhiteBalance:YES];
			[whiteBalanceSlider setEnabled:NO];
		} 
		else {
			[cameraControl setAutoWhiteBalance:NO];
			[whiteBalanceSlider setEnabled:YES];
			[cameraControl setWhiteBalance:whiteBalanceSlider.floatValue];
		}
	}
	
	// Auto Focus
	else if( [sender isEqualTo:autoFocusCheckBox] ) {
		if( autoFocusCheckBox.state == NSOnState ) {
			[cameraControl setAutoFocus:YES];
			[focusSlider setEnabled:NO];
		} 
		else {
			[cameraControl setAutoFocus:NO];
			[focusSlider setEnabled:YES];
			[cameraControl setAbsoluteFocus:focusSlider.floatValue];
		}
	}
	
}

-(IBAction)deviceChanged:(id)sender {
	QTCaptureDevice *device = [QTCaptureDevice deviceWithUniqueID:[self selectedDeviceId]];
	if(device)
		[self connectToVideoDevice:device];
}

- (void)dealloc {
	[captureSession release];
	[videoInput release];
	[videoDevice release];
	
	[cameraControl release];
	[allDevices release];
	[super dealloc];
}

- (CIImage *)view:(QTCaptureView *)view willDisplayImage:(CIImage
														  *)image{
	return [image
			imageByApplyingTransform:CGAffineTransformMakeRotation(rotation * M_PI /
																   180.0)];
}

- (IBAction)rotatePreview:(id)sender {
	NSMenuItem *i = sender;
	rotation = (int)(rotation + i.tag) % 360;
	while(rotation<0)rotation+=360;
}

-(void)realignCaptureView {
	NSRect r = [window.contentView bounds];
	if(!inspector.isHidden)
		r.size.width -= inspector.frame.size.width;
	captureView.frame = r;
}

- (IBAction)toggleInspector:(id)sender {
	NSMenuItem *i = sender;
	[i setState: i.state == NSOnState ? NSOffState : NSOnState];
	
	[inspector setHidden: i.state == NSOffState];
	[self realignCaptureView];
}

- (IBAction)toggleFullScreen:(id)sender {
	if(!fullScreenWindow) {
		fullScreenWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, window.screen.frame.size.width, window.screen.frame.size.height)
													   styleMask:NSBorderlessWindowMask
														 backing:NSBackingStoreBuffered
														   defer:NO screen:window.screen];
		[fullScreenWindow setContentView:captureView];
		[fullScreenWindow makeKeyAndOrderFront:nil];
		[window orderOut:nil];
	} else {
		[window.contentView addSubview:captureView];
		[self realignCaptureView];
		[fullScreenWindow release];
		fullScreenWindow = nil;
		[window orderFront:nil];
		[window makeKeyAndOrderFront:nil];
	}
}

@end

