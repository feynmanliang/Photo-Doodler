function Doodle(dataPoints){
	this.data = dataPoints;

	this.send = function (){
		$("#sendjson").html(JSON.stringify(this));
		var photoId = ($("#photoid").html()).toString();


		var postAddress = photoId + "/save";
		$.ajax({
			type: "POST",
			url: postAddress,
			data: { data: this.data.toString() }
		}).done(function( msg ) {
			console.log(msg);
		});		
	}
}