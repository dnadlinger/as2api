
xsltproc=xsltproc
docbook_stylesheet=/usr/share/sgml/docbook/stylesheet/xsl/nwalsh/fo/docbook.xsl
java_home=~/opt/j2sdk1.4.2_05
fop=~/incoming/fop-0.20.5/fop.sh

sources = documenter.rb doc_comment.rb xmlwriter.rb html_output.rb parse/lexer.rb parse/parser.rb parse/as_io.rb api_loader.rb api_model.rb
dist_files = ${sources} style.css as2api-documentation.pdf

version = 0.2

dist_dir = as2api-${version}
tgz_name = ${dist_dir}.tar.gz
w32_dist_dir = as2api-allinone-w32-${version}
zip_name = ${w32_dist_dir}.zip

dist: tgz zip

tgz: docs
	mkdir -p ${dist_dir}
	cp --parents ${dist_files} ${dist_dir}
	tar czvf ${tgz_name} ${dist_dir}
	rm -r ${dist_dir}

zip: docs
	mkdir -p ${w32_dist_dir}
	cp as2api_win32.exe style.css ${w32_dist_dir}
	zip -r ${zip_name} ${w32_dist_dir}
	rm -r ${w32_dist_dir}

test:
	ruby -w ts.rb

clean:
	rm -rf ${tgz_name} ${zip_name} ${w32_dist_dir} ${dist_dir}


docs: as2api-documentation.pdf


as2api-documentation.fo: as2api-documentation.xml
	${xsltproc} --stringparam shade.verbatim 1 \
	            --stringparam fop.extensions 1 \
		    ${docbook_stylesheet} \
		    as2api-documentation.xml \
				> as2api-documentation.fo

as2api-documentation.pdf: as2api-documentation.fo
	JAVA_HOME=${java_home} \
	${fop} as2api-documentation.fo -pdf as2api-documentation.pdf
