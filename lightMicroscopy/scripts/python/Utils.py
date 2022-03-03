'''
This file contains a set of utilities (mostly I/O) commonly needed in python scripts

1. 	close_non_image_windows()
	closes all non-image windows except as documented in teh function.
		
2. 	close_image_windows()

3. 	open_image()
	Prompts for image, and returns an ImagePlus, imagePrifix, and image path.
	
4. 	outputCreater(inputPath, inputPrefix, outputPrefix, noDate = False)

	
5. 	getCreatedImages(inputName, nameStr)
	Used to catch image screaed as byproducts of IJ.run() calls.

6. 	saveFile(imp, format, outputDirPath)
	Convenient utility for saving file in nay format that IJ provides.

Last Modifed: 26 May 21
Author: Aryeh Weiss
'''




from ij import IJ,ImagePlus,WindowManager, Prefs
from ij.io import OpenDialog, LogStream, FileSaver

import os
from os import sep, path, makedirs
import sys, math, re, time
from datetime import datetime
from pprint import pprint


def close_non_image_windows():
	"""
	Close all non-image windows except for the script editor, Recorder, Commander Finder, and Memory in application
	"""
	if WindowManager.getWindow('Results') != None:
		WindowManager.getWindow('Results').close(False)
	for w in WindowManager.getNonImageTitles():
		if (w[:-3] != '.py' and w[:-4]!='.ijm' and w[:] != 'Recorder') and w[:] != "Command Finder" and w[:] != "Memory" and w[:] != "Log":
			WindowManager.getWindow(w).close()

def close_image_windows():
	"""
	Closes all image windows which are open in the application
	"""
	for w in WindowManager.getImageTitles():
		imp = WindowManager.getImage(w)
		imp.changes = False
		imp.close()


def open_image():
	"""
	opens an image, returns an imagePlus object and its name in that order
	"""
	# Prompt user for the input image file.
	print "open_image begin"
	op = OpenDialog("Choose input image...", "")
	
	if op.getPath() == None :
		sys.exit('User canceled dialog')
	# open selected image and prepare it for analysis  
	
	inputName = op.getFileName()
	inputDirPath = op.getDirectory()
	inputPath = inputDirPath + inputName

	# Strip the suffix off of the input image name
	if inputName[-4] == ".":
		inputPrefix = inputName[:-4]	# assumes that a suffix exists
	else:
		inputPrefix = inputName

	#opens image and returns it.
	inputImp = ImagePlus(inputPath)

	print "open_image finis"
	return inputImp, inputPrefix, inputDirPath 

def outputCreater(inputPath, inputPrefix, outputPrefix, noDate = False):
	'''
	checks that there is no directory with the name we intend to use and creates it
	
	input: directory name(str), root for directory creation (str), 3 constants to be used in directory name (str), (int), (int)
	output: path to directory created (str)
	'''
	#get data for title of the folder
	date = str(datetime.now().year) + str(datetime.now().month).zfill(2) + str(datetime.now().day).zfill(2)
	loctime = str(datetime.now().hour).zfill(2) + str(datetime.now().minute).zfill(2)
	if noDate:
		outputDir = inputPrefix +'_'+outputPrefix+'_Output'
	else:
		outputDir = inputPrefix +'_'+outputPrefix+'_Output_'+date + loctime
	outputPath = inputPath + outputDir

	# create the output directory. It should never already exist,
	# but it is good practice to check
	# code appears to throw an exception if the directory does not exist,
	# so this only makes a directory when this is the case
	# the original code does not do anything to react to the results of
	# the test, so this code changes this to request a new path from the
	# user
	try: 
		if(path.exists(outputPath)):
			return(outputPath+os.sep)
			#this flag is only created if the path exists, in which case, until the user
			#inputs a new valid path, the code goes into an infinite loop asking for a
			#new valid path
			direx = 0
			while direx == 0:
				warning = GenericDialog("Warning")  
				warning.addStringField("Directory exists!!! Please input a path manually", "")
				warning.showDialog()
				outputPath = warning.getNextString()
				#the contents of the if statement should not ever be used, but path.exists
				#does what it is supposed to then the if statement deals with that
				if warning.wasCanceled():
					sys.exit()
				if not(path.exists(outputPath)):
					direx = 1
					makedirs(outputPath)
		else:
			makedirs(outputPath) 
	except:
		makedirs(outputPath)
	return outputPath+os.sep

def getCreatedImages(inputName, nameStr):
	# This function returns the ImagePlus, ImageProcessor, and image title associated 
	# with an image that was open with IJ.run(something that creates an image)
	# It was first writen for IJ.run(bioformats...), but is not restricted to bioformats
	imp = WindowManager.getImage(inputName)
	imp.setTitle(nameStr)
	impTitle = imp.getTitle()
	ip = imp.getProcessor()
	return [imp, ip, impTitle]

def saveFile(imp, format, outputDirPath):
	fs = FileSaver(imp)
	saveDict = {
		'tif' : lambda: fs.saveAsTiff(outputDirPath + imp.getTitle() + ".tif"),
		'zip' : lambda: fs.saveAsZip(outputDirPath + imp.getTitle() + ".zip"),
		'png' : lambda: fs.saveAsPng(outputDirPath + imp.getTitle() + '.png'),
		'txt' : lambda: fs.saveAsTxt(outputDirPath + imp.getTitle() + '.txt'),
		'jpg' : lambda: fs.saveAsJpg(outputDirPath + imp.getTitle() + '.jpg')
		}
	
	saveDict[format]()
	return