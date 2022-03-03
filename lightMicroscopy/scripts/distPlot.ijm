/* Distribution_Plotter.ijm
 * IJ BAR: https://github.com/tferr/Scripts#scripts
 *
 * Plots cumulative and relative frequencies from data in the Results table. A Gaussian
 * curve (normal distribution) is fitted to the histogram. Can be called from other
 * scripts using BAR. Python example:

#@Context context

from bar import Runner
runner = Runner(context)
args =  "Area|Relative frequency (%)|Sturges"
runner.runBARMacro("Data_Analysis/Distribution_Plotter.ijm", args)
print("Macro exited: %s " % runner.scriptLoaded())

 * Distribution tables can be accessed through the 'List' button of the plot window:
 * X0: Bin start, Y0: Relative frequencies; X1: Values, Y1: Cumulative frequencies.
 *
 * TF, 2017.04
 */

plotSize = 300;     // Size (in pixels) of histogram canvas
histScale = 0.77;   // Height of modal class relatively to axis of cumulative frequencies


var tabChoices = newArray('Number of values', 'Relative frequency (%)', 'Relative frequency (fractions)');
var binChoices = newArray("Square-root", "Sturges", "Scott (IJ's default)", "Freedman-Diaconis", "Specify manually below:");
var parameter, yAxis, autoBin, userBins, ignoreZeros;


if (nResults==0 || !isOpen("Results")) {
	if ("" + call("bar.Utils.getResultsTable") == "null")
		exit();
}

resCount = nResults;
if (!readSettingsFromArg(getArgument()))
	getSettingsFromUser(resCount);

for (i=0, countInvalid=0; i<resCount; i++) {
	value = getResult(parameter, i);
	if (isNaN(value) || (ignoreZeros && value==0))
		countInvalid++;
}
obsCount = resCount-countInvalid;
if (obsCount==0)
	exit("No valid data for \""+ parameter +"\" in the Results table");

values = newArray(obsCount);
for (i=0, j=0; i<resCount; i++) {
	value = getResult(parameter, i);
	if (!isNaN(value) && !(ignoreZeros && value==0))
		values[j++] = value;
}
cumFreq = newArray(obsCount);
if (yAxis==tabChoices[0]) {
	cumFreq[0] = 1; plotYmax = obsCount;
} else if (yAxis==tabChoices[1]) {
	cumFreq[0] = 100/obsCount; plotYmax = 100;
} else {
	cumFreq[0] = 1/obsCount; plotYmax = 1;
}
for (i=1; i<obsCount; i++) {
	cumFreq[i] = cumFreq[i-1] + cumFreq[0];
}

Array.sort(values);
Array.getStatistics(values, min, max, mean, stdDev);

// http://en.wikipedia.org/wiki/Histogram#Number_of_bins_and_width
if (autoBin==binChoices[0]) { // Square-root
	binWidth = (max-min) / sqrt(obsCount);
} else if (autoBin==binChoices[1]) { // Sturges
	binWidth = (max-min) / (log(obsCount)/log(2) + 1);
} else if (autoBin==binChoices[2]) { // Scott
	binWidth = 3.5 * stdDev * pow(obsCount, -1/3);
} else if (autoBin==binChoices[3]) { // Freedman-Diaconis
	binWidth = 2 * (values[(0.75*obsCount)-1]-values[(0.25*obsCount)-1]) * pow(obsCount, -1/3);
} else {// User-defined
	binWidth = (max-min)/userBins;
}
if (binWidth==0)
	exit("Automatic binning could not be performed.\nRe-check settings or specify bins manually.");

nBins = -floor(-( (max-min)/binWidth ));
bins = getBinStarts(nBins, binWidth, min);
freqs = getHistCounts(bins, values);
Array.getStatistics(freqs, histMin, histMax);
plotXmin = min - binWidth;
plotXmax = max + binWidth;

Plot.create("Histograms for "+ parameter, parameter, yAxis);
Plot.setFrameSize(plotSize, plotSize);
Plot.setLimits(plotXmin, plotXmax, 0, plotYmax);
drawLabel();
Plot.add("dots", bins, freqs);
Plot.setLineWidth(2);
drawHistogramBars("blue", "cyan");
drawNormalCurve(mean, stdDev, "blue");
Plot.setColor("black");
Plot.add("line", values, cumFreq);
Plot.setLineWidth(1);
drawHistogramLabels("blue", 13-(0.05*nBins));
Plot.show();


function readSettingsFromArg(argString) {
	args = split(argString, "|");
	if (args.length<1)
		return false;
	parameter = args[0];
	yAxis = tabChoices[0];
	if (args.length>1)
		yAxis = args[1];
	autoBin = binChoices[3];
	if (args.length>2)
		autoBin = args[2];
	userBins = 2;
	if (args.length>3)
		userBins = parseInt(args[3]);
	ignoreZeros = false;
	if (args.length>4)
		userBins = args[4];
	return true;
}

