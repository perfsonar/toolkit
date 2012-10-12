/**
 * File: maddash.js
 * Description: This file contains bases classes for MaDDash framework.
 *
 * Authors: Andy Lake <andy@es.net>
 */


/**
 * Class: MaDDashDataSource
 * Description: Connects MadDash widgets to backen data. Created
 *   with a URI that specifies the location of some REST data. You then
 *   call the "connect" function which is given a Javascript object. That 
 *   Javascript MUST implement a render function. When MaDDashDataSource.render()
 *   is called it will asynchronously retrieve the data and call each connected objects
 *   render(data, uri) function.
 * Parameters:
 *   url: the URL to the rest data that will be rendered by connected objects
 *   aysnc: optional boolean indicating if the render call should be asynchronous. Defaults to true.
 */
var MaDDashDataSource = function(url, async){
	var instance = this;
	this.xhr = null;
	this.url = url;
	this.data = null;
	this.callbacks = new Array();
	this.async = (async == null ? true : async);
	
	this.setURL = function(url){
		this.url = url;
	}
	
	this.render = function() {
		this._initXhr();
		this.xhr.open("GET", this.url, this.async);
		this.xhr.send();
	}
	
	this.connect = function(obj){
		this.callbacks.push(obj);
	}
	/**
	 * Private methods
	 */
	this._initXhr = function() {
		//return if xhr already inited
		if(this.xhr != null){
			return;
		}
		
		if (window.XMLHttpRequest){
			// code for IE7+, Firefox, Chrome, Opera, Safari
  			this.xhr=new XMLHttpRequest();
	  	}else{
			// code for IE6, IE5
	  		this.xhr=new ActiveXObject("Microsoft.XMLHTTP");
	  	}
		
		//set response handler
		this.xhr.onreadystatechange = this._xhrResponseHandler;
	}
	
	this._xhrResponseHandler = function(){
		if(instance.xhr.readyState == 4 && instance.xhr.status==200){
			this.data = eval('(' + instance.xhr.responseText + ')');
			for(i=0; i < instance.callbacks.length; i++){
				instance.callbacks[i].render(this.data, instance.url);
			}
		}	
	}
	
}

/**
 * Class: MaDDashGrid
 * Description: Widget that displays grid of checks. Uses
 *   d3 and jQuery to draw the grid.
 * Parameters:
 *      parentId: id string of the container element
 *      legendId: id string of the legend element
 */

