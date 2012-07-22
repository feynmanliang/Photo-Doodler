

var drawingApp = (function () {

	"use strict";

	var canvas,
		context,
		canvasWidth,
		canvasHeight,
		colorPurple = "#cb3594",
		colorGreen = "#659b41",
		colorYellow = "#ffcf33",
		colorBrown = "#986928",
		backgroundImage = new Image(),
		
		drawingPoints = [],
		drawUpTo = 0,
		existingPoints = [],

		paint = false,
		curColor = "#cb3594",
		curTool = "crayon",
		curSize = "normal",
		drawingAreaX = 0,
		drawingAreaY = 0,
		drawingAreaWidth,
		drawingAreaHeight,

		totalLoadResources = 1,
		curLoadResNum = 0,

		// Clears the canvas.
		clearCanvas = function () {
			context.clearRect(0, 0, canvasWidth, canvasHeight);
		},

		// Redraws the canvas.
		drawPoints = function (points, startPoint) {
			if(points==null){return;}

			var locX,
				locY,
				radius,
				i,
				selected;

			// Make sure required resources are loaded before redrawing
			if (curLoadResNum < totalLoadResources) {
				return;
			}

			//clearCanvas();

			// Keep the drawing in the drawing area
			context.save();
			context.beginPath();
			context.rect(drawingAreaX, drawingAreaY, drawingAreaWidth, drawingAreaHeight);
			context.clip();
			
			// For each point drawn
			var i;
			for (i = startPoint; i < points.length; i += 1) {

				// Set the drawing radius
				switch (points[i].size) {
				case "small":
					radius = 2;
					break;
				case "normal":
					radius = 5;
					break;
				case "large":
					radius = 10;
					break;
				case "huge":
					radius = 20;
					break;
				default:
					break;
				}
				

				// If dragging then draw a line between the two points
				if (points[i].drag && i) {
					context.moveTo(points[i - 1].x, points[i - 1].y);
				} else {
					// The x position is moved over one pixel so a circle even if not dragging
					context.moveTo(points[i].x - 1, points[i].y);
				}
				context.lineTo(points[i].x, points[i].y);
				
				// Set the drawing color
				if (points[i].tool === "eraser") {
					//context.globalCompositeOperation = "destination-out"; // To erase instead of draw over with white
					context.strokeStyle = 'white';
				} else {
					//context.globalCompositeOperation = "source-over";	// To erase instead of draw over with white
					context.strokeStyle = points[i].color;
					console.log(points[i].color);
				}
				context.lineCap = "round";
				context.lineJoin = "round";
				context.lineWidth = radius;
				context.stroke();
			}
			drawUpTo = i;
			context.closePath();
			//context.globalCompositeOperation = "source-over";// To erase instead of draw over with white
			context.restore();
		},

		// Adds a point to the drawing array.
		// @param x
		// @param y
		// @param dragging
		addClick = function (x, y, dragging) {
			//console.log(curColor);
			var p = new Point(x, y, curColor, curSize, dragging);
			drawingPoints.push(p);
		},

		// Add mouse and touch event listeners to the canvas
		createUserEvents = function () {

			var press = function (e) {
				// Mouse down location
				var sizeHotspotStartX,
					mouseX = e.pageX - this.offsetLeft,
					mouseY = e.pageY - this.offsetTop;

				paint = true;
				addClick(mouseX, mouseY, false);
				drawPoints(drawingPoints,drawUpTo);
			},

				drag = function (e) {
					if (paint) {
						addClick(e.pageX - this.offsetLeft, e.pageY - this.offsetTop, true);
						drawPoints(drawingPoints,drawUpTo);
					}
					// Prevent the whole page from dragging if on mobile
					e.preventDefault();
				},

				release = function () {
					paint = false;
					drawPoints(drawingPoints,drawUpTo);
				},

				cancel = function () {
					paint = false;
				};

			// Add mouse event listeners to canvas element
			canvas.addEventListener("mousedown", press, false);
			canvas.addEventListener("mousemove", drag, false);
			canvas.addEventListener("mouseup", release);
			canvas.addEventListener("mouseout", cancel, false);

			// Add touch event listeners to canvas element
			canvas.addEventListener("touchstart", press, false);
			canvas.addEventListener("touchmove", drag, false);
			canvas.addEventListener("touchend", release, false);
			canvas.addEventListener("touchcancel", cancel, false);
		},

		// Calls the drawPoints function after all neccessary resources are loaded.
		resourceLoaded = function (existingDoodle) {
			curLoadResNum += 1;
			if (curLoadResNum === totalLoadResources) {
				initialImage(existingDoodle);
				createUserEvents();
			}
		},

		initialImage = function (existingDoodle, doodlesToBeShownArray) {
			//add background image
			context.drawImage(backgroundImage, drawingAreaX, drawingAreaY, drawingAreaWidth, drawingAreaHeight);
			
			//add existing doodles
			if(existingDoodle.length > 0){
				for(var i=1;i<existingDoodle.length; i++){
					if(doodlesToBeShownArray == undefined)
						drawPoints(eval(existingDoodle[i].data), 0);
					else{
						if($.inArray(i.toString(), doodlesToBeShownArray) != -1)
							drawPoints(eval(existingDoodle[i].data), 0);
					}
				}
			}
			drawPoints(drawingPoints,0);
		},
				
		// Creates a canvas element, loads images, adds events, and draws the canvas for the first time.
		init = function (existingDoodle) {
			backgroundImage.src = existingDoodle[0].photo_url;
			backgroundImage.onload = function () {
				canvasWidth = backgroundImage.width;
				canvasHeight = backgroundImage.height;
				drawingAreaWidth = canvasWidth-2;
				drawingAreaHeight = canvasHeight-2;
				// Create the canvas (Neccessary for IE because it doesn't know what a canvas element is)
				canvas = document.createElement('canvas');
				canvas.setAttribute('width', canvasWidth);
				canvas.setAttribute('height', canvasHeight);
				canvas.setAttribute('id', 'canvas');
				document.getElementById('canvasDiv').appendChild(canvas);
				if (typeof G_vmlCanvasManager !== "undefined") {
					canvas = G_vmlCanvasManager.initElement(canvas);
				}
				context = canvas.getContext("2d"); // Grab the 2d canvas context
				resourceLoaded(existingDoodle)
			};
		},
		
		save = function (){
			if(drawingPoints.length == 0){
				$("#sendjson").html("DRAW FIRST");
			}
			else{
				var dataPoints = $.toJSON(drawingPoints);
				
				var doodleToSave = new Doodle(dataPoints);
				doodleToSave.send();
			}

		};


	return {
		init: init,
		save: save,
		initialImage: initialImage
	};
}());