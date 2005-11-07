
def quicknav_script(output_dir)
  name = "quicknav.js"

  # avoid overwriting a (possibly modified) existing stylesheet
  return if FileTest.exist?(File.join(output_dir, name))

  write_file(output_dir, name) do |out|
    out.print <<-HERE
function attachQuicknav() {
	var main_nav = document.getElementById("main_nav");
	var li = document.createElement("li");
	var span = document.createElement("span");
	li.className = "quicknav";
	main_nav.insertBefore(li, main_nav.firstChild);
	li.appendChild(span);
	// setup quicknav input box,
	var label = document.createElement("label");
	label.setAttribute("for", "quicknav_input");
	label.appendChild(document.createTextNode("Quicknav "));
	span.appendChild(label);
	var input = document.createElement("input");
	input.id = "quicknav_input"
	input.setAttribute("autocomplete", "off");
	input.setAttribute("onfocus", "quicknavFocus();");
	input.setAttribute("onkeyup", "quicknavKeyup();");
	input.setAttribute("onblur", "quicknavBlur();");
	span.appendChild(input);
	var menu = document.createElement("ul");
	menu.id = "quicknav_menu";
	menu.style.visibility = "hidden";
	menu.appendChild(document.createTextNode("Loading..."));
	
	span.appendChild(menu);
	// setup frame to load search data,
	var dataFrame = document.createElement("iframe");
	dataFrame.style.width = "0";
	dataFrame.style.height = "0";
	dataFrame.style.visibility = "hidden";
	dataFrame.src = adjustHref("quicknav.html");
	dataFrame.id = "data_frame"
	span.appendChild(dataFrame);
}

function quicknavFocus() {
	showQuicknavMenu();
	quicknavSearch();
}

function quicknavKeyup() {
	quicknavSearch();
}
function quicknavSearch() {
 	var input = document.getElementById("quicknav_input");
	var dataFrame = document.getElementById("data_frame");
	var search = input.value.toLowerCase();
	var items = dataFrame.contentDocument.getElementsByTagName("li");
	var menu = document.getElementById("quicknav_menu");
	clearQuicknavMenu(menu);
	var count = 0;
	for (var i=0; i < items.length; i++) {
		var item = items[i];
		var match = item.firstChild.text;
		if (match.substr(0, search.length).toLowerCase() == search) {
			var clone = item.cloneNode(true);
			var href = clone.firstChild.getAttribute("href");
			href = adjustHref(href);
			clone.firstChild.setAttribute("href", href);
			menu.appendChild(clone);
			count++;
		}
		if (count >= 8) {
			break;
		}
	}
}

function adjustHref(href) {
	return document.quicknavBasePath + "/" + href;
}

function clearQuicknavMenu(menu) {
	for (var i = menu.childNodes.length -1; i >= 0 ; i--) {
		menu.removeChild(menu.childNodes[i]);
	}
}

function quicknavBlur() {
	// give the user a chance to click on one of the menu items,
	setTimeout("hideQuicknavMenu()", 200);
}

function showQuicknavMenu() {
 	var input = document.getElementById("quicknav_input");
	var menu = document.getElementById("quicknav_menu");
	menu.style.left = getElementX(input) + "px";
	menu.style.top = getElementY(input) + input.offsetHeight + 2 + "px";
	var width = getWidth(input);
	if (width > 0) {
		menu.style.width = width + "px";
	}
	menu.style.visibility = "visible";
}

function hideQuicknavMenu() {
	var menu = document.getElementById("quicknav_menu");
	menu.style.visibility = "hidden";
}

function getElementX(element){
    var targetLeft = 0;
    while (element) {
        if (element.offsetParent) {
            targetLeft += element.offsetLeft;
        } else if (element.x) {
            targetLeft += element.x;
        }
        element = element.offsetParent;
    }
    return targetLeft;
}


function getElementY(element){
    var targetTop = 0;
    while (element) {
        if (element.offsetParent) {
            targetTop += element.offsetTop;
        } else if (element.y) {
            targetTop += element.y;
        }
        element = element.offsetParent;
    }
    return targetTop;
}

function getWidth(element) {
    if (element.clientWidth && element.offsetWidth && element.clientWidth <element.offsetWidth) {
        return element.clientWidth; /* some mozillas (like 1.4.1) return bogus clientWidth so ensure it's in range */
    } else if (element.offsetWidth) {
        return element.offsetWidth;
    } else if (element.width) {
        return element.width;
    } else {
        return 0;
    }
}

window.onload = attachQuicknav;
    HERE
  end
end
