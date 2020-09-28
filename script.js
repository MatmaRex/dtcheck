Array.from(document.getElementsByClassName('diffbutton')).forEach(function(button){
	button.onclick = function(){
		var diffrow = this.parentNode.parentNode.nextElementSibling;
		diffrow.style.display = diffrow.style.display ? '' : 'none';
	}
});
Array.from(document.getElementsByClassName('diffbuttonall')).forEach(function(button){
	button.onclick = function(){
		var rows = document.querySelectorAll('.difftable > tbody > tr:not(:first-child)');
		this.diffstate = !this.diffstate;
		Array.from(rows).forEach(function(row, i){
			if(i % 2 !== 0) {
				row.style.display = button.diffstate ? '' : 'none';
			}
		})
	}
});
