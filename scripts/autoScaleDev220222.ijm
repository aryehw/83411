/*
 * This script helps find the spatial calibration of an image of a ruler.
 * 
 * Input:   1. 	The user is prompted to select the objective magnification used to image the ruler. 
 * 				The choice are 4x, 10x, 20x, 40x (corresponding to what we have in the lab).
 * 			2. 	An image of a ruler. We use a 1 mm scale marked in 10 micron units.
 *        		The ruler is assumed to be oriented along the X-axis (horizontal). 
 *        		The longest markings are assumed to have a spacing of 100 microns.
 *        		
 * Output: 	1. 	A thresholded image of the ruler.
 * 			2. The original image with the 100 micron lines indicated.
 * 			3. The ROI manager contains the ROI list corresponding to the 100 micron markings.
 * 			4. The calibration (microns/pixel) is printed in the Log window.
 *         
 *  24 May 20	1. Added a condition on max_feret, which is the longest dimension of an object. 
 *  			2. Added local contrast enhancement (CLAHE) to fix images with highly nonuniform contrast.
 *             
 *  22 Feb 22	Added a startup parameter to select between the Ted Pella ruler slide and the Ali Express ruler slide. 
 *  			When using the AliExpress slide at low magnification, the vertical as well as horizontal scale is visible.
 *  			This will confuse the autoScale script. Therefore, when the program prompts to select the correct slice, 
 *  			the stack should be cropped so that it only contains vertical lines (of the horizontal scale. It should
 *  			also not include the central s50 micron squares.
 *             
 *  To do: The many "magic numbers" (ie, empicial constants) should be derived automatically rather than empirically. 
 *  	 
 *         
 *  Author:		Aryeh Weiss
 *  Last modified:  	22 Feb 22
 */

// #@ Integer(label="Objective Magnification",value=4) mag
#@ String(choices={4, 10,20, 40}, style="listBox") mag

#@ String(choices={"Ted Pella" , "AliExpress"}, style="listBox") RULER_SLIDE

print("\\Clear");
 
if (RULER_SLIDE == "Ted Pella") {
	minArea = 400;	// empirically determined size for the 100 micron markings with the 4X objective.
	maxFeret = 130; // empirically determined minimum length of the 100 miron markings
}

else if (RULER_SLIDE == "AliExpress") {
	minArea = 700;	// empirically determined size for the 100 micron markings with the 4X objective.
	maxFeret = 200; // empirically determined minimum length of the 100 miron markings

}

if (mag == 4){
	magFactor = 1;
}
else if(mag == 10) {
	magFactor = 2.5;
}
else if (mag == 20) {
	magFactor = 2*2.5;
}
else if (mag == 40) {
	magFactor = 2*2*2.5;
}
else {
	exit("invalid objective magnification");
}

size = minArea*(magFactor*magFactor); // areas scale as magFactor squared
rollingBallRadius = magFactor*2;

maxFeret = maxFeret*magFactor;   // linear measures scale linearly with magFactor
print("maxFeret = ", maxFeret);

run("Close All");

// prompt for the input file and open the  image
inputPath =File.openDialog("input file");
print("image path: ", inputPath);
inputTitle = File.getName(inputPath);
print("image name: ", inputTitle);
open(inputPath);
inputTitle = getTitle();	// save the image title in a variable

// remove any overlay if the image was saved with an overlay
run("Remove Overlay");

getDimensions(width, height, channels, slices, frames);
print("Width = ", width, "; Height = ", height, "; Channels = ", channels, "; Slices = ", slices, "; Frames = ",frames);

// remove any calibration that came with the image -- work in pixel units
// this should be changed to allow for work in calibrated units.
run("Properties...", "unit=pixel pixel_width=1 pixel_height=1 voxel_depth=1.0000000");

// If an image stack was entered, then prompt the user to select the correct slice.
if (slices*frames*channels > 1) {
	waitForUser("select slice");
	slice = getSliceNumber();
	print("Slice = ", slice); 
}
print("Objective magnification = "+d2s(mag,0)+"X ; Minimum size (pixels) = ", size);
run("Duplicate...", " ");
run("Invert");	// I prefer white marks on a dark background

// Subtract Background level the image so that the background is flat.
// The rolling ball radius must be larger than the width of the lines in the ruler
// The appropriate radius is scaled as required for the magnification
run("Subtract Background...", "rolling=&rollingBallRadius");

// the median filter removes point noise 
run("Median...", "radius=2");
// Local contrast enhancement helps when there is a large variation in contrast across the image
// It does not appear to hurt when it is nt needed, so it is applied here before thresholding
run("Enhance Local Contrast (CLAHE)", "blocksize=127 histogram=256 maximum=2 mask=*None*");

// Find a suitable automatic threshold.Empirically, MaxEntropy has worked on images of the scale
setAutoThreshold("MaxEntropy dark");
setOption("BlackBackground", true);
run("Convert to Mask"); 		// create a binary image

run("Median...", "radius=1"); 	// remove isolated points
run("Convert to Mask");			// let ImageJ know that it is still a binary image
run("Duplicate...", " ");
run("Options...", "iterations=1 count=1 black do=Close");	// close holes that the thresholding may have created


// make sure that the measurements we need are selected
run("Set Measurements...", "area mean standard centroid center bounding fit shape feret's redirect=None decimal=3");

// Find objects that are white, provided that they are not  round and larger than a size that depends on the magnification.
// This is designed to leave only the large marking that indicate 100 micron units on the ruler.
// Originally, we filtered onl on area. However, filtering on length make more sense, and this is now added - 24 May 20 [AW] 
// Note that float or int variables can be converted to strings and entered into the argument list. 
run("Extended Particle Analyzer", "pixel  output_in_pixels area="+d2s(size,0)+"-Infinity max_feret="+d2s(maxFeret,0)+"-Infinity show=Nothing redirect=None keep=None display clear add reset");

// Get the location of each of the 100 micron lines
// If the scale is partly truncated in the  vertical direction (as happens with the 40x objective), then the 100 micron lines
// may not be found. In that case, the size cutoff will be reduced 10%, and we try again. If the size cutoff gets below
// the size cutoff for the lowest magnification (4x), the program will exit.
if (nResults > 1) {
	xLocations = Table.getColumn("BX");
//	Array.print(xLocations);
}
else {
	while (nResults < 2) {
		size = 0.9*size;
		maxFeret = 0.9*maxFeret;
		run("Extended Particle Analyzer", "pixel output_in_pixels  area="+d2s(size,0)+"-Infinity max_feret="+d2s(maxFeret,0)+"-Infinity show=Nothing redirect=None keep=None display clear add reset");
		if (size < minArea) {
			exit("ruler not found");
		}
	}
	xLocations = Table.getColumn("BX");
//	Array.print(xLocations);	
}
Array.sort(xLocations); 	// sort the locations, so that we can easily computer largest - smallest
numPixels = xLocations[xLocations.length -1] - xLocations[0];
print("Number of pixels between extreme 100 markings = ", numPixels); 
print("Number of 100 micron gaps = ", xLocations.length -1);

// spatialCal is the calibration in microns/pixel. The 100 below represents the 100 micron spacing between the largest marks.
spatialCal = (xLocations.length -1)*100/numPixels; 	
print("Spatial calibration = ", spatialCal, " microns/pixel");

// Select the input image and set its spatial scale accordingly
selectImage(inputTitle);
run("Properties...", "unit=micron pixel_width=&spatialCal pixel_height=&spatialCal voxel_depth=1.0000000");
setSlice(slice);
roiManager("Show All with labels");
