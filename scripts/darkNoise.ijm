/*
 * This macro finds the best fit straight line for dark noise vs exposure time, and plots the data and the best fit
 * line of the mean intensity of slices in a stack.
 * 
 * Inputs: 	1. An image stack that should contain exposures in sequence.
 * 			2. The number of exposures. If the number of exposures is less than 2, a default sequence of 10 exposures
 * 			   (2, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000) ms is assumed. If the number of exposures is greater 
 * 			   than 1, the user is prompted for the exposures. The default sequence happens to be what I used.
 * 			   Note that exposures must monotonically increase.
 * 	
 * Outputs: 1. A plot of the data and best fit line, including the slope, offset and R squared.
 * 			2. A table of the data values (mean intensity of each slice).
 * 			
 * Author:			Aryeh Weiss
 * Last modified:	4 Feb 19 
 */

// special scripting syntax that simplifies prompting for input parameters
#@ Integer(label="Number of exposures",value=10) numExp

// If number of exposures is less than 1, assume default exposure list.
if (numExp > 1) {
	exposures = newArray(numExp);	
	for (i=0; i < numExp; i++) {
		exposures[i] = getNumber("input exposure "+d2s(i+1,0),-1);
		if (exposures[i] < 0) {
			exit("invalid exposure"); 
		}
	}
}
else {
	exposures =  newArray(4,10,20,50,100,200,500,1000,2000,5000); // default exposures that I happen to use
}

	

Array.print(exposures);
Array.sort(exposures);  // in case they were entered in the wrong order.
Array.print(exposures);

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

if ( slices * frames < numExp) {
	exit("Stack size not equal to number of exposures");
}

// remove any calibration that came with the image -- work in pixel units
// this should be changed to allow for work in calibrated units.
run("Properties...", "unit=pixel pixel_width=1 pixel_height=1 voxel_depth=1.0000000");

// remove any selection so that the mean intensity  of the entire area is calculated.
run("Select None");
run("Plot Z-axis Profile"); // this creates a plot of the mean intensities for each slice

// Get the values of the active (in this case only) plot.
Plot.getValues(xpoints, ypoints);
Plot.showValues();

Fit.doFit("Straight line", exposures, ypoints);


offset = Fit.p(0);
slope = Fit.p(1);
rSqr = Fit.rSquared;
print(offset, slope, rSqr);

Plot.create("DARK NOISE", "EXPOSURE, ms", "MEAN GRAY LEVEL");
Plot.setLineWidth(2);
Plot.setColor("red", "red");
Plot.add("triangle",  exposures, ypoints);
Plot.setLineWidth(1);
Plot.setColor("black");
Plot.drawLine(exposures[0], Fit.f(exposures[0]),exposures[exposures.length - 1], Fit.f(exposures[exposures.length - 1])) ;
Plot.setColor("blue");
Plot.addText("y = a+bx", 0.05, 0.1);
Plot.addText("a = "+d2s(offset,0), 0.05, 0.15);
Plot.addText("b = "+d2s(slope,2), 0.05, 0.2);
Plot.addText("R squared = "+d2s(rSqr, 4), 0.05, 0.25);

Plot.show();
Plot.getValues(xpoints, ypoints);
Plot.showValues();


