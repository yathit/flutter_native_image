#import "FlutterNativeImagePlugin.h"
#import <UIKit/UIKit.h>
#import "UIImage+Resize.h"

@implementation FlutterNativeImagePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"flutter_native_image"
                                     binaryMessenger:[registrar messenger]];
    FlutterNativeImagePlugin* instance = [[FlutterNativeImagePlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (UIImage *)normalizedImage:(UIImage *)image {
  if (image.imageOrientation == UIImageOrientationUp) return image;

  UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
  [image drawInRect:(CGRect){0, 0, image.size}];
  UIImage *normalizedImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return normalizedImage;
}

- (UIImage *)imageRotatedByDegrees:(UIImage*)image deg:(CGFloat)degrees{
    
    CGFloat rotation = degrees * M_PI / 180;
    
    // Calculate Destination Size
    CGAffineTransform t = CGAffineTransformMakeRotation(rotation);
    CGRect sizeRect = (CGRect) {.size = image.size};
    CGRect destRect = CGRectApplyAffineTransform(sizeRect, t);
    CGSize destinationSize = destRect.size;
    
    // Draw image
    UIGraphicsBeginImageContext(destinationSize);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, destinationSize.width / 2.0f, destinationSize.height / 2.0f);
    CGContextRotateCTM(context, rotation);
    [image drawInRect:CGRectMake(-image.size.width / 2.0f, -image.size.height / 2.0f, image.size.width, image.size.height)];
    
    // Save image
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

- (UIImage *)scaledImage:(UIImage *)image
                maxWidth:(CGFloat)maxWidth {
    double originalWidth = image.size.width;
    double originalHeight = image.size.height;
    
    double width = (double) maxWidth;
    double height = (width / originalWidth) * originalHeight;
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, height), NO, 1.0);
    [image drawInRect:CGRectMake(0, 0, width, height)];
    
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return scaledImage;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSDictionary *_arguments;
    
    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    }
    else if ([@"compressImage" isEqualToString:call.method]) {
        _arguments = call.arguments;
        
        NSString *fileExtension = @"_compressed.jpg";
        
        int qualityArgument = [[_arguments objectForKey:@"quality"] intValue];
        int percentageArgument = [[_arguments objectForKey:@"percentage"] intValue];
        int widthArgument = [[_arguments objectForKey:@"targetWidth"] intValue];
        int heightArgument = [[_arguments objectForKey:@"targetHeight"] intValue];
        NSString *fileArgument = [_arguments objectForKey:@"file"];
        NSURL *uncompressedFileUrl = [NSURL URLWithString:fileArgument];
        
        NSString *fileName = [[fileArgument lastPathComponent] stringByDeletingPathExtension];
        NSString *tempFileName =  [fileName stringByAppendingString:fileExtension];
        NSString *finalFileName = [NSTemporaryDirectory() stringByAppendingPathComponent:tempFileName];
        
        NSString *path = [uncompressedFileUrl path];
        NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
        
        UIImage *img = [[UIImage alloc] initWithData:data];

        CGFloat newWidth = (widthArgument == 0 ? (img.size.width / 100 * percentageArgument) : widthArgument);
        CGFloat newHeight = (heightArgument == 0 ? (img.size.height / 100 * percentageArgument) : heightArgument);
        
        CGSize newSize = CGSizeMake(newWidth, newHeight);
        
        UIImage *resizedImage = [img resizedImage:newSize interpolationQuality:kCGInterpolationHigh];
        resizedImage = [self normalizedImage:resizedImage];
        NSData *imageData = UIImageJPEGRepresentation(resizedImage, qualityArgument / 100.0);

        if ([[NSFileManager defaultManager] createFileAtPath:finalFileName contents:imageData attributes:nil]) {
            result(finalFileName);
        } else {
            result([FlutterError errorWithCode:@"create_error"
                                       message:@"Temporary file could not be created"
                                       details:nil]);
        }
        
        result(finalFileName);
        return;
    } 
    else if ([@"getImageProperties" isEqualToString:call.method]) {
        _arguments = call.arguments;
        
        NSString *fileArgument = [_arguments objectForKey:@"file"];
        NSURL *uncompressedFileUrl = [NSURL URLWithString:fileArgument];
        NSString *fileName = [[fileArgument lastPathComponent] stringByDeletingPathExtension];

        NSString *path = [uncompressedFileUrl path];
        NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];

        UIImage *img = [[UIImage alloc] initWithData:data];
        
        // Class ALAsset that provides a way to get EXIF attributes has been deprecated since iOS 8+,
        // but the replacing class PHAsset does not have a way to obtain image orientation.
        // For the purposes of FlutterNativeImagePlgin it's ok to leave it as undefined, as
        // all images captured/stored on iOS effectively have "normal" orientation so
        // it should not affect image crop/resize operations.
        int orientation = 0; // undefined orientation
        NSDictionary *dict = @{ @"width" : @(lroundf(img.size.width)),
                                @"height" : @(lroundf(img.size.height)),
                                @"orientation": @((NSInteger)orientation)};

        result(dict);
        return;
    }
    else if([@"cropImage" isEqualToString:call.method]) {
    	_arguments = call.arguments;

    	NSString *fileExtension = @"_cropped.jpg";

    	NSString *fileArgument = [_arguments objectForKey:@"file"];
    	NSURL *uncompressedFileUrl = [NSURL URLWithString:fileArgument];
    	int originX = [[_arguments objectForKey:@"originX"] intValue];
    	int originY = [[_arguments objectForKey:@"originY"] intValue];
    	int width = [[_arguments objectForKey:@"width"] intValue];
    	int height = [[_arguments objectForKey:@"height"] intValue];

		NSString *fileName = [[fileArgument lastPathComponent] stringByDeletingPathExtension];
        NSString *tempFileName =  [fileName stringByAppendingString:fileExtension];
        NSString *finalFileName = [NSTemporaryDirectory() stringByAppendingPathComponent:tempFileName];
        
        NSString *path = [uncompressedFileUrl path];
        NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
        
        UIImage *img = [[UIImage alloc] initWithData:data];
        img = [self normalizedImage:img];

        if(originX<0 || originY<0 
        	|| originX>img.size.width || originY>img.size.height 
        	|| originX+width>img.size.width || originY+height>img.size.height) {
        	result([FlutterError errorWithCode:@"bounds_error"
                                        message:@"Bounds are outside of the dimensions of the source image"
                                        details:nil]);
        }

		CGRect cropRect = CGRectMake(originX, originY, width, height);
		CGImageRef imageRef = CGImageCreateWithImageInRect([img CGImage], cropRect);
		UIImage *croppedImg = [UIImage imageWithCGImage:imageRef];
		CGImageRelease(imageRef);

		NSData *imageData = UIImageJPEGRepresentation(croppedImg, 1.0);

        if ([[NSFileManager defaultManager] createFileAtPath:finalFileName contents:imageData attributes:nil]) {
            result(finalFileName);
        } else {
            result([FlutterError errorWithCode:@"create_error"
                                        message:@"Temporary file could not be created"
                                        details:nil]);
        }

        result(finalFileName);
        return;
    }
    else if([@"resizeImage" isEqualToString:call.method]) {
        _arguments = call.arguments;
        
        int maxWidth = [[_arguments objectForKey:@"maxWidth"] intValue];
        
        NSString *fileArgument = [_arguments objectForKey:@"file"];
    
        NSURL *inFileUrl = [NSURL URLWithString:fileArgument];
 
        NSString *fileExtension = @"_resize.jpg";
        
        NSString *fileName = [[fileArgument lastPathComponent] stringByDeletingPathExtension];
        NSString *tempFileName =  [fileName stringByAppendingString:fileExtension];
        NSString *finalFileName = [NSTemporaryDirectory() stringByAppendingPathComponent:tempFileName];
        
        NSString *path = [inFileUrl path];
        NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
        UIImage *img = [[UIImage alloc] initWithData:data];
        img = [self normalizedImage:img];
        
        UIImage *image2 = [self scaledImage:img maxWidth:maxWidth ];
        
        NSData *imageData = UIImageJPEGRepresentation(image2, 0.9);
        
        if ([[NSFileManager defaultManager] createFileAtPath:finalFileName contents:imageData attributes:nil]) {
            
            NSDictionary *dict = @{ @"width" : @(lroundf(image2.size.width)),
                                    @"height" : @(lroundf(image2.size.height)),
                                    @"outputFileName": finalFileName};
            
            result(dict);
            
        } else {
            result([FlutterError errorWithCode:@"resize_image"
                                       message:@"File could not be saved"
                                       details:nil]);
        }
        
        return;
        
    }
    else if([@"rotateImage" isEqualToString:call.method]) {
        _arguments = call.arguments;
        
        NSString *fileArgument = [_arguments objectForKey:@"file"];
        NSURL *inFileUrl = [NSURL URLWithString:fileArgument];
        NSString *direction = [_arguments objectForKey:@"direction"];
        int angle = 90;
        if ([direction isEqualToString:@"left"])
        {
            angle = 270;
        }
        
        NSString *fileExtension = @"_rotate.jpg";
        
        NSString *fileName = [[fileArgument lastPathComponent] stringByDeletingPathExtension];
        NSString *tempFileName =  [fileName stringByAppendingString:fileExtension];
        NSString *finalFileName = [NSTemporaryDirectory() stringByAppendingPathComponent:tempFileName];
        
        NSString *path = [inFileUrl path];
        NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
        
        UIImage *img = [[UIImage alloc] initWithData:data];
        img = [self normalizedImage:img];
        
        UIImage *image2 = [self imageRotatedByDegrees:img deg:angle];
        
        NSData *imageData = UIImageJPEGRepresentation(image2, 1.0);
        
        if ([[NSFileManager defaultManager] createFileAtPath:finalFileName contents:imageData attributes:nil]) {
            result(finalFileName);
        } else {
            result([FlutterError errorWithCode:@"rotate_image"
                                       message:@"File could not be saved"
                                       details:nil]);
        }
        
        return;
    }
    else {
        result(FlutterMethodNotImplemented);
    }
}
@end
