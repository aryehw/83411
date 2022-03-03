/*
 * This macro calculates the running ratios (ratio of current slice to previous slice) 
 * of the mean intensity of slices in a stack.
 * It it useful When one wants to compare mean image intensities between images in which
 * some parameter was changed systematically (eg, magnification, illumination intenisty, camera exposure, etc).
 * The black level (offset) of the camera (if provided) is subtracted from the mean intensities.
 * 
 * Inputs: 	1. An image stack.
 * 			2. The black level of the system
 * 	
 * Outputs: 1. A plot of the mean intensities vs slice number.
 * 			2. A table of the plot values, and the running ratio.
 */

// special scripting syntax that simplifies promting for input parameters
#@ Integer(label="Black Level",value=0) offset

// closes all image windows
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

if ( slices * frames < 2) {
	exit)"This program expects an image stack");
}

// remove any calibration that came with the image -- work in pixel units
// this should be changed to allow for work in calibrated units.
run("Properties...", "unit=pixel pixel_width=1 pixel_height=1 voxel_depth=1.0000000");

// remove any selection so that the mean intensity  of the entire area is calculated.
run("Select None");
run("Plot Z-axis Profile");

// Get the values of the active (in this case only) plot.
Plot.getValues(xpoints, ypoints);
Plot.showValues();

ratios = newArray(xpoints.length); // allocate the array to hold the ratios of current intensity to previous
ratios[0] = 1; // by definition

// loop throug the intensities, calculate teh ratio after subtracting the black level
for (i=1; i<xpoints.length; i++){
	ratios[i] = (ypoints[i]-offset)/(ypoints[i-1]-offset);
}

// add the ratios to the results table
Table.setColumn("Ratios", ratios);
updateResults();



 