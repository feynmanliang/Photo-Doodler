function Doodle(id, userId, photoId, dataPoints){
	this.id = id;
	this.userId = userId;
	this.photoId = photoId;
	this.dataPoints = dataPoints;

	
	this.send = function (){
		$("#sendjson").html(JSON.stringify(this));
	}
}