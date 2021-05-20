/*
 * This script will combine two images acqured at two different exposures into a single 
 * HDR (high dynamic range) image.
 * 
 * Currently, it assumes that the ratio of the two exposures is 4:1
 * 
 * Input: image stack with three 16-bit images in the following order:
 * 			1. dark image (currently not used
 * 			2. short exposure time image
 * 			3. long exposure time image 
 * 
 * Outputs:
 * 			1. A 32-bit HDR image
 * 			2. An ROI manager that includes all of the detected objects
 * 			3. A variety of intermediate images, including the masks that mark the saturated pixels,
 * 			
 * To do: 	1. Enable the macro to work on input images that are not 16-bit
 * 			2. Add code to allow selection of the input file and automatic closing of open images.   [DONE, though intermediate images are not closed] 
 * 			3. Add options to allow for image stacks that do not include the unnecessary dark image. [DONE]
 * 			
 * 21-06-20: V3 - Uses find maxima to locate beads, and then creates an (approx) 3micron ROI centered on the found maxima. 
 *                Currently assumes a calibration of 0.11micron/pixel (40X objective). This should be changed to allow for
 *                other calibrations, and other bead sizes.
 * 			
 * Author: Aryeh Weiss
 * Last Modified: 22 June 2020
 * 			
 */


// image stack must be open and active 
// inputTitle = getTitle();  


// #@ Integer(label="Objective Magnification",value=4) mag
#@ String(choices={1,2,3,4}, style="listBox") selectField

run("Close All");
run("Set Measurements...", "area mean standard modal min centroid center perimeter bounding fit shape integrated stack limit display redirect=None decimal=3");
// prompt for the input file and open the  image
inputPath =File.openDialog("input file");
print("image path: ", inputPath);
inputTitle = File.getName(inputPath);
print("image name: ", inputTitle);
open(inputPath);
fullInputTitle = getTitle();	// save the image title in a variable
inputTitle = File.nameWithoutExtension;   // turns out that we need the title wihtout the image type extension

// remove any overlay if the image was saved with an overlay
run("Remove Overlay");

getDimensions(width, height, channels, slices, frames);
print(width, height, channels, slices, frames);

// short and long exposures (would be nice to get them from the metadata)

shortExposure = 50.0; // ms
longExposure = 200.0; //ms
exposureRatio = longExposure/shortExposure;
//exposureRatio = 16;
run("Median...", "radius=2 stack");	// remove point noise

//remove calibration
Stack.setXUnit("pixel");
Stack.setYUnit("pixel");
run("Properties...", "pixel_width=1 pixel_height=1 voxel_depth=1.0000000 global");
run("Non-local Means Denoising", "sigma=15 smoothing_factor=1 auto stack");

run("Stack to Images");

if (slices*channels*frames == 3) {  
// we have an HDR image with a dark image in channel 1, short exposure in channel 2, long exposure 9n channel 3
	selectWindow(inputTitle+"-0001");
	close();  // background image is not needed

	selectWindow(inputTitle+"-0002");
	run("Subtract Background...", "rolling=400"); 	// removes all background, since we only care about bead intensity
	selectWindow(inputTitle+"-0003");
	run("Subtract Background...", "rolling=400");

// in the macro language, we need to grab the titles of images that are creaed
// because arguments are not returned
	selectWindow(inputTitle+"-0003");
	rename("longExp");
	longExpTitle = getTitle(); 
	selectWindow(inputTitle+"-0002");
	rename("shortExp");
	shortExpTitle = getTitle();
}
else if (slices*channels*frames > 1) {

	shortExpSlice = (parseInt(selectField)-1)*2+1;
	longExpSlice = (parseInt(selectField)-1)*2+2;
	selectWindow(inputTitle+"-000"+d2s(shortExpSlice,0));
	run("Subtract Background...", "rolling=400"); 	// removes all background, since we only care about bead intensity
	selectWindow(inputTitle+"-000"+d2s(longExpSlice,0));
	run("Subtract Background...", "rolling=400");
	selectWindow(inputTitle+"-000"+d2s(longExpSlice,0));
	rename("longExp");
	longExpTitle = getTitle(); 
	selectWindow(inputTitle+"-000"+d2s(shortExpSlice,0));
	rename("shortExp");
	shortExpTitle = getTitle();
}


// set up the image masks
// define saturation a 0.9*the maximum value of the long exposure image
// we subrtracted background, so it is not 65535
selectWindow(longExpTitle);

run("Duplicate...", " "); 
getRawStatistics(nPixels, mean, min, max, std, histogram);
saturation = 0.9*max;
print("saturation = ", saturation);
setThreshold(saturation, 65535);
setOption("BlackBackground", true);
run("Convert to Mask");
rename(inputTitle+"_mask");
maskTitle = getTitle();   // this marks all of the saturated pixels in the long exposure image

// now create the complement of the mask -- these are the pixels that are not saturated in the long exposure image
run("Duplicate...", " ");
run("Invert");
rename(inputTitle+"_inverseMask");
inverseMaskTitle=getTitle();

// divide by 255, so the masks will have pixels that have gray levels of either 0 or 1
run("Divide...", "value=255");
selectWindow(maskTitle);
run("Divide...", "value=255.000");

// multiply the long exposure image by the complement mask to zero out all saturated pixels
imageCalculator("Multiply create", longExpTitle,inverseMaskTitle);
selectWindow("Result of "+longExpTitle);
maskedLongExpTitle = getTitle();

// multiply the short exposure image by the mask to keep only pixels where the corresponding pixels
// in the long exposure image were saturated.
imageCalculator("Multiply create", shortExpTitle,maskTitle);
selectWindow("Result of "+shortExpTitle);
maskedShortExpTitle = getTitle();

// convert to 32 bit so that we have all of the needed dynamic range
run("32-bit");
selectWindow(maskedLongExpTitle);
run("32-bit");
selectWindow(maskedShortExpTitle);

// multiply short exposure by the ratio of (long exposure time)/(short exposure time)
run("Multiply...", "value="+d2s(exposureRatio,2));

// hdr image = exposureRatio*maskedShortExposureImage + longExposureImage
imageCalculator("Add create 32-bit", maskedShortExpTitle,maskedLongExpTitle);
selectWindow("Result of "+maskedShortExpTitle);
rename(inputTitle+"_hdr");
hdrTitle = getTitle();
// clear the incorrect unit that micromanager inserts
run("Properties...", "channels=1 slices=1 frames=1 pixel_width=1 pixel_height=1 voxel_depth=1");
Stack.setXUnit("pixel");
Stack.setYUnit("pixel");

run("glasbey inverted");	// use a pseudocolor LUT to see the weak objects
run("Gaussian Blur...", "sigma=2");
run("Find Maxima...", "prominence=2000 strict output=[Maxima Within Tolerance]");
maximaTitle = getTitle();
run("Analyze Particles...", "size=1-Infinity display exclude clear add");

count = roiManager("count");
for (i=0; i<count; i++){
	roiManager("select", i);

	Roi.getBounds(x, y, width, height);
	xcenter=x+width/2;
	ycenter=y+height/2;
	newRadius = 33/2;

	makeOval(round(xcenter-newRadius), round(ycenter-newRadius), 33, 33); 
	roiManager("add");
}

roiManager("select", Array.getSequence(count));
roiManager("delete");

selectImage(hdrTitle);
run("biop-12colors");
roiManager("Set Color", "red");
roiManager("Show All without labels");
close("Results");
selectImage(hdrTitle);
roiManager("Measure");
run("Distribution Plotter", "parameter=Max tabulate=[Number of values] automatic=[Specify manually below:] bins=400");

