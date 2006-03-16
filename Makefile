
xsltproc=xsltproc
#docbook_home=/usr/share/sgml/docbook/stylesheet/xsl/nwalsh
docbook_home=/home/dave/incoming/docbook-xsl-1.69.1
docbook_fo_stylesheet=${docbook_home}/fo/docbook.xsl
docbook_man_stylesheet=${docbook_home}/manpages/docbook.xsl
docbook_html_stylesheet=${docbook_home}/html/docbook.xsl
java_home=~/opt/j2sdk1.4.2_05
fop=~/incoming/fop-0.20.5/fop.sh
as2api=ruby -w as2api.rb
ruby_mswin32=/cygdrive/c/ruby/bin/ruby
rubyscript2exe=${ruby_mswin32} -w ../rubyscript2exe.rb
stuff=~/incoming/stuffit520.611linux-i386/bin/stuff

sources = documenter.rb doc_comment.rb output/utils.rb \
	  output/html/core_pages.rb output/html/default_frameset.rb \
	  output/html/driver.rb output/html/index.rb output/html/quicknav.rb \
	  output/html/default_css.rb output/html/diff.rb \
	  output/html/html_framework.rb \
	  output/html/sources.rb output/xml/xml_formatter.rb output/utils.rb \
          xmlwriter.rb xhtmlwriter.rb \
          parse/lexer.rb parse/parser.rb parse/as_io.rb parse/aslexer.rb \
	  parse/doccomment_lexer.rb parse/doccomment_parser.rb \
	  api_loader.rb api_model.rb \
          as2api.rb ui/cli.rb
doc_pdf=as2api-documentation.pdf
dist_files = ${sources} ${doc_pdf} as2api.1 COPYING
mx_classes=examples/flash_mx_2004_7.2/Classes

version = 0.4

dist_dir = as2api-${version}
tgz_name = ${dist_dir}.tar.gz
w32_dist_dir = as2api-allinone-w32-${version}
zip_name = ${w32_dist_dir}.zip
osx_dist_dir = as2api-allinone-osx-${version}
sit_name = ${osx_dist_dir}.sit

dist: tgz zip sit

web-dist: tgz zip sit
	mkdir -p projects/as2api/releases
	#cp ${tgz_name} ${zip_name} ${sit_name} projects/as2api/releases
	cp ${tgz_name} projects/as2api/releases
	mkdir -p projects/as2api/examples
	${as2api} --classpath ${mx_classes}:examples/as2lib_0.9/src \
	          --output projects/as2api/examples/as2lib-0.9 \
		  --draw-diagrams \
		  --title "as2lib 0.9" \
		  main.* org.as2lib.*
	${as2api} --classpath ${mx_classes}:examples/enflash-0.3/src/classes \
	          --output projects/as2api/examples/enflash-0.3 \
		  --draw-diagrams \
		  --title "enflash 0.3" \
		  com.asual.*
	${as2api} --classpath ${mx_classes}:examples/Oregano_client-1.2.0beta3/\
	          --output projects/as2api/examples/oregano_1.2.0beta3/ \
		  --draw-diagrams \
		  --encoding utf-8 \
		  --title "Oregano Client 1.2.0 beta3" \
		  org.omus.*
	cd projects/as2api && xsltproc ../../../www/project_page.xsl ../../project.xml > index.html
	cp ../www/bif.css projects/as2api

tgz: docs
	mkdir -p ${dist_dir}
	cp --parents ${dist_files} as2api-documentation.xml ${dist_dir}
	tar czvf ${tgz_name} ${dist_dir}
	rm -r ${dist_dir}

as2api.exe: ${sources}
	${rubyscript2exe} as2api.rb

zip: docs
	mkdir -p ${w32_dist_dir}
	cp as2api.exe ${doc_pdf} ${w32_dist_dir}
	zip -r ${zip_name} ${w32_dist_dir}
	rm -r ${w32_dist_dir}

sit: ${sit_name}

${sit_name}: docs as2api-0.4_darwin
	mkdir -p ${osx_dist_dir}
	cp as2api-0.4_darwin ${osx_dist_dir}/as2api
	cp ${doc_pdf} as2api.1 ${osx_dist_dir}
	${stuff} --name=${sit_name} ${osx_dist_dir}

test:
	ruby -w ts.rb

clean:
	rm -rf ${tgz_name} ${zip_name} ${sit_name} ${w32_dist_dir} ${dist_dir}


docs: ${doc_pdf} as2api.1


as2api-documentation.fo: as2api-documentation.xml
	${xsltproc} --stringparam shade.verbatim 1 \
	            --stringparam fop.extensions 1 \
		    ${docbook_fo_stylesheet} \
		    as2api-documentation.xml \
				> as2api-documentation.fo

${doc_pdf}: as2api-documentation.fo
	JAVA_HOME=${java_home} \
	${fop} as2api-documentation.fo -pdf ${doc_pdf}

as2api.1: as2api-documentation.xml
	${xsltproc} ${docbook_man_stylesheet} as2api-documentation.xml

as2api-documentation.html: as2api-documentation.xml
	${xsltproc} --output as2api-documentation.html \
	            --stringparam html.stylesheet ../www/bif.css \
	            bif_docbook_html.xsl as2api-documentation.xml

# noddy check that running with --help option doesn't complain of missing
# required files,
dist-check: tgz
	rm -rf dist-check-tmp
	mkdir dist-check-tmp
	cd dist-check-tmp && \
	tar xzf ../${tgz_name} && \
	cd ${dist_dir} && \
	ruby -w as2api.rb --help > /dev/null
	rm -r dist-check-tmp

translations: data/locale/en/LC_MESSAGES/as2api.mo data/locale/i_piglatin/LC_MESSAGES/as2api.mo data/locale/pl/LC_MESSAGES/as2api.mo
	

po/as2api.pot:
	mkdir -p po
	rgettext `find -name "*.rb"` -o $@

po/en/as2api.po: po/as2api.pot
	mkdir -p po/en
	msgen $< -o $@

data/locale/en/LC_MESSAGES/as2api.mo: po/en/as2api.po
	mkdir -p data/locale/en/LC_MESSAGES
	rmsgfmt $< -o $@

data/locale/i_piglatin/LC_MESSAGES/as2api.mo: po/i_piglatin/as2api.po
	mkdir -p data/locale/i_piglatin/LC_MESSAGES
	rmsgfmt $< -o $@

data/locale/pl/LC_MESSAGES/as2api.mo: po/pl/as2api.po
	mkdir -p data/locale/pl/LC_MESSAGES
	rmsgfmt $< -o $@
