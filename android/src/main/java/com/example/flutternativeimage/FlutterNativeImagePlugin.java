package com.example.flutternativeimage;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Matrix;
import android.media.ExifInterface;
import android.util.Log;
import android.app.Activity;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;

import java.lang.IllegalArgumentException;

import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.PluginRegistry.Registrar;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.HashMap;

/**
 * FlutterNativeImagePlugin
 */
public class FlutterNativeImagePlugin implements MethodCallHandler {
  private final Activity activity;
  /**
   * Plugin registration.
   */
  public static void registerWith(Registrar registrar) {
    final MethodChannel channel = new MethodChannel(registrar.messenger(), "flutter_native_image");
    channel.setMethodCallHandler(new FlutterNativeImagePlugin(registrar.activity()));
  }

  private FlutterNativeImagePlugin(Activity activity) {
    this.activity = activity;
  }

  @Override
  public void onMethodCall(MethodCall call, Result result) {
    if(call.method.equals("compressImage")) {
      String fileName = call.argument("file");
      int resizePercentage = call.argument("percentage");
      int targetWidth = call.argument("targetWidth") == null ? 0 : (int) call.argument("targetWidth");
      int targetHeight = call.argument("targetHeight") == null ? 0 : (int) call.argument("targetHeight");
      int quality = call.argument("quality");

      File file = new File(fileName);

      if(!file.exists()) {
        result.error("file does not exist", fileName, null);
        return;
      }

      Bitmap bmp = BitmapFactory.decodeFile(fileName);
      ByteArrayOutputStream bos = new ByteArrayOutputStream();

      int newWidth = targetWidth == 0 ? (bmp.getWidth() / 100 * resizePercentage) : targetWidth;
      int newHeight = targetHeight == 0 ? (bmp.getHeight() / 100 * resizePercentage) : targetHeight;

      bmp = Bitmap.createScaledBitmap(
              bmp, newWidth, newHeight, false);

      bmp.compress(Bitmap.CompressFormat.JPEG, quality, bos);

      try {
        String outputFileName = File.createTempFile(
          getFilenameWithoutExtension(file).concat("_compressed"), 
          ".jpg", 
          activity.getExternalCacheDir()
        ).getPath();

        OutputStream outputStream = new FileOutputStream(outputFileName);
        bos.writeTo(outputStream);

        copyExif(fileName, outputFileName);

        result.success(outputFileName);
      } catch (FileNotFoundException e) {
        e.printStackTrace();
        result.error("file does not exist", fileName, null);
      } catch (IOException e) {
        e.printStackTrace();
        result.error("something went wrong", fileName, null);
      }

      return;
    }
    if(call.method.equals("resizeImage")) {
      String fileName = call.argument("file");
      int newWidth = (int) call.argument("width");
      int quality = call.argument("quality");

      File file = new File(fileName);

      if(!file.exists()) {
        result.error("file does not exist", fileName, null);
        return;
      }

      int orientation = ExifInterface.ORIENTATION_UNDEFINED;
      try {
        ExifInterface exif = new ExifInterface(fileName);
        orientation = exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_UNDEFINED);
      } catch(IOException ex) {
        // EXIF could not be read from the file; ignore
      }


      Bitmap bmp = BitmapFactory.decodeFile(fileName);
      ByteArrayOutputStream bos = new ByteArrayOutputStream();

      if (bmp.getWidth() == newWidth) {
        result.success(fileName);
        return;
      }

      int newHeight = bmp.getHeight() * newWidth / bmp.getWidth();

      bmp = Bitmap.createScaledBitmap(
              bmp, newWidth, newHeight, false);

      int angle = orientation == ExifInterface.ORIENTATION_ROTATE_90 ? 90 :
              orientation == ExifInterface.ORIENTATION_ROTATE_270 ? 270 :
                      orientation == ExifInterface.ORIENTATION_ROTATE_180 ? 180 : 0;
      if (angle > 0) {
        try {
          Matrix matrix = new Matrix();
          matrix.postRotate(angle);
          bmp = Bitmap.createBitmap(bmp, 0, 0, bmp.getWidth(), bmp.getHeight(), matrix, true);
        } catch(IllegalArgumentException e) {
          e.printStackTrace();
          result.error(e.toString(), fileName, null);
        }
      }

      bmp.compress(Bitmap.CompressFormat.JPEG, quality, bos);

      try {
        String outputFileName = File.createTempFile(
                getFilenameWithoutExtension(file).concat("_resize"),
                ".jpg",
                activity.getExternalCacheDir()
        ).getPath();

        OutputStream outputStream = new FileOutputStream(outputFileName);
        bos.writeTo(outputStream);

        result.success(outputFileName);
      } catch (FileNotFoundException e) {
        e.printStackTrace();
        result.error("file does not exist", fileName, null);
      } catch (IOException e) {
        e.printStackTrace();
        result.error("something went wrong", fileName, null);
      }

      return;
    }
    if(call.method.equals("getImageProperties")) {
      String fileName = call.argument("file");
      File file = new File(fileName);

      if(!file.exists()) {
        result.error("file does not exist", fileName, null);
        return;
      }

      BitmapFactory.Options options = new BitmapFactory.Options();
      options.inJustDecodeBounds = true;
      BitmapFactory.decodeFile(fileName,options);
      HashMap<String, Integer> properties = new HashMap<String, Integer>();
      properties.put("width", options.outWidth);
      properties.put("height", options.outHeight);

      int orientation = ExifInterface.ORIENTATION_UNDEFINED;
      try {
        ExifInterface exif = new ExifInterface(fileName);
        orientation = exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_UNDEFINED);
      } catch(IOException ex) {
        // EXIF could not be read from the file; ignore
      }
      properties.put("orientation", orientation);

