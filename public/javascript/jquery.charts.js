(function($)
{
	// This script was written by Steve Fenton
	// http://www.stevefenton.co.uk/Content/Jquery-Side-Content/
	// Feel free to use this jQuery Plugin
	// Version: 1.1.2
    // Contributions by:
    //     Hug Capella
	
	$.fn.charts = function (settings) {
	
		var config = {
			classmodifier: "charts",
			charttype: "bars",
			direction: "horizontal",
			labelcolumn: 0,
			valuecolumn: 1,
			linkcolumn: 2,
            groupcolumn: -1,
            duration: 2000,
			showoriginal: false,
			chartbgcolours: ["#336699", "#669933", "#339966"],
			chartfgcolours: ["#FFFFFF", "#FFFFFF", "#FFFFFF"],
			chartpadding: 8,
			chartheight: 500,
			showlabels: true,
			showgrid: false,
			gridlines: 8,
            gridvalues: true
		};
		
		if (settings) {
			$.extend(config, settings);
		}
		
		var labelTimer;
		
		function RoundToTwoDecimalPlaces(number) {
			number = Math.round(number * 100);
			number = number / 100;
			return number;
		}
				

		function GetWaterfallOutput(labelArray, valueArray, linkArray, totalValue, smallestValue, largestValue, labelTextArray) {
			var output = "";
			var colourIndex = 0;
			var leftShim = 0;
			var totalValue = (largestValue-smallestValue)
			var shimAdjustment = RoundToTwoDecimalPlaces(100 / labelArray.length);
			var widthAdjustment = shimAdjustment - 1;
			
			output += "<div style=\"height: " + config.chartheight + "px; position: relative;\">";
			
			var runningTotal = 0;
			
			for (var i = 0; i < valueArray.length; i++) {
				
				var positiveValue = valueArray[i];
				var isPositive = true;
				var colourIndex = 1;
				
				if (positiveValue < 0) {
					positiveValue = positiveValue * -1;
					isPositive = false;
					if (config.chartbgcolours.length > 2) {
						colourIndex = 2;
					}
				}
			
				var percent = RoundToTwoDecimalPlaces((positiveValue / totalValue) * 100);
				var barHeight = RoundToTwoDecimalPlaces((positiveValue / totalValue) * 100);
				
				var bottomPosition = runningTotal - barHeight; // Negative column
				if (isPositive) {
					bottomPosition = runningTotal;
				}
				
				if (i == (valueArray.length - 1)) {
					// last column
					colourIndex = 0;
					if (isPositive) {
						//alert (barHeight);
						bottomPosition = runningTotal - barHeight -1  ; /* I don't know why I need the -1 */
					}
					else {
						bottomPosition = runningTotal;
					}
				}  

				bottomPosition += (100 - (largestValue/totalValue * 100));
				
				// Labels
				var displayLabel = "";
				if (config.showlabels) {
					displayLabel = "<span class=\"" + config.classmodifier + "title\" style=\"height: 2; display: block; position: absolute; opacity:0.9; bottom: 2; text-align: " + (isPositive ? "left" : "left") + "; -moz-transform-origin: left top; -webkit-transform-origin: left top; width:" + ((100 - bottomPosition) /100 * config.chartheight - 50) + "px; -webkit-transform: rotate(-90deg); -moz-transform: rotate(-90deg); background-color: " /* + config.chartbgcolours[colourIndex] */ + "transparent" + ";\">" + labelArray[i]   + "&nbsp;&nbsp;&nbsp;<strong>" + valueArray[i] +" </strong> </span>"
					//displayLabel = "<span style=\"display: block; width: 100%; position: absolute; opacity:1; bottom: 0; text-align: center;  background-color: " /* + config.chartbgcolours[colourIndex] */ + "transparent" + ";\">" + labelArray[i] + "</span>"
				}
				
				// Column
                output += "<a class=\"" + config.classmodifier + "link\" style=\"text-decoration:none;\" href=\"" + linkArray[i] + "\">"
				output += "<div class=\"" + config.classmodifier + "bar " + config.classmodifier + (isPositive?'pos':'neg') + "\" style=\"position: absolute; bottom: " + bottomPosition + "%; left: " + leftShim + "%; display: block; height: 0%; border-color: " + config.chartbgcolours[colourIndex] + "; background-color: " + config.chartbgcolours[colourIndex] + "; width: " + widthAdjustment + "%; text-align: center;\" rel=\"" + barHeight + "\" title=\"" + labelTextArray[i] + ":  " + valueArray[i] /* + " (" + percent + "%)" */ + "\">" + "<span style=\"position:absolute;  " + (isPositive ? "left:" : "right:") + ": 0; " + (isPositive ? "top:-20;" : "bottom:-20") + "\">" + /* valueArray[i] + */ "</span>" + displayLabel + "</div>"
                output += "</a>"

				leftShim = leftShim + shimAdjustment;
				
				if (isPositive) {
					runningTotal = runningTotal + barHeight;
				} else {
					runningTotal = runningTotal - barHeight;
				}
			}
			
			output += "</div>";
			
			return output;
		}
		
		return this.each(function () {
			
			// Validate settings
			if (config.chartbgcolours.length != config.chartfgcolours.length) {
				alert("Invalid settings, chartfgcolours must be same length as chartbgcolours");
			}
			
			var $table = $(this);
			
			// Caption
			var caption = $table.children("caption").text();
			
			// Headers
			var maxColumn = Math.max(config.valuecolumn, config.labelcolumn, config.groupcolumn);
			var headers = $table.find("thead th");
			if (headers.length <= maxColumn) {
				alert("Header count doesn't match settings");
			}
			
			// Values
			var values = $table.find("tbody tr");
                        if (config.direction=='vertical') config.chartpadding*= (values.length-1)*100/$table.parent().width()/values.length
			
			var labelArray = new Array();
			var labelTextArray = new Array();
			var valueArray = new Array();
            var linkArray = new Array();
            var groupArray = new Array();
			
			var totalValue = 0;
			var largestValue = 0;
			var smallestValue = 0;
			var currentGroup = "";
			
			// Creates a list of values and a total (and sets groups if required)
			for (var i = 0; i < values.length; i++) {
				if (config.groupcolumn > -1) {
					groupArray[groupArray.length] = $(values[i]).children("td").eq(config.groupcolumn).html();
				}
				var valueString = $(values[i]).children("td").eq(config.valuecolumn).text();
				if (valueString.length > 0) {
					var valueAmount = parseFloat(valueString, 10);
					
					if (valueAmount != 0 || i == (values.length - 1) /* include net, even if 0 */ ) {
						
						labelArray[labelArray.length] = $(values[i]).children("td").eq(config.labelcolumn).html();
						labelTextArray[labelTextArray.length] = $(values[i]).children("td").eq(config.labelcolumn).text();
						valueArray[valueArray.length] = valueAmount;
                        linkArray[linkArray.length] = $(values[i]).children("td").eq(config.linkcolumn).text();
                        totalValue = totalValue + valueAmount;
						if (i != (values.length - 2)) { // don't include net in running totals
							if (totalValue > largestValue) {
								largestValue = totalValue;
							}
							// include smallest value in range
							if (totalValue < smallestValue) {
								smallestValue = totalValue;
							}
						}
					//alert($(values[i]).children("td").eq(config.labelcolumn).html() + $(values[i]).children("td").eq(config.labelcolumn).text() + valueAmount)
					}
				}
			}
			//if (largestValue< -1 * smallestValue) largestValue = smallestValue * -1; 
			
			// Containing division
			var output = "<h3>" + caption + "</h3>" +
				"<div class=\"" + config.classmodifier + "container\">" +
				"<div class=\"" + config.classmodifier + "label\">&nbsp;</div>";
			
			// Get output based on chart type
			switch (config.charttype) {
			
				case 'bars':
				
					switch (config.direction) {
						
						case 'horizontal':
							// Horizontal Bars
							output += GetHorizontalBarsOutput(groupArray, labelArray, valueArray, totalValue, largestValue, labelTextArray);
							break;
							
						case 'vertical':
							// Vertical Bars
							output += GetVerticalBarsOutput(groupArray, labelArray, valueArray, totalValue, largestValue, labelTextArray);
							break;

					}
					break;
					
				case 'waterfall':
				
					switch (config.direction) {
					
						case 'horizontal':
							// Horizontal Bars
							alert("Horizontal waterfall charts not yet supported!");
							break;

						case 'vertical':
							// Waterfall chart
							output += GetWaterfallOutput(labelArray, valueArray, linkArray, totalValue, smallestValue, largestValue, labelTextArray);
							break;
					}
					break;
			
			}
			
			// Close container
			output += "</div>";
			
			// Show the chart
			$table.after(output);
			
			if (!config.showoriginal) {
				$table.hide();
			}
			
			// $("." + config.classmodifier + "gridline").each( function () {
			// 							$This = $(this);
			// 							if ($This.hasClass("even")) {
			// 								$This.css({ opacity: 0.5 });
			// 							} else {
			// 								$This.css({ opacity: 0.2 });
			// 							}
			// 						});
			
			// Animation
			$("." + config.classmodifier + "bar").each( function() {
				var calculatedSize = $(this).attr("rel");
				
				switch (config.direction) {
					case "horizontal":
						$(this).animate({ width: calculatedSize+"%" }, config.duration);
						break;
					case "vertical":
						$(this).animate({ height: calculatedSize+"%" }, config.duration);
						break;
				}
			});
			
			// Labels
			$("." + config.classmodifier + "bar").mouseover( function() {
				window.clearTimeout(labelTimer);
				var $Label = $(this).parents("." + config.classmodifier + "container").find("." + config.classmodifier + "label");
				var $Bar = $(this);
				$Label.html("<div style=\"width: 70%; margin: 0 auto;\">" + $Bar.attr("title") + "</div>");
				$Label.find("div").css({ "text-align": "center", "color": "ivory", "background-color": "transparent" });
				var labelHeight = $Label.find("div").height();
				$Label.css({ height: labelHeight });
				return false;
			});
			
			$("." + config.classmodifier + "bar").mouseleave( function() {
				var $Bar = $(this);
				labelTimer = window.setTimeout(function () {
					$Bar.parents("." + config.classmodifier + "container").find("." + config.classmodifier + "label div").fadeOut("slow");
				}, 1000);
				return false;
			});
			
		});
		
		return this;
	};
})(jQuery);