var MaDDashGrid =function(parentId, legendId){
    var instance = this;
    var colorscale = d3.scale.category10().range(["green", "yellow", "red", "orange", "gray"]);
    this.parent = parentId;
    this.legend = legendId;
    this.cellSize = 13;
    this.cellPadding = 2;
    this.textBlockSize = 130;
      
    this.render = function (data){
        //TODO: Set title
        //d3.select("#dashboard_name").html(dashboard.name + " Dashboard");
        d3.select("#" + this.parent).html("");
        this.displaygrid(data, this.parent);
    }
      
      
    this.displaygrid = function (data, canvas){
      //Display legends
      colorscale.domain(d3.range(0,data.statusLabels.length));
      var legendsdata = data.statusLabels
      .map(function(d,i){ return {label:d, color:colorscale(i)} })
      //.filter(function(d,i){return d.label === null ? false : true})
      d3.select("#"+this.legend).html("")
      var legends = d3.select("#"+this.legend)
        .selectAll(".legend")
          .data(legendsdata)
          .enter()
            .append("div").attr("class", "legend");
      legends.append("div")
        .attr("class", "lsymbol")
        .style("background", function(d,i){return d.color})
        .style("display", function(d,i){return d.label === null ? "none" : "block"})
      legends.append("div")
        .attr("class", "ltext")
        .text(function(d,i){return d.label})
        .style("display", function(d,i){return d.label === null ? "none" : "block"})

      //GRID Container
      var nrows = data.grid.length;
      var ncols = data.grid[0].length;
      
      //Changed these from portal to allow customization
      var cellsize = this.cellSize;
      var padding = this.cellPadding;
      var text_block_size = this.textBlockSize;
    
      var viz = d3.select("#" + canvas)
        .style("width", ncols * (cellsize + 2*padding) + 110 + text_block_size)
    
      var top = viz.append("div")
        .attr("class", "gtop")
        .style("margin-left", text_block_size + "px")
        .style("float", "left")
        .append("svg:svg")
          .attr("height", text_block_size)
          .attr("width", ncols * (cellsize + 2*padding) + 90)
        .selectAll(".rname")
          .data(data.columnNames)
          .enter()
            .append("g")
            .attr("class", function(d,i){return "gcol" + i})
            .attr("transform", function(d,i){return "translate("+(i*(cellsize+2*padding))+",0)"})        
    
      top.append("svg:rect")
        .attr("class", function(d,i){return "gcol" + i})
        .attr("x",0).attr("y",0)
        .attr("transform", "rotate(45,0,"+ text_block_size +") translate (-0.5,3)")
        .attr("height",text_block_size).attr("width",(cellsize+padding))
        //.attr("transform", "rotate(35,"+ (cellsize+padding)/2  + "," + text_block_size/2 + ")")
      
      
      top.append("svg:text")
        .attr("class", "gtext")
        .attr("text-anchor", "start")
        .attr("dy", "1.5em")
        .attr("dx", "1em")
        .attr("transform", "rotate(-45,0,"+ text_block_size +")  translate(0,"+ (text_block_size-5) + ")")
        .text(function(d,i){return d})        
    
      var left = viz.append("div")
        .attr("class", "gleft")
        .append("svg:svg")
          .attr("width", text_block_size)
          .attr("height", nrows * (cellsize + 2*padding))
        .selectAll(".rname")
          .data(data.rows)
          .enter()
            .append("g")
            .attr("class", function(d,i){return "grow" + i})
            .attr("transform", function(d,i){return "translate(0,"+(i*(cellsize+2*padding))+")"})

      left.append("svg:rect")
        .attr("class", function(d,i){return "grow" + i})
        .attr("x",0).attr("y",0)
        .attr("width",text_block_size).attr("height",(cellsize+2*padding))
      
      left.append("svg:text")
        .attr("class", "gtext")
        .attr("transform", "translate("+ (text_block_size-5) +",0)")
        .text(function(d,i){return data.rows[i].name})
        .attr("text-anchor", "end")
        .attr("dy", "1.1em")


      var grid = viz.append("div")
        .attr("class", "ggrid")
    
      var cols = grid.selectAll(".gcol")
        .data(data.columnNames)
        .enter()
          .append("div")
          .attr("class", function(d,i){return "gcol gcol" + i})
          .style("width", (cellsize+2*padding) + "px")
          .style("height", "100%")
          .style("left", function(d,i){return (i*(cellsize+2*padding)) + "px"})
    
      var rows = grid.selectAll(".grow")
        .data(data.grid)
        .enter()
          .append("div")
          .attr("class", function(d,i){return "grow grow" + i})
          .style("width", "100%")
          .style("z-index", 1000)
    
      var color = "";
      var selected_row = 0;
      var selected_col = 0;
      var cells = rows.selectAll(".gcell")
        .data(function(d,r){ return d.map(function(d,i){ return {celldata:d, row:r}}) })
        .enter()
          .append("div")
          .attr("class", "gcell")
          .style("height", cellsize +"px")
          .style("width", cellsize +"px")
          .style("margin", (padding) +"px")
          
          .on("mouseover", function(d,i){
            selected_row = d.row;
            selected_col = i;
            if(d.celldata){
              d3.select(this).style("margin", (padding-1) +"px");
              d3.select(this).classed("shadow", true);
            }
            viz.selectAll(".gcol"+ i).classed("gactive", true);
            viz.selectAll(".grow"+ d.row).classed("gactive", true);
          })
          .on("mouseout", function(d,i){
            // d3.select(this).classed("shadow", false);
            // d3.select(this).style("background-color", color.brighter());
            d3.select(this).style("margin", (padding) +"px");
            d3.select(this).classed("shadow", false);
            viz.selectAll(".gcol"+ i).classed("gactive", false);
            viz.selectAll(".grow"+ d.row).classed("gactive", false);
          })
         /* 
           //DELETE FROM PORTAL
           .on("click", function(d,i){
            var that = this;
            if(d.celldata!=null){
              var href = "details.cgi?uri=" + d.celldata[0].uri;
              window.open( href, "Graph");
            }
          }) */
      
      $("#"+canvas).find(".gcell").each(function(i,d){
        var data = d3.select(this).data()[0];
        if(data.celldata!=null){
          var html = "<div class='tooltip'><div class='top-tip'>" + (data.celldata[0]? data.celldata[0].message : "") + "</div><div class='bottom-tip'>" + (data.celldata[1]? data.celldata[1].message : "") + "</div></div>";
          $(this).tipsy({
            html :true,
            opacity: 0.9,
            title : function(){
            return html
          }})
        }
      })
      
      var temp = cells.selectAll(".gsubcell")
        .data(function(d,i){return d.celldata===null? [] : d.celldata })
        .enter()
          .append("div");
      temp
        .style("height", cellsize/2 +"px")              
        .style("background", function(d,i){
          return colorscale(parseInt(d.status));
        })
        .on("click", function(d,i){ //CHANGE FROM PORTAL
            var that = this;
            if(d!=null && d.uri!=null && instance.handleClick != null){
              instance.handleClick(d);
            }
          })
  }
  
  /****************************
     Customization functions 
  ****************************/
    /* Default handler. Can be overridden with setClickHandler */
    this.handleClick = function(d){
        var uri = d.uri;
        $.getJSON(uri, function(data) {
                var href = data['history'][0].returnParams.graphUrl.replace("https", "http");
                 window.open( href, "Graph", "menubar=0,location=0,height=700,width=700" );
         })
        
    }
    this.setClickHandler = function(f){
        this.handleClick = f;
    }
    this.setCellSize = function(value){
        this.cellSize = value;
    }
    this.setCellPadding = function(value){
        this.cellPadding = value;
    }
    this.setTextBlockSize = function(value){
        this.textBlockSize = value;
    }
    
}