function getSettingsFromUser(nValues) {
	Dialog.create('Distribution Plotter');
	prmtrs = getParameters();
	Dialog.addChoice("Parameter:", prmtrs);
	Dialog.addChoice('Tabulate:', tabChoices);
	Dialog.addRadioButtonGroup("Automatic binning:", binChoices, 3, 2, binChoices[3]);
	Dialog.addSlider("Bins:", 2, nValues, sqrt(nValues));
	Dialog.addCheckbox("Ignore zeros (NB: NaN values are always ignored)", false);
	Dialog.addMessage("       "+ nValues +" data points in the Results Table...");
	Dialog.addHelp("https://github.com/tferr/Scripts/tree/master#data-analysis");
	Dialog.show;
	parameter = Dialog.getChoice;
	yAxis = Dialog.getChoice;
	autoBin = Dialog.getRadioButton;
	userBins = Dialog.getNumber;
	if (isNaN(userBins))
		userBins = 2;
	userBins = maxOf(2, minOf(userBins, resCount));
	ignoreZeros = Dialog.getCheckbox;
}

function drawHistogramBars(lineColor, fillColor) {
	drawingStep = plotYmax/plotSize;
	for (i=0; i<bins.length; i++) {
		x1 = bins[i]; x2 = x1 + binWidth;
		y = plotYmax * histScale * freqs[i] / histMax;
		Plot.setColor(fillColor);
		for (j=0; j<plotSize*histScale; j++) {
			yfill = maxOf(0, y - j*drawingStep);
			Plot.drawLine(x1, yfill, x2, yfill);
			Plot.drawLine(x1, yfill, x2, yfill);
		}
		Plot.setColor(lineColor);
		Plot.drawLine(x1, y, x2, y);
		Plot.drawLine(x1, 0, x1, y);
		Plot.drawLine(x2, 0, x2, y);
	}
}

function drawHistogramLabels(color, fontSize) {
	Plot.setColor(color);
	Plot.setFontSize(fontSize);
	Plot.setJustification("center");
	for (i=0; i<bins.length; i++) {
		xpos = (binWidth/2+bins[i]-plotXmin)/(plotXmax-plotXmin);
		ypos = 1-(histScale * freqs[i] / histMax);
		if (yAxis==tabChoices[1])
			label = d2s(freqs[i], 1);
		else if (yAxis==tabChoices[2])
			label = substring(d2s(freqs[i], 2), 1);
		else
			label = freqs[i];
		Plot.addText(label, xpos, ypos);
	}
}

function drawLabel() {
	leftMargin = 3/plotSize; topMargin = 15/plotSize;
	colWidth = 100/plotSize; rowHeight = 13/plotSize;
	row1 = topMargin;        col1 = leftMargin;
	row2 = row1 + rowHeight; col2 = col1 + colWidth;
	row3 = row2 + rowHeight; col3 = col2 + colWidth;
	row4 = row3 + rowHeight;
	Plot.addText("N: "+ resCount, col1, row1);
	Plot.addText("Mean: "+ d2s(mean,2), col1, row2);
	Plot.addText("SD: "+ d2s(stdDev,2), col1, row3);
	Plot.addText("Min: "+  d2s(min,2), col1, row4);
	Plot.addText("Max: "+ d2s(max,2), col2, row1);
	Plot.addText("Median: "+ d2s(getMedian(),2), col2, row2);
	Plot.addText("Bins: "+ nBins, col2, row3);
	Plot.addText("Bin width: "+ d2s(binWidth,2), col2, row4);
	if (countInvalid!=0)
		Plot.addText("Ignored entries: "+ countInvalid, col3, row1);
}

function drawNormalCurve(mu, sigma, color) {
	Plot.setColor(color);
	lambda = (binWidth * plotYmax);
	scale = plotYmax * histScale * lambda / histMax;
	drawingStep = (plotXmax-plotXmin)/plotSize;
	for (i=0; i<plotSize; i++) {
		x = plotXmin + i * drawingStep;
		y = scale * ( (1/(sigma*sqrt(2*PI))) * ( exp( -(((x-mu)*(x-mu))/((2*sigma*sigma))) ) ));
		Plot.drawLine(x, y, x, y);
	}
}

function getBinStarts(n, width, startValue) {
	bins = newArray(n);
	for (i=0; i<n; i++)
		bins[i] = i * width + startValue;
	return bins;
}

function getHistCounts(binArray, valuesArray) {
	counts = newArray(nBins);
	for (i=0; i<obsCount; i++) {
		value = valuesArray[i];
		if (value>binArray[nBins-1])
			counts[nBins-1] += 1;
		else {
			for (j=1; j<nBins; j++)
				if (value>=binArray[j-1] && value<binArray[j])
					counts[j-1] += 1;
		}
	}
	for (i=0; i<nBins; i++){
		if (yAxis==tabChoices[1])
			counts[i] = 100 * counts[i] / obsCount ;
		else if (yAxis==tabChoices[2])
			counts[i] = counts[i] / obsCount;
	}
	return counts;
}

function getParameters() {
	list = split(String.getResultsHeadings, "\t");
	if (list[0]==" ") list = Array.slice(list,1); // row numbers
	return Array.sort(list);
}

function getMedian() { // values[] is already sorted
	if (obsCount%2==0)
		median = (values[obsCount/2] + values[obsCount/2 -1])/2;
	else
		median = values[obsCount/2];
	return median;
}