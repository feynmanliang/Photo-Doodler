function Doodle(dataPoints){
	this.data = dataPoints;

	this.send = function (){
		$("#sendjson").html(JSON.stringify(this));
		var photoId = $("#photoid").html();
		var postAddress = photoId + "/save";
		$.ajax({
			type: "POST",
			url: postAddress
		}).done(function( msg ) {
			console.log(msg);
		});		
	}
}