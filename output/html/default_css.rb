
def stylesheet(output_dir)
  name = "style.css"

  # avoid overwriting a (possibly modified) existing stylesheet
  return if FileTest.exist?(File.join(output_dir, name))

  write_file(output_dir, name) do |out|
    out.print <<-HERE
h1, h2, h3, h4, caption {
	font-family: sans-serif;
}

h2 {
	background-color: #ccccff;
	padding-left: .2em;
	padding-right: .2em;
	-moz-border-radius: .2em;
}

h4 {
	margin: 0;
}

.extra_info {
	padding-left: 2em;
	margin: 0;
}

.method_details, .field_details {
	padding-bottom: .5em;
}

.method_info, .field_info {
	padding-left: 3em;
}

p.inherited_docs {
	margin-bottom: 0;
	font-weight: bolder;
	-moz-opacity: 0.5;
	font-size: smaller;
}
p.inherited_docs+p {
	margin-top: 0;
}

.alt_row {
	background-color: #eeeeee;
}

body {
	/* make some space for the navigation */
	padding-top: 2em;
}
.main_nav {
	background-color: #EEEEFF;
	position: fixed;
	top: 0;
	left: 0;
	display: block;
	width: 100%;
	margin: 0;
	padding: .5em;
	border-top: .5em solid white;
}
.main_nav li {
	font-family: sans-serif;
	font-weight: bolder;
	display: inline;
}
.main_nav li * {
	padding: 4px;
}
.nav_current {
	background-color: #00008B;
	color: #FFFFFF;
}

table.summary_list {
	border-collapse: collapse;
	width: 100%;
	margin-bottom: 1em;
}
table.summary_list td, table.summary_list caption {
	border: 2px solid grey;
	padding: .2em;
}
table.summary_list caption {
	background-color: #CCCCFF;
	border-bottom: 0;
	font-size: larger;
	font-weight: bolder;
}
ul.navigation_list {
	padding-left: 0;
}
ul.navigation_list li {
	margin: 0 0 .4em 0;
	list-style: none;
}

table.exceptions td, table.arguments td {
	vertical-align: text-top;
	padding: 0 1em .5em 0;
}

/*
.unresolved_type_name {
	background-color: red;
	color: white;
}
*/

.interface_name {
	font-style: italic;
}

.footer {
	text-align: center;
	font-size: smaller;
}
/*
.read_write_only {
}
*/
.diagram {
	text-align: center;
}


/* Source highlighting rules */

.lineno {
  color: gray;
  background-color:lightgray;
  border-right: 1px solid gray;
  margin-right: .5em;
}
.comment { color: green; }
.comment.doc { color: 4466ff; }
.str_const, .num_const { color: blue; }
.key { font-weight: bolder; color: purple; }
    HERE
  end
end


# vim:softtabstop=2:shiftwidth=2
