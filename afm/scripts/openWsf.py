'''
This script imports the wsf image files produced by the AFMWorkshop TT-AFM atomic force microscope.

input: a wsf image file
output: 1. A 32 bit floating point image with the correct spatial calibration in microns/pixel
		2. A text window that displays the metadata from the wsf file.

Author: Aryeh Weiss
Last modified: 14 March 2019

'''

from ij import IJ, Prefs, ImagePlus
from ij.process import FloatProcessor
from ij.io import DirectoryChooser,  OpenDialog
from ij.measure import Calibration
from ij.text import TextWindow

from os import sys

#IJ.log("\\Clear")

op = OpenDialog("Choose input image...", "")
path = op.getDirectory()+ op.getFileName()
inputName = op.getFileName()
inputDir = op.getDirectory()
inputPath = inputDir + inputName

print inputName[-3:]
if inputName[-4] == ".":
	if inputName[-3:] != "wsf":
		sys.exit("wrong file type")
	inputPrefix = inputName[:-4]	# assumes that a suffix exists
else:
	inputPrefix = inputName 		# we should never get here

print inputPath, "\n", inputPrefix

inputFile = open(inputPath, "r") 
inputLines = inputFile.readlines()

tw = TextWindow(inputPrefix[0:25]+" Metadata", " " , 550,  650)
tw.append("File name: "+inputPrefix)
tw.append(" ")
'''
IJ.log("Metadata")
IJ.log("========")
IJ.log("File name: "+inputPrefix)
IJ.log(" ")
'''
#parse the WSF file
for line in inputLines:
	if line[0].isalpha():
		tw.append(line[0:-2])
#		IJ.log(line[0:-2])
	
	if  "Pixels in X" in line:
		width = int(line.split(" ")[3])

	if "Lines in Y" in line:
		height = int(line.split(" ")[3])

	if "X Range" in line:
		xRange = float(line.split(" ")[2])

	if "Y Range" in line:
		yRange = float(line.split(" ")[2])

try:
	xCal = xRange/width
	yCal = yRange/height
except:
	sys.exit("Error parsing metadata: this may not be  a wsf file")
	

# hard coded for now
units = "micron"

print width, height

#extract the image data
imageData = []
for line in inputLines:
	if len(line.split("\t")) == width: # If the line has <width> elements, it is probably image data
		imageData.append( map(float, line.split("\t"))) # convert strings to floats  

# create the imageprocessor which will hope the floating point data
fp = FloatProcessor(width, height)
pix = fp.getPixels()

# copy the data to the floatprocessor
for i in range(height):
	for j in range(width):
		pix[i*width + j] = imageData[i][j]
		
# create an ImagePlus object using the loaded floatprocessor 
imp = ImagePlus(inputPrefix, fp)

# set the spatial calibration 
IJ.run(imp, "Properties...", "channels=1 slices=1 frames=1 unit=micron pixel_width="+str(xCal)+" pixel_height="+str(yCal)+" voxel_depth=1.0000");

newCal = Calibration()

newCal.pixelWidth = xCal
newCal.pixelHeight = yCal
newCal.setXUnit(units)
newCal.setYUnit(units)
imp.setCalibration(newCal)

imp.show()