
sources = documenter.rb doc_comment.rb xmlwriter.rb html_output.rb parse/lexer.rb parse/parser.rb parse/as_io.rb api_loader.rb api_model.rb
dist_files = ${sources} style.css

version = 0.2

dist_dir = as2api-${version}
tgz_name = ${dist_dir}.tar.gz
w32_dist_dir = as2api-allinone-w32-${version}
zip_name = ${w32_dist_dir}.zip

dist: tgz zip

tgz:
	mkdir -p ${dist_dir}
	cp --parents ${dist_files} ${dist_dir}
	tar czvf ${tgz_name} ${dist_dir}
	rm -r ${dist_dir}

zip:
	mkdir -p ${w32_dist_dir}
	cp as2api_win32.exe style.css ${w32_dist_dir}
	zip -r ${zip_name} ${w32_dist_dir}
	rm -r ${w32_dist_dir}

test:
	ruby -w ts.rb

clean:
	rm -rf ${tgz_name} ${zip_name} ${w32_dist_dir} ${dist_dir}
