/*
 * This script helps find thespatial calibration of an image of a ruler.
 * 
 * Input: An image of a ruler. We use a 1 mm scale marked in 10 micron units.
 * Output: A line profile of the ruler, and the spatial calibraiton in microns/pixel. The iamge calibration is modified.
 *         
 *  Author: 		Aryeh Weiss
 *  Last modified: 	3 Feb 2019
 */


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
print(width, height, channels, slices, frames);

// remove any calibration that came with the image -- work in pixel units
// this should be changed to allow for work in calibrated units.
run("Properties...", "unit=pixel pixel_width=1 pixel_height=1 voxel_depth=1.0000000");

// prompt for either a line or rectangular ROI. If no ROI is selected, exit, If something other than a line or rectangle
// is selected, prompt again. 
while (selectionType() != 0 && selectionType() != 5) {
	waitForUser("create a line or rectangular selection over the image of the ruler, or no selection to quit");
	if (selectionType() <0) { exit()}
}

// create a line intensity profile. 
run("Plot Profile");

// prompt the user to find teh numberof pixels between two line (which the user chooses)
// it is best to use lines that are as far apart as possible) 
waitForUser("Measure the distance in pixels between two lines of the ruler (best to choose lines that are far apart)");

// we used waitForUser before in order to allwo the user to interactively  measure the position of the lines inthe plot
pixels = getNumber("Input distance in pixels between the two lines", 0);
microns = getNumber("Input calibrated distance as indicated by the ruler for the chosen points", 0);

if (pixels == 0 || microns == 0) {
	exit("No calibration entered");
}

// calculate teh spatial calibration and print it to the log
spatialCalibration = microns/pixels;	// microns/pixel
print("Spatial calibration = ", spatialCalibration);

// set the image calibration to the spatial calibration that was just calculated.
selectImage(inputTitle);
run("Properties...", "unit=micron pixel_width=&spatialCalibration pixel_height=&spatialCalibration voxel_depth=1.0000000");

// display a calibrated profile to show that the image is now calibrated.
run("Plot Profile");