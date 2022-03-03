'''
 * This script finds the best fit straight line for dark noise vs exposure time, and plots the data and the best fit
 * line of the mean intensity of slices in a stack.
 * 
 * Inputs: 	1. An image stack that should contain exposures in sequence.
 * 			2. The user is prompted for the exposures, which are input to a pop-up window. The sequence ends when a negative 
 *			   exposure is entered. (The default entry is -1). If the number of exposures is less than 2, a default sequence
 *			   of 10 exposures (2, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000) ms is assumed. The default sequence happens to be what I used.
 * 			   The exposures are automatically sorted to monotonically increase.
 * 	
 * Outputs: 1. A plot of the data and best fit line, including the slope, offset and R squared.
 * 			2. A table of the data values (mean intensity of each slice).
 * 
 * [26 May 21] converted the original ImageJ macro script to Python.
 *			   Note that functions from Utils.py must be imported. In order for this to work,
 *			   the path to Utils.py must be appended to the import path (see line 37), or Utils.py
 *			   must be in the Fiji jars/lib directory.
 *		
 * Author:			Aryeh Weiss
 * Last modified:	26 May 2021
 '''


from ij import IJ

import os
from os import sys, sep, path, makedirs
from time import sleep
from pprint import pprint
from ij.gui import Plot
from ij.plugin import ZAxisProfiler
from ij.measure import CurveFitter

# Utils is a set of utilites for opening images, creating the output directory, saving images closing all windows
# If it is in the Fiji jars/Lib directory, it will be found. Otherwise, an explicit absolute path must be appended to the search path. 
# The path in the next line must be changed to appropriate to the system on which this code runs
sys.path.append(os.path.abspath("/home/amw/git/jythonIJdev/libs"))
from Utils import *

close_non_image_windows()
close_image_windows()

# If number of exposures is less than 1, assume default exposure list.

exposures = []	
while True:
	exposures.append(IJ.getNumber("exposure (ms)", -1))
	if exposures[-1] < 0:
		exposures.pop()
		exposures.sort()
		break
if len(exposures) < 2:
	exposures =  [4,10,20,50,100,200,500,1000,2000,5000] # default exposures that I happen to use

pprint(exposures)

inputImp, inputPrefix, inputDirPath  = open_image()
print("image directory path: ", inputDirPath.encode("ascii"))
inputImp.setTitle(inputPrefix)
inputTitle = inputImp.getTitle()
print("image name: ", inputTitle.encode("ascii"))


inputImp.setHideOverlay(True)
inputImp.show()


width, height, channels, slices, frames  =inputImp.getDimensions()
print("width=", width," ; height=",  height, " ; number of channels=", channels, " ; number of slices=",  slices, " ; number of franes=  ", frames)

if  slices * frames < len(exposures):
	sys.exit("Stack size not equal to number of exposures")

# remove any calibration that came with the image -- work in pixel units
# this should be changed to allow for work in calibrated units.
IJ.run(inputImp, "Properties...", "unit=pixel pixel_width=1 pixel_height=1 voxel_depth=1.0000000")
# remove any selection so that the mean intensity  of the entire area is calculated.
inputImp.killRoi()

# generate a plot of the mean intensity of each image
# this plot is never displayed. We just use the values generated 
# by the zAxisProfiler.
zPlot = ZAxisProfiler.getPlot(inputImp, "time")

# We do not need the X values. They are just the slice number.
# exp = zPlot.getXValues()
levels = zPlot.getYValues()

# Find the best linear fit of mean gray level vs camera exposure 
cf = CurveFitter(exposures, list(levels))
cf.doFit(CurveFitter.STRAIGHT_LINE)
fitParams = cf.getParams()
slope = fitParams[1]
intercept = fitParams[0]
rSqr = cf.getRSquared()

print("slope=",slope," ; intercept=",intercept," ; rSquared=", rSqr)


# Plot the data and the regression line
newPlotFlags = Plot.TRIANGLE + Plot.X_GRID + Plot.X_NUMBERS + Plot.Y_GRID + Plot.Y_NUMBERS
newPlot = Plot("DARK NOISE", "EXPOSURE, ms", "MEAN GRAY LEVEL",  newPlotFlags)
newPlot.setLineWidth(2)
newPlot.setColor("red")
newPlot.add("triangle",  exposures, list(levels))
newPlot.setLineWidth(1)
newPlot.setColor("black")
newPlot.drawLine(exposures[0], cf.f(exposures[0]),exposures[-1],cf.f(exposures[-1])) 
newPlot.setColor("blue")
newPlot.setFontSize(20)
newPlot.addText("y = a+bx", 100.0, 13000.0)
newPlot.addText("a = "+str(round(intercept,2)),100.0, 12250.0)
newPlot.addText("b = "+str(round(slope,2)), 100.0, 11500.0)
newPlot.addText("R squared = "+str(round(rSqr,3)), 100.0, 10750.0)
newPlot.show()

# Place the plot data into a ResultsTable
rt = newPlot.getResultsTable()
rt.show("Dark Noise Results")
