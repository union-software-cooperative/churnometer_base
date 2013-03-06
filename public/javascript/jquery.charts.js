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
			othercolumn: 2,
      combinedcolumn: 3,
      linkcolumn: 4,
      valuelinkcolumn: 5,
      otherlinkcolumn: 6,
      combinedlinkcolumn: 7,
      groupcolumn: -1,
      duration: 0,
			showoriginal: false,
			chartbgcolours: ["#336699", "#669933", "#339966", "#FF7D40"],
			chartfgcolours: ["#FFFFFF", "#FFFFFF", "#FFFFFF"],
			othercolour: "#FF7D40", 
			combinedcolour: "#B3572D",
			connectorcolour: "grey", 
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
				

		function GetWaterfallOutput(labelArray, valueArray, linkArray, valueLinkArray, otherLinkArray, combinedLinkArray, totalValue, smallestValue, largestValue, labelTextArray, otherArray, combinedArray) {
			var output = "";
			var colourIndex = 0;
			var leftShim = 0;
			var totalValue = largestValue-smallestValue
			
			var bar_count = 0;
			for (var i = 0; i < valueArray.length; i++)  {
		    if (valueArray[i] != 0 || otherArray[i] != 0) bar_count++;
		  }
		  
			var shimAdjustment = RoundToTwoDecimalPlaces(100 / bar_count);
			var widthAdjustment = shimAdjustment - 1;
			var connectorWidth = (shimAdjustment * 2) - (shimAdjustment - widthAdjustment);
				
			output += "<div style=\"height: " + config.chartheight + "px; position: relative;\">";
			
			// net line
			var zero_pos = (100 - (largestValue/totalValue * 100));
			output += "<div class=\"" + config.classmodifier + (isPositive?'pos':'neg') + "\" style=\"position: absolute; bottom: " + zero_pos + "%; left: 0%; display: block; height: 2px; border-color: "+config.chartbgcolours[0]+"; background-color: "+config.chartbgcolours[0]+"; width: 99%; text-align: center;\" rel=\"0\"></div>"
  
			var runningTotal = 0;
			var lastLabel = ""; 
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
				var otherHeight = RoundToTwoDecimalPlaces((Math.abs(otherArray[i]) / totalValue) * 100);
				var combinedHeight = 1
				var combinedWidth = widthAdjustment
			  var combinedLeft = leftShim
			  
				var bottomPosition = runningTotal - barHeight; // Negative column
				var otherBottomPosition = runningTotal - otherHeight;
				var connectorPosition = runningTotal;
				var combinedBottomPosition = runningTotal - combinedHeight;
				
				if (isPositive) {
					bottomPosition = runningTotal;
				}
				
				if (i == (valueArray.length - 1)) {
					// last column
					colourIndex = 0;
					if (isPositive) {
						//alert (barHeight);
						bottomPosition = runningTotal - barHeight ; /* Sometimes -1 is needed here to stop net from inverting*/
					}
					else {
						bottomPosition = runningTotal;
					}
				}  

				bottomPosition += (100 - (largestValue/totalValue * 100));
				otherBottomPosition += (100 - (largestValue/totalValue * 100));
				connectorPosition = runningTotal + (100 - (largestValue/totalValue * 100));
				combinedBottomPosition += (100 - (largestValue/totalValue * 100));
				
				// fix rendering bug in safari and firefox that cause bar to jump to top when left/bottom approaches 0
				if (Math.abs(bottomPosition) < 0.1 ) bottomPosition = 0.1;
				if (Math.abs(otherBottomPosition) < 0.1) otherBottomPosition = 0.1;
				if (Math.abs(connectorPosition) < 0.1) connectorPosition = 0.1;
				if (Math.abs(combinedBottomPosition) < 0.1) combinedBottomPosition = 0.1;
				
				// Labels
				var displayLabel = "";
				var netLabel = "";
				
				if (config.showlabels) {
				  if (i == (valueArray.length - 1)) {
				    netLabel = valueArray[i];
					}
					displayLabel = "<span class=\"" + config.classmodifier + "title\" style=\"height: 2; display: block; position: absolute; opacity:0.9; bottom: 2; text-align: " + (isPositive ? "left" : "left") + "; -moz-transform-origin: left top; -webkit-transform-origin: left top; width:" + ((100 - bottomPosition) /100 * config.chartheight - 50) + "px; -webkit-transform: rotate(-90deg); -moz-transform: rotate(-90deg); background-color: " /* + config.chartbgcolours[colourIndex] */ + "transparent" + ";white-space: nowrap;\">" + labelArray[i].toUpperCase()   + "&nbsp;&nbsp;&nbsp;" + netLabel + "</strong> </span>"
					valueLabel = labelArray[i].toLowerCase() + (isPositive ? " gain: " : " loss: ") + Math.abs(valueArray[i])
					otherLabel = labelArray[i].toLowerCase() + " problems: " + Math.abs(otherArray[i])
					combinedLabel = labelArray[i].toLowerCase() + " combined " + (isPositive ? " gain " : " loss ") + " and problems: " + Math.abs(combinedArray[i])
				}
				
				// Column
				
				if (valueArray[i] != 0 || otherArray[i] != 0) {
          
          //output += "<a class=\"" + config.classmodifier + "link\" style=\"text-decoration:none;\" href=\"" + linkArray[i] + "\">"
          
          // main colour
          output += "<a class=\"" + config.classmodifier + "link\" style=\"text-decoration:none;\" href=\"" + valueLinkArray[i] + "\">"
          output += "<div class=\"" + config.classmodifier + "bar " + config.classmodifier + (isPositive?'pos':'neg') + "\" style=\"position: absolute; bottom: " + bottomPosition + "%; left: " + leftShim + "%; display: block; height: 0%; border-color: " + config.chartbgcolours[colourIndex] + "; background-color: " + config.chartbgcolours[colourIndex] + "; width: " + widthAdjustment + "%; text-align: center;\" rel=\"" + barHeight + "\" title=\"" + valueLabel + "\">" + "<span style=\"position:absolute;  " + (isPositive ? "left:" : "right:") + ": 0; " + (isPositive ? "top:-20;" : "bottom:-20") + "\">" + /* valueArray[i] + */ "</span></div>"
          output += "</a>"
          
          // other colour
          output += "<a class=\"" + config.classmodifier + "link\" style=\"text-decoration:none;\" href=\"" + otherLinkArray[i] + "\">"
          output += "<div class=\"" + config.classmodifier + "bar " + config.classmodifier + (isPositive?'pos':'neg') + "\" style=\"position: absolute; bottom: " + otherBottomPosition + "%; left: " + (leftShim + 1) + "%; display: block; height: 0%; border-color: " + config.othercolour + "; background-color: " + config.othercolour + "; width: " + (widthAdjustment - 1) + "%; text-align: center;\" rel=\"" + otherHeight + "\" title=\"" + otherLabel + "\">" + "<span style=\"position:absolute;  " + (isPositive ? "left:" : "right:") + ": 0; " + (isPositive ? "top:-20;" : "bottom:-20") + "\">" + /* valueArray[i] + */ "</span></div>"
          output += "</a>"
          
          // combined colour
          if (valueArray[i] != 0 && otherArray[i] != 0) {
            output += "<a class=\"" + config.classmodifier + "link\" style=\"text-decoration:none;\" href=\"" + combinedLinkArray[i] + "\">"
            output += "<div class=\"" + config.classmodifier + "bar " + config.classmodifier + (isPositive?'pos':'neg') + "\" style=\"position: absolute; bottom: " + combinedBottomPosition + "%; left: " + combinedLeft + "%; display: block; height: 0%; border-color: " + config.othercolour + "; background-color: " + config.combinedcolour + "; width: " + combinedWidth + "%; text-align: center;\" rel=\"" + combinedHeight + "\" title=\"" + combinedLabel + "\">" + "<span style=\"position:absolute;  " + (isPositive ? "left:" : "right:") + ": 0; " + (isPositive ? "top:-20;" : "bottom:-20") + "\">" + /* valueArray[i] + */ "</span></div>"
            output += "</a>"
          }
          
          // connector
          if (i > 0) {
            output += "<div class=\"" + config.classmodifier + (isPositive?'pos':'neg') + "\" style=\"position: absolute; bottom: " + connectorPosition + "%; left: " + (leftShim - shimAdjustment) + "%; display: block; height: 2px; border-color: " + config.connectorcolour + "; background-color: " + config.connectorcolour + "; width: " + (connectorWidth) + "%; text-align: center;\" rel=\"0\"></div>"
          }
          
          // label connector
          if (lastLabel != labelArray[i]) {
            output += "<div class=\"" + config.classmodifier + "bar " + config.classmodifier + (isPositive?'pos':'neg') + "\" style=\"position: absolute; bottom: 0%; left: " + leftShim + "%; display: block; height: 0%; border-width: 5px; border-color: white; border-style:solid; border-left-width:15px; background-color: " + config.connectorcolour + "; width: 1px; text-align: center;\" rel=\"" +connectorPosition+"\"  title=\"" + labelArray[i] + "\"></div>"
          }
          
          // label
          if (lastLabel != labelArray[i]) {
            output += "<a class=\"" + config.classmodifier + "link\" style=\"text-decoration:none;\" href=\"" + linkArray[i] + "\">"
            output += "<div class=\"" + config.classmodifier + "bar " + config.classmodifier + (isPositive?'pos':'neg') + "\" style=\"position: absolute; bottom: 0%; left: " + leftShim + "%; display: block; height: 0%; border-width: 5px; border-color: white; border-style:solid; border-left-width:15px; background-color: transparent; width: auto; text-align: center;\" rel=\"auto\" title=\"" + labelArray[i] + "\">" + displayLabel + "</div>"
            output += "</a>"
          }
          
          
          //output += "</a>"
          
           
          leftShim = leftShim + shimAdjustment;
				  lastLabel = labelArray[i];
        }

        				
        
				if (isPositive) {
					runningTotal = runningTotal + barHeight;
				} else {
					runningTotal = runningTotal - barHeight;
				}
				
				//if (i == 0) zero_pos = connectorPosition;
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
      var otherArray = new Array();
      var combinedArray = new Array();
      var linkArray = new Array();
      var valueLinkArray = new Array();
      var otherLinkArray = new Array();
      var combinedLinkArray = new Array();
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
				var otherString = $(values[i]).children("td").eq(config.othercolumn).text();
        var combinedString = $(values[i]).children("td").eq(config.combinedcolumn).text();

        var valueAmount = 0
        var otherAmount = 0 
        var combinedAmount = 0 
        
				if (valueString.length > 0) {
					valueAmount = parseFloat(valueString, 10);
				}
				
				if (otherString.length > 0) {
					otherAmount = parseFloat(otherString, 10);
				}
				
				if (combinedString.length > 0) {
					combinedAmount = parseFloat(combinedString, 10);
				}
				
        if (valueAmount != 0 || otherAmount !=0 || i == (values.length - 1) /* include net, even if 0 */ ) {
          
          valueArray[valueArray.length] = valueAmount;
          otherArray[otherArray.length] = otherAmount;
          combinedArray[combinedArray.length] = combinedAmount;
          
          labelArray[labelArray.length] = $(values[i]).children("td").eq(config.labelcolumn).html();
          labelTextArray[labelTextArray.length] = $(values[i]).children("td").eq(config.labelcolumn).text();
          linkArray[linkArray.length] = $(values[i]).children("td").eq(config.linkcolumn).text();
          valueLinkArray[valueLinkArray.length] = $(values[i]).children("td").eq(config.valuelinkcolumn).text();
          otherLinkArray[otherLinkArray.length] = $(values[i]).children("td").eq(config.otherlinkcolumn).text();
          combinedLinkArray[combinedLinkArray.length] = $(values[i]).children("td").eq(config.combinedlinkcolumn).text();
          
          totalValue = totalValue + valueAmount;
          
          if (i != (values.length - 1)) { // don't include net in running totals
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
							output += GetWaterfallOutput(labelArray, valueArray, linkArray, valueLinkArray, otherLinkArray, combinedLinkArray, totalValue, smallestValue, largestValue, labelTextArray, otherArray, combinedArray);
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