      result.success(properties);
      return;
    }
    if(call.method.equals("cropImage")) {
    	String fileName = call.argument("file");
    	int originX = call.argument("originX");
    	int originY = call.argument("originY");
    	int width = call.argument("width");
    	int height = call.argument("height");

      File file = new File(fileName);

    	if(!file.exists()) {
  			result.error("file does not exist", fileName, null);
  			return;
  		}

    	Bitmap bmp = BitmapFactory.decodeFile(fileName);
      ByteArrayOutputStream bos = new ByteArrayOutputStream();

    	try {
			 bmp = Bitmap.createBitmap(bmp, originX, originY, width, height);
      } catch(IllegalArgumentException e) {
        e.printStackTrace();
        result.error("bounds are outside of the dimensions of the source image", fileName, null);
      }

      bmp.compress(Bitmap.CompressFormat.JPEG, 100, bos);

    	try {
        String outputFileName = File.createTempFile(
          getFilenameWithoutExtension(file).concat("_cropped"), 
          ".jpg", 
          activity.getExternalCacheDir()
        ).getPath();

  			OutputStream outputStream = new FileOutputStream(outputFileName);
  			bos.writeTo(outputStream);

        copyExif(fileName, outputFileName);

        result.success(outputFileName);
  		} catch (FileNotFoundException e) {
  			e.printStackTrace();
        result.error("file does not exist", fileName, null);
  		} catch (IOException e) {
  			e.printStackTrace();
        result.error("something went wrong", fileName, null);
  		}

  		return;
    }
    if(call.method.equals("rotateImage")) {
      String fileName = call.argument("file");
      String direction = call.argument("direction");
      int angle = "left".equals(direction) ? 270 : 90;

      File file = new File(fileName);

      if(!file.exists()) {
        result.error("file does not exist", fileName, null);
        return;
      }

      Bitmap bmp = BitmapFactory.decodeFile(fileName);
      ByteArrayOutputStream bos = new ByteArrayOutputStream();

      try {
        Matrix matrix = new Matrix();
        matrix.postRotate(angle);
        bmp = Bitmap.createBitmap(bmp, 0, 0, bmp.getWidth(), bmp.getHeight(), matrix, true);
      } catch(IllegalArgumentException e) {
        e.printStackTrace();
        result.error(e.toString(), fileName, null);
      }

      bmp.compress(Bitmap.CompressFormat.JPEG, 90, bos);

      try {
        String outputFileName = File.createTempFile(
                getFilenameWithoutExtension(file).concat(angle == 90 ? "r" : "l"),
                ".jpg",
                activity.getExternalCacheDir()
        ).getPath();

        OutputStream outputStream = new FileOutputStream(outputFileName);
        bos.writeTo(outputStream);

        result.success(outputFileName);
      } catch (FileNotFoundException e) {
        e.printStackTrace();
        result.error("file does not exist", fileName, null);
      } catch (IOException e) {
        e.printStackTrace();
        result.error("something went wrong", fileName, null);
      }

      return;
    }
    if (call.method.equals("getPlatformVersion")) {
      result.success("Android " + android.os.Build.VERSION.RELEASE);
    } else {
      result.notImplemented();
    }
  }

  private void copyExif(String filePathOri, String filePathDest) {
    try {
      ExifInterface oldExif = new ExifInterface(filePathOri);
      ExifInterface newExif = new ExifInterface(filePathDest);

      List<String> attributes =
          Arrays.asList(
              "FNumber",
              "ExposureTime",
              "ISOSpeedRatings",
              "GPSAltitude",
              "GPSAltitudeRef",
              "FocalLength",
              "GPSDateStamp",
              "WhiteBalance",
              "GPSProcessingMethod",
              "GPSTimeStamp",
              "DateTime",
              "Flash",
              "GPSLatitude",
              "GPSLatitudeRef",
              "GPSLongitude",
              "GPSLongitudeRef",
              "Make",
              "Model",
              "Orientation");
      for (String attribute : attributes) {
        setIfNotNull(oldExif, newExif, attribute);
      }

      newExif.saveAttributes();

    } catch (Exception ex) {
      Log.e("FlutterNativeImagePlugin", "Error preserving Exif data on selected image: " + ex);
    }
  }

  private void setIfNotNull(ExifInterface oldExif, ExifInterface newExif, String property) {
    if (oldExif.getAttribute(property) != null) {
      newExif.setAttribute(property, oldExif.getAttribute(property));
    }
  }

  private static String pathComponent(String filename) {
    int i = filename.lastIndexOf(File.separator);
    return (i > -1) ? filename.substring(0, i) : filename;
  }

  private static String getFilenameWithoutExtension(File file) {
    String fileName = file.getName();

    if (fileName.indexOf(".") > 0) {
      return fileName.substring(0, fileName.lastIndexOf("."));
    } else {
      return fileName;
    }
  }
}
