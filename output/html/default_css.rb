
def stylesheet(output_dir)
  name = "style.css"

  # avoid overwriting a (possibly modified) existing stylesheet
  return if FileTest.exist?(File.join(output_dir, name))

  write_file(output_dir, name) do |out|
    out.print <<-HERE
.quicknav span.ui {
	float: right;
}

#quicknav_menu {
	list-style-type: none;
	border: 1px solid black;
	position: absolute;
	font-size: normal;
	padding: 0;
	background-color: white;
	overflow: hidden;
}
.quicknav label {
	font-size: smaller;
	font-weight: normal;
	font-family: sans-serif;
}
#quicknav_input {
	color: black;
}
#quicknav_menu li {
	display: block;
	font-size: smaller;
	font-weight: normal;
	font-family: sans-serif;
	white-space: nowrap;
	padding: 0.1em 0;
	margin: 0;
	color: black;
}

h2 {
	background-color: #ccccff;
	padding-left: .2em;
	padding-right: .2em;
	border: 2px ridge gray;
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
	border-bottom: 2px ridge #888888;
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
	padding: .2em .4em;
	border-top: .5em solid white;
}
.main_nav li {
	font-family: Arial, sans-serif;
	font-weight: bolder;
	display: inline;
}
.main_nav li .button {
	padding: 0 7px;
	height: 1em;  /* hack to get padding working in IE */
}
.nav_current {
	background-color: #00008B;
	color: #FFFFFF;
}

table.summary_list {
	border-collapse: collapse;
	width: 100%;
	margin-left: 1px;
	margin-right: 1px;
	margin-bottom: 1em;
}
table.summary_list td, table.summary_list caption {
	border: 2px ridge gray;
	padding: .2em;
	text-align: left;
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

.type_hierachy li {
	list-style: none;
}
.type_hierachy li li:before {
	content: "\\2514  ";
}


/* Source highlighting rules */

.lineno {
  color: gray;
  background-color:lightgray;
  border-right: 1px solid gray;
  margin-right: .5em;
}
.comment { color: green; }
.comment.doc { color: #4466ff; }
.str_const, .num_const { color: blue; }
.key { font-weight: bolder; color: purple; }
    HERE
  end
end

def alternate_stylesheet(output_dir)
  name = "unnatural.css"

  # avoid overwriting a (possibly modified) existing stylesheet
  return if FileTest.exist?(File.join(output_dir, name))

  write_file(output_dir, name) do |out|
    out.print <<-HERE
/* apologies to the authors of NaturalDocs */
.quicknav span.ui {
	float: right;
}

#quicknav_menu {
	list-style-type: none;
	border: 1px solid black;
	position: absolute;
	font-size: normal;
	padding: 0;
	background-color: white;
	overflow: hidden;
}
.quicknav label {
	font-size: smaller;
	font-weight: normal;
	font-family: sans-serif;
}
.quicknav #quicknav_input {
	color: black;
}
.quicknav #quicknav_menu li {
	display: block;
	font-size: smaller;
	font-weight: normal;
	font-family: sans-serif;
	white-space: nowrap;
	padding: 0.1em 0;
	margin: 0;
	color: black;
}
.quicknav #quicknav_menu a {
	color: blue;
}

body {
	font-family: sans-serif;
}

h1, h2, caption {
	font-family: Georgia,serif;
	font-weight: normal;
}

h2, table.summary_list caption {
	border-bottom: 2px solid black;
	font-variant: small-caps;
	text-align: left;
	margin-bottom: 0.5em;
}

.type_indexes {
	background-color: #FFFFF0;
	padding: 1em;
	border: 1px solid #C0C060;
	margin-left: 2em;
	margin-right: 2em;
	-moz-border-radius: 20px;
}

.type_indexes h2 {
	border-bottom: none;
	font-variant: normal;
	font-size: inherit;
	font-family: sans-serif;
	font-weight: bolder;
}
.type_indexes h4 {
	font-variant: small-caps;
}

h3 {
	border-bottom: 1px solid #C0C0C0;
}

h4 {
	margin: 0;
}

p {
	text-indent: 5ex;
}

.extra_info {
	margin: 0;
}

.method_details, .field_details {
	padding-bottom: .5em;
}


.method_synopsis, .field_synopsis {
	padding: 5px 3ex;
}
.method_synopsis {
	border: 1px solid #F4F4F4;
	border-color: #D0D0D0
}
.field_synopsis {
	background-color: #F4F4FF;
	border: 1px solid #C0C0E8;
}
.field_info, .method_info {
	margin-top: .5em;
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

body {
	padding-top: 2em;
}

.main_nav {
	position: fixed;
	top: 0;
	left: 0;
	background-color: #4A4AC0;
	padding: 4px;
	display: block;
	width: 100%;
	margin: 0;
	padding-top: .5em;
	padding-bottom: .5em;
	border-bottom: 3px solid black;
}
.main_nav li {
	font-family: sans-serif;
	font-weight: bolder;
	display: inline;
}
.main_nav li .button {
	padding: 4px;
	color: #FFFFFF;
	height: 1em;  /* hack to get padding working in IE */
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
table.summary_list td
	padding: .2em;
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

.type_hierachy li {
	list-style: none;
}
.type_hierachy li li:before {
	content: "\\2514  ";
}


/* Source highlighting rules */

.lineno {
  color: gray;
  background-color:lightgray;
  border-right: 1px solid gray;
  margin-right: .5em;
}
.comment { color: green; }
.comment.doc { color: #4466ff; }
.str_const, .num_const { color: blue; }
.key { font-weight: bolder; color: purple; }
    HERE
  end
end



# vim:softtabstop=2:shiftwidth=2
